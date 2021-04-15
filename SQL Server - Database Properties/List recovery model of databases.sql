--Steve Bergkamp
--Script to list recovery model of databases.
declare @dblist table(db sysname,model char(45))
declare @dbname sysname,@model char(45)
insert @dblist(db)select name from master..sysdatabases 
where name not in ('master','model','tempdb','msdb')
select @dbname=min(db) from @dblist

while @dbname is not null
begin
select @model=cast(databasepropertyex(@dbname, 'Recovery') as char(45))
update @dblist set model=@model where db=@dbname
select @dbname=min(db) from @dblist where db>@dbname
end
select * from @dblist order by model
