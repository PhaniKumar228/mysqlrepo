if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_serverup]') 
and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_serverup]
GO

CREATE PROCEDURE usp_serverup
(
   @server    sysname,           -- remote server
   @islinked  char(1)  = 'N',    -- is it a linked server ?
   @timeout   int      = 10,     -- login timeout
   @up        int      OUTPUT    -- returns server status
)
AS
/*
Determines if a specified remote SQL server can be connected to   
    1  =  Running
   -1  =  Down

*/
SET NOCOUNT ON

   DECLARE @hr int
   DECLARE @sql int
   DECLARE @cnt int ; SET @cnt = 0
   DECLARE @server_resolved sysname
   DECLARE @status int ; SET @status = 0
   
   IF @islinked='Y'
   BEGIN
   
      SELECT @cnt=COUNT(*)
      FROM master.dbo.sysservers
      WHERE srvname=@server
      AND isremote=1
   
      IF @cnt<>1
      BEGIN
         RAISERROR('Linked server name cannot be resolved',16,1)
         RETURN(1)
      END
   
      SELECT @server_resolved = datasource
      FROM master..sysservers
      WHERE srvname=@server
      AND isremote=1
   
   END
   ELSE
   
      SELECT @server_resolved = @server
   

   
   EXEC @hr = sp_OACreate 'SQLDMO.SQLServer', @sql OUTPUT
   IF @hr<>0 EXEC sp_OAGetErrorInfo @sql
   
   EXEC @hr = sp_OASetProperty @sql ,'LoginSecure','True'
   EXEC @hr = sp_OASetProperty @sql ,'LoginTimeout',10
   EXEC @hr = sp_OAMethod @sql,'Connect',null,@server_resolved
   IF @hr<>0 EXEC sp_OAGetErrorInfo @sql
   
   EXEC @hr = sp_OAGetProperty @sql ,'Status',@status OUTPUT
   EXEC @hr = sp_OAMethod @sql,'DisConnect',null
   EXEC @hr=sp_OADestroy @sql
   
   SELECT @up = CASE WHEN @status = 1
                     THEN 1 ELSE -1 END

RETURN

GO
