/*
Scan stored procedures in all databases

I wrote this for the developers because they were always asking me to find all of their stored procedures that did X.

It scans through the syscomments text in each database looking for the requested string.  
User must have read access on the syscomments and sysobjects tables in each database. 

*/

exec sp_MSforeachdb 'SELECT db=''?'', [type], [name], [text] FROM [?]..sysobjects a inner join [?]..syscomments b on a.id = b.id where text like ''%Text to search for%'' order by [name], [number]', '?'

