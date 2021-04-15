/*
Retrieve Tables, Indexes, Files, and File Groups Information

Description

Sample script that lists information regarding tables, indexes, file groups and file names. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

select 'table_name'=object_name(i.id)
		,i.indid
		,'index_name'=i.name
		,i.groupid
		,'filegroup'=f.name
		,'file_name'=d.physical_name
		,'dataspace'=s.name
from	sys.sysindexes i
		,sys.filegroups f
		,sys.database_files d
		,sys.data_spaces s
where objectproperty(i.id,'IsUserTable') = 1
and f.data_space_id = i.groupid
and f.data_space_id = d.data_space_id
and f.data_space_id = s.data_space_id
order by f.name,object_name(i.id),groupid
go

