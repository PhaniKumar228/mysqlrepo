/*
usp_ActiveProcesses - SQL 2k5

Returns list of active processes and their buffer contents (what they execute)
A process is considered as active if it has some changes of cpu time consumed or number of io operation in specified period.
Usage: EXEC usp_ActiveProcessesInput <SecondsDelay> -> Optional time interval to catch activity.


*/

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = Object_id(N'[dbo].[usp_ActiveProcesses]') AND Objectproperty(id,N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[usp_ActiveProcesses]
GO

CREATE PROC usp_ActiveProcesses @Delay smallint= 5
AS
--
-- Description Returns list of active processes and their buffer contents (what they execute)
-- A process is considered as active if it has some changes of cpu time consumed or number
-- of io operation in specified period.
-- Input (optional) @Delay - Time interval to catch activity
-- Output Result set with active processes
--
-- 2008-04-01 Pedro Lopes (NovaBase) pedro.lopes@novabase.pt
--
SET nocount on

IF @Delay > 59
	SET @Delay = 59

IF @Delay < 1
	SET @Delay = 1

PRINT @Delay

DECLARE @DelayClock CHAR(8), @Internal_Value int

SET @DelayClock = '00:00:' + LTRIM(STR(@Delay))

CREATE TABLE #tmpsysprocesses (
	EventTime DATETIME,
	DBName sysname NULL,
	ObjectName sysname NULL,
	spid smallint,
	[Host_Name] sysname NULL,
	[Program_Name] sysname NULL,
	[Login_Name] sysname NULL,
	[Start_Time] DATETIME,
	TotalReads int,
	TotalWrites int,
	TotalCPU int,
	Writes_in_TempDB int,
	CmdType VARCHAR(16),
	CmdStatus VARCHAR(30),
	SQL_Text xml,
	Blocking_spid smallint,
	Blocking_Text xml)

INSERT INTO #tmpsysprocesses
SELECT GETDATE(), (SELECT DB_NAME(dbid) FROM master.sys.dm_exec_sql_text(x.sql_handle)) AS dbname,
(SELECT OBJECT_NAME(objectid) FROM master.sys.dm_exec_sql_text(x.sql_handle)) AS objectname,
x.session_id AS spid, 
x.host_name, 
x.program_name,
x.login_name, 
x.start_time, 
x.totalReads, 
x.totalWrites, 
x.totalCPU, 
x.writes_in_tempdb,
x.command AS cmdtype,
x.status,
(SELECT text AS [text()] FROM master.sys.dm_exec_sql_text(x.sql_handle) FOR XML PATH(''), TYPE) AS sql_text, 
COALESCE(x.blocking_session_id, 0) AS blocking_spid,
(SELECT p.text FROM (SELECT MIN(sql_handle) AS sql_handle FROM master.sys.dm_exec_requests r2 WHERE r2.session_id = x.blocking_session_id) AS r_blocking
CROSS APPLY
(SELECT text AS [text()] FROM master.sys.dm_exec_sql_text(r_blocking.sql_handle) FOR XML PATH(''), TYPE) p (text)) AS blocking_text
FROM
(SELECT r.session_id, s.host_name, s.login_name, r.start_time, r.sql_handle, r.blocking_session_id,r.command,r.status,
 SUM(r.reads) AS totalReads, SUM(r.writes) AS totalWrites, SUM(r.cpu_time) AS totalCPU,
 SUM(tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) AS writes_in_tempdb, s.program_name
 FROM sys.dm_exec_requests r
 JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
 JOIN sys.dm_db_task_space_usage tsu ON s.session_id = tsu.session_id and r.request_id = tsu.request_id
 WHERE r.status IN ('running', 'runnable', 'suspended')
 GROUP BY r.session_id, s.host_name, s.login_name, r.start_time, r.sql_handle, r.blocking_session_id, r.command, r.status, s.program_name) x

WAITFOR delay @DelayClock

CREATE TABLE #tmpsysprocesses2 (
	EventTime DATETIME,
	DBName sysname NULL,
	ObjectName sysname NULL,
	spid smallint,
	[Host_Name] sysname NULL,
	[Program_Name] sysname NULL,
	[Login_Name] sysname NULL,
	[Start_Time] DATETIME,
	TotalReads int,
	TotalWrites int,
	TotalCPU int,
	Writes_in_TempDB int,
	CmdType VARCHAR(16),
	CmdStatus VARCHAR(30),
	SQL_Text xml,
	Blocking_spid smallint,
	Blocking_Text xml)

INSERT INTO #tmpsysprocesses2
SELECT GETDATE(), (SELECT DB_NAME(dbid) FROM master.sys.dm_exec_sql_text(x.sql_handle)) AS dbname,
(SELECT OBJECT_NAME(objectid) FROM master.sys.dm_exec_sql_text(x.sql_handle)) AS objectname,
x.session_id AS spid, 
x.host_name, 
x.program_name,
x.login_name, 
x.start_time, 
x.totalReads, 
x.totalWrites, 
x.totalCPU, 
x.writes_in_tempdb,
x.command AS cmdtype,
x.status,
(SELECT text AS [text()] FROM master.sys.dm_exec_sql_text(x.sql_handle) FOR XML PATH(''), TYPE) AS sql_text, 
COALESCE(x.blocking_session_id, 0) AS blocking_spid,
(SELECT p.text FROM (SELECT MIN(sql_handle) AS sql_handle FROM master.sys.dm_exec_requests r2 WHERE r2.session_id = x.blocking_session_id) AS r_blocking
CROSS APPLY
(SELECT text AS [text()] FROM master.sys.dm_exec_sql_text(r_blocking.sql_handle) FOR XML PATH(''), TYPE) p (text)) AS blocking_text
FROM
(SELECT r.session_id, s.host_name, s.login_name, r.start_time, r.sql_handle, r.blocking_session_id,r.command,r.status,
 SUM(r.reads) AS totalReads, SUM(r.writes) AS totalWrites, SUM(r.cpu_time) AS totalCPU,
 SUM(tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) AS writes_in_tempdb, s.program_name
 FROM sys.dm_exec_requests r
 JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
 JOIN sys.dm_db_task_space_usage tsu ON s.session_id = tsu.session_id and r.request_id = tsu.request_id
 WHERE r.status IN ('running', 'runnable', 'suspended')
 GROUP BY r.session_id, s.host_name, s.login_name, r.start_time, r.sql_handle, r.blocking_session_id, r.command, r.status, s.program_name) x

CREATE TABLE #xp_msver (
	[index] int,
	[name]VARCHAR(1000) NULL,
	internal_value INT NULL,
	character_value VARCHAR(1000) NULL)

INSERT INTO #xp_msver
EXEC master..xp_msver 'ProcessorCount'

SELECT @Internal_Value = internal_value
FROM #xp_msver
WHERE [name] = 'ProcessorCount'

SELECT t2.DBName,t2.ObjectName,t2.spid 'ProcessId',t2.TotalReads,t2.TotalWrites,t2.TotalReads+t2.TotalWrites 'TotalPhysical_IO',(t2.TotalReads+t2.TotalWrites)-(t.TotalReads+t.TotalWrites) 'Physical_IO_InTheTimeFragment',t2.TotalCPU,t2.TotalCPU-t.TotalCPU 'CPU_ConsumedInTheTimeFragment',t2.Writes_in_TempDB,UPPER(t2.CmdStatus) 'CmdStatus',t2.CmdType,t2.SQL_Text,t2.[Program_Name] 'Application_Name',t2.[Host_Name],t2.[Login_Name],t2.[Start_Time],t2.Blocking_spid,t2.Blocking_Text
FROM #tmpsysprocesses2 t2 INNER JOIN #tmpsysprocesses t
ON t2.spid = t.spid AND t2.start_time = t.start_time --AND t2.DBName IS NOT NULL

SELECT MAX(DATEDIFF(ms,t.EventTime,t2.EventTime)) 'Fragment_Duration', @Internal_Value 'Number_Of_CPUs', SUM(t2.TotalCPU-t.TotalCPU)'SUM CPU_ConsumedInTheTimeFragment', SUM((t2.TotalReads+t2.TotalWrites)-(t.TotalReads+t.TotalWrites))'SUM Physical_IO_InTheTimeFragment'
FROM #tmpsysprocesses2 t2 INNER JOIN #tmpsysprocesses t ON t2.spid = t.spid

SELECT TOP 5 'Top 5 Queries by CPU' AS Comment, total_worker_time/execution_count AS [Avg_CPU_Time], execution_count AS [Execution_Count],
(SELECT text AS [text()] FROM master.sys.dm_exec_sql_text(qs.sql_handle) FOR XML PATH(''), TYPE) AS Statement_Text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY total_worker_time/execution_count DESC;

SELECT TOP 5 'Top 5 Queries by IO' AS Comment, (total_logical_writes + total_logical_reads)/execution_count AS [Avg_IO_per_Exec], execution_count AS [Execution_Count],
(SELECT text AS [text()] FROM master.sys.dm_exec_sql_text(qs.sql_handle) FOR XML PATH(''), TYPE) AS Statement_Text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY (total_logical_writes + total_logical_reads)/execution_count DESC;

DROP TABLE #tmpsysprocesses
DROP TABLE #tmpsysprocesses2
GO
