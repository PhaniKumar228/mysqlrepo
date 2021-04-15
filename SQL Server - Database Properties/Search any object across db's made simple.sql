/*
Search any object across db's ..made simple

I just saw a script on this site for object search across the db's. 
I have written an alternate version with sp_msforeachdb undocumented sp which is much simpler.
This avoids a lot of code and dynamic sql.

Replace "object_name" with the name of the object which needs to be searched across the databases.

*/

SET QUOTED_IDENTIFIER ON 
GO
sp_msforeachdb "use ? ; SELECT name AS Table_Name,xtype AS type,'?' AS DB_Name FROM sysobjects WHERE name LIKE 'object_name%'"

