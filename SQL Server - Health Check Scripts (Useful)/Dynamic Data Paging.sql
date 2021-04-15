/*

Dynamic Data Paging

I've search high and low on the Internet for good examples of Paging Data in an application. 
However, none of the Examples were clean enough, or worked for all situations. 
For example, there are no examples of Data Paging for Tables with Composite Keys.

This Script is able to page Data on any Table, using any Criteria, Sorting, or Grouping as well as handling Composite Keys auto-magically.

Please let me know if you improve upon this or find problems. 

*/

CREATE PROCEDURE dbo.spGetDataPage
(
	@Table VarChar(128) = Null, 
	@Columns VarChar(1000) = '*', 
	@Criteria VarChar(2000) = Null,
	@Group VarChar(2000) = Null,
	@Sort VarChar(2000) = Null,
	@PageNo Int = 1, 
	@PageSize Int = 0, 
	@GetTotals Bit = 0,
	@TotalRecords Int = 0 Output, 
	@TotalPages Decimal(10,2) = 0 Output
)
AS
-- Variables
Set NoCount On
Declare @AllRecords Bit, @GetDefaultSort Bit, @Criteria1 VarChar(8000), @Criteria2 VarChar(8000)
Declare @KeyColumn VarChar(8000), @PageNoStr VarChar(50), @PageSizeStr VarChar(50), @SkipRows VarChar(50)
Declare @Cursor Cursor, @Column VarChar(128), @Type VarChar(50), @MaxLen SmallInt

-- Set the Defaults
If (@PageNo < 1) Set @PageNo = 1
Select @KeyColumn = '', @Criteria1 = '', @Criteria2 = ''
Select @Criteria = Upper(@Criteria), @Sort = Upper(@Sort), @Group = Upper(@Group)
Select @Criteria = IsNull(@Criteria, ''), @Sort = IsNull(@Sort, ''), @Group = IsNull(@Group, '')
Select @PageNoStr = Convert(VarChar(50), @PageNo), @PageSizeStr = Convert(VarChar(50), @PageSize)
If (@Sort = '') Set @GetDefaultSort = 1

-- Determine the Key Columns from the Table
If (Select Count(*) From Information_Schema.Key_Column_Usage CU
	Inner Join Information_Schema.Columns C ON (CU.Table_Name = C.Table_Name) And (CU.Column_Name = C.Column_Name)
	Where (CU.Table_Name = @Table) And (CU.Constraint_Name IN(Select Name From SysObjects Where Xtype = 'pk'))) = 1
	BEGIN
	Select @KeyColumn = C.Column_Name 
		From Information_Schema.Key_Column_Usage CU
		Inner Join Information_Schema.Columns C ON (CU.Table_Name = C.Table_Name) And (CU.Column_Name = C.Column_Name)
		Where (CU.Table_Name = @Table) And (CU.Constraint_Name IN(Select Name From SysObjects Where Xtype = 'pk'))
	END
Else
	BEGIN
	Set @Cursor = Cursor Fast_Forward For
		Select C.Column_Name As ColumnName, Data_Type As Type, IsNull(C.Character_Maximum_Length, C.Character_Octet_Length) As MaxLen
			From Information_Schema.Key_Column_Usage CU
			Inner Join Information_Schema.Columns C ON (CU.Table_Name = C.Table_Name) And (CU.Column_Name = C.Column_Name)
			Where (CU.Table_Name = @Table) And (CU.Constraint_Name IN(Select Name From SysObjects Where Xtype = 'pk'))
	Open @Cursor
	Fetch Next From @Cursor Into @Column, @Type, @MaxLen
	While (@@Fetch_Status <> -1)
	BEGIN
		If (@@Fetch_Status <> -2)
			BEGIN
			Set @KeyColumn = @KeyColumn + ' Convert(VarChar(50), ' + @Column + ') + '':'' +'
			If (@GetDefaultSort = 1)
				BEGIN
				Set @Sort = @Sort + @Column + ', '
				END
			END
		Fetch Next From @Cursor Into @Column, @Type, @MaxLen
	END
	Close @Cursor
	DeAllocate @Cursor
	Set @KeyColumn = SubString(@KeyColumn, 1, Len(@KeyColumn) - 7)
	If (@GetDefaultSort = 1) Set @Sort = SubString(@Sort, 1, Len(@Sort) - 1)
	END

-- Page Size
If (@PageSize Is Null) OR (@PageSize < 1)         -- Bring all records, don't do paging.
	Set @AllRecords = 1
Else
	BEGIN
	Set @AllRecords = 0
    	Set @SkipRows = Convert(VarChar(50), @PageSize * (@PageNo - 1))
	END

-- Criteria
If (CharIndex('WHERE', @Criteria) > 0) Set @Criteria = Replace(@Criteria, 'WHERE', '')
If (@Criteria Is Not Null) AND (@Criteria <> '')
	BEGIN
	Set @Criteria1 = ' WHERE (' + @Criteria + ') '
	Set @Criteria2 = ' AND (' + @Criteria + ') '
	END

-- Sorting
If (@Sort Is Not Null) AND (@Sort <> '')
	BEGIN
	If (CharIndex('ORDER BY', @Sort) = 0) Set @Sort = ' ORDER BY ' + @Sort + ' '
	END

-- Grouping
If (@Group Is Not Null) AND (@Group <> '')
	BEGIN
	If (CharIndex('GROUP BY', @Group) = 0) Set @Group = ' GROUP BY ' + @Group + ' '
	END

-- Return the Records
If (@AllRecords = 1)                   -- Ignore paging and run a simple SELECT.
	BEGIN
   	EXEC ('Select ' + @Columns + ' From ' + @Table + ' ' + @Criteria1 + ' ' + @Group + ' ' + @Sort)
	END
Else
	BEGIN
	If (@PageNo = 1)                                -- In this case we can execute a more efficient query with no subqueries.
		BEGIN
		EXEC (
		'Select Top ' + @PageSizeStr + ' ' + @Columns + ' From ' + @Table + ' ' + @Criteria1 + ' ' + @Group + ' ' + @Sort
		)
		END
	Else
		BEGIN
		EXEC (
			'Select Top ' + @PageSizeStr + ' ' + @Columns + ' From ' + @Table
				+ ' Where ' + @KeyColumn + ' NOT IN(Select Top ' + @SkipRows + ' ' + @KeyColumn + ' From ' + @Table + ' ' + @Criteria1 + ' ' + @Group + ' ' + @Sort + ')'
			+ ' ' + @Criteria2 + ' ' + @Group + ' ' + @Sort
		)
		END
	END

If (@GetTotals = 1)
	BEGIN
	Select @TotalRecords = Sum(Rows) From dbo.SysIndexes Where ID IN(Select ID From dbo.SysObjects Where Name = @Table)
	If (@PageSize > 0) Set @TotalPages = Ceiling(@TotalRecords / @PageSize) + 1
	END

RETURN
