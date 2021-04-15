/*
Compare Parallel Data Streams

This a script to compare two parallel data streams, in my case production and QA.  
Two extracts were created and a mapping table was created as a look-up between old and new recordids.  
A final table TestResults was created to hold the results of the comparison.  
The comparison table names and join syntax are controlled by variables.  
The script uses syscolumns to find the common column names and compares each row in the two tables, 
column by column and inserts any differences in to the results table.
The comparisons support nulls and casts any column with the word 'date' in the name as a datetime before conmparing.
*/

declare @icID 		int,
	@iOldID		int,
	@vcTable1	varchar(255),
	@vcTable2	varchar(255),
	@vcColumn 	varchar(255),
	@vcAuditColumn	varchar(255),
	@vcJoin1	varchar(255),
	@vcJoin2	varchar(255),
	@vcQuery  	varchar(2000)

-- table variable to hold the list of common column names
declare @tblCommonColumns  table 	(
	cID 		int identity, 
	ColumnName	varchar(255) 	)

Select 	@vcTable1 	= 'ProdRaw',	--> OriginalData
	@vcTable2	= 'QARaw',		--> New Data
	@vcJoin1 = ' Join dbo.TestMapping tm on t1.RecordID = tm.ProdRecordID and tm.IsProcessed = 0 ', --> added check for processed
	@vcJoin2 = ' t2.RecordID = tm.QARecordID',
	@iOldID	= 0

Insert  @tblCommonColumns
(ColumnName)
-- get the list of all common column names
Select t.name
From	-- First derived table returns all the column names for table 1
(Select 	sc.name
	From 	sysobjects 	so
	join	syscolumns 	sc (nolock) on so.id = sc.id
	where	so.name = @vcTable1 ) t
Join -- Second derived table returns all the column names for table 2
(Select 	sc.name	
	From 	sysobjects 	so
	join	syscolumns 	sc (nolock) on so.id = sc.id
	where	so.name = @vcTable2) t2
			on t.name = t2.name  --> By joining them we get a list of common columns

-- Remove the list of Audit Columns that will never be the same, and other columns that we dont really care about comparing
Delete @tblCommonColumns
Where ColumnName in ('RecordID', 'FileID', 'SourceFileName')

While  1 = 1	-- Do

Begin

-- reset the column Name
	Set @vcColumn = null	
	
-- Get the first Column to work with
	Select 	top 1   @icID	    = cID,
					@vcColumn   = ColumnName
	From @tblCommonColumns
	Where cID > @iOldID
	order by cID

-- check the column name
	If @vcColumn is null
		Break

	Set @vcQuery = 

		'Insert into tempdb.dbo.TestResults ' + 
		'(OldRecordID, NewRecordID, OldValue, NewValue, ColumnName) ' +
		'Select  t1.RecordID, t2.RecordID, t1.' + @vcColumn   + ', t2.' + @vcColumn + ', ''' + @vcColumn  + ''''+
		 ' From ' 	 + @vcTable1    + ' t1  ' +
		 @vcJoin1 +
		 ' Join ' 	 + @vcTable2    + ' t2 on ' + @vcJoin2 +
			' and Isnull(' + 
								Case
									When CharIndex('Date', @vcColumn) > 0 Then 'Cast(t1.' + @vcColumn + ' as Datetime)'
									Else 't1.' + @vcColumn
								End + ', '''') <> IsNull(' + 
								Case
									When CharIndex('Date', @vcColumn) > 0 Then 'Cast(t2.' + @vcColumn + ' as Datetime)'
									Else 't2.' + @vcColumn
								End + ', '''')'
		 
--Print @vcQuery
	Exec (@vcQuery)	

-- set the next seed
	Set @iOldID = @icID

END
