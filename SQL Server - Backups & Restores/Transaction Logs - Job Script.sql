/*
Transaction Logs - Job Script

I've included this job script, because it is used by the scheduler scripts that I've also posted. 
This job is a little more involved than most may need... It first checks to see if certain jobs are running. 
Is so, it waits for a while, and then checks again. 
After that it drops the existing dump devices, and then recreates them for each database 
(MAKE SURE TO CHANGE THE @FILE LOCATION FOR THE DUMP DEVICE). 

Then it deletes the old backup files, and tries to do a differential DB backup. 
If that fails, it tries a full DB backup... After trying twice it continues with a quick truncate of the transaction log.

If it completes the backup without errors, it stops the job. 
If not it then resets the database options, and retries the backup. 
(PLEASE LOOK AT EACH JOB STEP, AND MODIFY/REMOVE ANY PORTIONS THAT SHOULD NOT APPLY OR THAT MAY SPECIFY PHYSICAL PATHS
 THAT DON'T EXIST ON YOUR SERVER). 

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
  WHERE (name = N'Transaction Logs')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''Transaction Logs'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'Transaction Logs' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'Transaction Logs', @owner_login_name = N'sa', @description = N'No description available.', @category_name = N'Database Maintenance', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'No other job running', @command = N'DECLARE
	@result int,
	@is_sysadmin INT,
	@job_owner   sysname,
	@tries int

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

set @tries = 0
set @result = 1

while @result>0 and @tries<60
begin
	truncate table #xp_results

	INSERT INTO #xp_results
	EXECUTE master..xp_sqlagent_enum_jobs  @is_sysadmin, @job_owner

	SELECT @result=count(*)
	FROM #xp_results x
	INNER JOIN msdb..sysjobs s
	ON x.job_id=s.job_id
	WHERE x.running>0
	AND s.[name] not in (
		''Transaction Logs'',
		''Tri-Weekly Job Scheduler'',
		''Hourly Job Scheduler'',
		''Daily Job Scheduler'',
		''Master Job Scheduler''
		)

	SET @result=ISNULL(@result,-1)
	set @tries = @tries + 1

	IF(@RESULT>0)
		waitfor delay ''00:00:15''
end

DROP TABLE #xp_results

IF(@RESULT>0)
	RAISERROR (''Job Running'', 16, 1)
', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 0, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 1
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 2, @step_name = N'remove old trn 1', @command = N'del /s g:\backups\logs\*.trn', @database_name = N'', @server = N'', @database_user_name = N'', @subsystem = N'CmdExec', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 3, @step_name = N'remove old bak 1', @command = N'del /s g:\backups\databases\*.bak', @database_name = N'', @server = N'', @database_user_name = N'', @subsystem = N'CmdExec', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 4, @step_name = N'remove old bak 2', @command = N'del /s j:\mssql7\backup\*.bak', @database_name = N'', @server = N'', @database_user_name = N'', @subsystem = N'CmdExec', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 5, @step_name = N'remove old trn 2', @command = N'del /s j:\mssql7\transaction_logs\*.trn', @database_name = N'', @server = N'', @database_user_name = N'', @subsystem = N'CmdExec', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 6, @step_name = N're-create devices', @command = N'declare
	@db varchar(500),
	@device varchar(500),
	@file varchar(500)
begin
	declare #cd cursor local fast_forward for
	select [name] from master..sysdatabases
	where [name] not in (''tempdb'',''master'')

	open #cd
	fetch next from #cd into @db
	
	while(@@fetch_status=0)
	begin
		set @device=''d''+replace(@db,'' '',''_'')
		set @file=''j:\mssql7\backup\''+replace(@db,'' '',''_'')+''.bak''

		exec(''sp_dropdevice '' + @device)
		exec(''sp_addumpdevice ''''disk'''',''''''+@device+'''''',''''''+@file+''.bak'''''')
		fetch next from #cd into @db
	end
	
	close #cd
	deallocate #cd

end
', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 7, @step_name = N'backup logs', @command = N'declare
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
		set @file=''j:\mssql7\backup\''+replace(@db,'' '',''_'')+''.bak''
		set @cmd = ''del ''+@file
		set @tries=0

--		exec(''backup log [''+@db+''] to ''+@device)
--		exec(''sp_addumpdevice ''''disk'''',''''''+@device+'''''',''''j:\mssql7\backup\''+@db+''.bak'''''')
		exec(''backup database [''+@db+''] to ''+@device+'' with differential, retaindays=0, init'')
		while (@tries<2) and (@@error in (3266, 3013))
		begin
			set @tries=@tries + 1
			if @tries=1
			begin
				exec master..xp_cmdshell @cmd
				exec(''backup database [''+@db+''] to ''+@device+'' with differential, retaindays=0, init'')
			end
			else
			begin
				exec(''backup database [''+@db+''] to ''+@device+'' with retaindays=0, init'')
			end
		end
		exec(''backup log [''+@db+''] with truncate_only'')
--		exec(''DBCC SHRINKDATABASE ([''+@db+''], 10)'')
		fetch next from #cd into @db
	end
	
	close #cd
	deallocate #cd

end
', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 8, @step_name = N'db options', @command = N'declare
	@db varchar(500)
begin
	declare #cd cursor local fast_forward for
	select [name] from master..sysdatabases
	where [name] not in (''master'',''tempdb'')

	open #cd
	fetch next from #cd into @db

	while(@@fetch_status=0)
	begin
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''dbo use only'''', @optvalue=''''false'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''single user'''', @optvalue=''''false'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''auto create statistics'''', @optvalue=''''true'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''auto update statistics'''', @optvalue=''''true'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''autoshrink'''', @optvalue=''''true'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''select into/bulkcopy'''', @optvalue=''''true'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''torn page detection'''', @optvalue=''''true'''''')
		exec(''exec sp_dboption @dbname=''''''+@db+'''''', @optname=''''trunc. log on chkpt.'''', @optvalue=''''false'''''')
		fetch next from #cd into @db
	end

	close #cd
	deallocate #cd
end

', @database_name = N'master', @server = N'', @database_user_name = N'dbo', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 3, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 9, @step_name = N'backup logs (try again)', @command = N'declare
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
		set @file=''j:\mssql7\backup\''+replace(@db,'' '',''_'')+''.bak''
		set @cmd = ''del ''+@file
		set @tries=0

--		exec(''backup log [''+@db+''] to ''+@device)
--		exec(''sp_addumpdevice ''''disk'''',''''''+@device+'''''',''''j:\mssql7\backup\''+@db+''.bak'''''')
		exec(''backup database [''+@db+''] to ''+@device+'' with differential, retaindays=0, init'')
		while (@tries<2) and (@@error in (3266, 3013))
		begin
			set @tries=@tries + 1
			if @tries=1
			begin
				exec master..xp_cmdshell @cmd
				exec(''backup database [''+@db+''] to ''+@device+'' with differential, retaindays=0, init'')
			end
			else
			begin
				exec(''backup database [''+@db+''] to ''+@device+'' with retaindays=0, init'')
			end
		end
		exec(''backup log [''+@db+''] with truncate_only'')
--		exec(''DBCC SHRINKDATABASE ([''+@db+''], 10)'')
		fetch next from #cd into @db
	end
	
	close #cd
	deallocate #cd

end
', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 1, @retry_interval = 30, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 3
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 10, @step_name = N'Backup DB', @command = N'exec sp_start_job @job_name=''Backup ''''DB To J''''''', @database_name = N'msdb', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'Transaction Logs', @enabled = 1, @freq_type = 4, @active_start_date = 20010606, @active_start_time = 200, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 2, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 180059
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



