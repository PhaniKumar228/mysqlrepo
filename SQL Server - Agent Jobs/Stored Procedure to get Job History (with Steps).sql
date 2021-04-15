/*
Stored Procedure to get Job History (with Steps)

This procedure returns the job history for any jobs run on a given day. 
The parameter should be entered in mm/dd/yyyy format surrounded by single quotes. 
I use it to produce a report of any jobs that failed on any given day.

It should be created on the MSDB database.

Example: EXEC usp_job_history '10/02/2004' 

This is my first script, so if I've missed anything or if you see any room for improvement, please let me know. 

*/

CREATE PROCEDURE usp_job_history
	@dateparam DATETIME
AS
SELECT     dbo.sysjobhistory.server, dbo.sysjobs.name AS job_name, 
CASE dbo.sysjobhistory.run_status
	WHEN 0 THEN 'Failed'
	WHEN 1 THEN 'Succeeded'
	ELSE '???'
	END as run_status, dbo.sysjobhistory.run_date, dbo.sysjobhistory.run_time, dbo.sysjobhistory.step_id, dbo.sysjobhistory.step_name, dbo.sysjobhistory.run_duration, dbo.sysjobhistory.message
FROM         dbo.sysjobhistory INNER JOIN
                      dbo.sysjobs ON dbo.sysjobhistory.job_id = dbo.sysjobs.job_id
WHERE dbo.sysjobs.category_id = 0 and dbo.sysjobhistory.run_date = datepart(yyyy,@dateparam)*10000 + datepart(mm,@dateparam)*100 + datepart(dd,@dateparam)
ORDER BY dbo.sysjobhistory.server, dbo.sysjobhistory.run_date, dbo.sysjobhistory.run_time, dbo.sysjobs.name, dbo.sysjobhistory.step_id
GO


