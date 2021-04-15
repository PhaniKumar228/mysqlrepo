/*
    
Database Configuration Script
An easy script that gives you the information of all non-system databases, its size and all the configuration options that you can get individually with DATABASEPROPERTYEX function.  
 
*/

-- Generates a complete report for each database in the server about the configuration options.


Set NOCOUNT ON
-- Generates the temporary result table
IF OBJECT_ID('tempdb..#DbConfigTable') IS NOT NULL    Drop Table #DbconfigTable

Create Table #DbConfigTable (
	DbName				varchar(30)
	  Primary Key, 
	SizeMb				float,
	IsAnsiNullDefault               int,
	IsAnsiPaddingEnabled            int,
	IsAnsiWarningsEnabled           int,
	IsArithmeticAbortEnabled        int,
	IsAutoClose                     int,
	IsAutoCreateStatistics          int,
	IsAutoShrink                    int,
	IsAutoUpdateStatistics          int,
	IsCloseCursorsOnCommitEnabled   int,
	IsFulltextEnabled               int,
	IsInStandBy                     int,
	IsLocalCursorsDefault           int,
	IsMergePublished                int,
	IsNullConcat                    int,
	IsNumericRoundAbortEnabled      int,
	IsQuotedIdentifiersEnabled      int,
	IsRecursiveTriggersEnabled      int,
	IsSubscribed                    int,
	IsTornPageDetectionEnabled      int,
	Recovery                        varchar(15),
	SQLSortOrder                    varchar(15),
	Status                          varchar(15),
	Updateability                   varchar(15),
	UserAccess                      varchar(15),
	Version                         varchar(15),
	IsAnsiNullsEnabled              varchar(15))


-- Generates a cursor with the databases
DECLARE @DbName 	varchar(50),
	@ParamDataInt	int,
	@ParamDataStr	varchar(15),
	@SQL		varchar(300)

DECLARE cDatabases CURSOR FOR
	select name
	from master..sysdatabases
	where dbid > 4 -- Filter system databases.
	order by name

OPEN cDatabases

FETCH NEXT FROM cDatabases INTO @DbName
WHILE (@@FETCH_STATUS <> -1)
BEGIN
   IF (@@FETCH_STATUS <> -2)
   BEGIN   
	-- Inserts (for each database) a new record in the temporary table.
	Insert into #DbConfigTable (DbName) values (@DbName)

	-- Updates each record with All database's options
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAnsiNullDefault'))
	Update #DbConfigTable Set IsAnsiNullDefault = @ParamDataInt Where DbName = @DbName

	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAnsiNullsEnabled'))
	Update #DbConfigTable Set IsAnsiNullsEnabled = @ParamDataInt Where DbName = @DbName

	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAnsiPaddingEnabled'))
	Update #DbConfigTable Set IsAnsiPaddingEnabled = @ParamDataInt Where DbName = @DbName

	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAnsiWarningsEnabled'))
	Update #DbConfigTable Set IsAnsiWarningsEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsArithmeticAbortEnabled'))
	Update #DbConfigTable Set IsArithmeticAbortEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAutoClose'))
	Update #DbConfigTable Set IsAutoClose = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAutoCreateStatistics'))
	Update #DbConfigTable Set IsAutoCreateStatistics = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAutoShrink'))
	Update #DbConfigTable Set IsAutoShrink = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsAutoUpdateStatistics'))
	Update #DbConfigTable Set IsAutoUpdateStatistics = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsCloseCursorsOnCommitEnabled'))
	Update #DbConfigTable Set IsCloseCursorsOnCommitEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsFulltextEnabled'))
	Update #DbConfigTable Set IsFulltextEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsInStandBy'))
	Update #DbConfigTable Set IsInStandBy = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsLocalCursorsDefault'))
	Update #DbConfigTable Set IsLocalCursorsDefault = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsMergePublished'))
	Update #DbConfigTable Set IsMergePublished = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsNullConcat'))
	Update #DbConfigTable Set IsNullConcat = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsNumericRoundAbortEnabled'))
	Update #DbConfigTable Set IsNumericRoundAbortEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsQuotedIdentifiersEnabled'))
	Update #DbConfigTable Set IsQuotedIdentifiersEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsRecursiveTriggersEnabled'))
	Update #DbConfigTable Set IsRecursiveTriggersEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsSubscribed'))
	Update #DbConfigTable Set IsSubscribed = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataInt = Convert(int, DATABASEPROPERTYEX(@DbName, 'IsTornPageDetectionEnabled'))
	Update #DbConfigTable Set IsTornPageDetectionEnabled = @ParamDataInt Where DbName = @DbName
	SELECT @ParamDataStr = Convert(varchar(15), DATABASEPROPERTYEX(@DbName, 'Recovery'))
	Update #DbConfigTable Set Recovery = @ParamDataStr Where DbName = @DbName
	SELECT @ParamDataStr = Convert(varchar(15), DATABASEPROPERTYEX(@DbName, 'SQLSortOrder'))
	Update #DbConfigTable Set SQLSortOrder = @ParamDataStr Where DbName = @DbName
	SELECT @ParamDataStr = Convert(varchar(15), DATABASEPROPERTYEX(@DbName, 'Status'))
	Update #DbConfigTable Set Status = @ParamDataStr Where DbName = @DbName
	SELECT @ParamDataStr = Convert(varchar(15), DATABASEPROPERTYEX(@DbName, 'Updateability'))
	Update #DbConfigTable Set Updateability = @ParamDataStr Where DbName = @DbName
	SELECT @ParamDataStr = Convert(varchar(15), DATABASEPROPERTYEX(@DbName, 'UserAccess'))
	Update #DbConfigTable Set UserAccess = @ParamDataStr Where DbName = @DbName
	SELECT @ParamDataStr = Convert(varchar(15), DATABASEPROPERTYEX(@DbName, 'Version'))
	Update #DbConfigTable Set Version = @ParamDataStr Where DbName = @DbName

	-- Updates the available space for the database
	select @SQL = 'Update #DbConfigTable  ' 
				+ 'Set SizeMb = (select convert(float, (sum(size*8))/1024) from '
				+ QuoteName(@DbName) + '.dbo.sysfiles)' 
				+ ' Where DbName = ''' + @DbName + ''''
		/* Insert row for each database */
	--print @sql
	execute (@SQL)
   END
   FETCH NEXT FROM cDatabases INTO @DbName
END
CLOSE cDatabases
DEALLOCATE cDatabases

-- Displays the results
select * from #DbConfigTable
compute count(DbName), sum(SizeMb)
-- Eliminates the temporary result table.
Drop Table #DbConfigTable
