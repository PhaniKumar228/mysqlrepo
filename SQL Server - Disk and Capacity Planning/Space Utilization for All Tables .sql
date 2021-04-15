/*
Space Utilization for All Tables 

This script refines the one submitted by pochinej. It returns the data in table format instead of table by table. 

*/

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_AllTableSpace]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_AllTableSpace]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_TableSpaceCursor]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_TableSpaceCursor]
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE PROCEDURE sp_AllTableSpace AS

--Uses sp_tablespacecursor  to populate temp table with all table space data.

CREATE TABLE #temp
(
	TableName		varchar(50) NULL,
	NumberOfRows		int NULL,
	DataSpaceUsed       	int NULL,
	IndexSpaceUsed  	int NULL
)

SET NOCOUNT ON

DECLARE 	@TableName 		varchar(50), 
		@NumberOfRows	int,
		@DataSpaceUsed       	int,
		@IndexSpaceUsed 	int


DECLARE gettable INSENSITIVE CURSOR FOR 

     Select name from sysobjects
	where type = 'U'

FOR READ ONLY 

    OPEN gettable 


    FETCH NEXT FROM gettable INTO @TableName 
    WHILE (@@FETCH_STATUS = 0) 

	BEGIN
	
	DECLARE @recordlist CURSOR
	EXECUTE sp_TableSpaceCursor @TableName,@recordlist OUTPUT

	FETCH NEXT FROM @recordlist INTO @NumberOfRows, @DataSpaceUsed, @IndexSpaceUsed
    	WHILE (@@FETCH_STATUS = 0) 

		BEGIN
		
		INSERT INTO #temp (TableName, NumberOfRows, DataSpaceUsed, IndexSpaceUsed)	
		VALUES (@TableName, @NumberOfRows, @DataSpaceUsed, @IndexSpaceUsed)	


		FETCH NEXT FROM @recordlist   INTO @NumberOfRows, @DataSpaceUsed, @IndexSpaceUsed
		END  
	
	CLOSE @recordlist
	DEALLOCATE @recordlist


	FETCH NEXT FROM gettable   INTO @TableName 

	END  

CLOSE gettable 
DEALLOCATE gettable 

SET NOCOUNT OFF

Select * from #temp order by TableName ASC
Drop Table #temp
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

CREATE procedure sp_TableSpaceCursor
@name nvarchar(517), 
@recordlist CURSOR VARYING OUTPUT 
as
	
--SWB 31 December 2001
--returns a cursor containing the space utilization data for specified table.
	
	SET NOCOUNT ON	

	declare @rows int, @datasizeused int, @indexsizeused int, @pagesize int
	declare @dbname nvarchar(128)
	declare @id int
	
	select @dbname = db_name()

	if (@id is null)
		select @id = id from dbo.sysobjects where id = object_id(@name) and (OBJECTPROPERTY(id, N'IsTable') = 1)
	if (@id is null)
	begin
		RAISERROR (15009, -1, -1, @name, @dbname)
		return 1
	end

	/* rows */
	SELECT @rows = convert(int, rowcnt)
		FROM dbo.sysindexes
		WHERE indid < 2 and id = @id

	/* data */
	SELECT @datasizeused =
	(SELECT sum(dpages)
	 FROM dbo.sysindexes
	 WHERE indid < 2 and id = @id)
	+
	(SELECT isnull(sum(used), 0)
	 FROM dbo.sysindexes
	 WHERE indid = 255 and id = @id)

   /* Do not consider 2 < indid < 255 rows, those are nonclustered indices, and the space used by them are included by indid = 0(table) */
   /* or indid = 1(clustered index) already.  indid = 0(table) and = 1(clustered index) are mutual exclusive */
	/* index */
	SELECT @indexsizeused =
	(SELECT sum(used)
	 FROM dbo.sysindexes
	 WHERE indid in (0, 1, 255) and id = @id)
	 - @datasizeused

	/* Pagesize on this server (sysindexes stores size info in pages) */
	select @pagesize = v.low / 1024 from master..spt_values v where v.number=1 and v.type=N'E'
	
	

	SET @recordlist = CURSOR 
	FOR
	select Rows = @rows, DataSpaceUsed = @datasizeused * @pagesize, IndexSpaceUsed = @indexsizeused * @pagesize

	OPEN @recordlist


RETURN
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


