/*
Capture SQL Logins
Captures all SQL Logins at the server level with password and spid unchanged into a sql script. 
Nothing fancy just needed it to do a server move and load into QA.  
*/

/******************************************************************
--Name        : Capture SQL Logins 
--Server      : Generic
--
--Description : Captures SQL Login info. 
--            : Works in ISQL/W, ISQL, OSQL & Query Analyzer
--Date        : 07/29/2001
--History     : 5/18/2004 fixed typos and set the varbinary to 256 
--		to capture passwords properly set varbinary to 85
--		to make sure that user sids are grabbed as well
--	      : 5/25/2004 changed output to file directly
--		using undocumented function
--		master.dbo.fn_varbintohexstr
******************************************************************/

Set NOCOUNT On
DECLARE @path varchar(255)
DECLARE @server_name varchar(255)
DECLARE @user varchar(255)
DECLARE @Status int
DECLARE @bcp varchar(8000)


set @server_name = cast(serverproperty('servername') as varchar(255))
--server name won't work on MSDE version of sql replace with @@SERVERNAME
set @path = '\\bakfile01\hold\spmigration\permissions\'
--path to save to UNC works just fine must have trailing select @user = loginame from master.dbo.sysprocesses where spid = @@SPID
--pulls the login name of the current user to fill out some of the self documentation

create table ##cmdhold
(
cmdid int IDENTITY(1,1),
text varchar(8000)
)
insert into ##cmdhold (text)
values('-- Server: ' + @server_name)
insert into ##cmdhold (text)
values('-- Date captured: ' + convert(varchar(26), GetDate(),113))
insert into ##cmdhold (text)
values('-- This script restores logins and server role memberships.')
--Getting nt login info
insert into ##cmdhold (text)
values('-- Script for restoring nt sql logins...')
insert into ##cmdhold (text)
select 'Exec sp_grantlogin ''' + loginname + ''''
  from master.dbo.syslogins 
 where isntname = 1
   and name <> 'Administrator'
   and name <> 'BUILTIN\Administrators'
   and name is not null


--Getting sql login info
insert into ##cmdhold (text)
values('-- Script for restoring std sql logins...')
insert into ##cmdhold (text)
select cast('Exec sp_addlogin ''' + a.loginname + ''', ' as varchar(60))+' '+
	     upper(master.dbo.fn_varbintohexstr(Convert(varbinary(256), b.password)))+' '+
	     cast(',''' + isnull(a.dbname,'master') + ''', ' +
	     '''' + isnull(a.language,'us_english') + ''', ' as varchar(100))+' '+
             upper(master.dbo.fn_varbintohexstr(Convert(varbinary(85),b.sid)))+' '+
	     ',''skip_encryption'' '
  from master.dbo.syslogins a,
       master.dbo.sysxlogins b
 where a.isntname = 0
   and a.sid = b.sid
   and b.name not in ('sa','repl_publisher','repl_subscriber')
 order by b.name

--Getting server role info
insert into ##cmdhold (text)
values('-- Scripts for restoring server role members...')
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''sysadmin''' 
  from sysxlogins
 where xstatus&16 = 16
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''securityadmin'''
  from sysxlogins
 where xstatus&32 = 32
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''serveradmin'''
  from sysxlogins
 where xstatus&64 = 64
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''setupadmin'''
  from sysxlogins
 where xstatus&128 = 128
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''processadmin'''
  from sysxlogins
 where xstatus&256 = 256
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''diskadmin'''
  from sysxlogins
 where xstatus&512 = 512
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0
insert into ##cmdhold (text)
select 'Exec sp_addsrvrolemember ''' + name + ''',''dbcreator'''
  from sysxlogins
 where xstatus&1024 = 1024
   and name not in ('sa','BUILTIN\Administrators')
   and isrpcinmap = 0
   and ishqoutmap = 0
   and selfoutmap = 0

SELECT @bcp = 'bcp "SELECT rtrim(text) FROM master.dbo.##cmdhold" QUERYOUT "'+@path+'UserLogins_' + @server_name +'.sql" -T -c'
EXEC @Status = master.dbo.xp_cmdshell @bcp, no_output

IF @Status <> 0
BEGIN
	PRINT 'An error ocurred while generating the SQL file.'
END 
ELSE 
begin
	PRINT ''+@path+'UserLogins_' + @server_name +'.sql file generated succesfully.'
end
drop table ##cmdhold

go



