/*
List Schedulers, Workers, and Runnable Queues

Description

Sample script that lists schedulers, workers, and runnable queues. Note than schedulers with IDs greater than 255 are hidden schedulers. This script requires Microsoft SQL Server 2005. 

Script Code


*/

select 
	scheduler_id,
	current_tasks_count,
	runnable_tasks_count,
	current_workers_count,
	active_workers_count,
	work_queue_count,
	load_factor,
	status
from sys.dm_os_schedulers
--where scheduler_id < 255
order by scheduler_id

