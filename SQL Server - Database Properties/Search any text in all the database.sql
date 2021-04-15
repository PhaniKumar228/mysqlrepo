DECLARE @DBCount INT
DECLARE @CNTR INT
DECLARE @SQL VARCHAR(8000)
DECLARE @dbname NVARCHAR(255)
DECLARE @SearchText NVARCHAR(255)

SET @SearchText = 'null'

IF ISNULL(@SearchText,'') <> ''
BEGIN

 DECLARE @DBs TABLE ([ID] INT IDENTITY(1,1), [NAME] VARCHAR(255))
 INSERT INTO @DBs--drop table @DBs
 SELECT [NAME] FROM Master.dbo.sysdatabases
 WHERE [NAME] NOT IN ('MASTER', 'TEMPDB', 'MSDB', 'MODEL')
 ORDER BY [NAME]

 IF EXISTS(SELECT [NAME] FROM TEMPDB.DBO.SYSOBJECTS WHERE NAME LIKE '%#Results%')
 BEGIN
 DROP TABLE #Results
 END

 CREATE TABLE #Results([SERVERNAME] VARCHAR(255), [DBName] VARCHAR(255), [NAME] VARCHAR(255), XTYPE VARCHAR(255))

 SELECT @DBCount = (SELECT MAX([ID]) FROM @DBs)
 SET @CNTR = 1
 WHILE @CNTR <= @DBCount
 BEGIN
 SELECT @dbname = (SELECT [NAME] FROM @DBs WHERE [ID] = @CNTR)
 SELECT @SQL = 
 'USE [' + @dbname + '] insert into #Results
 SELECT DISTINCT 
 --substring(sc.Text, charindex(''' + @SearchText + ''', sc.text, 1) - 20, 255) as ''text'', 
 @@SERVERNAME, ''' + @dbname + ''' AS [DBName], so.[name], so.xtype
 FROM
 sysobjects so WITH(NOLOCK)
 inner join syscomments sc on so.id = sc.id 
 WHERE 
 sc.text like ''%'+ @SearchText + '%'''
 --PRINT @sql
 EXEC (@SQL)
 SET @CNTR = @CNTR + 1
 END

 SELECT * 
 FROM #Results
 ORDER BY DBName, XType, [Name]

END