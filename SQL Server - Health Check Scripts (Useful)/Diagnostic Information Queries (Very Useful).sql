-- Diagnostic Information Queries

-- SQL Server Name
SELECT @@SERVERNAME AS 'SQL Server Name'

-- SQL Version information
SELECT @@VERSION AS 'Version Info'
 
-- Hardware Information
SELECT cpu_count AS 'Logical CPU Count', hyperthread_ratio AS 'Hyperthread Ratio',
cpu_count/hyperthread_ratio As 'Physical CPU Count', 
physical_memory_in_bytes/1048576 AS 'Physical Memory (MB)'
FROM sys.dm_os_sys_info

-- sp_configure values
EXEC sp_configure 'Show Advanced Options', 1
GO
RECONFIGURE
GO
EXEC sp_configure

-- File Names and Paths 
SELECT dbid, fileid, filename 
FROM sys.sysaltfiles
WHERE fileid IN (1,2)

-- Recovery model 
SELECT [name], recovery_model_desc, log_reuse_wait_desc 
FROM sys.databases

-- Individual File Sizes
SELECT name AS 'File Name' , physical_name AS 'Physical Name', size/128 AS 'Total Size in MB',
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)/128.0 AS 'Available Space In MB'--, *
FROM sys.database_files;

-- Top Wait Stats
WITH Waits AS
(
  SELECT
    wait_type,
    wait_time_ms / 1000. AS wait_time_s,
    100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct,
    ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
  FROM sys.dm_os_wait_stats
  WHERE wait_type NOT LIKE '%SLEEP%' -- filter out additional irrelevant waits
)
SELECT
  W1.wait_type, 
  CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s,
  CAST(W1.pct AS DECIMAL(12, 2)) AS pct,
  CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct
FROM Waits AS W1
INNER JOIN Waits AS W2
ON W2.rn <= W1.rn
GROUP BY W1.rn, W1.wait_type, W1.wait_time_s, W1.pct
HAVING SUM(W2.pct) - W1.pct < 90 -- percentage threshold
ORDER BY W1.rn;


-- Signal Waits
SELECT '%signal (cpu) waits' = CAST(100.0 * SUM(signal_wait_time_ms) / SUM (wait_time_ms) AS NUMERIC(20,2)),
       '%resource waits'= CAST(100.0 * SUM(wait_time_ms - signal_wait_time_ms) / SUM (wait_time_ms) AS NUMERIC(20,2))
FROM sys.dm_os_wait_stats;


-- Page Life Expectancy
SELECT cntr_value AS 'Page Life Expectancy'
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
AND counter_name = 'Page life expectancy'


-- Buffer Pool 
SELECT TOP 10 [type], sum(single_pages_kb) AS [SPA Mem, Kb] 
FROM sys.dm_os_memory_clerks 
GROUP BY type  
ORDER BY SUM(single_pages_kb) DESC;
-- Switch to the database you are interested in before you run these: -- SP's By Execution Count
SELECT TOP 50 qt.text AS 'SP Name', qs.execution_count AS 'Execution Count',  
qs.execution_count/DATEDIFF(Second, qs.creation_time, GetDate()) AS 'Calls/Second',
qs.total_worker_time/qs.execution_count AS 'AvgWorkerTime',
qs.total_worker_time AS 'TotalWorkerTime',
qs.total_elapsed_time/qs.execution_count AS 'AvgElapsedTime',
qs.max_logical_reads, qs.max_logical_writes, qs.total_physical_reads, 
DATEDIFF(Minute, qs.creation_time, GetDate()) AS 'Age in Cache'
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.dbid = db_id() -- Filter by current database
ORDER BY qs.execution_count DESC


-- SP's By Worker Time
SELECT TOP 20 qt.text AS 'SP Name', qs.total_worker_time AS 'TotalWorkerTime', 
qs.total_worker_time/qs.execution_count AS 'AvgWorkerTime',
qs.execution_count AS 'Execution Count', 
ISNULL(qs.execution_count/DATEDIFF(Second, qs.creation_time, GetDate()), 0) AS 'Calls/Second',
ISNULL(qs.total_elapsed_time/qs.execution_count, 0) AS 'AvgElapsedTime', 
qs.max_logical_reads, qs.max_logical_writes, 
DATEDIFF(Minute, qs.creation_time, GetDate()) AS 'Age in Cache'
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.dbid = db_id() -- Filter by current database
ORDER BY qs.total_worker_time DESC


-- SP's By Logical Reads
SELECT TOP 20 qt.text AS 'SP Name', total_logical_reads, 
qs.execution_count AS 'Execution Count', total_logical_reads/qs.execution_count AS 'AvgLogicalReads',
qs.execution_count/DATEDIFF(Second, qs.creation_time, GetDate()) AS 'Calls/Second', 
qs.total_worker_time/qs.execution_count AS 'AvgWorkerTime',
qs.total_worker_time AS 'TotalWorkerTime',
qs.total_elapsed_time/qs.execution_count AS 'AvgElapsedTime',
qs.total_logical_writes,
qs.max_logical_reads, qs.max_logical_writes, qs.total_physical_reads, 
DATEDIFF(Minute, qs.creation_time, GetDate()) AS 'Age in Cache'
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.dbid = db_id() -- Filter by current database
ORDER BY total_logical_reads DESC


-- Bad Indexes
SELECT 'Table Name' = object_name(s.object_id), 'Index Name' = i.name, i.index_id,
       'Total Writes' =  user_updates, 'Total Reads' = user_seeks + user_scans + user_lookups,
        'Difference' = user_updates - (user_seeks + user_scans + user_lookups)
FROM sys.dm_db_index_usage_stats AS s 
INNER JOIN sys.indexes AS i
ON s.object_id = i.object_id
AND i.index_id = s.index_id
WHERE objectproperty(s.object_id,'IsUserTable') = 1
AND s.database_id = db_id()
AND user_updates > (user_seeks + user_scans + user_lookups)
ORDER BY 'Difference' DESC, 'Total Writes' DESC, 'Total Reads' ASC;


-- Missing Indexes By Index Advantage
SELECT user_seeks * avg_total_user_cost * (avg_user_impact * 0.01) AS index_advantage, migs.last_user_seek, mid.statement as 'Database.Schema.Table',
mid.equality_columns, mid.inequality_columns, mid.included_columns,
migs.unique_compiles, migs.user_seeks, migs.avg_total_user_cost, migs.avg_user_impact
FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK)
ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK)
ON mig.index_handle = mid.index_handle
ORDER BY index_advantage DESC;
