/*
Shrinking all log files (or data files) on SQL Server 2005

This can be run as a job or manually. 
There are no parameters so it will do ALL log files that it finds; 
excluding system files.

If you want to shrink all database files including data files (and indexes) then find these lines of code:

SELECT @exec_stmt = 'INSERT INTO #logfiles 
SELECT ''' + @DBName + ''' , name FROM ' + quotename(@DBName, N'[') + N'.dbo.sysfiles 
WHERE groupid = 0'

and replace it with this code:

SELECT @exec_stmt = 'INSERT INTO #logfiles
SELECT ''' + @DBName + ''' , name FROM ' + quotename(@DBName, N'[') +N'.dbo.sysfiles'

*/

DECLARE @DBName AS NVARCHAR(100)
DECLARE @LogFileName AS NVARCHAR(100)
DECLARE @exec_stmt nvarchar(625)

--create the temporary table to hold the log file names
CREATE TABLE #logfiles
(
????dbname NVARCHAR(100),
????[filename] NVARCHAR(100),
)

--select all dbs, except for system dbs
DECLARE curDBName CURSOR FOR
????SELECT [name] FROM sys.databases 
????WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb') 
????AND state_desc = 'ONLINE'

--add the log file name to the temporary table
OPEN curDBName
FETCH NEXT FROM curDBName INTO @DBName
WHILE @@FETCH_STATUS = 0
BEGIN
????SELECT @exec_stmt = 'INSERT INTO #logfiles 
???????????????????????? SELECT ''' + @DBName + ''' , name FROM ' + quotename(@DBName, N'[') + N'.dbo.sysfiles 
???????????????????????? WHERE groupid = 0'
????EXECUTE (@exec_stmt)
????FETCH NEXT FROM curDBName INTO @DBName
END
CLOSE curDBName
DEALLOCATE curDBName

--view all files if required
--SELECT * FROM #logfiles

--select all log filenames
DECLARE curLogName CURSOR FOR
SELECT dbname, [filename] FROM #logfiles

--shrink all log files
OPEN curLogName
FETCH NEXT FROM curLogName INTO @DBName, @LogFileName
WHILE @@FETCH_STATUS = 0
BEGIN

????SELECT @exec_stmt = ' USE ' + quotename(@DBName, N'[') + 
????????????????????????N' CHECKPOINT ' +
????????????????????????N' BACKUP LOG ' + quotename(@DBName, N'[') + ' WITH NO_LOG ' + 
????????????????????????N' DBCC SHRINKFILE (' + quotename(@LogFileName, N'[') + N', 0, TRUNCATEONLY)'
SELECT (@exec_stmt)????
EXECUTE (@exec_stmt)
????
????FETCH NEXT FROM curLogName INTO @DBName, @LogFileName
END
CLOSE curLogName
DEALLOCATE curLogName

--clean up the logfile table
DROP TABLE #logfiles
