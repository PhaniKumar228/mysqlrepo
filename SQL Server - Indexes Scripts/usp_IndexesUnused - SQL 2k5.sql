/*
usp_IndexesUnused - SQL 2k5

Checks for unused indexes (no updates or user hits). DB name is authorative.

Usage: EXEC usp_IndexesUnused <DBName>

*/

IF EXISTS (SELECT name FROM dbo.sysobjects WHERE id = Object_id(N'[dbo].[usp_Indexesunused]') AND OBJECTPROPERTY(id,N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[usp_IndexesUnused]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

CREATE PROC usp_IndexesUnused @DBName VARCHAR(255) = NULL
AS
--
--  usp_IndexesUnused.sql - Checks for unused indexes (no updates or user hits)
--
--  EXEC usp_IndexesUnused <DBName>
--
SET NOCOUNT ON
IF @DBName IS NULL
	BEGIN
		SELECT 'DB name is authorative.' AS 'WARNING - SYNTAX ERROR!'
		RETURN
	END
DECLARE @DBID int
SELECT @DBID = DB_ID(@DBName)
DECLARE @SQLcmd NVARCHAR(max)
SET @SQLcmd = 'USE [' + @DBName + '];
	SELECT ''[' + @DBName + ']'' AS DBName,
			OBJECT_NAME(a.object_id) AS ''Table'',
			c.name AS ''IndexName'',
			(SELECT used/128 FROM sysindexes b WHERE b.id = a.object_id AND b.name=c.name AND c.index_id = b.indid) AS ''Size_MB'',
			(a.user_seeks + a.user_scans + a.user_lookups) AS ''Hits'',
			RTRIM(CONVERT(NVARCHAR(10),CAST(CASE WHEN (a.user_seeks + a.user_scans + a.user_lookups) = 0 THEN 0 ELSE CONVERT(REAL, (a.user_seeks + a.user_scans + a.user_lookups)) * 100 / 
			CASE (a.user_seeks + a.user_scans + a.user_lookups + a.user_updates) WHEN 0 THEN 1 ELSE CONVERT(REAL, (a.user_seeks + a.user_scans + a.user_lookups + a.user_updates)) END END AS DECIMAL(18,2)))) + ''/'' +
			RTRIM(CONVERT(NVARCHAR(10),CAST(CASE WHEN a.user_updates = 0 THEN 0 ELSE CONVERT(REAL, a.user_updates) * 100 / 
			CASE (a.user_seeks + a.user_scans + a.user_lookups + a.user_updates) WHEN 0 THEN 1 ELSE CONVERT(REAL, (a.user_seeks + a.user_scans + a.user_lookups + a.user_updates)) END END AS DECIMAL(18,2)))) AS [R/W_Ratio],
			a.user_updates AS ''Updates'', --indicates the level of maintenance on the index caused by insert, update, or delete operations on the underlying table or view
			a.last_user_update AS ''Update_Date''
	FROM sys.dm_db_index_usage_stats a
	JOIN sysobjects AS o ON (a.OBJECT_ID = o.id)
	JOIN sys.indexes AS c ON (a.OBJECT_ID = c.OBJECT_ID AND a.index_id = c.index_id)
	WHERE o.type = ''U''			-- exclude system tables
	AND c.is_unique = 0			-- no unique indexes
	AND c.type = 2				-- nonclustered indexes only
	AND c.is_primary_key = 0		-- no primary keys
	AND c.is_unique_constraint = 0		-- no unique constraints
	AND c.is_disabled = 0			-- only active indexes
	AND a.database_id = ' + CAST(@DBID AS CHAR(4)) + ' -- for current database only
	AND ((a.user_seeks + a.user_scans + a.user_lookups) = 0)
	ORDER BY OBJECT_NAME(a.object_id), a.user_updates'
EXEC master..sp_executesql @SQLcmd
GO

SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO