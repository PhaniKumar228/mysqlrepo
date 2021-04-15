set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
GO
/********************************************************************************************************
** NAME: sp_ShowDown
**
** DESC: Display (SHOWs) the results of a SELECT vertically (DOWN) instead of horizontally	
**		 The query can be as complex as necessary with as many joins however the column names
**		 must be unique because of the temp table.  Note image and text fields display only 
**		 their size (DATALENGTH)
**
** PARM: @Help = 1 will display syntax and instructions
**
** RETR: the resultset of the records.  Notes displaying a lot of records will take a LONG time.  Generally
**		 this should be used for recordsets of no more than 10.  
**
** SYNTAX  sp_showdown 1 -- displays full syntax on how to run
**
** MOD DATE:
** 05.22.07 - DTS Prevent casting of image & text to varchar
** 05.20.07 - DTS original version
*********************************************************************************************************/
ALTER PROCEDURE [dbo].[sp_ShowDown] (
	@help	BIT = NULL
)
AS

SET NOCOUNT ON

	-- ------------------------------------------------------------------------
	-- DECLARATION AND TABLE CREATION
	-- ------------------------------------------------------------------------

	DECLARE 
		@Column		VARCHAR(60),		-- the fieldname
		@CurrOrdPos	INT,				-- the order of the column in the table
		@SQL		VARCHAR(1000),		-- dynamic select statement
		@SQ			CHAR(1),			-- single quote
		@MaxTable	VARCHAR(1000),		-- holds the tempwide2 name - the true one stored in tempdb
		@RecordID	INT,				-- each record's number to aid in sorting when more than one record is return
		@DataType	VARCHAR(25),		-- the datatype of the field
		@FieldName	VARCHAR(200)			-- will hold column's name with brackets ready for the SELECT				

	IF OBJECT_ID('tempdb..#tempdown') IS NOT NULL DROP TABLE #tempdown

	CREATE TABLE #tempdown (
		Rec			INT,				-- short column names on purpose so it doesn't take up much 
		Ord			INT,				-- space in final result
		ColumnName	VARCHAR(60),		-- the columnname 
		Data		VARCHAR(7500)		-- the data for the column
	)

	-- ------------------------------------------------------------------------
	-- INITIALIZE
	-- ------------------------------------------------------------------------

	SET @RecordID = 0

	-- CONSTANTS
	SET @SQ = CHAR(39)		-- single quote


	-- ------------------------------------------------------------------------
	-- LOGIC
	-- ------------------------------------------------------------------------ 

	-- print the syntax and usage instructions to the result window
	IF @Help = 1 BEGIN
		PRINT 'Keep in mind that with temp tables the column names must be unique!'
		PRINT ' '
		PRINT 'Example of syntax: '
		PRINT ' '
		PRINT 'IF OBJECT_ID(''tempdb..#tempwide'') IS NOT NULL DROP TABLE #tempwide  -- ADD TO TOP OF YOUR SELECT'
		PRINT ' '
		PRINT 'SELECT TOP 1 * '
		PRINT 'INTO	#tempwide			-- ADD THIS TO YOUR QUERY'
		PRINT 'FROM	authors a'
		PRINT ' ' 
		PRINT 'EXEC _SHOWDOWN				-- ADD AS THE LAST LINE'
		PRINT '  '						   
		PRINT 'COPY THESE LINES and place where instructed'
		PRINT 'IF OBJECT_ID(''tempdb..#tempwide'') IS NOT NULL DROP TABLE #tempwide'
		PRINT 'INTO #tempwide'
		PRINT 'EXEC sp_SHOWDOWN'

		RETURN
	END

	-- Create a new 'wide' table so we can add a RecordID (DIDROCER) which allows muliple records and their fields 
	-- to be grouped together.  DIDROCER is RecordID backwards.  Needed a field name that will have an unlikely
	-- chance of ever being in a real table since it will be excluded from the results displayed vertically.
	SELECT	0 'DIDROCER', *
	INTO	#tempwide2
	FROM	#tempwide

	-- increment the record id for the table
	UPDATE	#tempwide2 SET	@RecordID = DIDROCER = @RecordID + 1

	-- get name of tempwide2 table (the true name in tempdb)
	SET @MaxTable = (	SELECT	MAX(TABLE_NAME) 
						FROM	tempdb.INFORMATION_SCHEMA.TABLES
						WHERE	Table_Name LIKE '%#tempwide2%'
					)

	-- get the min ord position for the first column for my temp table.  Eliminates need for cursor
	SET @CurrOrdPos = ( SELECT	MIN(Ordinal_Position) 
						FROM	tempdb.INFORMATION_SCHEMA.COLUMNS 
						WHERE	Table_Name LIKE '%' + @MaxTable + '%' )


	-- while we have columns in the temp table loop through them and put their data into the 
	-- tempdown table
	WHILE @CurrOrdPos IS NOT NULL BEGIN 

		-- get a column name and the data type
		SELECT	@Column = COLUMN_NAME, @DataType = Data_Type
		FROM	tempdb.INFORMATION_SCHEMA.COLUMNS 
		WHERE	Table_Name LIKE '%' + @MaxTable + '%' 
		AND		Ordinal_Position = @CurrOrdPos 


		IF @Column <> 'DIDROCER' BEGIN		-- if it is not the recordid (spelled backward) row from tempwide2 get the row


			IF @DataType IN ( 'image', 'text' ) BEGIN
				-- 'Size of Data: ' + CONVERT(VARCHAR(15), DATALENGTH([NoteText] )) 
				SET @FieldName = @SQ + 'Size of Data: ' + @SQ + ' + CONVERT(VARCHAR(15), DATALENGTH(' + @FieldName + ')) '
			END ELSE BEGIN
				SET @FieldName = 'CAST( [' + @Column + '] AS VARCHAR(7500) )'			-- the fieldname w/ brackets used in SELECT to display the data
			END

			-- build the insert that will put the data into the tempdown table
			SET @SQL = ' INSERT INTO #tempdown ' 
			SET @SQL = @SQL + 'SELECT didrocer ' + @SQ + 'RecordID' + @SQ + ', '		-- recordid field from tempwide2 table
			SET @SQL = @SQL + CONVERT(VARCHAR(10), @CurrOrdPos) + ', '					-- order of the column
			SET @SQL = @SQL + @SQ + @Column + @SQ + ' ' + @SQ + 'Field' + @SQ + ', '	-- field name 
			SET @SQL = @SQL + @FieldName + @SQ + @Column + @SQ							-- field data
			SET @SQL = @SQL + ' FROM ' + @MaxTable										-- from tempwide2
		END

		--@SQL above looks like this:
		--INSERT INTO #tempdown SELECT DIDROCER 'RecordID', 5, 'UserID' 'Field', [UserID] 'UserID' FROM #tempwide2 {shorten}_____00010000003F
		--PRINT @SQL

		EXEC ( @SQL )		-- run the insert into #tempdown
		
		-- get the next column pos
		SET @CurrOrdPos = ( SELECT	MIN(Ordinal_Position) 
							FROM	tempdb.INFORMATION_SCHEMA.COLUMNS 
							WHERE	Table_Name LIKE '%' + @MaxTable + '%'
								AND Ordinal_Position > @CurrOrdPos)


	END

	-- display the results VERTICALLY!
	SELECT	ColumnName, Data FROM	#tempdown ORDER BY Rec, Ord, ColumnName

	-- clean up
	IF OBJECT_ID('tempdb..#tempdown') IS NOT NULL DROP TABLE #tempdown
	IF OBJECT_ID('tempdb..#tempwide') IS NOT NULL DROP TABLE #tempwide
	IF OBJECT_ID('tempdb..#tempwide2') IS NOT NULL DROP TABLE #tempwide2


