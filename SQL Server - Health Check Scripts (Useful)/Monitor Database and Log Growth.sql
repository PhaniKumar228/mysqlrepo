/*
Monitor Database and Log Growth

Most DBA's would like to be notified when automatic database file growth occurs. 
This script will log file growth. It will not log file shrink but could be easily modifed to do so.

Script does the following: 
1. create tables to store server list, current & historical file sizes and actual growth for each database file 
2. add a user-defined error message to state that file size has changed 
3. create an alert for that message that will notify an operator of file growth 
4. create stored procedure to compare the current file size and the stored file size. If file size has changed this stored procedure will raise the error and it will trigger the alert. 
5. create a scheduled job to run the procedure regularly. 


*/

/*

Most DBA's would like to be notified when automatic database file growth occurs. 
This script will log file growth.  
It will not log file shrink but could be easily modifed to do so.

Script does the following: 
1. create tables to store server list, current & historical file sizes and actual growth for each database file 
2. add a user-defined error message to state that file size has changed 
3. create an alert for that message that will notify an operator of file growth  
4. create stored procedure to compare the current file size and the stored file size. 
If file size has changed this stored procedure will raise the error and it will trigger the alert. 
5. create a scheduled job to run the procedure regularly. 

NOTES:   
** This is done from a single SQL Server that is used for administrative purposes.  You must add linked servers to all of the servers that you want to check.
** Populate the serverlist table with the names of the servers that you want to check.
** I have set the proc to clean out historical records more than 10 days old.  You can modify this parameter if you want.  
         There is really no reason to keep much historical data since growth is logged to the dbfile_growth_info table.
** In the procedure, the variable @xlist holds an exclusion list of databases that I do not want to check.  You can modify this list to your requirements.
** You can modify the job schedule to your requirements. I scheduled mine to run every 2 hours.
*/

--
--Replace string <operator_name> with the operator name
--Replace string <admindatabase> with the administrative database name 
--
USE <admindatabase>
GO
--serverlist table holds names of all servers that are checked
CREATE TABLE [dbo].[serverlist] (
	[srvrname] [varchar] (30) NULL 
) ON [PRIMARY]
GO
--current_dbfile_info will hold the most recent file stats.  
--The contents of this table are first put into the historical_dbfile_info table and then truncated each time the proc is run.
CREATE TABLE [dbo].[current_dbfile_info] (
	[servername] [varchar] (50) NULL ,
	[dbname] [varchar] (50) NULL ,
	[fileid] [int] NOT NULL ,
	[statdate] [datetime] NULL ,
	[size] [int] NULL ,
	[sizeMB] [int] NULL ,
	[filename] [varchar] (250) NULL 
) ON [PRIMARY]
GO
--historical_dbfile_info table will hold historical stats.
--The column mostrecentstat when set to 1 will indicate that the record is the most recent and is used to identify the record to compare against the current stat.
CREATE TABLE [dbo].[historical_dbfile_info] (
	[statdate] [datetime] NOT NULL ,
	[servername] [varchar] (50) NOT NULL ,
	[dbname] [varchar] (50) NOT NULL ,
	[fileid] [int] NOT NULL ,
	[size] [int] NULL ,
	[sizeMB] [int] NULL ,
	[filename] [varchar] (250) NOT NULL ,
	[mostrecentstat] [smallint] NOT NULL 
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[historical_dbfile_info] ADD 
	CONSTRAINT [DF_historical_dbfile_info_mostrecentstat] DEFAULT (0) FOR [mostrecentstat],
	CONSTRAINT [PK_historical_dbfile_info] PRIMARY KEY  CLUSTERED 
	(
		[fileid],
		[statdate],
		[servername],
		[dbname]
	)  ON [PRIMARY] 
GO
--dbfile_growth_info table will hold only records of growth.
--this table is used for reporting and to monitor over time when file growth occurred
CREATE TABLE [dbo].[dbfile_growth_info] (
	[statdate] [datetime] NOT NULL ,
	[servername] [varchar] (50) NOT NULL ,
	[dbname] [varchar] (50) NOT NULL ,
	[filename] [varchar] (250) NOT NULL ,
	[sizeMBnow] [int] NULL ,
	[sizeMBwas] [int] NULL 
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[dbfile_growth_info] ADD 
	CONSTRAINT [PK_dbfile_growth_info] PRIMARY KEY  CLUSTERED 
	(
		[statdate],
		[servername],
		[dbname],
		[filename]
	)  ON [PRIMARY] 
GO

--add a user-defined error message to state that file size has changed
EXEC sp_addmessage @msgnum = 60000, @severity = 16, 
    	@msgtext = N'A database file has auto grown. Check dbfile_growth_xstatdt or dbfile_growth_xdb for information.',
    	@lang = 'us_english',
      @replace = REPLACE
GO
--create an alert for that message. This alert will send email to an operator.
IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'Database file has changed size'))
 	---- Delete the alert with the same name if one already exists.
  	EXECUTE msdb.dbo.sp_delete_alert @name = N'Database file has changed size' 
	BEGIN 
--Add alert
EXECUTE msdb.dbo.sp_add_alert @name = N'Database file has changed size', @message_id = 60000,
	@severity = 0, @enabled = 1, @delay_between_responses = 0, @include_event_description_in = 5, 
	@category_name = N'[Uncategorized]'
--notify operator
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'Database file has changed size', 
	@operator_name = N'<operator_name>', @notification_method = 1
END
GO

--view to see growth by most recent statdate
CREATE VIEW dbo.dbfile_growth_xstatdt
AS
SELECT TOP 20 statdate, servername, dbname, filename, sizeMBnow, sizeMBwas 
FROM dbo.dbfile_growth_info
ORDER BY statdate DESC, servername ASC, dbname ASC
GO

--view to see growth grouped by db
CREATE VIEW dbo.dbfile_growth_xdb
AS
SELECT TOP 20 statdate, servername, dbname, filename, sizeMBnow, sizeMBwas 
FROM dbo.dbfile_growth_info
ORDER BY servername ASC, dbname ASC, statdate DESC
GO

--Create the procedure
CREATE PROCEDURE dbo.monitor_file_growth
AS
SET NOCOUNT ON
--set mostrecentstat flag to no in historical table
UPDATE dbo.historical_dbfile_info SET mostrecentstat = 0 WHERE mostrecentstat = 1
--move current to historical table with mostrecentstat flag set to yes
INSERT INTO dbo.historical_dbfile_info (statdate,servername,dbname,fileid,[size],sizeMB,filename,mostrecentstat)
   (SELECT statdate,servername,dbname,fileid,[size],sizeMB,filename,1 FROM dbo.current_dbfile_info)
--only keep 10 days of historical data
DELETE FROM dbo.historical_dbfile_info WHERE statdate < getdate()-10 
--get rid of old current data
TRUNCATE TABLE dbo.current_dbfile_info
--declare variables
DECLARE @SQLString NVARCHAR(500)
DECLARE @SQLStr1 NVARCHAR(500)
DECLARE @SQLStr2 NVARCHAR(500)
DECLARE @xlist VARCHAR(100)      --db exclusion list
DECLARE @sn VARCHAR(32)          
DECLARE @dbn VARCHAR(32)
--list of servers cursor
DECLARE listservers CURSOR FOR
SELECT srvrname FROM dbo.serverlist
--open server cursor
OPEN listservers
--get first server to process
FETCH next FROM listservers INTO @sn
--begin server loop
WHILE (@@FETCH_STATUS = 0)
BEGIN
   --run for each database on the server
   --Declare cursor for holding the names of all databases on the server
   SET @xlist = '''master'',''model'',''msdb'',''distribution'',''Northwind'',''pubs'',''tempdb''' 
   SET @SQLStr1 = 'DECLARE listdbs CURSOR FOR SELECT name FROM ['+@sn+'].master.dbo.sysdatabases WHERE name NOT IN('+@xlist+')'
   EXEC sp_executesql @SQLStr1
   --open database cursor
   OPEN listdbs
   --get first database to process
   FETCH NEXT FROM listdbs INTO @dbn
   --begin database loop
   WHILE (@@FETCH_STATUS = 0)
   BEGIN
      --add new current data
      SET @SQLStr2 = 'INSERT INTO current_dbfile_info SELECT '''+@sn+''', '''+@dbn+''', fileid, getdate(), size, ((size*8)/1024), filename FROM ['+@sn+'].['+@dbn+'].dbo.sysfiles'
      EXEC sp_executesql @SQLStr2
      -- Get next database to process
      FETCH NEXT FROM listdbs INTO @dbn
   END  --end database loop
   --clean up database cursor
   CLOSE listdbs
   DEALLOCATE listdbs
   --get next server to process
   FETCH next FROM listservers INTO @sn
END  --end server loop
--clean up server cursor
CLOSE listservers
DEALLOCATE listservers
-- compare the current size against the stored file size  
--if the current size is larget than the historical size then it is logged into dbfile_growth_info table for reporting and error is raised that will alert the DBA of the file growth
IF EXISTS (SELECT 1 FROM dbo.current_dbfile_info c JOIN dbo.historical_dbfile_info h 
	ON (c.servername = h.servername AND c.dbname = h.dbname AND c.fileid = h.fileid)
		WHERE h.mostrecentstat = 1 AND (c.sizeMB > h.sizeMB))
BEGIN
   INSERT INTO dbo.dbfile_growth_info 
      SELECT c.statdate, c.servername, c.dbname, c.filename, c.sizeMB, h.sizeMB FROM dbo.current_dbfile_info c JOIN dbo.historical_dbfile_info h 
	      ON (c.servername = h.servername AND c.dbname = h.dbname AND c.fileid = h.fileid)
         WHERE h.mostrecentstat = 1 AND (c.sizeMB > h.sizeMB)
         ORDER BY c.statdate, c.servername, c.dbname, c.filename

   RAISERROR(60000, 16, 1) WITH LOG
END
GO

--Create the job to run the proc
BEGIN TRANSACTION            
  DECLARE @JobID BINARY(16)  
  DECLARE @ReturnCode INT    
  SELECT @ReturnCode = 0     
IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'AdminJobs') < 1 
  EXECUTE msdb.dbo.sp_add_category @name = N'AdminJobs'

  -- Delete the job with the same name (if it exists)
  SELECT @JobID = job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'Monitor File Growth')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''Monitor File Growth'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'Monitor File Growth' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'Monitor File Growth', @owner_login_name = N'sa', @description = N'Checks file size for all db''s on all servers and will send notification if the size changes.', @category_name = N'AdminJobs', @enabled = 1, @notify_level_email = 2, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0, @notify_email_operator_name = N'<operator_name>'
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'Check db file size', @command = N'EXEC dbo.monitor_file_growth', @database_name = N'<admindatabase>', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'Check db file growth schedule', @enabled = 1, @freq_type = 4, @active_start_date = 20050711, @active_start_time = 0, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 2, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 235959
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the Target Servers
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)' 
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

END
COMMIT TRANSACTION          
GOTO   EndSave              
QuitWithRollback:
  IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION 
EndSave: 
