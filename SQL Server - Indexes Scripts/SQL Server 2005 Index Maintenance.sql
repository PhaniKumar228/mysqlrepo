/*
SQL Server 2005 Index Maintenance

The first procedure is based on the process found in Books Online. 
However the cursor has been replaced with a while loop and modified to accept a database name as a parameter. 
Using dynamic sql I was able to overcome the issue in having to deploy to each db on the server. 
The procedure will REORGANIZE any indexes that have a fragementation level between 20 & 30 percent and has 
a page count greater than 10. 
The REBUILD parameter will be used if the fragmentation level is 30 percent or above. 
I have also added the ability to log information into a table regarding start & end times 
(currently set to Insert into DBInfo in a database named MAINT). Uses the SORT_IN_TEMPDB and ONLINE options 
(Please see BOL for more information on these options before deploying to your environment).

The second procedure will cycle through each non system database on the server and execute the uspIndexMaintenance script.

*/
USE [master]
GO

SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
/**
This procedure reorganizes any indexes (NON XML) that have a page
count greater than 10 and a fragmentation level greater than 20%. If 
the fragmentation level is 30% or above the index will be rebuilt 
using the ONLINE parameter (enterprise edition only). Sorting will be 
done in the TEMPDB to decrease the maintenance time interval. 
TEMPDB must have sufficient space available otherwise remove "SORT_IN_TEMPDB=ON"
before creating this script in the Master db. 
*/

CREATE PROCEDURE [dbo].[uspIndexMaintenance] @dbname varchar(50)
--

AS
BEGIN

--DECLARE @dbname varchar(50)
--Set @dbname = ''
--Setup dynamic SQL to run. Otherwise the Procedure needs to be deployed to each db. 
DECLARE @SQL varchar(4000)
SET @SQL = 'Use ' + @dbname + '
--Declare variables here
DECLARE @objectid int
DECLARE @indexid int
DECLARE @partitioncount bigint
DECLARE @schemaname varchar(130)
DECLARE @objectname varchar(130)
DECLARE @indexname varchar(130)
DECLARE @partitionnum bigint
DECLARE @partitions bigint
DECLARE @frag int
DECLARE @command varchar(4000)

--Used for looping
DECLARE @max int
DECLARE @min int

--Create tables to hold Index information about each table in the database

CREATE TABLE #IndexList (ID int IDENTITY(1,1), 
DBName varchar(50), 
objectID int,
indexID int,
IndexType varchar(30),
frag int,
avg_fragment_size_in_pages int,
page_count int,
partition_number int)

--Create indexes on #IndexList
CREATE CLUSTERED INDEX IX_CL_IndexList ON #IndexList(ID)

--Get Index stats
INSERT #IndexList (DBName, objectID, indexID, IndexType, frag, avg_fragment_size_in_pages, page_count, partition_number)
????SELECT DB_Name(database_id) AS DBName,
???????? object_id,
???????? index_id,
???????? index_type_desc AS IndexType,
???????? avg_fragmentation_in_percent, 
???????? avg_fragment_size_in_pages,
 page_count,
???? partition_number FROM sys.dm_db_index_physical_stats 
????????(DB_ID(), NULL, NULL, NULL, ''LIMITED'')
????WHERE page_count > 10 AND index_id > 0 AND avg_fragmentation_in_percent > 20 AND
????index_type_desc NOT LIKE ''%XML%''

--Begin reorganizing or rebuilding indexes. Determined by level of fragmentation.
--Rebuilding of indexes will use the SORT_IN_TEMPDB and ONLINE parameters.

SELECT @max = (SELECT max(ID) FROM #IndexList)
SELECT @min = 1
WHILE @min <= @max
BEGIN

????SELECT @objectid = objectID,
????????@indexid = indexID,
????????@partitionnum = partition_number,
????????@frag = frag FROM #IndexList 
????WHERE ID = @min

????SELECT @objectname = o.name, @schemaname = s.name
????FROM sys.objects AS o
????JOIN sys.schemas AS s ON s.schema_id = o.schema_id
????WHERE o.object_id = @objectid
????SELECT @indexname = name
????FROM sys.indexes
????WHERE object_id = @objectid AND index_id = @indexid;
????SELECT @partitioncount = count(*)
????FROM sys.partitions
????WHERE object_id = @objectid AND index_id = @indexid

--Reorganize or Rebuild
--Inserts Index information into Maint.dbo.DBIndexInfo for logging purposes
????INSERT Maint.dbo.DBIndexInfo (DBName, TableName, IndexName, Status, CreationDate)
????VALUES ('''+ @dbname +''', @objectname, @indexname, ''Start'', Getdate())

IF @frag < 30
????
????SET @command = ''ALTER INDEX '' + @indexname + '' ON '' + @schemaname + ''.'' + @objectname +'' REORGANIZE'';
????--PRINT @command
????EXEC (@command)

IF @frag >= 30
????SET @command = ''ALTER INDEX '' + @indexname + '' ON '' + @schemaname + ''.'' + @objectname +'' REBUILD WITH(FILLFACTOR = 80, ONLINE = ON, SORT_IN_TEMPDB = ON)'';
????--PRINT @command
????EXEC (@command)

IF @partitioncount > 1
????SET @command = @command + ''PARTITION ='' + CAST(@partitionnum AS varchar(10));
????--PRINT @command
????EXEC (@command)

INSERT Maint.dbo.DBIndexInfo (DBName, TableName, IndexName, Status, CreationDate)
????VALUES ('''+ @dbname +''', @objectname, @indexname, ''End'', Getdate())
SET @min = @min+1
END

PRINT ''Index maintenance on the '+@dbname +' database has completed.''
???????
--select * from maint.dbo.DBIndexInfo

DROP TABLE #IndexList
'
EXEC (@SQL)
--PRINT @SQL
END
GO

USE [master]
GO
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

/*
********** uspDBIndexCycle ************
Script will cycle through each database on the server and execute the sp_MaintAutoReindex2005 procedure.
*/

CREATE PROCEDURE [dbo].[uspDBIndexCycle]
AS
BEGIN

DECLARE @sql varchar(300)
DECLARE @dbname sysname
DECLARE @min int
DECLARE @max int

--Create our temp table to hold all database names on the server
CREATE TABLE #database ([ID] int IDENTITY(1,1), [Name] varchar(60))

--
--Create Clustered Index on the name column & and insert values
CREATE CLUSTERED INDEX IX_CL_database ON #database([Name])


INSERT INTO #database ([Name])
SELECT [name] FROM sys.databases WHERE [name] NOT IN('master','tempdb','model','msdb')


--Build our loop

SELECT @max = (SELECT max(ID) FROM #database)
SELECT @min = 1

WHILE @min <= @max
BEGIN

SELECT @dbname = [Name] FROM #database WHERE ID = @min

SELECT @sql = 'EXEC uspIndexMaintenance ''' + @dbname +''''
EXEC (@sql)
--PRINT @sql

SET @min = @min+1
END

--Clean up
DROP TABLE #database

END










