/*
List Real Time Tempdb Task Usage

Description

Sample script that lists the real-time task usage of Tempdb. This script requires Microsoft SQL Server 2005. 

Script Code


*/

SELECT t1.session_id,
(t1.internal_objects_alloc_page_count + task_alloc) as allocated,
(t1.internal_objects_dealloc_page_count + task_dealloc) as
 deallocated 
from sys.dm_db_session_space_usage as t1, 
(select session_id, 
   sum(internal_objects_alloc_page_count)
   			as task_alloc,
   sum (internal_objects_dealloc_page_count) as 
		task_dealloc 
      from sys.dm_db_task_space_usage group by session_id) as t2
where t1.session_id = t2.session_id and t2.session_id >50
order by allocated DESC

