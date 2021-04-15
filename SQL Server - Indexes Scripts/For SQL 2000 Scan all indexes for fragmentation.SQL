/*
For SQL 2000 Scan all indexes for fragmentation

This script creates an error message with a valid error number, and alert associated with the error message. 
(everything when it doesn't exists). Then captures all the user indexes in the database and 
executes DBCC ShowContig for each one. It calculates the % of fragmentation on leaf level and fires the alert when is fragmented.
Then saves a log file with all the scanned indexes and info for the ones that need to be defrag.
   It can be inserted in a job to check on schedule for fragmentation on indexes, or executed on demand.
*/

/*

**
**  Script to be included in a Job that manages fragmentation
**  in all indexes in the executing database.
*/


Set Nocount On

/*
** *************Error Message Definition********************
*/

/* Declare Variables that wil be used for the error message */
Declare @Error_no Int
Declare @AddMessage Varchar(1500)

/* Calculates the last error number of the message */
Set @Error_no = (Select Top 1 error From master.dbo.sysmessages Order by error Desc)

/*
   First checks if the message that will be added exists.
   If it doesn't, calculates the available error number 
   and creates the message.
*/
If Not Exists
		(Select description from master.dbo.sysmessages
		Where description Like ('%View C:\Frag_Info.log for more info.'))
Begin
	/* 
	   If no user define error messages were added (Error < 50001).
	   Creates the message with the number 50001.
	*/
	If @Error_no < 50001
		Begin
			Set @Error_no = 50001
			Set @AddMessage = 'EXEC Sp_addmessage @msgnum=' + Convert(VarChar(5), @Error_no) + ', 
				   @severity=19,
				   @msgtext="%s index %s on table %s is %s percent fragmented. Consider re-building the index. View C:\Frag_Info.log for more info.",
				   @with_log=True'
			EXEC (@AddMessage)		
		End
	Else
	/*
	   If there is an used define error (Error > 50001). Calculates the
	   first available error number and creates the error message.
	*/
		Begin
			Set @Error_no = @Error_no + 1
			Set @AddMessage='EXEC Sp_addmessage @msgnum=' + Convert(VarChar(5), @Error_no) + ', 
				   @severity=19,
				   @msgtext="%s index %s on table %s is %s percent fragmented. Consider re-building the index. View C:\Frag_Info.log for more info.",
				   @with_log=True'
			EXEC (@AddMessage)
		End
End

/*
** *************Alert Definition********************
*/

/*
** If the Alerts Does not exists, it is created to response to the Error message 
** created before.
*/
If Not Exists
		(Select Name From msdb.dbo.sysalerts Where name = 'Fragmentation above 50% in user index.')
Begin
	EXECUTE msdb.dbo.sp_add_alert @name = 'Fragmentation above 50% in user index.',
						@message_id = @Error_no,
						@Severity = 0,
						@Enabled = 1,
						@delay_between_responses = 0,
						@category_name = '[Uncategorized]'
End


/*
** *************Selecting Sysindexes columns********************
*/


/*  Creates a Temp Table to hold the results from DBCC ShowContig   */

/*  Creates a Temp Table to show the results from DBCC ShowContig  */
Create Table #SaveResults
	(ObjectName Sysname,
	ObjectId int,
	IndexName Sysname,
	Indexid tinyint,
	[Level] int,
	Pages Int,
	[Rows] Int,
	MinimumRecordSize Int,
	MaximumRecordSize Int,
	AverageRecordSize Int,
	ForwardedRecords Int,
	Extents Int,
	ExtentSwitches Int,
	AverageFreeBytes Int,
	AveragePageDensity Int,
	ScanDensity Int,
	BestCount tinyint,
	ActualCount TinyInt,
	LogFragmentation TinyInt,
	ExtentFragmentation Int)

/*  Creates a Temp Table to show the modified results from DBCC ShowContig   */
Create Table ##ShowResults
	(TableName sysname,
	IndexName sysname,
	IndexType Varchar (12),
	[%Frag] TinyInt,
	Defrag VarChar (3),
	Pages Int,
	AvgFreeBytes Int)	

/* 
   Declares a cursor and variables that holds the table and index Type  (Clustered or Nonclustered) 
   and the FillFactor (original) from user tables with indexes.
*/   
Declare @TableName sysname
Declare @IndexName sysname
Declare vCursor Cursor For
			Select 	Object_name (i.id) As 'TableName',
							i.name As 'IndexName'				 			
			From Sysindexes i Inner Join sysobjects o
			On i.id=o.id
			Where (Indid = 1 Or Indid Between 2 And 250) And xtype = 'U'

Declare @cmdDBCC Varchar (200)


Open vCursor
Fetch Next From vCursor Into @TableName, @IndexName
While @@Fetch_Status = 0
	Begin
		Set @cmdDBCC = 'DBCC ShowContig (' + @TableName + ', ' + @IndexName + 
				') With TableResults'
		Insert #SaveResults
		Exec (@cmdDBCC)		
		/*  Fills the #SaveResults Table with all the results of the execution*/
		Fetch Next From vCursor Into @TableName, @IndexName		
	End

/*  Close the cursor because it don't use it anymore   */
Close vCursor
Deallocate Vcursor

/*  Declare variables to save info from the #SaveResults   */
Declare @ObjectName Sysname 				 
Declare @IndexName2 Sysname
Declare @ScanDensity Int
Declare @IndexType Varchar(13)
Declare @Pages  Int
Declare @AverageFreeBytes Int
Declare @Rows Int
Declare @Defrag Char(3)
Declare vCursor2 Cursor For 
			Select ObjectName, IndexName, ScanDensity, 
			[IndexType]=
				Case
					When IndexId = 1 Then 'Clustered'
					Else 'NonClustered'
				End
			, 
			Pages, [Rows], AverageFreeBytes
			From #SaveResults
Open vCursor2
Fetch Next From vCursor2 Into @ObjectName, @IndexName2, @ScanDensity, @IndexType, 
				@Pages, @Rows, @AverageFreeBytes
		
While @@Fetch_Status = 0
Begin
	/* If fragmentation is above 50 % Then fire the error */
	If @ScanDensity < 50 
		Begin
			/* Builts the raise error sentence  */
			Declare @Raise Varchar(150)
			Set @Defrag = 'Yes'
			Set @Raise = 'Raiserror (' + Convert(Varchar(10),@Error_no) +
			', 18, 1,' + ''''  + @IndexType + '''' + ',' + '''' +  @IndexName2+ '''' + ',' + '''' +
			 @ObjectName + '''' + ',' + '''' + Convert(Varchar(20),@ScanDensity) + '''' + ')'
			EXEC (@Raise)
		End
	/*  If not just alter the variable  to indicate no defragmentation is needed*/
	Else
		Begin
		Set @Defrag = 'No'
	End

	/*  Insert the results into the temp table created to show the results  */	
	Insert ##ShowResults
		Values
		(@ObjectName, @IndexName2, @IndexType, 
		@ScanDensity, @Defrag, @Pages, 
		@AverageFreeBytes)		

	Fetch Next From vCursor2 Into @ObjectName, @IndexName2, @ScanDensity, @IndexType, 
				@Pages, @Rows, @AverageFreeBytes
End

Close vCursor2
Deallocate vCursor2

Drop Table #SaveResults

/*
** *************Log File generation********************
*/
Declare @cmd Varchar(1000)
Set @cmd=' EXEC master.dbo.xp_cmdShell ' + '''' + 
	'OSQL -E -q"Set Nocount On Select Substring(@@ServerName,1,20) as [Executed On Server:] Select Substring(db_name(),1,20) ' + 
	'AS [Executed On Database:] Select Getdate() as [LogFile generated with the ' + 
	'results of fragmentation in all user Indexes. Date:] Select ' + 
	'SubString(TableName,1,20) as TableName,IndexType, Substring(IndexName,1,20) ' + 
	'as IndexName, [%Frag] as [%Defrag] , Defrag As [Need Defrag.?]  from ##ShowResults" -oC:\Frag_Info.log' + ''''
EXEC (@cmd)
Drop Table ##ShowResults
