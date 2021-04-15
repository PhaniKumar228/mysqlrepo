/*

Monitor Any Linked Server From SQL 2005

DBA's often monitor Backups, Replication e.t.c manually or through some automation but there is one thing which needs to be monitored is linked server. 
Often there may be some issue in linked server and DBA's will not know till Application user raises issue. 
Also there is no straight method to test excel linked server since the external procedure by SQL 2005 will say pass even the excel sheet is deleted from the path. 
So this script will help you to monitor Linked servers from SQL 2005 and i will also post a SQL 2000 version of this script later.

Also fine below the behaviour of excel sheet on different action and the test i have done on this script. 
Any enhancements/suggestions are always welcome!

Testing Done on Behaviour of Excel Linked Server When Excel sheet is used by some one [For General Understanding on Excel]

*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[uspMonitor_LinkedServer_2005] 
AS
BEGIN
DECLARE @ServerName VARCHAR(255)
DECLARE @msg VARCHAR(500)
DECLARE @status INT ;SET @status = 0

-- Get the list of Linked Servers 
DECLARE Lnkd_srvr_Crsr CURSOR FAST_FORWARD FOR
SELECT name FROM sys.servers WHERE is_linked=1 AND name NOT IN ('') --Not in Clause can be used to exclude some Test Linked Servers

OPEN Lnkd_srvr_Crsr
FETCH NEXT FROM Lnkd_srvr_Crsr INTO @ServerName
WHILE @@FETCH_STATUS = 0
BEGIN
 -- The Below query will list the tables available in the linked server. Even it works for Excel
 BEGIN TRY
	EXEC master..sp_tables_ex @ServerName
	SET @status = @@ROWCOUNT
 END TRY

 -- Checking Status and Sending Alert Mail to Team
 BEGIN CATCH
	SET @msg= 'Error from linked server ' + @ServerName + ' Configured at ' + @@SERVERNAME + ' ' + error_message()
	Exec [MONITOR].master.dbo.xp_smtp_sendmail @from= 'Linked_Server_Alert@Company.com' ,@from_name= @@SERVERNAME ,
	@to='Team@Company.com', 
	@priority = 'HIGH', @subject=@msg, 
	@type= 'text/plain', @server = 'mailserver.company.com' 
	Print 'Mail Sent' + @ServerName
	SET @status = 1
 END CATCH

 IF @status = 0 BEGIN
	SET @msg= 'No Recordset Returned from linked server ' + @ServerName + ' Configured at ' + @@SERVERNAME 
	Exec [MONITOR].master.dbo.xp_smtp_sendmail @from= 'Linked_Server_Alert@Company.com' ,@from_name= @@SERVERNAME ,
	@to='Team@Company.com', 
	@priority = 'HIGH', @subject=@msg, 
	@type= 'text/plain', @server = 'mailserver.company.com' 
	Print 'Mail Sent' + @ServerName
 END
 SET @status = 0       -- Setting the Status Variable back to 0 for Resetting Error Trapped
 FETCH NEXT FROM Lnkd_srvr_Crsr INTO @ServerName
END
CLOSE Lnkd_srvr_Crsr
DEALLOCATE Lnkd_srvr_Crsr

END




