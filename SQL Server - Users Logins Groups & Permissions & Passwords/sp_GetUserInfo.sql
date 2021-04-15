/*
sp_GetUserInfo
Returns database user information as a runnable script for the specified database. 
The default is master. 
Great for restoring user access and permissions after a restore to a development server. 
Run prior to the restore and save the output to an sql file. 

*/

if exists (select * 
             from dbo.sysobjects 
            where id = object_id(N'[dbo].[sp_GetUserInfo]') 
              and OBJECTPROPERTY(id, N'IsProcedure') = 1)
   drop procedure [dbo].[sp_GetUserInfo]
GO

Create procedure [dbo].[sp_GetUserInfo]
       @dbname varchar(30) = 'master'
as

/*******************************************************************/
--Name        : sp_GetUserInfo
--Server      : Generic
--Description : Captures database user info. 
--            : Works in ISQL/W, ISQL, OSQL & Query Analyzer
/*******************************************************************/

Set NOCOUNT On
Print '-- Server: ' + @@servername
Print '-- Database: ' + @dbname
Print '-- Date captured: ' + convert(varchar(26), GetDate(),113)

-- Declare variable(s)
Declare @rtn int

--Getting database user info
print ''
print '-- Scripts for restoring database user info...'
print ''
select 'use ' + @dbname
exec( 'If exists(select * ' +
                  'from ' + @dbname + '.dbo.sysusers ' +
                 'where sid not in(select sid from master.dbo.syslogins) ' +
                    'and name <> ''guest'') ' +
         'Begin ' +
            'Print ''-- These users have sids that are different than their login sids:'' ' +
            'Select ''-- '' + name ' +
              'from ' + @dbname + '.dbo.sysusers ' +
             'where sid not in(select sid from master.dbo.syslogins) ' +
               'and name <> ''guest'' ' +
         'End')
select '     -- Scripts for adding roles'
exec( 'select ''     exec sp_addrole N'''''' + name + ''''''''' + 
      ' from ' + @dbname + 
      '.dbo.sysusers where uid > 16393')
select '     -- Scripts for adding users'
exec( 'select ''     exec sp_grantdbaccess N'''''' + b.loginname + '''''',N'''''' + a.name + ''''''''' + 
      ' from ' + @dbname + 
      '.dbo.sysusers a join master.dbo.syslogins b on a.sid = b.sid where a.uid > 3 and a.uid < 16384')
select '     -- Scripts for adding role members'
exec( 'select ''     exec sp_addrolemember N'''''' + b.name + '''''',N'''''' + a.name + ''''''''' + 
      ' from ' + @dbname + 
      '.dbo.sysusers a, ' +
      @dbname + '.dbo.sysusers b, ' +
      @dbname + '.dbo.sysmembers c ' +
      'where a.uid = c.memberuid ' +
      'and a.uid > 3 ' + --and a.uid < 16384 ' +
      'and b.uid = c.groupuid')
print '' 
select '     -- Scripts for granting user & role permissions'
Exec ('select case when action = 26  then ''     Grant REFERENCES'' ' +
                   'when action = 193 then ''     Grant SELECT'' ' +
                   'when action = 195 then ''     Grant INSERT'' ' +
                   'when action = 196 then ''     Grant DELETE'' ' +
                   'when action = 197 then ''     Grant UPDATE'' ' +
                   'when action = 198 then ''     Grant CREATE TABLE'' ' +
                   'when action = 203 then ''     Grant CREATE DATABASE'' ' +
                   'when action = 207 then ''     Grant CREATE VIEW'' ' +
                   'when action = 222 then ''     Grant CREATE PROCEDURE'' ' +
                   'when action = 224 then ''     Grant EXECUTE'' ' +
                   'when action = 228 then ''     Grant DUMP DATABASE'' ' +
                   'when action = 233 then ''     Grant CREATE DEFAULT'' ' +
                   'when action = 235 then ''     Grant DUMP TRANSACTION'' ' +
                   'when action = 236 then ''     Grant CREATE RULE'' ' +
                   'else '''' ' +
              'end + ' +
              ''' on '' + d.name + ''.'' + b.name + '' to '' + c.name + char(13) + char(10) + ''     go'' ' +
       'from ' + @dbname + '.dbo.sysprotects a,  ' +
            @dbname + '.dbo.sysobjects b,  ' +
            @dbname + '.dbo.sysusers c,  ' +
            @dbname + '.dbo.sysusers d  ' +
       'where a.id = b.id  ' +
         'and a.uid = c.uid ' + 
         'and a.uid >= 0  ' +
         'and a.protecttype = 205 ' +
         'and b.uid = d.uid ' + 
         'and b.xtype <> ''S'' ' + 
         'and b.status >= 0 ' + 
       'order by c.name, ' + 
                'b.name,  ' +
                'action ')

go

Grant Execute on [dbo].[sp_GetUserInfo] to public
go
