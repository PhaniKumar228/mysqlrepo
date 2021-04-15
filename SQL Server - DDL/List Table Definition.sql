/*
List Table Definition

System Stored Procedure to List the Table Definition of a table as a printable report. The procedure must exist in the master database. This works for any table in the current database. Do not fully qualify the tablename. Calling sample: use pubs exec sp_listtabledef 'authors' 

*/

use master
set quoted_identifier off
go

/**********************************************
** This is a system stored procedure that will
** return the table definition of any table in
** any database on the current SQL Server
** best to run with results in text
** can then print as report
*********************************/

CREATE PROCEDURE sp_ListTableDef
@TableName varchar(40)

AS
DECLARE @strSQL varchar(2000)
DECLARE @dbname varchar(40)
SET @dbname = db_name()

print 'Table Structure for table: ' +@TableName
print '--------------------------------------------------------------------------'
print ' '

SET @strSQL ="SELECT 'COLUMN_NAME'=CAST(COLUMN_NAME AS VARCHAR(25)), 
'DEFAULT_VALUE'=CAST(COLUMN_DEFAULT AS VARCHAR(15)), 
'ALLOW_NULLS'=IS_NULLABLE, 
'DATA_TYPE'=CAST(DATA_TYPE AS VARCHAR(15)), 
'CHAR_MAXLEN'=ISNULL(CHARACTER_MAXIMUM_LENGTH,0), 
'PRECISION'=ISNULL(NUMERIC_PRECISION,0), 'SCALE'=ISNULL(NUMERIC_SCALE,0)
FROM " + @dbname +".INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = '" + @TableName +
"' ORDER BY Ordinal_Position"

EXEC (@strSQL)


