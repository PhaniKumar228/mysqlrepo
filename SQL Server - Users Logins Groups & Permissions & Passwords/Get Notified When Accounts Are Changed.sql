/*
Get Notified When Accounts Are Changed

Perfect for finding developers that are changing your database accouts.  
This procedure can check the sysusers table for each database and\or the master..syslogins table for account changes.  
Gives the option of email notification, logging to a table or both. 

Update the set statements at the begining of the procedure to configure it however you like.  
It will create any tables it requires for you.  

The procedure accepts on parameter for the number of days back to report a change on. 
I would suggest setting this up as a scheduled procedure, so if you run the report daily pass in a 1, weekly a 7, etc.  
If there is an account change detected and you use the CreateBackupTable option you can then compare the account records before and after the change to find out what the user changed.  If you want to create a new copy of the backup tables, just delete them and they will be recreated the next time it runs.

*/

create procedure AccountChangeCheck (@iDaysDiff int = 1)
as

declare @sSql varchar(8000)
declare @sDBName varchar(128)
declare @sUserName varchar(128)
declare @sLoggingDB varchar(128)
declare @sLoggingTable varchar(128)
declare @sLoggingDBTable varchar(256)
declare @sEmailAddress varchar(128)
declare @iLoggingEnabled int
declare @iEmailEnabled int
declare @iCreateBackupTable int
declare @iCheckMasterOnly int

set nocount on

-- Pass the Number of days back to check for Account changes to the procedure

set @iLoggingEnabled = 1 	-- Set to 1 to enable logging a logging table will be created
                         	-- a logging database name and table is required if you enable logging
set @iCreateBackupTable = 1	-- Set to 1 if you would like to create a backup table in each database
                            	-- each backup table will be appended with the name '_backup'
                            	-- The backup table can be used to compare the changes that were made.
set @sLoggingDB = 'eoperationsdba' 
set @sLoggingTable = 'AccountChangeLog' 
set @iEmailEnabled = 1 		-- Set to 1 to enable email notification
set @sEmailAddress = 'youremail@yourdomain.com'
set @iCheckMasterOnly = 0 	-- Set to 1 to only check the master..syslogins table

select @sUserName = user
set @sLoggingDBTable = @sLoggingDB + '.' + @sUserName + '.' + @sLoggingTable

declare c1 cursor fast_forward for select name from master..sysdatabases
open c1
fetch next from c1 into @sDBName

while @@fetch_status = 0
begin
   if @sDBName = 'master' and @iCreateBackupTable = 1
   begin
      select @sSql = 'if not exists (select * from ' + @sDBName + '.dbo.sysobjects where type = ''u'' and name = ''syslogins_backup'')
            begin
               create table ' + @sDBName + '.' + @sUserName + '.syslogins_backup (
                  sid		varbinary(85),
                  status	smallint,
                  createdate	datetime,
                  updatedate	datetime,
                  accdate	datetime,
                  totcpu	int,
                  totio		int,
                  spacelimit	int,
                  timelimit	int,
                  resultlimit	int,
                  name		nvarchar(256),
                  dbname	nvarchar(256),
                  password	nvarchar(256),
                  language	nvarchar(256),
                  denylogin	int,
                  hasaccess	int,
                  isntname	int,
                  isntgroup	int,
                  isntuser	int,
                  sysadmin	int,
                  securityadmin	int,
                  serveradmin	int,
                  setupadmin	int,
                  processadmin	int,
                  diskadmin	int,
                  dbcreator	int,
                  bulkadmin	int,
                  loginname	nvarchar(256))
               insert into ' + @sDBName + '.' + @sUserName + '.syslogins_backup select * from ' + @sDBName + '.dbo.syslogins
            end' + char(13)
--         print @sSql
         exec(@sSql)

   end
   if @iCreateBackupTable = 1
   begin
      select @sSql = 'if not exists (select * from ' + @sDBName + '.dbo.sysobjects where type = ''u'' and name = ''sysusers_backup'')
         begin
            create table ' + @sDBName + '.' + @sUserName + '.sysusers_backup (
               uid		smallint,
               status		smallint,
               name		sysname,
               sid		varbinary(85),
               roles		varbinary(2048),
               createdate	datetime,
               updatedate	datetime,
               altuid		smallint,
               password		varbinary(256),
               gid		smallint,
               environ		varchar(255),
               hasdbaccess	int,
               islogin		int,
               inntname		int,
               isntgroup	int,
               isntuser		int,
               issqluser	int,
               isaliases	int,
               issqlrole	int,
               isapprole	int)
            insert into ' + @sDBName + '.' + @sUserName + '.sysusers_backup select * from ' + @sDBName + '.dbo.sysusers
         end' + char(13)
--      print @sSql
      exec(@sSql)

   end

-- Begin Account Checks

   if @sDBName = 'master'
   begin
      select @sSql = 'if exists (select * from master.dbo.syslogins where updatedate > dateadd(dd,-' + convert(varchar(5),@iDaysDiff) + ',getdate()))
                   begin
                      -- Should the change be logged?
                      if '  + convert(varchar(1),@iLoggingEnabled) + ' = 1 -- Log account change check
                      begin
                         if not exists(select * from ' + @sLoggingDB + '..sysobjects where type = ''u'' and name = ''' + @sLoggingTable + ''')
                         begin
                            create table ' + @sLoggingDBTable + ' (
                               DBName		Varchar(128),
                               uid		smallint,
                               name		sysname,
                               createdate	datetime,
                               updatedate	datetime,
                               hasdbaccess	int)
                         end
                         insert into  ' + @sLoggingDBTable + ' (DBName, name, createdate, updatedate, hasdbaccess) select ''' + @sDBName + ''', name, createdate, updatedate, hasaccess from master.dbo.syslogins where updatedate > dateadd(dd,-' + convert(varchar(5),@iDaysDiff) + ',getdate())
                      end
                      if '  + convert(varchar(1),@iEmailEnabled) + ' = 1 --Send email check
                      begin
			-- Create Message Body
			declare @query varchar(2000)
			select @query = ''print ''''Account Information Has Been Updated in Database: ' + @sDBname + '''''
					select name, createdate, updatedate, hasaccess, sysadmin  from master.dbo.syslogins where updatedate > dateadd(dd,-' + convert(varchar(5),@iDaysDiff) + ',getdate())''
			exec master..xp_sendmail @recipients = ''' + @sEmailAddress + ''',
						@subject = ''Database Account Changed'',
						@query = @query,
                                                @width = 1000,
                                                @attach_results = ''true''
                      end
                   end'
--      print @sSql
      exec(@sSql)
   end
   if @iCheckMasterOnly <> 1
   begin
      select @sSql = 'if exists (select * from ' + @sDBName + '.dbo.sysusers where updatedate > dateadd(dd,-' + convert(varchar(5),@iDaysDiff) + ',getdate()))
                   begin
                      -- Should the change be logged?
                      if '  + convert(varchar(1),@iLoggingEnabled) + ' = 1 -- Log account change check
                      begin
                         if not exists(select * from ' + @sLoggingDB + '..sysobjects where type = ''u'' and name = ''' + @sLoggingTable + ''')
                         begin
                            create table ' + @sLoggingDBTable + ' (
                               DBName		Varchar(128),
                               uid		smallint,
                               name		sysname,
                               createdate	datetime,
                               updatedate	datetime,
                               hasdbaccess	int)
                         end
                         insert into  ' + @sLoggingDBTable + ' select ''' + @sDBName + ''', uid, name, createdate, updatedate, hasdbaccess from ' + @sDBName + '.dbo.sysusers where updatedate > dateadd(dd,-' + convert(varchar(5),@iDaysDiff) + ',getdate())
                      end
                      if '  + convert(varchar(1),@iEmailEnabled) + ' = 1 --Send email check
                      begin
			-- Create Message Body
			declare @query varchar(2000)
			select @query = ''print ''''Account Information Has Been Updated in Database: ' + @sDBname + '''''
					select uid, name, createdate, updatedate, hasdbaccess from ' + @sDBName + '.dbo.sysusers where updatedate > dateadd(dd,-' + convert(varchar(5),@iDaysDiff) + ',getdate())''
			exec master..xp_sendmail @recipients = ''' + @sEmailAddress + ''',
						@subject = ''Database Account Changed'',
						@query = @query,
                                                @width = 1000,
                                                @attach_results = ''true''
                      end
                   end'
--      print @sSql
      exec(@sSql)
   end
fetch next from c1 into @sDBName
end
close c1 
deallocate c1






