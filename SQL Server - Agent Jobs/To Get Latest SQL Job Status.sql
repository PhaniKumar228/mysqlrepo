/*
To Get Latest SQL Job Status

This query will give you the current job status of all scheduled jobs on sql server. 
Just by using sysJobs, and sysJobHistory table you will get to know the details 
about the last status of the scheduled jobs, irrespective of their status like failed, successful, or cancelled.

Note: You must have admin right on MSDB database in order to execute this query.

*/

/*
SQL Job Status

This query will give you the current job status of all scheduled jobs on sql server.

Just by using sysJobs, and sysJobHistory table you will get to know the details about the last status of the scheduled jobs, irrespective of their status like failed, successful, or cancelled.

Note: You must have admin right on MSDB database in order to execute this query.
*/

Use msdb
go

select distinct j.Name as "Job Name", j.description as "Job Description", h.run_date as LastStatusDate, 
case h.run_status 
when 0 then 'Failed' 
when 1 then 'Successful' 
when 3 then 'Cancelled' 
when 4 then 'In Progress' 
end as JobStatus
from sysJobHistory h, sysJobs j
where j.job_id = h.job_id and h.run_date = 
(select max(hi.run_date) from sysJobHistory hi where h.job_id = hi.job_id)
order by 1


