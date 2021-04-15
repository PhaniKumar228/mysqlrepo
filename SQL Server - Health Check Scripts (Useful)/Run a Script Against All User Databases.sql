/*
Run a Script Against All User Databases

Now you can run administrative T-SQL tasks against all your databases in one shot. 
Very usefull for environments that have a seperate database for each client, ASP's, etc. 
It's pretty straight forward and can be used for almost any task. 

This example Looks for a table and prints the database name and selects from the table if it is found. 

*/

declare
@isql varchar(2000),
@dbname varchar(64)

declare c1 cursor for select name from master..sysdatabases where name not in ('master','model','msdb','tempdb')
open c1
fetch next from c1 into @dbname
While @@fetch_status <> -1
	begin
	select @isql = 'if exists(select * from @dbname..sysobjects where type = ''u'' and name like ''QueryTable'')' + char(13)
	select @isql = @isql + 'begin' + char(13)
	select @isql = @isql + 'print ''@dbname''' + char(13)
	select @isql = @isql + 'select * from @dbname..QueryTable' + char(13)
	select @isql = @isql + 'end' + char(13)
	select @isql = replace(@isql,'@dbname',@dbname)
--	print @isql
	exec(@isql)
	fetch next from c1 into @dbname
	end
close c1
deallocate c1






