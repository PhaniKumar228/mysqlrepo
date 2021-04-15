/*
Get Relationship for your tables

Use this script to get relationship between ur tables (PK, FK), if defined. 
This script will give you base table and its columns (PK) with other related tables and columns (FK).
So, no need to check in the diagram.

*/

select s1.name as 'BaseTable', c1.name as 'BaseColumn (PK)',
s2.name 'TargetTable', c2.name as 'TargetColumn (FK)'
from sysReferences sr 
join sysobjects s1 on (sr.rkeyid=s1.id)
join sysobjects s2 on (sr.fkeyid=s2.id)
join syscolumns c1 on (s1.id=c1.id and sr.rkey1=c1.colid)
join syscolumns c2 on (s2.id=c2.id and sr.fkey1=c2.colid)
--where sr.rkeyid=object_id('TableName')
order by s1.name, s2.name, c1.name, c2.name



