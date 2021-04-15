/*
A more efficient ForEach routine

SQL 2000's sp_MSForEachDB and sp_MSForEachTable are useful procedures for performing operations against multiple objects; however, they aren't always extremely efficient, because internally they use cursors to do their work.

These 2 sprocs, sp_ForEachDB and sp_ForEachTable, perform many of the same tasks as their Microsoft-shipped twins, but run faster because they dynamically build the SQL string without using cursors. In addition, these two sprocs can also be used with SQL 7, which doesn't come with the sp_MSForEach sprocs. 

*/

/*Important: create these sprocs in the MASTER DB. */

USE master
GO

/*
Script for sp_ForEachDB.
Executes a given commamd for all user DBs.
Example: EXEC sp_ForEachDB 'exec sp_helpdb ?'
*/

CREATE PROCEDURE sp_ForEachDB
@cmd VARCHAR(8000),
@exec bit = 1 
/* Set to 0 if you only want to print the statements, not execute them */

AS

DECLARE @sql VARCHAR(8000)

SELECT @sql = isnull(@sql + CHAR(13), '') +
REPLACE(@cmd, '?', name)
FROM sysdatabases
WHERE name NOT IN 
('master', 'model', 'msdb', 'tempdb')

IF @exec = 0
PRINT @sql

ELSE
EXEC(@sql)
------------------------
------------------------

/*
Script for sp_ForEachTable.
Executes a given commamd for all user tables in a database.
Example: EXEC sp_ForEachTable 'select top 10 from ?'
*/
CREATE PROCEDURE sp_ForEachTable
@cmd VARCHAR(8000),
@exec bit = 1 
/* Set to 0 if you only want to print the statements, not execute them */

AS

DECLARE @sql VARCHAR(8000)

SELECT @sql = isnull(@sql + CHAR(13), '') +
REPLACE(@cmd, '?', name)
FROM sysobjects
WHERE xtype = 'u'

IF @exec = 0
PRINT @sql

ELSE
EXEC(@sql)
