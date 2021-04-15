/*

sp_GetLoginInfo
Returns SQL server logins as a runnable script. 
Not a cleanup script. (updated 7/14/2004 to handle longer passwords that occurred in a previous service pack.) 

*/

if exists (select * 
              from dbo.sysobjects 
              where id = object_id(N'[dbo].[sp_GetLoginInfo]') 
              and OBJECTPROPERTY(id, N'IsProcedure') = 1)
   drop procedure [dbo].[sp_GetLoginInfo]
GO

Create procedure [dbo].[sp_GetLoginInfo]
as

/*******************************************************************/
--Name        : sp_GetLoginInfo
--Server      : Generic
--
--Description : Captures SQL Login info. 
--            : Works in ISQL/W, ISQL, OSQL & Query Analyzer
--Date        : 07/29/2001
--Author      : Clint Herring
--
--History     : 
/*******************************************************************/

Set NOCOUNT On
Print '-- Server: ' + @@servername
Print '-- Date captured: ' + convert(varchar(26), GetDate(),113)

-- Declare variable(s)
Declare @rtn int

print ''
Print '-- This output is a runnable script. Restores logins and server role memberships.'
--Getting nt login info
print '-- Script for restoring nt sql logins...'
select 'Exec sp_grantlogin ''' + loginname + ''''
  from master.dbo.syslogins 
 where isntname = 1
   and name <> 'Administrator'
   and name <> 'BUILTIN\Administrators'
   and name is not null

--Getting sql login info
print ''
print '-- Script for restoring std sql logins...'
select cast('Exec sp_addlogin ''' + a.loginname + ''', ' as varchar(40)),
	     convert(varbinary(60),b.password),
	     cast(',''' + a.dbname + ''', ' +
	     '''' + a.language + ''', ' as varchar(35)),
             convert(varbinary(20),b.sid),
	     ',''skip_encryption'' '
  from master.dbo.syslogins a,
       master.dbo.sysxlogins b
 where a.isntname = 0
   and a.sid = b.sid
   and b.name not in ('sa','repl_publisher','repl_subscriber')
 order by b.name
Print ''

--Getting server role info
print ''
print '-- Scripts for restoring server role members...'
select 'Exec sp_addsrvrolemember ''' + name + ''',''sysadmin''' 
  from sysxlogins
 where xstatus&16 = 16
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
select 'Exec sp_addsrvrolemember ''' + name + ''',''securityadmin'''
  from sysxlogins
 where xstatus&32 = 32
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
select 'Exec sp_addsrvrolemember ''' + name + ''',''serveradmin'''
  from sysxlogins
 where xstatus&64 = 64
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
select 'Exec sp_addsrvrolemember ''' + name + ''',''setupadmin'''
  from sysxlogins
 where xstatus&128 = 128
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
select 'Exec sp_addsrvrolemember ''' + name + ''',''processadmin'''
  from sysxlogins
 where xstatus&256 = 256
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
select 'Exec sp_addsrvrolemember ''' + name + ''',''diskadmin'''
  from sysxlogins
 where xstatus&512 = 512
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
select 'Exec sp_addsrvrolemember ''' + name + ''',''dbcreator'''
  from sysxlogins
 where xstatus&1024 = 1024
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0

go

