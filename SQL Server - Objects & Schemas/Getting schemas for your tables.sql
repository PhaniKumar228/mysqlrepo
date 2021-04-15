/*
Getting schemas for your tables

Try this script on Adventureworks where there is more than one schema. 
A quick way to access the tables you want is to pop the second script into a temp table by selecting only the tables you need (or don't), and create your own sp_msforeachtable procedure.

*/

-- Both these queries access same data, the first one creates
-- separate database, schema, and table columns

select db_name() "Database", a.name "Schema", b.name "Table"
  into #schema_table
  from sys.schemas a
  left join sys.tables b on (b.schema_id = a.schema_id)
  where a.name is not null and b.name is not null
  order by b.name

-- This takes the above and joins all three into one value.  
-- Remove quotename if you don't need the [ ] around each part.

select quotename(db_name()) + '.' + quotename(a.name) + '.' + quotename(b.name) "FullTableName"
  from sys.schemas a
  left join sys.tables b on (b.schema_id = a.schema_id)
  where a.name is not null and b.name is not null
  order by a.name, b.name










