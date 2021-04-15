/*
Display Defragmentation Of Selected Tables

This script will display the defragmentation of table(s) all indexes of selected tables and display a table/list of the DBCC SHOWCONTIG. 

It will also will report if there are tables in the list that can't be found in the current database. 
Run the script in the database where the tables you want to check are.

Check BOL for information about DBCC SHOWCONTIG, and the result of the same. 

*/

/*---------------------------------------------------------------------------------------------
                   SCRIPT TO CHECK CURRENT FRAGMENTATION OF DATA AND INDEX
---------------------------------------------------------------------------------------------*/

SET NOCOUNT ON

DECLARE	@ListItem		varchar(255),
		@List			varchar(1000),
		@Pos			int,
		@Delim			varchar(10),
		@Sql			varchar(355),
		@IndexItem		varchar(255)

---------------------------- CHANGE THESE VARIABLES BEFORE RUNNING  ---------------------------
-- Choose a separator for you list of table(s)
SELECT	@Delim = ','
-- What table(s) shall be checked, type them in separated with the separator chosen above
-- Note that the list shall start and end with a single quationmark
SELECT	@List = 'table1, table2, table3, table4, table5...'
-----------------------------------------------------------------------------------------------

CREATE TABLE #DBCC (
	[ObjectName]			sysname,
	[ObjectID]				int,
	[IndexName]				sysname,
	[IndexId]				int,
	[Level]					int,
	[Pages]					int,
	[Rows]					int,
	[MinimumRecordSize]		int,
	[MaximunRecordSize]		int,
	[AvarageRecordSize]		decimal(38,15),
	[ForwardRecords]		int,
	[Extents]				int,
	[ExtentSwitches]		int,
	[AvarageFreeBytes]		decimal(38,15),
	[AvaragePageDensity]	decimal(38,15),
	[ScanDensity]			decimal(5,2),
	[BestCount]				int,
	[ActualCount]			int,
	[LogicalFragmentation]	decimal(5,2),
	[ExtentFragmentation]	decimal(5,2) )

CREATE TABLE #NonExistent (
		[name]				sysname )

-- Check that the list end with a separator
IF RIGHT(@List,LEN(@Delim)) <> @Delim
BEGIN
	SELECT	@List = LTRIM(RTRIM(@List))+ @Delim
END
SELECT @Pos = CHARINDEX(@Delim, @List, 1)

IF REPLACE(@List, @Delim, '') <> ''
BEGIN
	-- Split the list of table(s) and run DBCC SHOWCONTIG, store the result in #DBCC
	WHILE @Pos > 0
	BEGIN
		SELECT	@ListItem = LTRIM(RTRIM(LEFT(@List, @Pos - 1)))
		-- Check that there really is text between the separator(s)
		-- and that the table exist in sysobjects
		IF ( @ListItem <> '' AND (SELECT COUNT(*) FROM sysobjects WHERE name = @ListItem AND type = 'U')=1 )
		BEGIN
			SELECT	@Sql = 'DBCC SHOWCONTIG(''' + @ListItem + ''') WITH ALL_INDEXES, TABLERESULTS'
			INSERT	INTO #DBCC
			EXEC	(@Sql)
		END
		ELSE
		BEGIN
			INSERT INTO #NonExistent ( [name] )
			VALUES ( @ListItem )
		END
		SELECT	@List = RIGHT(@List, LEN(@List) - @Pos - LEN(@Delim) + 1)
		SELECT	@Pos = CHARINDEX(@Delim, @List, 1)
	END
END

IF ( (SELECT COUNT(*) FROM #NonExistent)>0 )
BEGIN
	SELECT	[name] AS 'NonEistingTables'
	FROM	#NonExistent
	ORDER BY
			[name]
END

SELECT	*
FROM	#DBCC

-- Clean Up
DROP TABLE #DBCC
DROP TABLE #NonExistent


