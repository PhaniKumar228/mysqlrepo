------------------------------------------------------------------------------------------------------------
--  Stored Procedure/Script Name: RemoteExec.sql 
-- 							 
--  Purpose: This code will allow you to link to other 
-- servers, execute and retrieve the output all form one
-- location. EXECUTE THIS FROM SQL 2005
--
--  A few steps must be completed before you start.
--
-- 1.  Create a database on a srver that the table can be created can called it: MYCONNECTDB
--     If you don't like that name just to a search/replace for that name
--
-- 2.  Modify the INSERT INTO statements to place your instance names, sa-password
--
-- 3.  Change 'Domain\yourname' to your domain and user name
-- 
-- 4.  Search for 'YourCode' and change it to your code which is to be executed on the remote/linked server
--
-- That's it. Only have to modify once for your enviroment.
--
-- Currently, I'm using it to connect to 120+ servers!
--
-- Enjoy

------------------------------------------------------------------------------------------------------------


USE MYCONNECTDB
go

drop table [dbo].[LinkedInstanceTable]
go
 
USE MYCONNECTDB
go

CREATE TABLE [dbo].[LinkedInstanceTable]
 ( 
 [NamedInstance] VARCHAR(125), 
 [LinkedPsswd] VARCHAR(35)
 )
GO

INSERT INTO [MYCONNECTDB].[dbo].[LinkedInstanceTable]([NamedInstance],[LinkedPsswd]) VALUES ('InstanceName1','sa-password1')
INSERT INTO [MYCONNECTDB].[dbo].[LinkedInstanceTable]([NamedInstance],[LinkedPsswd]) VALUES ('InstanceName2','sa-password2')
INSERT INTO [MYCONNECTDB].[dbo].[LinkedInstanceTable]([NamedInstance],[LinkedPsswd]) VALUES ('InstanceName3','sa-password3')
GO

USE master
GO
		
PRINT ' '
PRINT '                 Linked Server Remoted Execution '
PRINT ' '
PRINT '                          Version 1.1'
PRINT ' '
PRINT '   Usage: This script is used to remotely execute T-SQL commands'
PRINT '   on remote linked servers. Thus eliminating the need to'
PRINT '   manually connect to each server.'
PRINT ' '
PRINT '   Edit this script and enter the servers to link to and enter'
PRINT '   the sa password. Once completed this script will delete the'
PRINT '   created table and remove all linked connections.'
PRINT ' '
PRINT '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
PRINT ' '

-- Stop unnecessary SQL ouput
SET NOCOUNT ON


DECLARE @InstanceName VARCHAR (125),
		@psswd VARCHAR (15),
		@mySQL VARCHAR (250),
		@mySQL2 VARCHAR (250),
		@Error VARCHAR (150)
        
-- Set up cursor to load instances names

DECLARE myInstances CURSOR FOR SELECT NamedInstance, LinkedPsswd FROM MYCONNECTDB.dbo.LinkedInstanceTable

OPEN myInstances
	FETCH NEXT FROM myInstances INTO @InstanceName, @psswd
	
	WHILE @@FETCH_STATUS = 0
		BEGIN
		PRINT 'Create/Connect/Execute/Drop Linked Server for Instance: [' + @InstanceName + ']'

---------------------------------------------------------------------------------------------------
-- Connect to the remote/linked instance
	
		EXEC sp_addlinkedserver @InstanceName , N'SQL Server'	
IF @@Error <> 0
 BEGIN
	PRINT 'WARNING! sp_addlinkedserver error for instance: [' + @InstanceName + '], please review'
 END
ELSE 
	PRINT 'Adding Linked Server for instance: [' + @InstanceName + ']'
		EXEC sp_addlinkedsrvlogin @InstanceName, 'FALSE', 'Domain\yourname', 'sa', @psswd

IF @@Error <> 0
 BEGIN
	PRINT 'WARNING! sp_addlinkedsrvlogin error for instance: [' + @InstanceName + '], please review'
 END
ELSE 
	PRINT 'Adding Linked Server Login for instance: [' + @InstanceName + ']'


--  Execute your code on the remote/linked server

   PRINT 'Executing Command on Instance: [' + @InstanceName + ']'
--   PRINT ' '

-- ------------------------------------------------------------------------------
-- Edit this section with the T_SQL query to be executed on all linked servers 
-- ------------------------------------------------------------------------------
-- ******************************************************************************


exec ('YourCode')


-- ******************************************************************************
-- ------------------------------------------------------------------------------  

IF @@Error <> 0
 BEGIN
	PRINT 'WARNING! CAN NOT EXECUTE REMOTE CODE ON INSTANCE: [' + @InstanceName + '], PLEASE REVIEW'
 END
ELSE 
	PRINT ' '
	PRINT 'Exeuted remote code on instance: [' + @InstanceName + ']'
PRINT ' '
PRINT ' '
PRINT ' '


-- Drop the remote/linked server connection

PRINT 'Dropping Linked Server Instance: [' + @InstanceName + ']'
	EXEC sp_dropserver @InstanceName, 'droplogins' 

IF @@Error <> 0
 BEGIN
	PRINT 'WARNING! CAN NOT DROP CONNECTION FOR INSTANCE: [' + @InstanceName + '] PLEASE REVIEW'
 END
ELSE 
	PRINT 'Dropped connection on instance: [' + @InstanceName + ']'

PRINT ' '
PRINT '*********************************************'
FETCH NEXT FROM myInstances INTO @InstanceName, @psswd
END

CLOSE myInstances
DEALLOCATE myInstances

-- Drop work table. This will ensure better security as it contains you 'sa' passwords!

drop table  [MYCONNECTDB].[dbo].[LinkedInstanceTable]

IF @@Error <> 0
 BEGIN
	PRINT 'WARNING! CAN NOT DROP TABLE: MYCONNECT, PLEASE REVIEW'
 END
ELSE 
	PRINT 'Dropped Table: MYCONNECT'

PRINT ' '
PRINT '*********************************************'
PRINT ' '
PRINT ' End of Query - Completed '