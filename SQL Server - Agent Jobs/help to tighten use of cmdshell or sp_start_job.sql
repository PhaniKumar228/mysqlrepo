/*

help to tighten use of  cmdshell  or sp_start_job

-- The goal is to avoid the use of sp_start_job in an application. 
So we have the application use RAISERROR to activate the job.

--  1) because you can only start jobs you own
--  2) we don't want to open the cmdshell to everyone
--  3) we want control regarding jobs that run on our server.
--  4) we want to have an indication how much is "ad-hoc"

*/
-- The goal is to avoid the use of sp_start_job in an application. 
--  So we have the application use RAISERROR to activate the job.
--  1) because you can only start jobs you own
--  2) we don't want to open the cmdshell to everyone
--  3) we want control regarding jobs that run on our server.
--  4) we want to have an indication how much is "ad-hoc"
--
--     to be adjusted : messagenumber 
--			jobname 
-- 			database_name 
--
-- IMPORTANT : The first time you activate an alert, SQLServerAgent needs to be restarted.
--            (needs also to be done when you have disabled all alerts and want to enable them again !)
-- 
-- IMPORTANT : When you disable a job, you have to disable the alert-related schedule 
--               or SQLAgent will write messages in it's log saying it cannot start the job.
--			It will keep on doing so every _second_ until the job is reenabled. Eventualy you disk will get full !!!
-- exec msdb.dbo.sp_help_alert
go

print @@servername

USE Master
go

Declare @MessageNummer int
Declare @jobname varchar(128)
Declare @DbName varchar(128)

set @MessageNummer = 60010			-- <-- ADJUST!!! (> 50000)
set @jobname = 'NameOfJobToBeLaunched'		-- <-- ADJUST!!! (has to be existing)
set @DbName = 'mydb'				-- <-- ADJUST!!! I only want the alert to fire when raised in the richt db.

--

Declare @wrkstr1 varchar(128)
Declare @wrkstr2 varchar(128)

set @wrkstr1 = 'UserAlert Requesting Job ' + @jobname + ' to be launched.' 
-- message toevoegen in Master
exec sp_addmessage  @msgnum = @MessageNummer 
    , @severity =  10  
    , @msgtext = @wrkstr1
    -- , @lang =  'language' 
    , @with_log = 'true'  
    -- , @replace =  'replace'  

set @wrkstr1 = 'UserAlert_Requesting_Job_' + @jobname
set @wrkstr2 = 'Requesting Job ' + @jobname + ' to be launched.'

-- Alert definiëren in MSDB
exec msdb.dbo.sp_add_alert @name = @wrkstr1 
    , @message_id = @MessageNummer 
    , @severity = 0    -- must be 0 because we provide message_id
    , @enabled = 1     -- 0 = disabled / 1 = enabled
    , @delay_between_responses = 5  -- Seconden 
    , @notification_message = @wrkstr2 
    --, @include_event_description_in = 0 
    , @database_name = @DbName 
    --, @event_description_keyword ='Requesting Job ' + @jobname + ' to be launched.'
    , @job_name = @jobname
   -- , @raise_snmp_trap = raise_snmp_trap] not with SQL 7.0 
   -- , @performance_condition = 'performance_condition' 
    --, @category_name = 'Application Events'

exec msdb.dbo.sp_help_alert
go

-- Cleanup alert
-- check sp_delete_alert BOL
-- 
--

-- usage
 use mydb
 go
  RAISERROR ( 60010  , 10 , 1 )
  
  go
-- 

