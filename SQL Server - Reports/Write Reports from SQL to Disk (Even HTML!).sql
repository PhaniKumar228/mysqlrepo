/*
Write Reports from SQL to Disk (Even HTML!)

Ever need to write reports out to a folder? I have found that creating output files are SA-WEET! (and easy too) The sample script uses BCP to create an HTML file.

This process works well for reports that need to be generated nightly and take too long to run in real time.  Use an SMTP mail agent, and ALAS web based mail!


First open the script and change MYDATABASE to your database.

Second, add the script to your database then run the following:
  --Create the HTML file
  usp_writeSysObjectReport 'C:\sysobjects.html'
  --See the contents
  master..xp_cmdshell 'type c:\sysobjects.html'

  --Run this to clean up (uncomment)
  --master..xp_cmdshell 'erase c:\sysobjects.html'

Summary:
You can use BCP to create HTML documents and/or HTML mail. Can create many reports fast! You could modify the output to push it to a web server.

*/

CREATE PROC usp_CreateSysObjectsReport
AS
   /***
    *   Location:     Any database
    *   Permissions:  PUBLIC EXECUTE
    *   
    *   Description:  Creates an HTML table from SYSOBJECTS
    *   
    *   Restrictions: some permissions may need to be set
    *   
    ***/
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON

   SELECT '<TABLE>'
   UNION ALL
   SELECT '<tr><td><CODE>' + name + '</CODE></td></tr>' FROM sysobjects
   UNION ALL
   SELECT '</TABLE>'
END
GO
GRANT EXECUTE ON usp_CreateSysObjectsReport TO PUBLIC
GO
CREATE PROC usp_writeSysObjectReport(@outfile VARCHAR(255))
AS
   /***
    *   Location:     Any database
    *   Permissions:  PUBLIC EXECUTE
    *   
    *   Description:  Writes the SYSOBJECTS report to specified @outfile
    *   
    *   Restrictions: some permissions may need to be set
    *   
    *   TODO!!!!!  CHANGE MYDATABASE TO YOUR DATABASE NAME!!!
    *   
    ***/
BEGIN
   DECLARE @strCommand VARCHAR(255)
   DECLARE @lret       INT

   SET @strCommand = 'bcp "EXECUTE MYDATABASE..usp_CreateSysObjectsReport"'
       + ' QUERYOUT "' + @outfile + '" -T -S' + LOWER(@@SERVERNAME) + ' -c'

   --BCP the HTML file
   PRINT 'EXEC master..xp_cmdshell ''' + @strCommand + ''''
   EXEC @lRet = master..xp_cmdshell @strCommand, NO_OUTPUT

   IF @lret = 0
      PRINT 'File Created'
   ELSE
      PRINT 'Error: ' + str(@lret)
END
GO
GRANT EXECUTE ON usp_writeSysObjectReport TO PUBLIC
GO

