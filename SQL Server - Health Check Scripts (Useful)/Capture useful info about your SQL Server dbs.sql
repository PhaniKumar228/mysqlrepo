/*
Capture useful info about your SQL Server dbs
The server goes down and you are scrambling to remember settings, file names, locations, etc. about your databases 
on that server. This script captures that useful information before a serious problem occurs. 
I run it as an OSQL (ISQL) job and send the output file to my backup folder so the infomation goes to tape each night.
Very useful in a recovery scenario. 
*/

/*******************************************************************/
--Name        : dbinfo.sql
--Server      : Generic
--Description : Captures general SQL server info. 
--            : Works in ISQL/W, ISQL, OSQL & Query Analyzer
/*******************************************************************/

Set NOCOUNT On
Use master
Select 'Server: '+ @@Servername
Select substring(@@version,1,27) + 
       substring(@@version,charindex('corporation',@@version) + 13,18) + ' ' +
       'version ' + substring(@@version,charindex('-',@@version) + 2,8) + 
       substring(@@version,charindex(' on ',@@version),47)
Go

-- Create a temp table to hold an db exclude list
If (Select object_id('tempdb.dbo.#dblist')) > 0
   Exec ('Drop table #dblist')
Create table #dblist(dbname sysname null)
Declare @rtn int

-- Exclude list for filename and filegroup info
Insert into #dblist Values('model')
Insert into #dblist Values('Northwind')
Insert into #dblist Values('pubs')
Insert into #dblist Values('tempdb')

Select 'Start time = ', GetDate()
Select 'Running sp_monitor '
Execute ('sp_monitor')
Select 'Running sp_configure '
Execute ('sp_configure')
Select 'Running sp_helpdevice '
Execute ('sp_helpdevice')
Select 'Running sp_helpserver '
Execute ('sp_helpserver')
Select 'Running sp_helpdb '
Execute ('sp_helpdb')
Select 'Running sp_databases '
Execute ('sp_databases')
Select 'Running sp_server_info '
Execute ('sp_server_info')
Select 'Running xp_msver '
Execute ('xp_msver')
Select 'Running xp_loginconfig '
Execute ('xp_loginconfig')
Select 'Running xp_logininfo '
Execute ('xp_logininfo')
Declare @name varchar(30)
   select @name = min(name)
     from sysdatabases
    where name not in (select dbname from #dblist)
   while @name is not null
      begin
         select 'Running sp_helpfilegroup for ' + @name
         exec('use ' + @name + ' exec sp_helpfilegroup')
         select 'Running sp_helpfile for ' + @name

         exec('use ' + @name + ' exec sp_helpfile')
         select @name = min(name)
           from sysdatabases
          where name > @name 
            and name not in (select dbname from #dblist)
      end
Select 'End time = ', GetDate()
Set NOCOUNT Off
Go
