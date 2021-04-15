/*
SQL-LOG-DAILY CYCLE - Job Script

Simple job script to cycle the SQL Log ever 24 hours
The job is set to disabled as you should review any script that creates a job before enabling it on your server.

*/

-- Simple Job Script to cycle the SQL Error Log every 24 hours
-- 	1. Should set the SQL Log files retention to 15 days (default = 6)
-- 	2. This assists in keeping large logs manageable
-- NOTES:
--	@output_file_name is a settable path value
-- 	@enabled is set to 0 (disabled) so you can review the 
--		job before attempting to run it
--	@owner_login_name Set to SA however you may wish to use
--		another existing service account
-- 	@active_start_time = 235900 This is 11:59:00 PM 
--		and is alterable as needed


BEGIN TRANSACTION            
  DECLARE 	@JobID 		BINARY(16)  
  DECLARE 	@ReturnCode 	INT    
  SELECT 	@ReturnCode 	= 0     
IF (SELECT COUNT(*) 
FROM msdb.dbo.syscategories 
	WHERE name = N'Database Maintenance') 	< 1 
EXECUTE msdb.dbo.sp_add_category @name 		= N'Database Maintenance'

-- Delete the job with the same name (if it exists)
  
SELECT @JobID 		= job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'SQL-LOG-DAILY CYCLE')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
-- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
-- There is, so abort the script 
    RAISERROR (N'Unable to import job ''SQL-LOG-DAILY CYCLE'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'SQL-LOG-DAILY CYCLE' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  
EXECUTE @ReturnCode 		= msdb.dbo.sp_add_job @job_id = @JobID OUTPUT 
	,@job_name 		= N'SQL-LOG-DAILY CYCLE'
	,@owner_login_name 	= N'SA'
	,@description 		= N'Cycle the SQL Server Error log every 24 hours'
	,@category_name 	= N'Database Maintenance'
	,@enabled 		= 1
	,@notify_level_email 	= 0
	,@notify_level_page 	= 0
	,@notify_level_netsend 	= 0
	,@notify_level_eventlog = 2
	,@delete_level		= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	GOTO QuitWithRollback 

  -- Add the job steps
  
EXECUTE @ReturnCode 		= msdb.dbo.sp_add_jobstep @job_id = @JobID
	, @step_id 		= 1
	, @step_name 		= N'Cycle Log (SQL Error Log)'
	, @command 		= N'EXEC SP_CYCLE_ERRORLOG'	
	, @database_name 	= N'master'
	, @server 		= N''
	, @database_user_name 	= N''
	, @subsystem 		= N'TSQL'
	, @cmdexec_success_code = 0
	, @flags 		= 0
	, @retry_attempts 	= 0
	, @retry_interval 	= 1
	, @output_file_name 	= N'C:\Program Files\Microsoft SQL Server\MSSQL\LOG\CYCLE_SQL_ERRORLOG'--Settable Path
	, @on_success_step_id 	= 0
	, @on_success_action 	= 1
	, @on_fail_step_id 	= 0
	, @on_fail_action 	= 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID
	, @start_step_id 	= 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	GOTO QuitWithRollback 

  -- Add the job schedules
  
EXECUTE @ReturnCode 		= msdb.dbo.sp_add_jobschedule @job_id = @JobID
, @name 			= N'CYCLE SQL ERROR LOG DAILY'
, @enabled 			= 0 -- currently disabled to enable set to 1 
, @freq_type 			= 4
, @active_start_date 		= 20040920
, @active_start_time 		= 235900
, @freq_interval 		= 1
, @freq_subday_type 		= 1
, @freq_subday_interval 	= 0
, @freq_relative_interval 	= 0
, @freq_recurrence_factor 	= 0
, @active_end_date 		= 99991231
, @active_end_time 		= 235959
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	GOTO QuitWithRollback 

  -- Add the Target Servers
  
EXECUTE @ReturnCode 		= msdb.dbo.sp_add_jobserver @job_id = @JobID
	, @server_name 		= N'(local)' 
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	GOTO QuitWithRollback 

	END
COMMIT TRANSACTION          
	GOTO   EndSave              
QuitWithRollback:
  IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION 
EndSave: 



