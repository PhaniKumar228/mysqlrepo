/*
Shrink DBs - Job Script

I'm posting this job script because it gets used by my scheduler script. 
It simply enumerates through each database on the server, and then executes a DBCC SHRINKDATABASE. 
The only wrinkle here is that I have it do a quick check to make sure that certain jobs are not already running. 

*/


BEGIN TRANSACTION            
  DECLARE @JobID BINARY(16)  
  DECLARE @ReturnCode INT    
  SELECT @ReturnCode = 0     
IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'Database Maintenance') < 1 
  EXECUTE msdb.dbo.sp_add_category @name = N'Database Maintenance'

  -- Delete the job with the same name (if it exists)
  SELECT @JobID = job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'Shrink DBs')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''Shrink DBs'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'Shrink DBs' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'Shrink DBs', @owner_login_name = N'sa', @description = N'No description available.', @category_name = N'Database Maintenance', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'No other jobs running', @command = N'DECLARE
	@result int,
	@is_sysadmin INT,
	@job_owner   sysname

set @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N''sysadmin''), 0)
set @job_owner = SUSER_SNAME()

CREATE TABLE #xp_results (job_id                UNIQUEIDENTIFIER NOT NULL,
             last_run_date         INT              NOT NULL,
	     last_run_time         INT              NOT NULL,
             next_run_date         INT              NOT NULL,
             next_run_time         INT              NOT NULL,
             next_run_schedule_id  INT              NOT NULL,
             requested_to_run      INT              NOT NULL, -- BOOL
             request_source        INT              NOT NULL,
             request_source_id     sysname          NULL,
             running               INT              NOT NULL, -- BOOL
             current_step          INT              NOT NULL,
             current_retry_attempt INT              NOT NULL,
             job_state             INT              NOT NULL)

INSERT INTO #xp_results
EXECUTE master..xp_sqlagent_enum_jobs  @is_sysadmin, @job_owner

SELECT @result=count(*)
FROM #xp_results x
INNER JOIN msdb..sysjobs s
ON x.job_id=s.job_id
WHERE x.running>0
AND s.[name] not in (
	''Shrink DBs'',
	''Tri-Weekly Job Scheduler'',
	''Hourly Job Scheduler'',
	''Daily Job Scheduler'',
	''Master Job Scheduler''
	)

SET @result=ISNULL(@result,-1)

DROP TABLE #xp_results

IF(@RESULT>0)
	RAISERROR (''Job Running'', 16, 1)
', @database_name = N'msdb', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 20, @retry_interval = 12, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 1
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 2, @step_name = N'Shrink Em', @command = N'declare
	@db varchar(500),
	@device varchar(500),
	@file varchar(500),
	@cmd varchar(500),
	@tries tinyint
begin
	declare #cd cursor local fast_forward for
	select [name] from master..sysdatabases
	where [name] not in (''tempdb'',''master'')

	open #cd
	fetch next from #cd into @db
	
	while(@@fetch_status=0)
	begin
		set @device=''d''+replace(@db,'' '',''_'')
		set @file=''f:\mssql7\backup\''+replace(@db,'' '',''_'')+''.bak''
		set @cmd = ''del ''+@file
		set @tries=0

--		exec(''backup log [''+@db+''] to ''+@device)
--		exec(''sp_addumpdevice ''''disk'''',''''''+@device+'''''',''''j:\mssql7\backup\''+@db+''.bak'''''')
/*		exec(''backup database [''+@db+''] to ''+@device+'' with differential, retaindays=0, init'')
		while (@tries<1) and (@@error in (3266, 3013))
		begin
			set @tries=@tries + 1
			exec master..xp_cmdshell @cmd
			exec(''backup database [''+@db+''] to ''+@device+'' with differential, retaindays=0, init'')
		end
		exec(''backup log [''+@db+''] with truncate_only'')
*/
		select @db as DB
		exec(''DBCC SHRINKDATABASE ([''+@db+''], 10)'')
		fetch next from #cd into @db
	end
	
	close #cd
	deallocate #cd

end
', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'Rinse and Repeat', @enabled = 1, @freq_type = 4, @active_start_date = 20010705, @active_start_time = 3000, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 12, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 185959
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



