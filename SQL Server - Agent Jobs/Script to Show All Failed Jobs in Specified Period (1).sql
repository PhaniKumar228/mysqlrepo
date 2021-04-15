/*
    
Script to Show All Failed Jobs in Specified Period

This script will allow you to create a stored procedure that will check a server for any jobs that have failed in a specified number of days. It has proven valuable to me, since I have servers with lots of jobs that run frequently; 

I got tired of checking the history of each job to look for past failures. Keep in mind that this will only find job information that's currently in your msdb database; if your "Job History Rows per Job" or "Job History Log Size" parameters (in SQL Agent properties) are set so that the job history information is truncated too often, they may have to be changed. 
 
 
*/

-- CREATE PROCEDURE 

CREATE PROC check_failed_jobs @NumDays int
AS

SET NOCOUNT ON
PRINT 	'Checking for all jobs that have failed in the last ' + CAST(@NumDays AS char(2)) +' days.......'
PRINT	' '

SELECT 	CAST(CONVERT(datetime,CAST(run_date AS char(8)),101) AS char(11))	AS 'Failure Date',
	SUBSTRING(T2.name,1,40)							AS 'Job Name',
	T1.step_id 								AS 'Step #',
	T1.step_name								AS 'Step Name',
	T1.message								AS 'Message'

FROM	msdb..sysjobhistory 	T1
JOIN	msdb..sysjobs		T2
	ON T1.job_id = T2.job_id

WHERE		T1.run_status != 1
	AND	T1.step_id != 0
	AND	run_date >= CONVERT(char(8), (select dateadd (day,(-1*@NumDays), getdate())), 112)

GO

-- EXECUTE PROC and PASS NUMBER OF DAYS TO CHECK FOR
--   JOB FAILURES - example uses 2 days

check_failed_jobs 2

