/*
Compare Signal Waits and Resource Waits
Description
Sample script that compares signal waits and resource waits. 
Signal waits are the time spent in the runnable queue waiting for the CPU, 
while resource waits are the time spent waiting for the resource (wait_time_ms minus signal_wait_time_ms). 
Wait_time_ms represents the total waits. 
This script requires Microsoft SQL Server 2005. 
Script Code

*/

Select signal_wait_time_ms=sum(signal_wait_time_ms)
	,'%signal waits' = cast(100.0 * sum(signal_wait_time_ms) / sum (wait_time_ms) as numeric(20,2))
	,resource_wait_time_ms=sum(wait_time_ms - signal_wait_time_ms)
	,'%resource waits'= cast(100.0 * sum(wait_time_ms - signal_wait_time_ms) / sum (wait_time_ms) as numeric(20,2))
From sys.dm_os_wait_stats

