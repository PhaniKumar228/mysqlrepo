/*
Monitor Object Changes

Based on post http://www.sqlservercentral.com/forum/link.asp?TOPIC_ID=4349 I decided to write this script which will check for object changes in all databases and send an email listing the objects changed to the Operator associated with the job. This by no means offsets the need to restrict change access to objects in production, but in those cases when you can't restrict it is a nice basic monitor. 

The first part of the script will create the job 
(you need to change the @owner_login_name and @notify_email_operator_name information) and the second part creates the procedure to check for changes. 

Pretty simple but effective. 

*/

/*	Create the job to run the object change monitor procedure.
*/

declare 
	@ReturnCode int,
	@JobID binary(16)

select @ReturnCode = 0   

if exists (
	select * from msdb..sysjobs where name = '#DBA - Monitor Object Changes')
	exec msdb.dbo.sp_delete_job @job_name = '#DBA - Monitor Object Changes' 

-- Add the job
	exec @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID output , @job_name = N'#DBA - Monitor Object Changes', @owner_login_name = N'DOMAIN\Account', @description = N'No description available.', @category_name = N'Database Maintenance', @enabled = 1, @notify_level_email = 2, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0, @notify_email_operator_name = N'Public, John'
		if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback 

-- Add the job steps
	exec @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'Check for Object Changes', @command = N'exec vsp_MonObjChanges', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
		if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback 
	exec @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 
	
		if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback 

-- Add the job schedules
	execute @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'MonObjChanges_Sched1', @enabled = 1, @freq_type = 4, @active_start_date = 20020523, @active_start_time = 231500, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 235959
	if (@@ERROR <> 0 OR @ReturnCode <> 0) goto QuitWithRollback 

-- Add the Target Servers
	exec @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)' 
	if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback 

goto   EndSave              
QuitWithRollback:
  if (@@trancount > 0) rollback transaction 
EndSave: 

/*	Create the procedure vsp_MonObjChanges.
*/

use master
go

if exists
	(select name from sysobjects where name = 'vsp_MonObjChanges')
	drop procedure vsp_MonObjChanges
go

create procedure vsp_MonObjChanges as

/*	Create table DBAObjMon if it does not currently exist. 
*/
if not exists 
	(select name from sysobjects where name = 'DBAObjMon')

	create table DBAObjMon (
		DBName varchar(32),
		Name varchar(128),
		XType varchar(2),
		CreateDT datetime
		)

/*	Clear out old records from DBAObjMon table 
*/
delete from DBAObjMon

/*	Declare necessary variables and set appropriately
*/
declare 
	@OperEmail varchar(32),
	@ServerName varchar(32),
	@SubjectMsg varchar(128)

set @OperEmail = 
	(select email_address 
		from msdb..sysjobs j join msdb..sysoperators o on j.notify_email_operator_id = o.id
		where j.name = '#DBA - Monitor Object Changes'
	)
set @ServerName = (select @@ServerName)
set @SubjectMsg = ('The following objects have changed on '+@ServerName+'!')

/*	Populate the DBAObjMon table using the sp_MSforeachdb procedure. 
*/
exec sp_MSforeachdb @command1 = 'insert DBAObjMon select ''?'' as DBName , name, xtype, crdate from ?.dbo.sysobjects where crdate > getdate()-1 and name not like ''#qtemp%'''

/*	Send mail message with attachment that includes changed objects list to the 
	Operator associated with the job.
*/
if exists
	(select DBName, Name, XType, CreateDT from DBAObjMon)
begin
	exec xp_sendmail
		@recipients = @OperEmail,
		@subject = @SubjectMsg,
		@query = 
			'select DBName, Name, XType, CreateDT from DBAObjMon',
		@attach_results = 'TRUE', @width = 500
end

go


