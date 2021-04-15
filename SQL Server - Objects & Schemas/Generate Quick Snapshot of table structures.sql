/*

Generate Quick Snapshot of table structures.

I use this script to quickly compare databases. 
In the past, I would generate creation scripts and compare those but that is tedious at best. 
This script generates a report of the metadata in an easy to read format that includes...

- Table and Field Listing with types.
- Foreign Key information
- Primary Key and Index information
- Default Constraints
- Check Constraints (name only)
- Stored Procedures (name only)
- Views (name only)
- Other objects (name only)

This script can be modified to include more information if you like.
 
*/

Set NoCount on
/**************************************************************************************
Detail Schema

This procedure will produce a report for SQL Server 2000 on the general structure of
the selected database.  It will query the sys* tables and build the report from that.
**************************************************************************************/

/* These variables determine the maximum characters that a user table can take up.  This
is used later on when formatting fields so that a text report can be generated without 
each field taking up too many columns.
*/
Declare @MaxTableNameLen int
Declare @MaxFieldNameLen int
Declare @MaxIndexNameLen int

Select @MaxTableNameLen = (Select Max(Len(Name))+1 From sysobjects Where xType = 'U')
Select @MaxFieldNameLen = (Select Max(Len(c.Name))+1 From sysobjects o inner Join syscolumns c on o.id = c.id Where o.xType = 'U')
Select @MaxIndexNameLen = (select Max(Len(sysindexes.name))
				from sysindexes join sysobjects on sysindexes.id = sysobjects.id
				where sysobjects.type ='U'
					AND  indexproperty(sysindexes.id, sysindexes.name, 'IsHypothetical')   = 0
					AND  indexproperty(sysindexes.id, sysindexes.name, 'IsStatistics')     = 0
					AND  indexproperty(sysindexes.id, sysindexes.name, 'IsAutoStatistics') = 0
					AND  objectproperty(sysindexes.id, 'IsMsShipped') = 0)

--Print @MaxTableNameLen 
--Print @MaxFieldNameLen 

Print '**********************************************************'
Print '* General Table Listing section **************************'
Print '**********************************************************'
SELECT	Convert(varchar,Left(sysobjects.name, @MaxTableNameLen)) AS TableName, 
	Convert(varchar,Left(syscolumns.name,@MaxFieldNameLen)) AS ColName, 
	Convert(varchar,Left(systypes.name,12)) AS Type, 
	syscolumns.length AS Length, 
	syscolumns.prec AS [Precision],
	syscolumns.scale AS Scale,
	columnproperty(object_id(sysobjects.name), syscolumns.name,'IsIdentity') as Idty
FROM syscolumns
	INNER JOIN sysobjects 
	ON syscolumns.id = sysobjects.id 
		INNER JOIN systypes 
		ON syscolumns.xtype = systypes.xtype
WHERE	(sysobjects.xtype = 'U') AND 
	(objectproperty(sysobjects.id, 'IsMsShipped') = 0)
ORDER BY sysobjects.name, syscolumns.colorder


Print '**********************************************************'
Print '* Foreign Key Relationships ******************************'
Print '**********************************************************'
SELECT Convert(varchar,Left(ReferenceKeyTable.name, @MaxTableNameLen)) AS RefTable,
	Convert(varchar,Left(RefKeyColumns.name,@MaxFieldNameLen)) AS RefCol,
	Convert(varchar,Left(ForiegnKeyTable.name,@MaxTableNameLen + 1)) AS FKTable, 
	Convert(varchar,Left(FKColumns.name,@MaxFieldNameLen)) AS FKCol
FROM sysobjects ForiegnKeyTable 
	INNER JOIN sysforeignkeys ForiegnKeys 
	ON ForiegnKeyTable.id = ForiegnKeys.fkeyid 
		INNER JOIN sysobjects ReferenceKeyTable 
		ON ForiegnKeys.rkeyid = ReferenceKeyTable.id 
			INNER JOIN syscolumns FKColumns 
			ON ForiegnKeys.fkey = FKColumns.colid AND ForiegnKeyTable.id = FKColumns.id 
				INNER JOIN syscolumns RefKeyColumns 
				ON ReferenceKeyTable.id = RefKeyColumns.id AND ForiegnKeys.rkey = RefKeyColumns.colid
Order by RefTable,RefCol,FKTable,FKCol


Print '**********************************************************'
Print '* Index and Primary Key information **********************'
Print '**********************************************************'

select Convert(varchar,Left(sysobjects.name,@MaxTableNameLen)) as TableName,
	Convert(varchar,Left(sysindexes.name,@MaxIndexNameLen)) as IndexName,
	Convert(varchar,Left(syscolumns.name,@MaxFieldNameLen)) as ColumnName,
	case sysindexes.indid when 1 then 1 else 0 end as "IndexClustered",
	sysindexes.keycnt 
--	sysindexes.rows
from sysindexes join sysobjects on sysindexes.id = sysobjects.id
join sysindexkeys on sysindexes.indid = sysindexkeys.indid
Join syscolumns on sysindexkeys.colid = syscolumns.colid
where sysobjects.type ='U'
	AND  sysobjects.id = sysindexkeys.id
	AND  sysobjects.id = syscolumns.id
	AND  indexproperty(sysindexes.id, sysindexes.name, 'IsHypothetical')   = 0
	AND  indexproperty(sysindexes.id, sysindexes.name, 'IsStatistics')     = 0
	AND  indexproperty(sysindexes.id, sysindexes.name, 'IsAutoStatistics') = 0
	AND  objectproperty(sysindexes.id, 'IsMsShipped') = 0
order by sysobjects.name, sysindexes.name, syscolumns.name


Print '**********************************************************'
Print '* Default Constraints ************************************'
Print '**********************************************************'

select	Convert(varchar,sysobjects_parent.name) 	as TABLE_NAME
	,Convert(varchar,syscolumns.name)		as COLUMN_NAME
	,Convert(varchar,syscomments.text)		as DEFAULT_CLAUSE
from	sysobjects
join 	syscomments	on 	sysobjects.id = syscomments.id
join 	sysobjects	sysobjects_parent  on  sysobjects.parent_obj = sysobjects_parent.id  
join    sysconstraints  on sysobjects.id	= sysconstraints.constid
join 	syscolumns	 on sysobjects_parent.id = syscolumns.id
			and sysconstraints.colid = syscolumns.colid
where
	sysobjects.xtype = 'D'
	And objectproperty(sysobjects_parent.id, 'IsMsShipped') = 0
Order by TABLE_NAME, COLUMN_NAME

Print '**********************************************************'
Print '* By name listing of other objects in the database *******'
Print '**********************************************************'
Declare @MaxSysObjNameLen int
Select @MaxSysObjNameLen = (Select Max(Len(Name))+1 From sysobjects Where objectproperty(id, 'IsMsShipped') = 0)

Select Convert(varchar,Left(name,@MaxSysObjNameLen)) as Name, 
	Case xType
		When 'C' then 'CHECK constraint'
		When 'L' then 'Log'
		When 'FN' then 'Scalar function'
		When 'IF' then 'Inlined table-function'
		When 'P' then 'Stored procedure'
		When 'RF' then 'Replication filter stored procedure '
		When 'S' then 'System table'
		When 'TF' then 'Table function'
		When 'TR' then 'Trigger'
		When 'UQ' then 'UNIQUE constraint (type is K)'
		When 'V' then 'View'
		When 'X' then 'Extended stored procedure'
	End As ObjectType
From sysobjects
Where objectproperty(id, 'IsMsShipped') = 0
And xtype not in ('U','PK','F','D')
order by xType, name



