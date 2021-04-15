/*
Automate Profiler Trace with xp_trace_
Instead of interactively running profiler, you can use built in stored procedures to obtain the same results. 
You can even schedule the execution of the trace and output to a designated output file. 
*/

DECLARE @queue_handle int  
DECLARE @column_value int  
DECLARE @trace_file   varchar(50)
 
select @trace_file = 'g:\sqlserverbackup\confirm_profile' +  CONVERT (varchar(8), getdate(), 112 )+ '.trc'
--Set the column mask for the data columns to capture
SET @column_value = 1|16|3|8192|128|512|1024|4096

EXEC xp_trace_addnewqueue 1000,
    5,
    95,
    90,
    @column_value,
    @queue_handle OUTPUT
--To look up the names, execute xp_trace_geteventnames.
EXEC xp_trace_seteventclassrequired @queue_handle, 
    45, 1 --SP:StmtCompleted

EXEC xp_trace_seteventclassrequired @queue_handle, 
    10, 1 --RPC:Completed

EXEC xp_trace_seteventclassrequired @queue_handle, 
    12, 1 --SQL:BatchCompleted


--Set any filters. (Don't trace the Profiler).
EXEC xp_trace_setappfilter @queue_handle, 
    NULL, 
    'SQL Server Profiler%;%Query Analyzer%;MS SQLEM%'

EXEC xp_trace_setntnmfilter @queue_handle,
    'xxxxxx','a%'

--Configure the queue to write to a file.

EXEC xp_trace_setqueuedestination @queue_handle,
    2,
    1,
    NULL,
    @trace_file

EXEC xp_trace_startconsumer @queue_handle

SELECT @queue_handle

WAITFOR DELAY '00:60'
EXEC xp_trace_destroyqueue @queue_handle




