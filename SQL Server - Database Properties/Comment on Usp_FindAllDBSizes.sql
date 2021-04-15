/*
Comment on Usp_FindAllDBSizes

This is a comment on/modification of the Usp_FindAllDBSizes script on.
Why use an inner loop when you can use a select stmt?
*/

CREATE PROCEDURE Usp_FindAllDBSizes
AS SET NOCOUNT ON

DECLARE 
  @Counter SMALLINT,
  @DBName VARCHAR(100)

IF EXISTS(SELECT name FROM sysobjects WHERE name='SizeInfo') DROP TABLE SizeInfo
CREATE TABLE SizeInfo(DBName SysName, FileSize DECIMAL(15,2))

SELECT @Counter=MAX(dbid) FROM master..sysdatabases
WHILE @Counter > 0 BEGIN
	SELECT @dbname=name FROM master..sysdatabases WHERE dbid=@counter
	Exec ('INSERT INTO SizeInfo(DBName, FileSize) SELECT ''' + @DBName + ''' As DBName, Size FROM '+ @DBName +'..SYSFILES')
	SET @Counter=@Counter-1
END

SELECT DBName, CAST(Sum(FileSize*0.0078125) AS DECIMAL(15,2)) AS [DBSIZE(MB)]
From SizeInfo
Group By DBName

SET NOCOUNT OFF
