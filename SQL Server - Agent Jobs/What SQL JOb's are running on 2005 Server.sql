/*
What SQL JOb's are running on 2005 Server

Place this script on the query editor and execute, it gives the result of all the running jobs witht he latest status.

*/

use msdb
Go
declare @MxCnt INT , @Cnt INT 
declare @JobID varbinary(max)
declare @RunnableJobs int 
declare @Owner varchar(20)

/****Pass the parameters for viewing the job lists***********************************/
SET @RunnableJobs=1 -->1: All runnable jobs 
????????????????????-->0: All Non Runnable jobs 
????????????????????-->Null: All enabled jobs 
/************************************************************************************/
SET @Owner= system_user
create table #enum_job ( RowID INT IDENTITY(1,1),
Job_ID uniqueidentifier,
Last_Run_Date int,
Last_Run_Time int,
Next_Run_Date int,
Next_Run_Time int,
Next_Run_Schedule_ID int,
Requested_To_Run int,
Request_Source int,
Request_Source_ID varchar(100),
Running int,
Current_Step int,
Current_Retry_Attempt int, 
State int,
JobID_var varchar(max)
) 
insert into #enum_job(Job_ID,Last_Run_Date,Last_Run_Time,Next_Run_Date,Next_Run_Time,
Next_Run_Schedule_ID,Requested_To_Run,Request_Source,Request_Source_ID,Running,
Current_Step,Current_Retry_Attempt,State)
execute master.dbo.xp_sqlagent_enum_jobs 1,@Owner --<1 -para -->sysadmin>???? 
????????????????????????????????????????????????????????--<2 -para -->owner>????

set @MxCnt=@@identity
set @Cnt = 1
????while (@Cnt<=@MxCnt)
????????begin
set @JobID=(select Job_ID from #enum_job where RowID=@Cnt)
print @JobID

update #enum_job 
set JobID_var=(select cast('' as xml).value('xs:hexBinary(sql:variable("@JobID") )', 'varchar(max)') )
where rowid=@Cnt

set @Cnt=@Cnt+1
????????end


SELECT j.name as JobName,
/*****************************************/
CASE WHEN LR.Last_Run_Date = 0 THEN 'Never Ran' ELSE
convert(varchar(100),convert(datetime,substring(cast(lr.Last_Run_Date as varchar(100)),1,4)+'-'+substring(cast(lr.Last_Run_Date as varchar(100)),5,2)
+'-'+substring(cast(lr.Last_Run_Date as varchar(100)),7,8)),6) END
????AS LastRunDate,
CASE 
when len(LR.last_run_time)>=5 and len(LR.last_run_time)<=6 then 
substring(cast(LR.last_run_time as varchar(10)),1,(case when len(LR.last_run_time)=5 then 1 else 2 end))+'-'+
substring(cast(LR.last_run_time as varchar(10)),(case when len(LR.last_run_time)=5 then 2 else 3 end)
,2)+'-'+substring(cast(LR.last_run_time as varchar(10)),(case when len(LR.last_run_time)=5 then 4 else 5 end),2) 
when len(LR.last_run_time)=4 then 
'12:'+
( CASE WHEN LEN(substring(cast(LR.last_run_time as varchar(10)),1,(case when len(LR.last_run_time)=3 then 1 else 2 end)))>1 THEN substring(cast(LR.last_run_time as varchar(10)),1,(case when len(LR.last_run_time)=3 then 1 else 2 end))
ELSE '0'+substring(cast(LR.last_run_time as varchar(10)),1,(case when len(LR.last_run_time)=3 then 1 else 2 end)) END )
+':'+
(CASE WHEN LEN(substring(cast(LR.last_run_time as varchar(10)),(case when len(LR.last_run_time)=3 then 2 else 3 end ),len(LR.last_run_time)))>1 THEN substring(cast(LR.last_run_time as varchar(10)),(case when len(LR.last_run_time)=3 then 2 else 3 end ),len(LR.last_run_time))
ELSE '0'+substring(cast(LR.last_run_time as varchar(10)),(case when len(LR.last_run_time)=3 then 2 else 3 end ),len(LR.last_run_time)) END)
else '12:00:00'end AS LastRunTime,

case when lr.last_run_outcome=1 then 'Success'when lr.last_run_outcome=0 then 'Failed' else 'Cancel'End
????AS LastRunStatus,
case 
when len(lr.last_run_duration)<=2 then 
'00 hrs : 00 min : '+' '+cast(lr.last_run_duration as varchar(100))+'sec'
when len(lr.last_run_duration)>2 and len(lr.last_run_duration)<=4 then 
'00 hrs : '+substring(cast(lr.last_run_duration as varchar(100)),1,(len(lr.last_run_duration)-2) )+' min : '
+' '+substring(cast(lr.last_run_duration as varchar(100)),(len(lr.last_run_duration)-1),len(lr.last_run_duration) )+'sec'
when len(lr.last_run_duration)>=5 and len(last_run_duration)<=6 then
substring(cast(lr.last_run_duration as varchar(100)),1,(case when len(lr.last_run_duration)=5 then 1 else 2 end ))+' hrs :'+
substring(cast(lr.last_run_duration as varchar(100)),(case when len(lr.last_run_duration)=5 then 2 else 3 end ),(case when len(lr.last_run_duration)=5 then 2 else 2 end ) )+' min : '+
substring(cast(lr.last_run_duration as varchar(100)),(case when len(lr.last_run_duration)=5 then 4 else 5 end )
,(case when len(lr.last_run_duration)=5 then 2 else 2 end ) )+' sec : '
else cast(substring(cast(lr.last_run_duration as varchar(10)),1,3)/24 as varchar(10))+''+'days' end AS 'LastRunDuration',

/*****************************************/
CASE WHEN P.Next_Run_Date = 0 THEN 'Never Ran' ELSE
convert(varchar(100),convert(datetime,substring(cast(p.Next_Run_Date as varchar(100)),1,4)+'-'+substring(cast(p.Next_Run_Date as varchar(100)),5,2)
+'-'+substring(cast(p.Next_Run_Date as varchar(100)),7,8)),6) END
????AS NextRunDate,

CASE WHEN LEN(p.Next_Run_Time)>5 THEN 
substring(cast(p.Next_Run_Time as varchar(100)),1,2)+'-'+
substring(cast(p.Next_Run_Time as varchar(100)),3,2)+'-'+
substring(cast(p.Next_Run_Time as varchar(100)),5,2)
WHEN LEN(p.Next_Run_Time)<=5 and LEN(p.Next_Run_Time)>1 THEN 
'0'+substring(cast(p.Next_Run_Time as varchar(100)),1,1)+'-'+
substring(cast(p.Next_Run_Time as varchar(100)),2,2)+'-'+
substring(cast(p.Next_Run_Time as varchar(100)),4,2) ELSE '12:00:00'END AS NextRunTime,

/*****************************************/
isnull(db_name(s.dbid),'') DatabaseName,
CASE when p.Running = 1 then 'Running' else 'Idle' end
????AS Current_Job_Status,
CASE WHEN Current_Step>0 THEN 'Step:'+' '+cast(Current_Step as varchar(10))+' execution under process.' ELSE 'Idle' END
????AS Current_Step_Execution,
isnull(st.text,'--') 
????AS CurrentQueryString,
isnull(s.Spid,'')Spid,'IsBlocked'=case when s.blocked<>0 then'Blocked By SPID: '+''+cast(s.blocked as varchar(10)) else '0' end,
isnull(CPU,0) CPU,isnull(Physical_IO,0)Physical_IO,isnull(Memusage,0)Memusage,'spid status'=isnull(s.status,'--'),'WaitResourceType'=isnull(s.LastWaitType,'--')
--,p.*
FROM #ENUM_JOB P
JOIN MSDB.DBO.SYSJOBS j on j.job_id = p.Job_ID 
LEFT JOIN MASTER.SYS.SYSPROCESSES s on substring(s.program_name,32,32)=p.JobID_var 
LEFT JOIN MSDB.DBO.SYSJOBSERVERS lr on lr.job_id=p.job_id
LEFT JOIN SYS.DM_EXEC_REQUESTS dm on dm.session_id=s.spid
OUTER APPLY SYS.DM_EXEC_SQL_TEXT(dm.sql_handle) AS st 
WHERE j.enabled=1 and p.running=isnull(@RunnableJobs,p.running) 
ORDER BY JobName

DROP TABLE #ENUM_JOB



