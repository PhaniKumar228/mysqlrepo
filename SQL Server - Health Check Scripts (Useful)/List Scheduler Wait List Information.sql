/*
List Scheduler Wait List Information

Description

Sample script that provides a breakdown by scheduler of scheduler wait list, workers, and runnable queues. This script requires Microsoft SQL Server 2005. 

Script Code


*/

select 
	scheduler_id,
	current_tasks_count,
	runnable_tasks_count,
	current_workers_count,
	active_workers_count,
	work_queue_count,
	load_factor
from sys.dm_os_schedulers
where scheduler_id < 255

