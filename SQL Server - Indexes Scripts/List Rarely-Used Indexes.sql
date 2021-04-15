/*
List Rarely-Used Indexes

Description

Sample stored procedure that lists rarely-used indexes. Because the number and type of accesses are tracked in dmvs, this procedure can find indexes that are rarely useful. Because the cost of these indexes is incurred during maintenance (e.g. insert, update, and delete operations), the write costs of rarely-used indexes may outweigh the benefits. This stored procedure requires Microsoft SQL Server 2005. 

Script Code


*/

declare @dbid int
select @dbid = db_id()
select objectname=object_name(s.object_id), s.object_id
	, indexname=i.name, i.index_id
	, user_seeks, user_scans, user_lookups, user_updates
from sys.dm_db_index_usage_stats s,
	sys.indexes i
where database_id = @dbid 
and objectproperty(s.object_id,'IsUserTable') = 1
and i.object_id = s.object_id
and i.index_id = s.index_id
order by (user_seeks + user_scans + user_lookups + user_updates) asc

