CREATE proc SP_NChelpindex
	@objname varchar(256),		-- the table to check for indexes
	@CLUST VARCHAR(20) = 'ALL',	-- CLUSTERED for Clustered Indexes only, NONCLUSTERED for nonclustered indexes only
	@pk VARCHAR(10) = 'ALL'		-- PKONLY for only PK Indexes, NOPK for Indexes that are not PKs

/*
CREATE IN MASTER DATABASE, THIS CAN THEN BE USED IN ANY DATABASE FOR THE INDEX INFORMATION.


USAGE:
	SP_NCHELPINDEX 	@OBJNAME = THE TABLE NAME
			@CLUST   = CLUSTERED FOR CLUSTERED INDEXES, NONCLUSTERED FOR NONCLUSTERED OR LEAVE BLANK FOR ALL INDEXES
			@PK      = PKONLY FOR ONLY PRIMARY KEYS, NOPK FOR ONLY NON-PRIMARY KEYS OR LEAVE BLANK FOR ALL

ADVANCED USAGE:

	Create a table to hold the data

		CREATE TABLE #INDEXINFO
				 (TABLENAME VARCHAR(256), 
				  INDEXNAME VARCHAR(256), 
				  INDEX_KEYS VARCHAR(256),
				  ISCLUSTERED VARCHAR(3),
				  ISPRIMARY_KEY VARCHAR(3),
				  IDXFILEGROUP VARCHAR(100),
				  INDEX_DESCRIPTION VARCHAR(200))


	USE SP_MSFOREACHTABLE to run the script against all tables in a database.

		SP_MSFOREACHTABLE "INSERT INTO #TABLE EXEC SP_NCHELPINDEX '?'" -- This inserts for all indexes
		SP_MSFOREACHTABLE "INSERT INTO #TABLE EXEC SP_NCHELPINDEX '?', 'CLUSTERED'" --This inserts only clustered index information
		SP_MSFOREACHTABLE "INSERT INTO #TABLE EXEC SP_NCHELPINDEX '?','','PKONLY'" -- This inserts only primary key index information


	Select data from the table, can ultimately be used to create index creation scripts for possible lost indexes.

		SELECT * FROM #INDEXINFO

*/
as	
	-- PRELIM
	set nocount on



	declare @objid int,			-- the object id of the table
			@indid smallint,	-- the index id of an index
			@groupid smallint,  -- the filegroup id of an index
			@indname sysname,
			@groupname sysname,
			@status int,
			@keys nvarchar(2126),	--Length (16*max_identifierLength)+(15*2)+(16*3)
			@dbname	sysname

	-- Check to see that the object names are local to the current database.
	select @dbname = parsename(@objname,3)

	if @dbname is not null and @dbname <> db_name()
	begin
			raiserror(15250,-1,-1)
			return (1)
	end

	-- Check to see the the table exists and initialize @objid.
	select @objid = object_id(@objname)
	if @objid is NULL
	begin
		select @dbname=db_name()
		raiserror(15009,-1,-1,@objname,@dbname)
		return (1)
	end

	-- OPEN CURSOR OVER INDEXES (skip stats: bug shiloh_51196)
	declare ms_crs_ind cursor local static for
		select indid, groupid, name, status from sysindexes
			where id = @objid and indid > 0 and indid < 255 and (status & 64)=0 order by indid
	open ms_crs_ind
	fetch ms_crs_ind into @indid, @groupid, @indname, @status

	-- IF NO INDEX, QUIT
	if @@fetch_status < 0
	begin
		deallocate ms_crs_ind
		raiserror(15472,-1,-1) --'Object does not have any indexes.'
		return (0)
	end

	-- create temp table
	create table #spindtab
	(
		index_name			sysname	collate database_default NOT NULL,
		stats				int,
		groupname			sysname collate database_default NOT NULL,
		index_keys			nvarchar(2126)	collate database_default NOT NULL -- see @keys above for length descr
	)

	-- Now check out each index, figure out its type and keys and
	--	save the info in a temporary table that we'll print out at the end.
	while @@fetch_status >= 0
	begin
		-- First we'll figure out what the keys are.
		declare @i int, @thiskey nvarchar(131) -- 128+3

		select @keys = index_col(@objname, @indid, 1), @i = 2
		if (indexkey_property(@objid, @indid, 1, 'isdescending') = 1)
			select @keys = @keys  + '(-)'

		select @thiskey = index_col(@objname, @indid, @i)
		if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
			select @thiskey = @thiskey + '(-)'

		while (@thiskey is not null )
		begin
			select @keys = @keys + ', ' + @thiskey, @i = @i + 1
			select @thiskey = index_col(@objname, @indid, @i)
			if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
				select @thiskey = @thiskey + '(-)'
		end

		select @groupname = groupname from sysfilegroups where groupid = @groupid

		-- INSERT ROW FOR INDEX
		insert into #spindtab values (@indname, @status, @groupname, @keys)

		-- Next index
		fetch ms_crs_ind into @indid, @groupid, @indname, @status
	end
	deallocate ms_crs_ind

	-- SET UP SOME CONSTANT VALUES FOR OUTPUT QUERY
	declare @empty varchar(1) select @empty = ''
	declare @des1			varchar(35),	-- 35 matches spt_values
			@des2			varchar(35),
			@des4			varchar(35),
			@des32			varchar(35),
			@des64			varchar(35),
			@des2048		varchar(35),
			@des4096		varchar(35),
			@des8388608		varchar(35),
			@des16777216	varchar(35)
	select @des1 = name from master.dbo.spt_values where type = 'I' and number = 1
	select @des2 = name from master.dbo.spt_values where type = 'I' and number = 2
	select @des4 = name from master.dbo.spt_values where type = 'I' and number = 4
	select @des32 = name from master.dbo.spt_values where type = 'I' and number = 32
	select @des64 = name from master.dbo.spt_values where type = 'I' and number = 64
	select @des2048 = name from master.dbo.spt_values where type = 'I' and number = 2048
	select @des4096 = name from master.dbo.spt_values where type = 'I' and number = 4096
	select @des8388608 = name from master.dbo.spt_values where type = 'I' and number = 8388608
	select @des16777216 = name from master.dbo.spt_values where type = 'I' and number = 16777216

	-- DISPLAY THE RESULTS
	IF @PK = 'PKONLY'
		BEGIN

	IF @CLUST = 'CLUSTERED' 
		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)
	from #spindtab
	WHERE (STATS & 16) <> 0 AND (STATS & 2048) <> 0
	order by index_name
	
		END
	ELSE
	IF @CLUST = 'NONCLUSTERED' 
		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)
	from #spindtab
	WHERE (STATS & 16) = 0 AND (STATS & 2048) <> 0
	order by index_name
	
		END
	ELSE

		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)

	from #spindtab WHERE (STATS & 2048) <> 0
	order by index_name
	
		END
END
ELSE 

	IF @PK = 'NOPK'
		BEGIN

	IF @CLUST = 'CLUSTERED' 
		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)
	from #spindtab
	WHERE (STATS & 16) <> 0 AND (STATS & 2048) = 0
	order by index_name
	
		END
	ELSE
	IF @CLUST = 'NONCLUSTERED' 
		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)
	from #spindtab
	WHERE (STATS & 16) = 0 AND (STATS & 2048) = 0
	order by index_name
	
		END
	ELSE

		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)

	from #spindtab WHERE (STATS & 2048) = 0
	order by index_name
	
		END
END
ELSE 

	
		BEGIN

	IF @CLUST = 'CLUSTERED' 
		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)
	from #spindtab
	WHERE (STATS & 16) <> 0 
	order by index_name
	
		END
	ELSE
	IF @CLUST = 'NONCLUSTERED' 
		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)
	from #spindtab
	WHERE (STATS & 16) = 0 
	order by index_name
	
		END
	ELSE

		BEGIN
	select
		'Tablename'  = @objname,
		'Index_name' = index_name,
		'Index_keys' = index_keys,
		'ISClustered'  = case when (stats & 16) <> 0 then 'YES' else 'NO' end,
		'ISPrimary_Key'= case when (stats & 2048)<>0 then 'YES' else 'NO' end,
		'IDXFileGroup'  = groupname,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when (stats & 16)<>0 then 'clustered' else 'nonclustered' end
				+ case when (stats & 1)<>0 then ', '+@des1 else @empty end
				+ case when (stats & 2)<>0 then ', '+@des2 else @empty end
				+ case when (stats & 4)<>0 then ', '+@des4 else @empty end
				+ case when (stats & 64)<>0 then ', '+@des64 else case when (stats & 32)<>0 then ', '+@des32 else @empty end end
				+ case when (stats & 2048)<>0 then ', '+@des2048 else @empty end
				+ case when (stats & 4096)<>0 then ', '+@des4096 else @empty end
				+ case when (stats & 8388608)<>0 then ', '+@des8388608 else @empty end
				+ case when (stats & 16777216)<>0 then ', '+@des16777216 else @empty end
				+ ' located on ' + groupname)

	from #spindtab 
	order by index_name
	
		END
END
	return (0) -- sp_helpindex

GO
