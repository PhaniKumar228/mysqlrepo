/*
List Runnable Queues

Description

Sample script that lists runnable queries. Runnable queues are those queues waiting for CPU time. Signal waits are the time spent in the runnable queue waiting for the CPU. This script requires Microsoft SQL Server 2005. 

Script Code


*/

select scheduler_id, session_id, status, command 
from sys.dm_exec_requests
where status = 'runnable'
and session_id > 50
order by scheduler_id

