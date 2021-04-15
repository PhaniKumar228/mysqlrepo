drop PROCEDURE hx_JobSchedules
go

/* 	
	input:	None
	output:	Table format
	Desc:	Displays Job Schedules info if any.
	Warnings: None.
*/
CREATE PROCEDURE hx_JobSchedules AS

SELECT DISTINCT -- I use distinct only for readability
	substring(msdb..sysjobs.name,1,100) AS [Job Name], 
	'Enabled'=case 
	WHEN msdb..sysjobs.enabled = 0 THEN 'No'
	WHEN msdb..sysjobs.enabled = 1 THEN 'Yes'
	end, 
    	substring(msdb..sysjobschedules.name,1,30) AS [Name of the schedule],
	'Frequency of the schedule execution'=case
	WHEN msdb..sysjobschedules.freq_type = 1 THEN 'Once'
	WHEN msdb..sysjobschedules.freq_type = 4 THEN 'Daily'
	WHEN msdb..sysjobschedules.freq_type = 8 THEN 'Weekly'
	WHEN msdb..sysjobschedules.freq_type = 16 THEN 'Monthly'
	WHEN msdb..sysjobschedules.freq_type = 32 THEN 'Monthly relative'	
	WHEN msdb..sysjobschedules.freq_type = 32 THEN 'Execute when SQL Server Agent starts'
	END,	
	'Units for the freq_subday_interval'=case
	WHEN msdb..sysjobschedules.freq_subday_type = 1 THEN 'At the specified time' 
	WHEN msdb..sysjobschedules.freq_subday_type = 2 THEN 'Seconds' 
	WHEN msdb..sysjobschedules.freq_subday_type = 4 THEN 'Minutes' 
	WHEN msdb..sysjobschedules.freq_subday_type = 8 THEN 'Hours' 
	END,	
	cast(cast(msdb..sysjobschedules.active_start_date as varchar(15)) as datetime) as active_start_date,	
	cast(cast(msdb..sysjobschedules.active_end_date as varchar(15)) as datetime) as active_end_date,	
	cast(cast(msdb..sysjobschedules.next_run_date as varchar(15)) as datetime) as next_run_date,	
	msdb..sysjobschedules.next_run_time,	
	msdb..sysjobschedules.date_created
	
FROM msdb..sysjobhistory INNER JOIN
       msdb..sysjobs ON 
       msdb..sysjobhistory.job_id = msdb..sysjobs.job_id INNER JOIN
       msdb..sysjobschedules ON msdb..sysjobs.job_id = msdb..sysjobschedules.job_id


