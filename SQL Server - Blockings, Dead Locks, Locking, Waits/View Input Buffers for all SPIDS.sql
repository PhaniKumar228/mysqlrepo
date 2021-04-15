/*
View Input Buffers for all SPIDS

This procedure, sp_AllInputBuffers, uses dynamic T-SQL to generate and execute the DBCC INPUTBUFFER statement for each server process (except yours).  Perfect for performance troubleshooting situations, when you want to see what commands are being executed against your server.  Also, a great example of the power of dynamic T-SQL.

For the @exec parameter, pass 1 or leave it blank to execute the DBCC statements; pass 0 if you only want to view the statements being generated. 

*/

USE MASTER

CREATE PROCEDURE sp_AllInputBuffers
@exec bit = 1

/* 
@exec parameter: 0=print DBCC statements, 1=execute statements
*/

AS

SET NOCOUNT ON

DECLARE @execstr NVARCHAR(4000)

SELECT @execstr = 
ISNULL(@execstr + CHAR(13), '') + 
'DBCC INPUTBUFFER(' + CAST(spid AS VARCHAR) + ')' 
FROM master..sysprocesses
WHERE spid <> @@spid

IF @exec = 1 EXEC sp_executesql @execstr
ELSE PRINT @execstr
