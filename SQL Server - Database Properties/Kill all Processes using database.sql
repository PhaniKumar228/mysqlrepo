--Script to kill all processes using database 
--The next script will kill all the proccesses that use database which name in set to @dbname variable 

declare @dbname sysname
set @dbname = 'dbname' -- type here the name of database you want to kill processes of
declare 
     @spid INT
    ,@Query VARCHAR(250)
    ,@processes CURSOR
SET @processes = CURSOR FOR
select spid
from master..sysprocesses
where db_name(dbid) = @dbname
open @processes
fetch next from @processes into @spid
while @@FETCH_STATUS = 0
begin
    set @query = 'kill ' + cast(@spid as varchar(10))
    exec(@query)
    fetch next from @processes into @spid
end
close @processes
deallocate @processes
GO

