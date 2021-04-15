/*
Imagine situation that you have a phone call from customer at 2 AM 
complaining of low performance of their system. 
After 10 seconds of incomprehension you begin to understand that this 
is not a nightmare and you are to undertake some actions. 
This article does not pretend to be the full description of capacity planning 
strategy and low performance prevention tips. 
Here you will find the description of the actions you must undertake right now. 
The aim is to figure out the cause of performance problem. 
When you got to know the cause - you almost fixed the issue. 

Finding out the root cause of low sql server performance quickly is kind of art. 
There are two major types of sql server performance deterioration 

When customer complains of low performance but all system counters show acceptable values
After customer complaint you see the issue on system level - Extreme CPU load, 
enormous disk queue length, memory presure.
The first type relates mostly to locking and index degradation. 
The second - to lack of system resources.

So lets begin the analysis.
Try to connect to the sql server instance. 
In worst case sql server won't accept new connection request and you will need to 
connect using DAC.
It would be great to connect to the remote desktop of the machine to see 
performance monitor (perfmon utility) for the analysis. 
Start performance monitor and choose the next counters:

CPU total - must be less than 80%. 
If greater - there are too much arithmetic operations or ad-hoc queries compilations.
Avg. Disk queue length - if this value is more than 20 you should investigate 
what uses disk so much - either table scans or memory preasure. 
Page life expectancy - should be more than 5 minutes (showed in seconds) 
- if less - you are having memory preasure 
Cache hit ratio - this value should be >90% approaching 100%. 
If lesser than 90% - memory preasure or table scans. 
*/

--If the problem occured on SQL Server 2000 instance - 
--run from query analyzer the next query 

select * from sysprocesses

/*Pay attention to blocked column - for blocked processes it shows 
the blocking process id (SPID). Look at cpu and physical_io columns. 
Sort by these columns the processes. 
If there is a process which cpu or physical_io is much much bigger than other processes' 
values (>=1000000) then you have probably found the culprit of sql server performance 
deterioration. Now you need to start profiler and filter it with the consumptive 
system process id. 
To see which statement the process is running right know run the query
*/
dbcc inputbuffer(spid)

/*
Most probably you will need to kill this process using kill spid query but 
this action must be approved by the customer.
If the problem happens on SQL Server 2005 or above version you can use the 
power of DMV - data management views and functions. 
You can still run the queries against sysprocesses but much more informative are
*/

select * from sys.dm_exec_sessions
select * from sys.dm_exec_requests

--SQL Server 2005 rebuild all indexes script
exec sp_msForEachTable 'alter index all on ? rebuild'

--SQL Server 2000 rebuild all indexes script
exec sp_msForEachTable 'dbcc dbreindex(''?'')'

--Script to update all statistics 
exec sp_updatestats







