/*
Check Job History for given time window
I use the following script to find out what was running at around the time something of interest happens on our 
SQL Server. I haven't got around to making this a stored procedure, but it is easy enough to change the date and time 
interval. 

*/

select  j.name,jh.step_name,run_date,run_time,run_duration,operator_id_emailed,jh.message
 from msdb..sysjobhistory jh(nolock),msdb..sysjobs j(nolock)
where jh.job_id = j.job_id
and run_date = '20090206'   --date of the job
and run_time > 0100	     --time 
and run_time < 64500
order by run_time
