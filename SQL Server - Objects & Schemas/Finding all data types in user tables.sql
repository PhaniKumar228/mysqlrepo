/*
Finding all data types in user tables

This script queries sys.columns to get the entire list of columns and tables existing in the current database, then maps the columns datatype with a name from sys.systypes. The where clause filters the results for user created databases, less 'sysdiagrams', or you can use the commented out where clause to target a specific table.

This is a great way to hunt down various data types and make sure different development teams are on the same page and don't do silly things like having the data types on their tables not matching other tables and causing frustrations in forgetting to cast the values.

*/

select object_name(c.object_id) "Table Name", c.name "Column Name", s.name "Column Type"
  from sys.columns c
  join sys.systypes s on (s.xtype = c.system_type_id)
  where object_name(c.object_id) in (select name from sys.tables where name not like 'sysdiagrams')
  -- where object_name(c.object_id) in (select name from sys.tables where name like 'TARGET_TABLE_NAME')



