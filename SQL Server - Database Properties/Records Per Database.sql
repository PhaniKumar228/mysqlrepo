/*****************************************************************************************************************************************
*
* Purpose This procedure returns a recorset with row count and space used for all tables
* in the specified database (or for all databases except tempdb and model)
* Date 2008.03.05 (version for SQL Server 2005)
*
******************************************************************************************************************************************/

if exists(select * from sys.objects where object_id = object_id('dbo.proc_records_per_database') and type = 'P')
	drop procedure dbo.proc_records_per_database
go

create procedure dbo.proc_records_per_database
	@db_name sysname = NULL
as
begin
	set nocount on

	if @db_name is not null
	begin
		if not exists(select * from master.sys.databases where name = @db_name and database_id not in (2, 3) /* skip tempdb and model */)
		begin
			raiserror('Database does not exist or can not be queried', 16, 1)
			return
		end
	end

	declare @dbs_table table(name sysname not null primary key)

	--------------------------------------------------------------------------------------
	-- prepare databases list

	insert into @dbs_table
	select 
		name 
	from 
		master.sys.databases
	where 
		(@db_name is null or
		(@db_name is not null and name = @db_name)) and
		database_id not in (2, 3)

	create table #temp_table_list
	(
		rec_id int identity(1, 1) not null,
		cat_name sysname not null,
		sch_name sysname not null,
		tab_name sysname not null,
		row_count bigint not null default 0,
		reserved_pages bigint not null default 0,
		reserved bigint not null default 0,
		pages bigint not null default 0,
		data bigint not null default 0,
		used_pages bigint not null default 0,
		used bigint not null default 0,
		index_size bigint not null default 0,
		not_used bigint not null default 0,
		primary key(rec_id)
	)

	declare @cmd varchar(max)
	declare @n_cmd nvarchar(max)
	declare @dbx_name sysname

	--------------------------------------------------------------------------------
	-- get all tables

	while 1 = 1 
	begin
		set @dbx_name = NULL

		select top 1 @dbx_name = [name] from @dbs_table

		if @dbx_name is NULL
			break

		set @cmd = 'insert into #temp_table_list (cat_name, sch_name, tab_name) select TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME from [' + @dbx_name + '].INFORMATION_SCHEMA.TABLES where TABLE_TYPE = ''BASE TABLE'''
		set @n_cmd = cast(@cmd as nvarchar(max))

		exec sp_executesql @n_cmd

		delete from @dbs_table where [name] = @dbx_name
	end

	declare @max_rec_id int
	set @max_rec_id = NULL

	select @max_rec_id = max(rec_id) from #temp_table_list

	if @max_rec_id is NULL
		set @max_rec_id = -1

	declare @counter int
	set @counter = 1

	declare @objname varchar(max)

	while @counter <= @max_rec_id
	begin
		--------------------------------------------------------------------------------
		-- update table usage statistics

		select 
			@cmd = 'use [' + cat_name + ']; dbcc updateusage(0, ''[' + sch_name + '].[' + tab_name + ']'') with no_infomsgs'
		from
			#temp_table_list
		where
			rec_id = @counter

		set @n_cmd = cast(@cmd as nvarchar(max))

		-- print @n_cmd

		exec sp_executesql @n_cmd

		-----------------------------------------------------------------------------------------------
		-- get table stats (based on the code of the procedure sp_spaceused)

		declare @reservedpages_param bigint
		declare @usedpages_param bigint
		declare @pages_param bigint
		declare @index_size_param bigint
		declare @unused_param bigint
		declare @rows_param bigint

		set @reservedpages_param = 0
		set @usedpages_param = 0
		set @pages_param = 0
		set @index_size_param = 0
		set @unused_param = 0
		set @rows_param = 0

		select 
			@cmd = 
			' use [' + cat_name + '];

			declare @id int

			select @id = object_id(''[' + sch_name + '].[' + tab_name + ']'')

			SELECT 
				@reservedpages = sum(reserved_page_count),
				@usedpages = sum(used_page_count),
				@pages = sum(
					CASE
					WHEN (index_id < 2) THEN (in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count)
					ELSE lob_used_page_count + row_overflow_used_page_count
					END
				),
				@rowCount = sum(
					CASE
					WHEN (index_id < 2) THEN row_count
					ELSE 0
					END
				)
			FROM sys.dm_db_partition_stats
			WHERE object_id = @id;

			IF (SELECT count(*) FROM sys.internal_tables WHERE parent_id = @id AND internal_type IN (202,204)) > 0 
			BEGIN

				SELECT 
					@reservedpages = @reservedpages + sum(reserved_page_count),
					@usedpages = @usedpages + sum(used_page_count)
				FROM sys.dm_db_partition_stats p, sys.internal_tables it
				WHERE it.parent_id = @id AND it.internal_type IN (202,204) AND p.object_id = it.object_id;
			END

			SET @reservedpages = @reservedpages
			SET @index_size = (CASE WHEN @usedpages > @pages THEN (@usedpages - @pages) ELSE 0 END) * 8
			SET @unused = (CASE WHEN @reservedpages > @usedpages THEN (@reservedpages - @usedpages) ELSE 0 END) * 8'	
		from 
			#temp_table_list
		where
			rec_id = @counter

		set @n_cmd = cast(@cmd as nvarchar(max))

		exec sp_executesql 
			@n_cmd,
			@parameters = N'@reservedpages bigint OUTPUT, @usedpages bigint OUTPUT, @pages bigint OUTPUT, @index_size bigint OUTPUT, @unused bigint OUTPUT, @rowCount bigint OUTPUT',
			@reservedpages = @reservedpages_param OUTPUT,
			@usedpages = @usedpages_param OUTPUT,
			@pages = @pages_param OUTPUT,
			@index_size = @index_size_param OUTPUT,
			@unused = @unused_param OUTPUT,
			@rowCount = @rows_param OUTPUT

		update 
			#temp_table_list
		set 
			row_count = @rows_param,
			reserved_pages = @reservedpages_param,
			reserved = @reservedpages_param * 8,
			data = @pages_param * 8,
			index_size = @index_size_param,
			not_used = @unused_param,
			pages = @pages_param,
			used_pages = @usedpages_param,
			used = @usedpages_param * 8
		where
			rec_id = @counter

		set @counter = @counter + 1
	end

	select 
		cat_name, 
		sch_name, 
		tab_name, 
		row_count,
		reserved_pages,
		used_pages,
		pages,
		reserved,
		used,
		data,
		index_size,
		not_used
	from 
		#temp_table_list
	order by 
		cat_name,
		sch_name,
		tab_name

	drop table #temp_table_list
end
go

-- example A:

exec dbo.proc_records_per_database 'AdventureWorks'

-- example A:

exec dbo.proc_records_per_database


/*****************************************************************************************************************************************
*
* Purpose This procedure returns a recorset with row count and space used for all tables
* in the specified database (or for all databases except tempdb and model)
* This is the version for SQL Server 2000
* Date 2008.04.21
*
******************************************************************************************************************************************/


if exists(select * from sysobjects where id = object_id('dbo.proc_records_per_database') and type = 'P')
	drop procedure dbo.proc_records_per_database
go

create procedure dbo.proc_records_per_database
	@db_name sysname = NULL
as
begin
	set nocount on

	if @db_name is not null
	begin
		if not exists(select * from master.dbo.sysdatabases where name = @db_name and dbid not in (2, 3) /* skip tempdb and model */)
		begin
			raiserror('Database does not exist or can not be queried', 16, 1)
			return
		end
	end

	declare @dbs_table table(name sysname not null primary key)

	--------------------------------------------------------------------------------------
	-- prepare databases list

	insert into @dbs_table
	select 
		name 
	from 
		master.dbo.sysdatabases
	where 
		(@db_name is null or
		(@db_name is not null and name = @db_name)) and
		dbid not in (2, 3)

	create table #temp_table_list
	(
		rec_id int identity(1, 1) not null,
		cat_name sysname not null,
		sch_name sysname not null,
		tab_name sysname not null,
		row_count bigint not null default 0,
		reserved_pages bigint not null default 0,
		reserved bigint not null default 0,
		pages bigint not null default 0,
		data bigint not null default 0,
		used_pages bigint not null default 0,    
		used bigint not null default 0,
		index_size bigint not null default 0,
		not_used bigint not null default 0,
		primary key(rec_id)
	)

	declare @cmd varchar(4000)
	declare @n_cmd nvarchar(4000)
	declare @dbx_name sysname

	--------------------------------------------------------------------------------
	-- get all tables

	while 1 = 1 
	begin
		set @dbx_name = NULL

		select top 1 @dbx_name = [name] from @dbs_table

		if @dbx_name is NULL
			break

		set @cmd = 'insert into #temp_table_list (cat_name, sch_name, tab_name) select ''' + @dbx_name + ''', '''', name from [' + @dbx_name + '].dbo.sysobjects where type = ''U'''

		set @n_cmd = cast(@cmd as nvarchar(4000))

		exec sp_executesql @n_cmd

		delete from @dbs_table where [name] = @dbx_name
	end

	declare @max_rec_id int
	set @max_rec_id = NULL

	select @max_rec_id = max(rec_id) from #temp_table_list

	if @max_rec_id is NULL
		set @max_rec_id = -1

	declare @counter int
	set @counter = 1

	declare @objname varchar(4000)

	while @counter <= @max_rec_id
	begin
		--------------------------------------------------------------------------------
		-- update table usage statistics

		select 
			@cmd = 'use [' + cat_name + ']; dbcc updateusage(0, ''[' + tab_name + ']'') with no_infomsgs'
		from
			#temp_table_list
		where
			rec_id = @counter

		set @n_cmd = cast(@cmd as nvarchar(4000))

		-- print @n_cmd

		exec sp_executesql @n_cmd

		-----------------------------------------------------------------------------------------------
		-- get table stats (based on the code of the procedure sp_spaceused)

		declare @reservedpages_param bigint
		declare @usedpages_param bigint
		declare @pages_param bigint
		declare @index_size_param bigint
		declare @unused_param bigint
		declare @rows_param bigint

		set @reservedpages_param = 0
		set @usedpages_param = 0
		set @pages_param = 0
		set @index_size_param = 0
		set @unused_param = 0
		set @rows_param = 0

		select 
			@cmd = 
'use [' + cat_name + '];
declare @id int
select @id = object_id(''[' + tab_name + ']'')
select @reservedpages = sum(reserved) from sysindexes where indid in (0, 1, 255) and id = @id 
select @pages = sum(dpages) from sysindexes where indid < 2 and id = @id
select @pages = @pages + isnull(sum(used), 0) from sysindexes where indid = 255 and id = @id
select @index_size = (sum(used) - @pages) from sysindexes where indid in (0, 1, 255) and id = @id
select @usedpages = @index_size + @pages
set @index_size = @index_size * 8
select @unused = (@reservedpages - (select sum(used) from sysindexes where indid in (0, 1, 255) and id = @id)) * 8
select @rowCount = rows from sysindexes where indid < 2 and id = @id'
		from 
			#temp_table_list
		where
			rec_id = @counter

		set @n_cmd = cast(@cmd as nvarchar(4000))

		-- print @n_cmd

		exec sp_executesql 
			@n_cmd,
			@parameters = N'@reservedpages bigint OUTPUT, @usedpages bigint OUTPUT, @pages bigint OUTPUT, @index_size bigint OUTPUT, @unused bigint OUTPUT, @rowCount bigint OUTPUT',
			@reservedpages = @reservedpages_param OUTPUT,
			@usedpages = @usedpages_param OUTPUT,
			@pages = @pages_param OUTPUT,
			@index_size = @index_size_param OUTPUT,
			@unused = @unused_param OUTPUT,
			@rowCount = @rows_param OUTPUT

		update 
			#temp_table_list
		set 
			row_count = @rows_param,
			reserved_pages = @reservedpages_param,
			reserved = @reservedpages_param * 8,
			data = @pages_param * 8,
			index_size = @index_size_param,
			not_used = @unused_param,
			pages = @pages_param,
			used_pages = @usedpages_param,
			used = @usedpages_param * 8
		where
			rec_id = @counter

		set @counter = @counter + 1
	end

	select 
		cat_name, 
		tab_name, 
		row_count,
		reserved_pages,
		used_pages,
		pages as data_pages,
		reserved,
		used,
		data,
		index_size,
		not_used
	from 
		#temp_table_list
	order by 
		cat_name, 
		tab_name

	drop table #temp_table_list
end
go

-- example:

exec dbo.proc_records_per_database 'AdventureWorks2000'

exec dbo.proc_records_per_database 'Northwind'













