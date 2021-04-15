/*
usp_ShowOrphanUsers - SQL 2k5

Check Orphaned logins ie, not associated with any database on the current instance.

*/

IF EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[usp_ShowOrphanUsers]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[usp_ShowOrphanUsers]
GO

CREATE PROC dbo.usp_ShowOrphanUsers
AS
--
--  usp_ShowOrphanUsers.sql - Check Orphaned SQL Logins
--
--  2007-06-19 Pedro Lopes (Novabase)
--  EXEC dba_database..usp_ShowOrphanUsers
--
BEGIN
	CREATE TABLE #Results
	([Database Name] sysname COLLATE Latin1_General_CI_AS, 
	[Orphaned User] sysname COLLATE Latin1_General_CI_AS,
	[Type User] sysname COLLATE Latin1_General_CI_AS)

	SET NOCOUNT ON	

	DECLARE @DBName sysname, @Qry NVARCHAR(4000)

	SET @Qry = ''
	SET @DBName = ''

	WHILE @DBName IS NOT NULL
	BEGIN
		SET @DBName = 
				(
					SELECT MIN(name) 
					FROM master..sysdatabases 
					WHERE 	name NOT IN 
						('master', 'model', 'tempdb', 'msdb', 'distribution', 'pubs', 'northwind', 'dba_database')
						AND DATABASEPROPERTY(name, 'IsOffline') = 0 
						AND DATABASEPROPERTY(name, 'IsSuspect') = 0 
						AND name > @DBName
				)
		
		IF @DBName IS NULL BREAK

		SET @Qry = '	SELECT ''' + @DBName + ''' AS [Database Name], 
				CAST(name AS sysname) COLLATE Latin1_General_CI_AS  AS [Orphaned User],
				[Type User] = 
					CASE isntuser 
						WHEN ''0'' THEN ''SQL User''
						WHEN ''1'' THEN ''NT User''
						ELSE ''Not Available''
					END
				FROM ' + QUOTENAME(@DBName) + '..sysusers su
				WHERE su.islogin = 1
				AND su.name NOT IN (''INFORMATION_SCHEMA'', ''sys'', ''guest'', ''dbo'', ''system_function_schema'')
				AND NOT EXISTS (SELECT 1 FROM master..syslogins sl WHERE su.sid = sl.sid)'
		INSERT INTO #Results 
		EXEC master..sp_executesql @Qry
	END
	SELECT * 
	FROM #Results 
	ORDER BY [Database Name], [Orphaned User]
	IF @@ROWCOUNT = 0
		PRINT 'No orphaned users exist in this server.'
END
GO
