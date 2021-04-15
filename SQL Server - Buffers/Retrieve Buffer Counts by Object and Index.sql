/*
Retrieve Buffer Counts by Object and Index

Description

Sample script that breaks down buffers by object (table, index) in the buffer cache. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

use Northwind
go
select b.database_id, db=db_name(b.database_id)
		,p.object_id
		,object_name(p.object_id) as objname
		,p.index_id
		,buffer_count=count(*)
from sys.allocation_units a,
		sys.dm_os_buffer_descriptors b,
		sys.partitions p
where a.allocation_unit_id = b.allocation_unit_id
and a.container_id = p.hobt_id
and b.database_id = db_id()
group by b.database_id,p.object_id, p.index_id
order by buffer_count desc
