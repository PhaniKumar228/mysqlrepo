/*
    
Script to automatically restore needed log-backups

Given a backupfile with a lot of sequential log-backups, this script automatically restores just those backups out of the file,
which are necessary to bring the database up to a given timelag relating to the original database.
Params are path to backupfile, name of the db to restore to, timelag in minutes. 
 
 
*/

/* **********************************************************************************
   Procedure to restore TA-Logs into the Database
   Params: path of the file containing the TA-log(s) 
                 name of the database to restore into 
                 timelag in minutes for the recovery-database
   ********************************************************************************** */

CREATE PROCEDURE restore_log_backups 
@backupfilepath sysname,
@dbn sysname,
@stop int

AS 
-- declare variables
declare @file smallint
declare @lsn decimal
declare @minlsn decimal
declare @maxlsn decimal
declare @stopat sysname
declare @msg nvarchar(2000)
declare @cmd nvarchar(2000)
DECLARE @oldfile int
declare @backupstartdate datetime
declare @hexlsn nvarchar(22)


-- set defaults
select @lsn = 0
select @minlsn = 0
select @maxlsn = 0
select @oldfile = 0

Print '--- beginning to restore transaktion logs...'

-- convert timelag in minutes to datetime
select @stopat= dateadd(mi,-@stop,getdate()) 

-- temporäre Tabellen erstellen
--drop table #dblog1
--drop table #backupfile_header
select  top 0 * into #dblog1 from  ::fn_dblog( default, default ) 
CREATE TABLE #backupfile_header
(
BackupName nvarchar(128), BackupDescription  nvarchar(255), BackupType smallint, ExpirationDate datetime, Compressed tinyint, Position smallint, DeviceType tinyint,
UserName nvarchar(128), ServerName nvarchar(128), DatabaseName nvarchar(128), DatabaseVersion  int, DatabaseCreationDate  datetime, BackupSize numeric(20,0),
FirstLSN numeric(25,0), LastLSN numeric(25,0), CheckpointLSN  numeric(25,0), DatabaseBackupLSN  numeric(25,0), BackupStartDate  datetime, BackupFinishDate  datetime,
SortOrder smallint,  CodePage smallint, UnicodeLocaleId int, UnicodeComparisonStyle int, CompatibilityLevel  tinyint, SoftwareVendorId  int, SoftwareVersionMajor  int, 
SoftwareVersionMinor  int, SoftwareVersionBuild  int, MachineName nvarchar(128), Flags int, BindingID uniqueidentifier, RecoveryForkID uniqueidentifier,Collation nvarchar(128) 
)
WAITFOR DELAY '00:00:05'

-- get headerinfo from backupfile into table #backupfile_header
insert #backupfile_header exec ('restore headeronly from disk = ''' + @backupfilepath + ''' ' )
WAITFOR DELAY '00:00:05'

-- get current LSN of recovery-database
insert  #dblog1 exec (' use '+@dbn+' select *  from   ::fn_dblog( default, default )')
select @hexlsn = (select min([Current LSN]) from #dblog1)
select @lsn = master.dbo.lsn2dec(@hexlsn)
Print 'The current LSN of database '+@dbn+' is ' + convert(nvarchar,@lsn) + '.'

-- test if backupfile contains the needed TA-backup 
select @minlsn = (select top 1 FirstLsn from #backupfile_header where BackupName = 'SITESQL' order by FirstLsn)
select @maxlsn = (select top 1 LastLsn from #backupfile_header where BackupName = 'SITESQL' order by LastLsn desc)
select @msg = 'The current LSN of database '+@dbn+' is ' + rtrim(convert(char,@lsn)) + ', in the backupfile ' + @backupfilepath + ' are LSN''s from ' + rtrim(convert(char,@minlsn)) + ' to ' + rtrim(convert(char,@maxlsn)) + ' !' 
-- if not raise hell about it
if @lsn < @minlsn or @lsn > @maxlsn
  RAISERROR ( @msg,16,1) with LOG, NOWAIT
else print @msg

-- for all valid TA-backups in the backupfile: recover them, but only up until timelag
while not ((select Position from #backupfile_header where BackupName = 'SITESQL' and FirstLSN<=@lsn and LastLsn>@lsn)) is NULL
begin
-- get current LSN of recovery-database
    delete from #dblog1 
    insert  #dblog1 exec (' use '+@dbn+'  select *  from   ::fn_dblog( default, default )')

--  select @hexlsn = (select min([Current LSN]) from master.dbo.dblog  where Operation = 'LOP_BEGIN_RECOVERY')
  select @hexlsn = (select min([Current LSN]) from #dblog1)
  select @lsn = master.dbo.lsn2dec(@hexlsn)
  Print ''
  Print 'The current LSN of database '+@dbn+' is ' + convert(nvarchar,@lsn) + '.'

-- get fileposition
  select @file = (select Position from #backupfile_header where BackupName = 'SITESQL' and FirstLSN<=@lsn and LastLsn>@lsn)
-- same position twice means problems, break
  if @oldfile = @file  begin 
    Print '--- Restore finished, have been trying to restore twice the same fileposition'
    break
  end
-- get and print some info about current recovery
  select @minlsn = (select FirstLsn from #backupfile_header where BackupName = 'SITESQL' and position = @file)
  select @maxlsn = (select LastLsn from #backupfile_header where BackupName = 'SITESQL' and position = @file)
  select @backupstartdate = (select BackupStartDate from #backupfile_header where BackupName = 'SITESQL' and position = @file)
  Print 'The current position in the backupfile is '+rtrim(convert(char,@file))+', first LSN is '+rtrim(convert(char,@minlsn)) + ', last LSN is ' + rtrim(convert(char,@maxlsn)) + '.'
  Print 'Stopat is "' + @stopat + '", BackupStartDate is "' + rtrim(convert(varchar,@backupstartdate)) + '".'
  if @backupstartdate > dateadd(mi,-@stop,getdate()) Begin
    Print '--No need to restore this backup, it was done at "' + rtrim(convert(varchar,@backupstartdate)) + '", '
    Print 'restoring now just to "' + @stopat + '". ending restore...'
    break
  end
-- kick all users out of the recovery-db
  exec master..user_trennen @dbn
  WAITFOR DELAY '00:00:05'
-- do the actual recovery
  set @cmd = 'RESTORE LOG '+@dbn+'  FROM DISK = ''' + @backupfilepath + '''
  WITH DBO_ONLY, STANDBY = ''e:\undo_'+@dbn+' .ldf'', STOPAT = ''' + @stopat + ''', FILE =  ' + convert(varchar,@file)
  Print 'SQL-Command: "' + @cmd + '".'
  EXEC (@cmd)
  WAITFOR DELAY '00:00:05'
-- memorize fileposition
  select @oldfile = @file
end

drop table #dblog1
drop table #backupfile_header

-- now no more backups in this backupfile
Print 'No more logs to restore from backupfile ' + @backupfilepath + '!. ' + convert(nvarchar,getdate())

Print '--- Ending the restore of transaktion logs...'

GO

