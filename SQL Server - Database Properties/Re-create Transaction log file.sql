/*
Re-create Transaction log file

This stored procedure detaches and re-attaches a database without specifying a filename for the transaction log. This causes SQL Server to create log file with default size of 512kb.

After playing around with SHRINKDATABASE, SHRINKFILE, forcing the virtual log to wrap around, etc... I found this was the quickest and most reliable method of reclaiming the lost disk space. It takes less than a minute.

The procedure only runs if the user is a sysadmin, the database is not in use, and a transaction log backup has been performed recently. The current file is renamed so if things go wrong you can re-attach using the original file. If all is ok, just delete the renamed file.

*/

/****** Object:  Stored Procedure dbo.usp_ReCreateTranLog    Script Date: 26/02/2002 10:10:33 ******/
if exists (select * from sysobjects where id = object_id('dbo.Usp_ReCreateTranLog') and sysstat & 0xf = 4)
	drop procedure dbo.usp_ReCreateTranLog
GO

CREATE PROCEDURE dbo.usp_ReCreateTranLog
/*************************************************************************
FILENAME: 
	
SQL SERVER OBJECT NAME:  
	dbo.usp_ReCreateTranLog 

PURPOSE:
	Detach and reattach database without specifying transaction log.
	causing SQL Server to create log file with default size of 512kb
ACTIONS:
	Ensure user is member of sysadmin role
	Ensure database specified is not a system database
	Ensure database is not being used by any active processes
	Ensure Transaction log has been backed up
	Retrieve path and filename for database from sysdatabases table
	Detach database
	Rename transaction log file

INPUTS:
	@vtDbName sysname - the database to detach and re-attach
OUTPUTS:
	@iErr int as RETURN - non-zero value indicates failure

MODIFICATION HISTORY
DATE		PERSON		REASON
----		------		-----------------------------------------
dd/mm/yyyy	Who		what, why


*************************************************************************/
	/* PASSED PARAMETERS */
	@vtDbName sysname
AS

BEGIN -- procedure
	DECLARE @vtProcName sysname
	DECLARE @vtMsg varchar(255)
	DECLARE @iErr int
	DECLARE @iCnt int
	DECLARE @vtDBPath nvarchar(260)
	DECLARE @vtLogPath nvarchar(260)
	DECLARE @vtLogName nvarchar(128)
	DECLARE @vtSQL nvarchar(1000)
	DECLARE @vtParm nvarchar(1000)
	DECLARE @vtCmd nvarchar(1000)
	DECLARE @vtFDate nvarchar(12)
	DECLARE @dtLastBkp datetime
	-- initialise variables
	SET @vtProcName = 'usp_ReCreateTranLog'
	SET @iErr = 0
	SET @iCnt = 0
	SET @vtDBPath = ''
	SET @vtLogPath = ''
	SET @vtLogName = ''
	SET @vtSQL = ''
	SET @vtParm = ''
	SET @vtCmd = ''
	SET @vtFDate = ''
	SET @dtLastBkp = ''		
    -- make sure only 'sa' users execute this script
    IF Is_SrvRoleMember('sysadmin') = 1
	BEGIN -- user is sa
		-- check if database is a system database
		IF @vtDBName NOT IN ('master', 'msdb', 'tempdb', 'model')
		BEGIN -- not system database
			-- check if database exists
			SELECT @iCnt = dbid
			FROM master..sysdatabases
			WHERE name = @vtDbName
			IF @iCnt > 0
			BEGIN -- database found
				-- retrieve last backup date
				SELECT @dtLastBkp = Max(backup_finish_date)
				FROM msdb.dbo.backupset
				WHERE database_name = @vtDbName
					AND type = 'L'
				-- check if transaction log was backed up today
				IF DateDiff(dy, @dtLastBkp, GetDate()) = 0
				BEGIN -- transaction log backed up
					-- re-initialise count variable
					SET @iCnt = 0
					-- check for existing processes using database
					SELECT @iCnt = Count(sPro.spid)
					FROM master..sysprocesses sPro
						INNER JOIN master..sysdatabases sDb
							ON sPro.dbid = sDb.dbid
					WHERE sDb.name = @vtDbName
					-- if @iCnt is zero do the detach/attach
					IF @iCnt = 0
					BEGIN -- detach and re-attach
						-- create dynamic SQL to retrieve Log device name
						SET @vtSQL = N'SELECT @vtLogName = name FROM ' + @vtDbName 
						SET @vtSQL = @vtSQL + '.dbo.sysfiles1 WHERE FileID = 2'
						SET @vtParm = N'@vtLogName nvarchar(128) OUTPUT'
						-- execute dynamic SQL to retrieve Log device name
						EXEC sp_ExecuteSQL @vtSQL, @vtParm, @vtLogName OUTPUT
						-- create dynamic SQL to retrieve Log filename
						SET @vtSQL = N'SELECT @vtLogPath = filename FROM ' + @vtDbName 
						SET @vtSQL = @vtSQL + '.dbo.sysfiles1 WHERE FileID = 2'
						SET @vtParm = N'@vtLogPath nvarchar(260) OUTPUT'
						-- execute dynamic SQL to retrieve Log filename
						EXEC sp_ExecuteSQL @vtSQL, @vtParm, @vtLogPath OUTPUT
						-- create dynamic SQL to retrieve database filename
						SET @vtSQL = N'SELECT @vtDbPath = filename FROM ' + @vtDbName 
						SET @vtSQL = @vtSQL + '.dbo.sysfiles1 WHERE FileID = 1'
						SET @vtParm = N'@vtDbPath nvarchar(260) OUTPUT'
						-- execute dynamic SQL to retrieve database filename
						EXEC sp_ExecuteSQL @vtSQL, @vtParm, @vtDbPath OUTPUT
						-- trim trailing spaces
						SET @vtDbName = RTrim(@vtDbName)
						SET @vtDbPath = RTrim(@vtDbPath)
						SET @vtLogName = RTrim(@vtLogName)
						SET @vtLogPath = RTrim(@vtLogPath)
						-- build date string to append to existing log filename
						SET @vtFDate = Right('0000' + Cast(DatePart(yy, GetDate()) as varchar(4)), 4)
						SET @vtFDate = @vtFDate + Right('00' + Cast(DatePart(mm, GetDate()) as varchar(2)), 2)
						SET @vtFDate = @vtFDate + Right('00' + Cast(DatePart(dd, GetDate()) as varchar(2)), 2)
						SET @vtFDate = @vtFDate + Right('00' + Cast(DatePart(hh, GetDate()) as varchar(2)), 2)
						SET @vtFDate = @vtFDate + Right('00' + Cast(DatePart(mi, GetDate()) as varchar(2)), 2)				
						-- detach database
						EXEC @iErr = sp_Detach_db @vtDbName
						IF @iErr = 0
						BEGIN -- detach successful
							-- rename old log file
							SET @vtCmd = 'REN "' + @vtLogPath + '" ' + @vtLogName + '.' + @vtFDate
							EXEC @iErr = xp_CmdShell @vtCmd, no_output
							IF @iErr <> 0
							BEGIN -- rename failed
								-- build message
								SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
								SET @vtMsg = @vtMsg + 'Error renaming old transaction log for database ' + @vtDBName + '.'
								-- log message
								RAISERROR(@vtMsg, 18, 1) WITH LOG
							END -- rename failed
							-- re-attach database without tran log file
							-- if rename failed the existing tran log file will be used
							EXEC @iErr = sp_Attach_db @vtDbName, @vtDBPath
							IF @iErr <> 0
							BEGIN -- re-attach failed
								-- build message
								SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
								SET @vtMsg = @vtMsg + 'Error re-attaching database ' + @vtDBName + '.'
								-- log message
								RAISERROR(@vtMsg, 18, 1) WITH LOG
							END -- re-attach failed
						END -- detach successful
						ELSE
						BEGIN -- detach failed
							-- build message
							SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
							SET @vtMsg = @vtMsg + 'Error detaching database ' + @vtDBName + '.'
							-- log message
							RAISERROR(@vtMsg, 18, 1) WITH LOG
						END -- detach failed
					END -- detach and re-attach
					ELSE
					BEGIN -- database in use
						-- build message
						SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
						SET @vtMsg = @vtMsg + 'Database ' + @vtDBName + ' is in use. Detach cannot be performed.'
						-- log message
						RAISERROR(@vtMsg, 18, 1) WITH LOG
					END -- database in use
				END -- transaction log backed up
				ELSE
				BEGIN -- transaction log has not been backed up
					-- build message
					SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
					SET @vtMsg = @vtMsg + 'Database ' + @vtDBName + ' has not been backed up. Detach cannot be performed.'
					-- log message
					RAISERROR(@vtMsg, 18, 1) WITH LOG
				END -- transaction log has not been backed up	
			END -- database found
			ELSE
			BEGIN -- database name not found
				-- build message
				SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
				SET @vtMsg = @vtMsg + 'Database ' + @vtDBName + ' cannot be found in sysdatabases table. Detach cannot be performed.'
				-- log message
				RAISERROR(@vtMsg, 18, 1) WITH LOG
			END -- database name not found			
		END -- not system database
		ELSE
		BEGIN -- system database
			-- build message
			SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
			SET @vtMsg = @vtMsg + 'Database ' + @vtDBName + ' is a system database and cannot be detached.'
			-- log message
			RAISERROR(@vtMsg, 18, 1) WITH LOG
		END -- system database
	END -- user is sa
	ELSE
	BEGIN -- user is not sa
		-- build message
		SET @vtMsg = CAST(GetDate() as varchar(30)) + ': ' + @vtProcName + ' - '
		SET @vtMsg = @vtMsg + 'Database ' + @vtDBName + ' cannot be detached. User has insufficient access rights.'
		-- log message
		RAISERROR(@vtMsg, 20, 1) WITH LOG
	END -- user is not sa
END -- procedure



