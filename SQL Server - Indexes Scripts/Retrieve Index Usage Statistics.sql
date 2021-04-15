/*
Retrieve Index Usage Statistics

Description

Sample script that lists statistics for existing Indexes, ordered by user_updates. When an index I used it is inserted into sys.dm_db_index_usage_stats. If an index is not used it will not appear in sys.dm_db_index_usage_stats. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 


*/

select 
	* 
from 
	sys.dm_db_index_usage_stats 
order by 
	user_updates desc

