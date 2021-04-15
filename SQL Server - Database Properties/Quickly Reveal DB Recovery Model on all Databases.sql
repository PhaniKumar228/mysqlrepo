/*
Quickly Reveal DB Recovery Model on all Databases.

I wrote this little tool out of the frustratingly slow process one must endure to find out what database Recovery Model your SQL 2000 databases are currently set to. 
This tool will quickly reveal whether your database Recovery model is set to either "Simple", "Full", or "Bulk-Logged."

Who has time to manually pull up "Properties" then "Options" on each database? Not us! Let's put an end to this problem!

OK - this script automatically writes and executes the necessary scripts to quickly reveal all of your database Recovery Models on all databases on a machine. 

Just drop it in Query Analyzer on any SQL 2000 or SQL 2005 machine - run it - and enjoy! This tool utilizes the SQL 2000 Transact-SQL function DATABASEPROPERTYEX. This tool will NOT work on SQL 6.5 or SQL 7.0. 

Also you will need to have full System Administrator privileges to execute this script. This script reveals information only. It does NOT alter or modify any database setting.

Here is my DBRecoveryModelGenerator Tool: 

*/

Use master
declare @DBName varchar(35),
             @str varchar (255)
declare DBRecoveryModelGenerator_cursor cursor for
 select name from sysdatabases
where category in ('0', '1','16') 
order by name
open DBRecoveryModelGenerator_cursor
fetch next from DBRecoveryModelGenerator_cursor into @DBName while (@@fetch_status <> -1)
begin
if (@@fetch_status <> -2)
begin
select @str = 'SELECT DATABASEPROPERTYEX ('''+ @DBName + ''', ''Recovery'')' + @DBName 
exec (@str)
end fetch next from DBRecoveryModelGenerator_cursor into @DBName end
close DBRecoveryModelGenerator_cursor
DEALLOCATE DBRecoveryModelGenerator_cursor
go



