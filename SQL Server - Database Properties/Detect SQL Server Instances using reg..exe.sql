/*
Detect SQL Server Instances using reg.exe 

Detect SQL Server Instance(s) using reg.exe from the resource kit, just pass the host name! (and make sure reg.exe from the resouce kit is in the ../tools/bin directory. SS2k Only.

Enjoy!


*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
CREATE PROC usp_ListSQLInstance(@HostName HOSTNAME)
AS
   /***
    *   Project:      Detecting SQL Instances
    *   Location:     Any user database
    *   Permissions:  PUBLIC EXECUTE
    *   
    *   Description:  Returns a list of instances found
    *                  on a machine.
    *   
    *   Restrictions: The instance may not be running, could
    *                  parse the results from srvinfo.exe
    *                  SQL Server Only
    * 
    *   Requirements:  reg.exe from the resource kit (nt or 2k)
    *
    *   History:
    *   
    ***/

BEGIN
   SET NOCOUNT ON
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @instance varchar(100)
   CREATE TABLE #instance (instance varchar (150))
   DECLARE @strSQL VARCHAR(400)


   SET @strSQL = 'call reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server" \\' + LTRIM(@HostName) + '| findstr /I /L /C:"[" '

   INSERT INTO #instance EXECUTE master..xp_cmdshell @strSQL
   DELETE FROM #instance where instance IS NULL
   DELETE FROM #instance where instance = '[80]' OR instance = '[8.00.000]'
   DELETE FROM #instance where charindex(' ', instance) > 0
   UPDATE #instance SET instance = REPLACE(instance, '[','')
   UPDATE #instance SET instance = REPLACE(instance, ']','')
   SELECT * FROM #instance --WHERE RTRIM(LTRIM(instance)) like '%[%'
   DROP TABLE #instance
END
GO
GRANT EXECUTE ON usp_ListSQLInstance TO PUBLIC
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO



