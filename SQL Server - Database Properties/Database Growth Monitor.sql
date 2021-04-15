/*
Database Growth Monitor

The script will monitor the growth of the databases on your server. It is really meant to just get you started on a more detailed solution.

*/

/*	Procedure for 8.0 server */
create proc usp_databases
as
	set nocount on
	declare @name sysname
	declare @SQL  nvarchar(600)

	/* Use temporary table to sum up database size w/o using group by */
	create table #databases (
				  DATABASE_NAME sysname NOT NULL,
				  size int NOT NULL)

	declare c1 cursor for 
		select name from master.dbo.sysdatabases
			where has_dbaccess(name) = 1 -- Only look at databases to which we have access

	open c1
	fetch c1 into @name

	while @@fetch_status >= 0
	begin
		select @SQL = 'insert into #databases
				select N'''+ @name + ''', sum(size) from '
				+ QuoteName(@name) + '.dbo.sysfiles'
		/* Insert row for each database */
		execute (@SQL)
		fetch c1 into @name
	end
	deallocate c1

	select	
		DATABASE_NAME,
		DATABASE_SIZE = size*8,/* Convert from 8192 byte pages to K */
		RUN_DT=GETDATE()
	from #databases
	order by 1

GO

