/*
Drop Statistics

This procedure was created to automate the dropping of statistics on a user specified table.  

Very simple code, but handy if the need is there.

Replace 'tablename' throughout script with the name of the table intended to temporarily house the statistics name(s). 

*/


CREATE PROCEDURE USP_DropStats
@TableName varchar(1024)
AS
DECLARE @StatName varchar(1024)
DECLARE @SQLString varchar(8000)
TRUNCATE TABLE <tablename>
INSERT INTO <tablename>
EXEC sp_helpstats @objname=@TableName
IF EXISTS(SELECT statistics_name,COUNT(statistics_name) 
	  FROM <tablename> 
	  GROUP BY statistics_name 
	  HAVING COUNT(statistics_name)>0)
BEGIN
DECLARE StatisticsCursor CURSOR FOR 
SELECT statistics_name FROM <tablename>

OPEN StatisticsCursor

FETCH NEXT FROM StatisticsCursor into @StatName
WHILE @@FETCH_STATUS = 0
BEGIN
    
SET @SQLString = 'DROP STATISTICS '+@TableName+'.'+@StatName+''
EXEC (@SQLString)

	
FETCH NEXT FROM StatisticsCursor into @StatName
END
CLOSE StatisticsCursor
DEALLOCATE StatisticsCursor
END
TRUNCATE TABLE <tablename>
