/*
sp_ServerStatus

Have you ever wanted to check that a server exists before using it. 
Here is a solution that use SQLDMO from within TSQL to get the status of a SQL Server service. 
It also works for 2000 instances. 
I have named it sp_ServerStatus for it to be based in master.

This returns the status integer and a text description through OUTPUT properties of the SP. 

Example

DECLARE @s int, @t varchar(100)
exec sp_ServerStatus 'MySQLServer\instance1',@s output, @t output
select @s, @t 

*/

DROP PROCEDURE dbo.sp_ServerStatus
go
CREATE PROCEDURE dbo.sp_ServerStatus
(
  @servername sysname
 ,@status      int OUTPUT
 ,@statusText varchar(20) OUTPUT
)
AS
SET XACT_ABORT ON

  declare @hr int , @object int
  exec @hr = sp_OACreate 'sqldmo.sqlserver', @object OUTPUT 
  IF @hr<> 0 
    RAISERROR ('Cannot create sqldmo.sqlserver object',15,1)
  
  exec @hr = sp_OASetProperty  @object, 'Name', @servername
  
  exec @hr = sp_OAGetProperty  @object, 'Status', @status OUTPUT

  SET @statusText = CASE @HR WHEN -2147221499 THEN 'Access Denied'
                             WHEN -2147219782 THEN 'Server does not exist'
                             WHEN 0 THEN CASE @status WHEN 0 THEN 'Unknown'
                                                       WHEN 5 THEN 'Stopping'
                                                       WHEN 3 THEN 'Stopped'
                                                       WHEN 4 THEN 'Starting'
                                                       WHEN 1 THEN 'Running'
                                                       WHEN 7 THEN 'Pausing'
                                                       WHEN 2 THEN 'Paused'
                                                       WHEN 6 THEN 'Continuing' 
                                                       ELSE 'Unknown' END
                             ELSE 'Unknown error occurred' END
  EXEC sp_OADestroy @object
GO

