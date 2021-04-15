/*
Monitoring SQL Server downtime

The following script creates a monitoring utility to find out for how long a sql server was down prior to the latest startup. 
The script creates one table (tblHeartbeat), four stored procedures (uspFillHeartBeat, uspGetDowntimeSummary, uspCleanHeartbeat, uspAtStartup) and two jobs (FillHeartbeat and CleanHeartbeat).
Notes:
1. By convention I introduced in my company (UGO Networks, Inc.) all "service" database objects except uspAtStartup 
are created in a dedicated database called DBAservice. 
2. uspAtStartup is created in master database. It must be in master in order to set up the startup option.
Note that user name "DBA" and email address "dba@your_company.com" in the text of uspAtStartup 
are to be substituted with real ones.
3. The "create job" section of the script is provided just for "completeness of the picture" and can be omitted as trivial. This task can be accomplished in Enterprise Manager.
The jobs FillHeartBeat (runs once a minute in my environment) executes uspFillHeartBeat, 
and the job CleanHeartbeat (runs once a week in my environment) executes uspCleanHeartbeat.


*/

-- =============================================
/*The following script creates a monitoring utility to find out for how long 
a sql server was down prior to the latest startup. 
The script creates one table (tblHeartbeat), four stored procedures 
(uspFillHeartBeat, uspGetDowntimeSummary, uspCleanHeartbeat, uspAtStartup) 
and two jobs (FillHeartbeat and CleanHeartbeat).
Notes:
1. By convention I introduced in my company (UGO Networks, Inc.) all "service" database objects except uspAtStartup 
are created in a dedicated database called DBAservice. 
2. uspAtStartup is created in master database. It must be in master in order to set up the startup option.
Note that user name "DBA" and email address "dba@your_company.com" in the text of uspAtStartup 
are to be substituted with real ones.
3. The "create job" section of this script can be omitted as trivial. 
This task can be accomplished in Enterprise Manager.
The jobs FillHeartBeat (runs once a minute in my environment) executes uspFillHeartBeat, 
and the job CleanHeartbeat (runs once a week in my environment) executes uspCleanHeartbeat.

*/
-- =============================================
use DBAservice
GO
IF EXISTS (SELECT name 
	   FROM   sysobjects 
	   WHERE  name = N'tblHeartBeat' 
	   AND 	  type = 'U')
    DROP TABLE tblHeartBeat
GO

create table tblHeartBeat (
id int IDENTITY(100, 1) Primary Key, 
DateTime DateTime NOT NULL Default getdate())
GO
IF EXISTS (SELECT name 
	   FROM   sysobjects 
	   WHERE  name = N'uspFillHeartBeat' 
	   AND 	  type = 'P')
drop proc uspFillHeartBeat
go
Create proc uspFillHeartBeat
AS
/*******************
Production server: all
Production database: DBAservice
Purpose: Makes an entry in tblHeartBeat 
comfirming that the server is up and running.
It is recommended that the procedure runs once a minute
Developed: Yul Wasserman 11/14/02
*****************/
Insert DBAservice.dbo.tblHeartBeat (datetime) values (default)

GO
IF EXISTS (SELECT name 
	   FROM   sysobjects 
	   WHERE  name = N'uspGetDowntimeSummary' 
	   AND 	  type = 'P')
drop proc uspGetDowntimeSummary
go
Create proc uspGetDowntimeSummary
@pCheckInterval int=1, --minutes between the regular checks
@pStartDate smalldatetime =NULL,
@pEndDate smalldatetime =NULL
/*******************
Production server: all
Production database: DBAservice
Purpose: Creates a summary of downtimes showing for each occurrence:
when was the last time the server was checked for running before shutdown,
and for how long it was down prior to the next startup
Developed: Yul Wasserman 11/14/02
*****************/
AS
select a.datetime as ShutdownAfter, datediff(mi, a.datetime,b.datetime) as DownTime_Minutes
from DBAservice.dbo.tblHeartBeat a join DBAservice.dbo.tblHeartBeat b on a.id=b.id-1 
where datediff(mi, a.datetime,b.datetime)>@pCheckInterval 
and (a.datetime<=@pEndDate or @pEndDate is NULL)
and (a.datetime>=@pStartDate or @pStartDate is NULL)
GO
IF EXISTS (SELECT name 
	   FROM   sysobjects 
	   WHERE  name = N'uspCleanHeartbeat' 
	   AND 	  type = 'P')
drop proc uspCleanHeartbeat
go
create proc uspCleanHeartbeat
@pCheckInterval int=1, --minutes between regular checks
@pKeepDowntimeHistory bit =1
/*******************
Production server: all
Production database: DBAservice
Purpose: Purges tblHeartBeat leaving beginning and end of each downtime period
Developed: Yul Wasserman 11/14/02
*****************/
AS
IF @pKeepDowntimeHistory=1
delete b 
from DBAservice.dbo.tblHeartBeat a 
join DBAservice.dbo.tblHeartBeat b on a.id=b.id-1 
join DBAservice.dbo.tblHeartBeat c on b.id=c.id-1 
where datediff(mi, a.datetime,b.datetime)<=@pCheckInterval AND datediff(mi, b.datetime,c.datetime)<=@pCheckInterval
ELSE truncate table tblHeartBeat
GO

use master
GO

IF EXISTS (SELECT name 
	   FROM   sysobjects 
	   WHERE  name = N'uspAtStartup' 
	   AND 	  type = 'P')
drop proc uspatstartup
go
CREATE PROCEDURE uspAtStartup
/*******************
Production server: all
Production database: master
Purpose: Notifies DBAs that the server has been started and starts SQL server agent
Developed: Igor Raytsin 
Last updated: Yul Wasserman 01/23/02
Note. User name "DBA" and email address "dba@your_company.com" are to be substituted with real ones.
*****************/
AS

DECLARE 	@Message 	varchar(250),
	 	@NetMessage 	varchar(250)

SELECT @Message = 'SQL Server started on ' + @@SERVERNAME + ' at ' + CONVERT (varchar, GETDATE(), 20) +
'. Downtime was '+ISNULL((CONVERT (varchar,datediff(mi,(select max(datetime) from DBAservice.dbo.tblHeartBeat),GETDATE()),6)),'NULL')+' minutes'
WAITFOR DELAY '00:00:05'
EXECUTE master.dbo.xp_startmail 
WAITFOR DELAY '00:00:05'

EXECUTE master.dbo.xp_sendmail 'dba@your_company.com', @Message, @subject=@Message

SET @NetMessage = 'net send DBA ' + @Message

EXECUTE master.dbo.xp_cmdshell @NetMessage, no_output
EXECUTE master.dbo.xp_cmdshell 'NET START SQLSERVERAGENT'
insert DBAservice.dbo.tblHeartBeat (datetime) values (default)
GO
sp_procoption 'uspAtStartup', 'startup','true'
go
/*Note. The following section of the script is provided just for "completeness of the picture" 
and can be omitted as trivial. This task can be accomplished in Enterprise Manager.
Just note that the jobs must be there:
The jobs FillHeartBeat (runs once a minute in my environment) executes uspFillHeartBeat, 
and the job CleanHeartbeat (runs once a week in my environment) executes uspCleanHeartbeat.

*/
use msdb


BEGIN TRANSACTION            
  DECLARE @JobID BINARY(16)  
  DECLARE @ReturnCode INT    
  SELECT @ReturnCode = 0     
IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'[Uncategorized (Local)]') < 1 
  EXECUTE msdb.dbo.sp_add_category @name = N'[Uncategorized (Local)]'

  -- Delete the job with the same name (if it exists)
  SELECT @JobID = job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'FillHeartBeat')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''FillHeartBeat'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'FillHeartBeat' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'FillHeartBeat', @owner_login_name = N'sa', @description = N'No description available.', @category_name = N'[Uncategorized (Local)]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'Insert into HeartBeat', @command = N'Execute DBAservice.dbo.uspFillHeartBeat', @database_name = N'master', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'insert tblHeartbeat', @enabled = 1, @freq_type = 4, @active_start_date = 20021112, @active_start_time = 0, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_end_date = 99991231, @active_end_time = 235959
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
go

BEGIN TRANSACTION            
  DECLARE @JobID BINARY(16)  
  DECLARE @ReturnCode INT    
  SELECT @ReturnCode = 0     
IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'[Uncategorized (Local)]') < 1 
  EXECUTE msdb.dbo.sp_add_category @name = N'[Uncategorized (Local)]'

  -- Delete the job with the same name (if it exists)
  SELECT @JobID = job_id     
  FROM   msdb.dbo.sysjobs    
  WHERE (name = N'CleanHeartbeat')       
  IF (@JobID IS NOT NULL)    
  BEGIN  
  -- Check if the job is a multi-server job  
  IF (EXISTS (SELECT  * 
              FROM    msdb.dbo.sysjobservers 
              WHERE   (job_id = @JobID) AND (server_id <> 0))) 
  BEGIN 
    -- There is, so abort the script 
    RAISERROR (N'Unable to import job ''CleanHeartbeat'' since there is already a multi-server job with this name.', 16, 1) 
    GOTO QuitWithRollback  
  END 
  ELSE 
    -- Delete the [local] job 
    EXECUTE msdb.dbo.sp_delete_job @job_name = N'CleanHeartbeat' 
    SELECT @JobID = NULL
  END 

BEGIN 

  -- Add the job
  EXECUTE @ReturnCode = msdb.dbo.sp_add_job @job_id = @JobID OUTPUT , @job_name = N'CleanHeartbeat', @owner_login_name = N'sa', @description = N'No description available.', @category_name = N'[Uncategorized (Local)]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job steps
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_id = 1, @step_name = N'CleanHeartbeat', @command = N'exec DBAservice.dbo.uspCleanHeartbeat', @database_name = N'DBAService', @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = 0, @retry_interval = 1, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
  EXECUTE @ReturnCode = msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1 

  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 

  -- Add the job schedules
  EXECUTE @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @JobID, @name = N'CleanHeartbeat', @enabled = 1, @freq_type = 8, @active_start_date = 20021115, @active_start_time = 30000, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_end_date = 99991231, @active_end_time = 235959
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





