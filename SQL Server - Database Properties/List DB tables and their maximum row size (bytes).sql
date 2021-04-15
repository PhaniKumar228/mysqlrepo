/*
List DB tables and their maximum row size (bytes)

Many users during the process of insert or update get the following warning issued by SQL Server

Warning: The table 'TABLE NAME' has been created but its maximum row size (XXXX) exceeds the maximum number of bytes per row (8060). INSERT or UPDATE of a row in this table will fail if the resulting row length exceeds 8060 bytes.

This is happening because the row-length in bytes, exceeds the maximum length SQL server allows. The script, does not prevent this from happening. Instead, it lists to the user all of its database tables, along with their length in Bytes. All Tables that are above 8060 should have their column datatype lengths changed to prevent any loss of Data during Insert or Update of Data. 

*/

select case when 
(grouping(sob.name)=1) then 'All_Tables' else isnull(sob.name, 'unknown')
end as Table_name,
sum(sys.length)as Byte_Length 
from sysobjects sob,  syscolumns sys 
where 
	sob.xtype='u' and
	sys.id=sob.id
	group by sob.name
	with cube
