/*
Verify Last successful CHECKDB on all databases

After reading an interesting blog post from Paul Randal about how to verify the last good CHECKDB that occurred for a database, I decided that I would create a report to add to my daily monitoring regimen.

This script is the basis for my report. It utilizes a feature in SQL Server 2005 which records the most recent successful CHECKDB in the boot page of the database.

I enumerate through each database using a cursor and return a simple result set to tell me the most recent occurrence of a successful CHECKDB, how many days it has been, and how many hours it has been. I then have this as the source of an Excel database query for each of the instances I support. It is a quick and dirty way to monitor the integrity of your databases.

*/

/*
Description: Examines the "boot page" of each database to 
express when the last successful CheckDB was performed

*/


SET NOCOUNT ON

CREATE TABLE #DBInfo_LastKnownGoodCheckDB
	(
		ParentObject varchar(1000) NULL,
		Object varchar(1000) NULL,
		Field varchar(1000) NULL,
		Value varchar(1000) NULL,
		DatabaseName varchar(1000) NULL
	
	)

DECLARE csrDatabases CURSOR FAST_FORWARD LOCAL FOR
SELECT name FROM sys.databases WHERE name NOT IN ('tempdb')

OPEN csrDatabases

DECLARE 
	@DatabaseName varchar(1000),
	@SQL varchar(8000)

FETCH NEXT FROM csrDatabases INTO @DatabaseName

WHILE @@FETCH_STATUS = 0
BEGIN

	--Create dynamic SQL to be inserted into temp table
	SET @SQL = 'DBCC DBINFO (' + CHAR(39) + @DatabaseName + CHAR(39) + ') WITH TABLERESULTS'

	--Insert the results of the DBCC DBINFO command into the temp table
	INSERT INTO #DBInfo_LastKnownGoodCheckDB
	(ParentObject, Object, Field, Value) EXEC(@SQL)

	--Set the database name where it has yet to be set
	UPDATE #DBInfo_LastKnownGoodCheckDB
	SET DatabaseName = @DatabaseName
	WHERE DatabaseName IS NULL

FETCH NEXT FROM csrDatabases INTO @DatabaseName
END

--Get rid of the rows that I don't care about
DELETE FROM #DBInfo_LastKnownGoodCheckDB
WHERE Field <> 'dbi_dbccLastKnownGood'

SELECT 
	DatabaseName, 
	CAST(Value AS datetime) AS LastGoodCheckDB,
	DATEDIFF(dd, CAST(Value AS datetime), GetDate()) AS DaysSinceGoodCheckDB,
	DATEDIFF(hh, CAST(Value AS datetime), GetDate()) AS HoursSinceGoodCheckDB
FROM #DBInfo_LastKnownGoodCheckDB
ORDER BY DatabaseName


DROP TABLE #DBInfo_LastKnownGoodCheckDB

