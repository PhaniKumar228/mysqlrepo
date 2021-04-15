/*

Failed Job Notification

This script notifies the DBA or Developers with the list of failed jobs. 
This script useful if you want to use either Mater-Target server option or even single server to monitor the Target servers jobs. You must have SQL MAIL configured on the SQL Server.
*/


Create Procedure Usp_Failed_Jobs_Notification
AS
Declare @Max_JobFailed_Error_Dt Datetime,
 @Max_JobFailed_Error_Dt_Dup Datetime
If not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Job_Tracking]') )
CREATE TABLE dbo.Job_Tracking ([job Name] varchar (80) ,[Failure Date] datetime, [Step #] varchar (5),[Step Name] varchar (80)  )
If not exists (select * from dbo.sysobjects where id = object_id(N'#Job_Tracking_dup') )
CREATE TABLE dbo.#Job_Tracking_dup ([job Name] varchar (80)  NULL ,[Failure Date] datetime NULL ,[Step #] varchar (5) NULL ,[Step Name] varchar (80)  NULL ) 
if (Select Count(*) from Job_Tracking) = 0
Begin
Insert Job_Tracking 
SELECT SUBSTRING(msdb..sysjobs.name,1,80) 'Job Name',SUBSTRING(CAST(msdb.sysjobHistory.run_date AS CHAR(8)),5,2) + '/' + RIGHT(CAST(msdb.sysjobHistory.run_date AS CHAR(8)),2) + '/' + LEFT(CAST(msdb.sysjobHistory.run_date AS CHAR(8)),4) + ' '+ LEFT(RIGHT('000000' + CAST(run_time AS VARCHAR(10)),6),2) + ':' +  SUBSTRING(RIGHT('000000' + CAST(run_time AS VARCHAR(10)),6),3,2) + ':' +  RIGHT(RIGHT('000000' + CAST(run_time AS VARCHAR(10)),6),2) 'Failure Date',
msdb..sysjobHistory.step_id ,
msdb..sysjobHistory.step_name 
FROM	msdb..sysjobhistory 
JOIN	msdb..sysjobs		
ON msdb..sysjobHistory.job_id = msdb..sysjobs.job_id
WHERE msdb..sysjobHistory.step_id  != 0
And msdb..sysjobHistory.run_status !=  1
And msdb..sysjobs.name <> 'Failed Job(s) Notification'
EXEC master..xp_sendmail 
@recipients = '<Eamils>' ,@message = ' Failed Job(s) on the Server <Server_Name>'
,@subject = 'Failed Job(s) Notification',@query   =  'Select [Job Name],[Failure Date],[Step #],[Step Name] from DB_Name..Job_Tracking'
,@attach_results = 'TRUE',@width = 300
End
Else
Begin
Insert #Job_Tracking_dup
SELECT SUBSTRING(msdb..sysjobs.name,1,80) ,SUBSTRING(CAST(msdb.sysjobHistory.run_date AS CHAR(8)),5,2) + '/' + RIGHT(CAST(msdb.sysjobHistory.run_date AS CHAR(8)),2) + '/' + LEFT(CAST(msdb.sysjobHistory.run_date AS CHAR(8)),4) + ' '+ LEFT(RIGHT('000000' + CAST(run_time AS VARCHAR(10)),6),2) + ':' +  SUBSTRING(RIGHT('000000' + CAST(run_time AS VARCHAR(10)),6),3,2) + ':' +  RIGHT(RIGHT('000000' + CAST(run_time AS VARCHAR(10)),6),2) ,
msdb..sysjobHistory.step_id ,
msdb..sysjobHistory.step_name  
FROM	msdb..sysjobhistory 	
JOIN	msdb..sysjobs		
ON msdb..sysjobHistory.job_id = msdb..sysjobs.job_id
WHERE msdb..sysjobHistory.step_id != 0
And msdb..sysjobHistory.run_status !=  1
And msdb..sysjobs.name <> 'Failed Job(s) Notification'
End
SElect @Max_JobFailed_Error_Dt_Dup = Max([Failure Date]) from #Job_Tracking_dup
Select @Max_JobFailed_Error_Dt = Max([Failure Date]) from Job_Tracking 
If  @Max_JobFailed_Error_Dt_Dup  > @Max_JobFailed_Error_Dt
Begin
Truncate table Job_Tracking
Insert Job_Tracking
SELECT * from #Job_Tracking_dup where 
[Failure Date] > @Max_JobFailed_Error_Dt
Drop table #Job_Tracking_dup
EXEC master..xp_sendmail 
 @recipients = '<Emails>' ,@message = ' Failed Job(s) on the Server <Server_Name>'
,@subject = 'Failed Job(s) Notification',@query   =  'Select [Job Name],[Failure Date],[Step #],[Step Name] from DB_Name..Job_Tracking',
@attach_results = 'TRUE',
@width = 300
End

