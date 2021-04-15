if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[my_sp_spaceused]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[my_sp_spaceused]
GO

create procedure my_sp_spaceused --- 2007/08/23 12:1
@objname nvarchar(776) = null,		-- The object we want size on.
@updateusage varchar(5) = false		-- Param. for specifying that
					-- usage info. should be updated.
as

declare @id	int			-- The object id of @objname.
declare @type	character(2) -- The object type.
declare	@pages	int			-- Working variable for size calc.
declare @dbname sysname
declare @dbsize dec(15,0)
declare @logsize dec(15)
declare @bytesperpage	dec(15,0)
declare @pagesperMB		dec(15,0)

/*Create temp tables before any DML to ensure dynamic
**  We need to create a temp table to do the calculation.
**  reserved: sum(reserved) where indid in (0, 1, 255)
**  data: sum(dpages) where indid < 2 + sum(used) where indid = 255 (text)
**  indexp: sum(used) where indid in (0, 1, 255) - data
**  unused: sum(reserved) - sum(used) where indid in (0, 1, 255)
*/
create table #spt_space
(
	[id]		[int] IDENTITY (1, 1) NOT NULL ,
	tblname		varchar(200),
	rows		int null,
	reserved	dec(15) null,
	data		dec(15) null,
	indexp		dec(15) null,
	unused		dec(15) null
)

/*
**  Check to see if user wants usages updated.
*/

if @updateusage is not null
	begin
		select @updateusage=lower(@updateusage)

		if @updateusage not in ('true','false')
			begin
				raiserror(15143,-1,-1,@updateusage)
				return(1)
			end
	end
/*
**  Check to see that the objname is local.
*/
if @objname IS NOT NULL
begin

	select @dbname = parsename(@objname, 3)

	if @dbname is not null and @dbname <> db_name()
		begin
			raiserror(15250,-1,-1)
			return (1)
		end

	if @dbname is null
		select @dbname = db_name()

	/*
	**  Try to find the object.
	*/
	select @id = null
	select @id = id, @type = xtype
		from sysobjects
			where id = object_id(@objname)

	/*
	**  Does the object exist?
	*/
	if @id is null
		begin
			raiserror(15009,-1,-1,@objname,@dbname)
			return (1)
		end


	if not exists (select * from sysindexes
				where @id = id and indid < 2)

		if      @type in ('P ','D ','R ','TR','C ','RF') --data stored in sysprocedures
				begin
					raiserror(15234,-1,-1)
					return (1)
				end
		else if @type = 'V ' -- View => no physical data storage.
				begin
					raiserror(15235,-1,-1)
					return (1)
				end
		else if @type in ('PK','UQ') -- no physical data storage. --?!?! too many similar messages
				begin
					raiserror(15064,-1,-1)
					return (1)
				end
		else if @type = 'F ' -- FK => no physical data storage.
				begin
					raiserror(15275,-1,-1)
					return (1)
				end
end

/*
**  Update usages if user specified to do so.
*/

if @updateusage = 'true'
	begin
		if @objname is null
			dbcc updateusage(0) with no_infomsgs
		else
			dbcc updateusage(0,@objname) with no_infomsgs
		print ' '
	end


set nocount on

/*
**  If @id is null, then we want summary data.
*/
/*	Space used calculated in the following way
**	@dbsize = Pages used
**	@bytesperpage = d.low (where d = master.dbo.spt_values) is
**	the # of bytes per page when d.type = 'E' and
**	d.number = 1.
**	Size = @dbsize * d.low / (1048576 (OR 1 MB))
*/
if @id is null
begin
declare
@strTblName varchar(200),
@intID	int

DECLARE cursor_ CURSOR FOR
 select [name] from sysobjects where xtype='U' and [name] not like 'dtprop%'
OPEN cursor_
FETCH NEXT FROM cursor_ INTO @strTblName
WHILE (@@FETCH_STATUS<>-1)
BEGIN
 	select @id = id, @type = xtype
		from sysobjects
			where id = object_id(@strTblName)
 

	/*
	**  Now calculate the summary data.
	**  reserved: sum(reserved) where indid in (0, 1, 255)
	*/
	insert into #spt_space (reserved,tblname)
		select sum(reserved),@strTblName
			from sysindexes
				where indid in (0, 1, 255)
					and id = @id
	select @intID = max([id]) from #spt_space
	/*
	** data: sum(dpages) where indid < 2
	**	+ sum(used) where indid = 255 (text)
	*/
	select @pages = sum(dpages)
			from sysindexes
				where indid < 2
					and id = @id
	select @pages = @pages + isnull(sum(used), 0)
		from sysindexes
			where indid = 255
				and id = @id
	update #spt_space
		set data = @pages where [id]=@intID


	/* index: sum(used) where indid in (0, 1, 255) - data */
	update #spt_space
		set indexp = (select sum(used)
				from sysindexes
					where indid in (0, 1, 255)
						and id = @id)
			    - data
	where [id]=@intID
	/* unused: sum(reserved) - sum(used) where indid in (0, 1, 255) */
	update #spt_space
		set unused = reserved
				- (select sum(used)
					from sysindexes
						where indid in (0, 1, 255)
							and id = @id)
	where [id]=@intID
	update #spt_space
		set rows = i.rows
			from sysindexes i
				where i.indid < 2
					and i.id = @id
	and #spt_space.[id]=@intID




FETCH NEXT FROM cursor_ INTO @strTblName
END
CLOSE cursor_
DEALLOCATE cursor_
	select  tblname,rows = convert(char(11), rows),
		reserved = ltrim(str(reserved * d.low / 1024.,15,0) +
				' ' + 'KB'),
		data = ltrim(str(data * d.low / 1024.,15,0) +
				' ' + 'KB'),
		index_size = ltrim(str(indexp * d.low / 1024.,15,0) +
				' ' + 'KB'),
		unused = ltrim(str(unused * d.low / 1024.,15,0) +
				' ' + 'KB')
	from #spt_space, master.dbo.spt_values d
		where d.number = 1
			and d.type = 'E'
	union
	select  '_Total_',rows = convert(char(11), sum(rows)),
		reserved = ltrim(str(sum(reserved) * d.low / 1024.,15,0) +
				' ' + 'KB'),
		data = ltrim(str(sum(data) * d.low / 1024.,15,0) +
				' ' + 'KB'),
		index_size = ltrim(str(sum(indexp) * d.low / 1024.,15,0) +
				' ' + 'KB'),
		unused = ltrim(str(sum(unused) * d.low / 1024.,15,0) +
				' ' + 'KB')
	from #spt_space, master.dbo.spt_values d
		where d.number = 1
			and d.type = 'E'
	group by d.low
end

/*
**  We want a particular object.
*/
else
begin
	/*
	**  Now calculate the summary data.
	**  reserved: sum(reserved) where indid in (0, 1, 255)
	*/
	insert into #spt_space (reserved)
		select sum(reserved)
			from sysindexes
				where indid in (0, 1, 255)
					and id = @id

	/*
	** data: sum(dpages) where indid < 2
	**	+ sum(used) where indid = 255 (text)
	*/
	select @pages = sum(dpages)
			from sysindexes
				where indid < 2
					and id = @id
	select @pages = @pages + isnull(sum(used), 0)
		from sysindexes
			where indid = 255
				and id = @id
	update #spt_space
		set data = @pages


	/* index: sum(used) where indid in (0, 1, 255) - data */
	update #spt_space
		set indexp = (select sum(used)
				from sysindexes
					where indid in (0, 1, 255)
						and id = @id)
			    - data

	/* unused: sum(reserved) - sum(used) where indid in (0, 1, 255) */
	update #spt_space
		set unused = reserved
				- (select sum(used)
					from sysindexes
						where indid in (0, 1, 255)
							and id = @id)
	update #spt_space
		set rows = i.rows
			from sysindexes i
				where i.indid < 2
					and i.id = @id

	select name = object_name(@id),
		rows = convert(char(11), rows),
		reserved = ltrim(str(reserved * d.low / 1024.,15,0) +
				' ' + 'KB'),
		data = ltrim(str(data * d.low / 1024.,15,0) +
				' ' + 'KB'),
		index_size = ltrim(str(indexp * d.low / 1024.,15,0) +
				' ' + 'KB'),
		unused = ltrim(str(unused * d.low / 1024.,15,0) +
				' ' + 'KB')
	from #spt_space, master.dbo.spt_values d
		where d.number = 1
			and d.type = 'E'
end

return (0) -- sp_spaceused


GO

