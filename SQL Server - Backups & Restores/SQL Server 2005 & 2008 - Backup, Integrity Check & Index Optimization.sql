/*
SQL Server 2005 & 2008 - Backup, Integrity Check & Index Optimization

I have made a solution for backup, integrity check and index optimization in SQL Server 2005 and SQL Server 2008. 
The solution is based on stored procedures, functions, sqlcmd and SQL Server Agent jobs. 

Dynamic selection of databases, e.g. USER_DATABASES.

Database state check. If a database is not online the procedure logs the database state and continues to the next database.

Robust error handling and logging. If an error occurs the procedure logs the error and continues to the next database or 
index. In the end the job reports failure. Information about all commands are logged with start time, command text, 
command output and end time.

Database backup features. Full, differential and transaction log backups. Automatic creation of backup directories. 
Backup file names with the name of the instance, the name of the database, backup type, date and time. 
Verification of backups. Deletion of old backup files.

EXECUTE dbo.DatabaseBackup
@Databases = 'USER_DATABASES',
@Directory = 'C:\Backup',
@BackupType = 'FULL',
@Verify = 'Y',
@CleanupTime = 24


Database integrity check features.

EXECUTE dbo.DatabaseIntegrityCheck
@Databases = 'USER_DATABASES' 


Dynamic index optimization. Rebuild indexes online or offline, reorganize indexes, update statistics, reorganize indexes and update statistics or do nothing based on fragmentation level and lob existence.

EXECUTE dbo.IndexOptimize
@Databases = 'USER_DATABASES',
@FragmentationHigh_LOB = 'INDEX_REBUILD_OFFLINE',
@FragmentationHigh_NonLOB = 'INDEX_REBUILD_ONLINE',
@FragmentationMedium_LOB = 'INDEX_REORGANIZE',
@FragmentationMedium_NonLOB = 'INDEX_REORGANIZE',
@FragmentationLow_LOB = 'NOTHING',
@FragmentationLow_NonLOB = 'NOTHING',
@FragmentationLevel1 = 5,
@FragmentationLevel2 = 30,
@PageCountLevel = 1000

Please see the code and the documentation.


*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[DatabaseSelect] (@DatabaseList nvarchar(max))

RETURNS @Database TABLE(DatabaseName nvarchar(max) NOT NULL)

AS

BEGIN

----------------------------------------------------------------------------------------------------
--// Declare variables                                                                          //--
----------------------------------------------------------------------------------------------------

  DECLARE @DatabaseItem nvarchar(max)
  DECLARE @Position int

  DECLARE @CurrentID int
  DECLARE @CurrentDatabaseName nvarchar(max)
  DECLARE @CurrentDatabaseStatus bit

  DECLARE @Database01 TABLE (DatabaseName nvarchar(max))

  DECLARE @Database02 TABLE (ID int IDENTITY PRIMARY KEY,
                             DatabaseName nvarchar(max),
                             DatabaseStatus bit,
                             Completed bit)

  DECLARE @Database03 TABLE (DatabaseName nvarchar(max),
                             DatabaseStatus bit)

  DECLARE @Sysdatabases TABLE (DatabaseName nvarchar(max))

----------------------------------------------------------------------------------------------------
--// Split input string into elements                                                           //--
----------------------------------------------------------------------------------------------------

  SET @DatabaseList = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@DatabaseList,' ',''),'[',''),']',''),'''',''),'"','')

  WHILE CHARINDEX(',,',@DatabaseList) > 0 SET @DatabaseList = REPLACE(@DatabaseList,',,',',')

  IF RIGHT(@DatabaseList,1) = ',' SET @DatabaseList = LEFT(@DatabaseList,LEN(@DatabaseList) - 1)
  IF LEFT(@DatabaseList,1) = ','  SET @DatabaseList = RIGHT(@DatabaseList,LEN(@DatabaseList) - 1)

  WHILE LEN(@DatabaseList) > 0
  BEGIN
    SET @Position = CHARINDEX(',', @DatabaseList)
    IF @Position = 0
    BEGIN
      SET @DatabaseItem = @DatabaseList
      SET @DatabaseList = ''
    END
    ELSE
    BEGIN
      SET @DatabaseItem = LEFT(@DatabaseList, @Position - 1)
      SET @DatabaseList = RIGHT(@DatabaseList, LEN(@DatabaseList) - @Position)
    END
    IF @DatabaseItem <> '-' INSERT INTO @Database01 (DatabaseName) VALUES(@DatabaseItem)
  END

----------------------------------------------------------------------------------------------------
--// Handle database exclusions                                                                 //--
----------------------------------------------------------------------------------------------------

  INSERT INTO @Database02 (DatabaseName, DatabaseStatus, Completed)
  SELECT DISTINCT DatabaseName = CASE WHEN DatabaseName LIKE '-%' THEN RIGHT(DatabaseName,LEN(DatabaseName) - 1) ELSE DatabaseName END,
                  DatabaseStatus = CASE WHEN DatabaseName LIKE '-%' THEN 0 ELSE 1 END,
                  0 AS Completed
  FROM @Database01

----------------------------------------------------------------------------------------------------
--// Resolve elements                                                                           //--
----------------------------------------------------------------------------------------------------

  WHILE EXISTS (SELECT * FROM @Database02 WHERE Completed = 0)
  BEGIN

    SELECT TOP 1 @CurrentID = ID,
                 @CurrentDatabaseName = DatabaseName,
                 @CurrentDatabaseStatus = DatabaseStatus
    FROM @Database02
    WHERE Completed = 0
    ORDER BY ID ASC

    IF @CurrentDatabaseName = 'SYSTEM_DATABASES'
    BEGIN
      INSERT INTO @Database03 (DatabaseName, DatabaseStatus)
      SELECT [name], @CurrentDatabaseStatus
      FROM sys.databases
      WHERE database_id <= 4
    END
    ELSE IF @CurrentDatabaseName = 'USER_DATABASES'
    BEGIN
      INSERT INTO @Database03 (DatabaseName, DatabaseStatus)
      SELECT [name], @CurrentDatabaseStatus
      FROM sys.databases
      WHERE database_id > 4
    END
    ELSE IF CHARINDEX('%',@CurrentDatabaseName) > 0
    BEGIN
      INSERT INTO @Database03 (DatabaseName, DatabaseStatus)
      SELECT [name], @CurrentDatabaseStatus
      FROM sys.databases
      WHERE [name] LIKE REPLACE(@CurrentDatabaseName,'_','[_]')
    END
    ELSE
    BEGIN
      INSERT INTO @Database03 (DatabaseName, DatabaseStatus)
      SELECT [name], @CurrentDatabaseStatus
      FROM sys.databases
      WHERE [name] = @CurrentDatabaseName
    END

    UPDATE @Database02
    SET Completed = 1
    WHERE ID = @CurrentID

    SET @CurrentID = NULL
    SET @CurrentDatabaseName = NULL
    SET @CurrentDatabaseStatus = NULL

  END

----------------------------------------------------------------------------------------------------
--// Handle tempdb and database snapshots                                                       //--
----------------------------------------------------------------------------------------------------

  INSERT INTO @Sysdatabases (DatabaseName)
  SELECT [name]
  FROM sys.databases
  WHERE [name] <> 'tempdb'
  AND source_database_id IS NULL

----------------------------------------------------------------------------------------------------
--// Return results                                                                             //--
----------------------------------------------------------------------------------------------------

  INSERT INTO @Database (DatabaseName)
  SELECT DatabaseName
  FROM @Sysdatabases
  INTERSECT
  SELECT DatabaseName
  FROM @Database03
  WHERE DatabaseStatus = 1
  EXCEPT
  SELECT DatabaseName
  FROM @Database03
  WHERE DatabaseStatus = 0

  RETURN

----------------------------------------------------------------------------------------------------

END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CommandExecute]

@Command nvarchar(max),
@Comment nvarchar(max),
@Mode int

AS

SET NOCOUNT ON

SET LOCK_TIMEOUT 3600000

----------------------------------------------------------------------------------------------------
--// Declare variables                                                                          //--
----------------------------------------------------------------------------------------------------

DECLARE @StartMessage nvarchar(max)
DECLARE @EndMessage nvarchar(max)
DECLARE @ErrorMessage nvarchar(max)

DECLARE @StartTime datetime
DECLARE @EndTime datetime

DECLARE @Error int

SET @Error = 0

----------------------------------------------------------------------------------------------------
--// Check input parameters                                                                     //--
----------------------------------------------------------------------------------------------------

IF @Command IS NULL OR @Command = ''
BEGIN
  SET @ErrorMessage = 'The value for parameter @Command is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @Comment IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @Comment is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @Mode NOT IN(1,2) OR @Mode IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @Mode is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check error variable                                                                       //--
----------------------------------------------------------------------------------------------------

IF @Error <> 0 GOTO ReturnCode

----------------------------------------------------------------------------------------------------
--// Log initial information                                                                    //--
----------------------------------------------------------------------------------------------------

SET @StartTime = CONVERT(datetime,CONVERT(varchar,GETDATE(),120),120)

SET @StartMessage = 'DateTime: ' + CONVERT(nvarchar,@StartTime,120) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Command: ' + @Command
IF @Comment <> '' SET @StartMessage = @StartMessage + CHAR(13) + CHAR(10) + 'Comment: ' + @Comment
SET @StartMessage = REPLACE(@StartMessage,'%','%%')
RAISERROR(@StartMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
--// Execute command                                                                            //--
----------------------------------------------------------------------------------------------------

IF @Mode = 1
BEGIN
  EXECUTE(@Command)
  SET @Error = @@ERROR
END

IF @Mode = 2
BEGIN
  BEGIN TRY
    EXECUTE(@Command)
  END TRY
  BEGIN CATCH
    SET @Error = ERROR_NUMBER()
    SET @ErrorMessage = 'Msg ' + CAST(ERROR_NUMBER() AS nvarchar) + ', ' + ISNULL(ERROR_MESSAGE(),'')
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  END CATCH
END

----------------------------------------------------------------------------------------------------
--// Log completing information                                                                 //--
----------------------------------------------------------------------------------------------------

SET @EndTime = CONVERT(datetime,CONVERT(varchar,GETDATE(),120),120)

SET @EndMessage = 'Outcome: ' + CASE WHEN @Error = 0 THEN 'Succeeded' ELSE 'Failed' END + CHAR(13) + CHAR(10)
SET @EndMessage = @EndMessage + 'Duration: ' + CASE WHEN DATEDIFF(ss,@StartTime, @EndTime)/(24*3600) > 0 THEN CAST(DATEDIFF(ss,@StartTime, @EndTime)/(24*3600) AS nvarchar) + '.' ELSE '' END + CONVERT(nvarchar,@EndTime - @StartTime,108) + CHAR(13) + CHAR(10)
SET @EndMessage = @EndMessage + 'DateTime: ' + CONVERT(nvarchar,@EndTime,120) + CHAR(13) + CHAR(10)
SET @EndMessage = REPLACE(@EndMessage,'%','%%')
RAISERROR(@EndMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
--// Return code                                                                                //--
----------------------------------------------------------------------------------------------------

ReturnCode:

RETURN @Error

----------------------------------------------------------------------------------------------------
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DatabaseBackup]

@Databases nvarchar(max),
@Directory nvarchar(max),
@BackupType nvarchar(max),
@Verify nvarchar(max) = 'N',
@CleanupTime int = NULL,
@Compress nvarchar(max) = 'N',
@CopyOnly nvarchar(max) = 'N',
@ChangeBackupType nvarchar(max) = 'N'

AS

SET NOCOUNT ON

----------------------------------------------------------------------------------------------------
--// Declare variables                                                                          //--
----------------------------------------------------------------------------------------------------

DECLARE @StartMessage nvarchar(max)
DECLARE @EndMessage nvarchar(max)
DECLARE @DatabaseMessage nvarchar(max)
DECLARE @ErrorMessage nvarchar(max)

DECLARE @CurrentID int
DECLARE @CurrentDatabase nvarchar(max)
DECLARE @CurrentBackupType nvarchar(max)
DECLARE @CurrentFileExtension nvarchar(max)
DECLARE @CurrentDifferentialLSN numeric(25,0)
DECLARE @CurrentLogLSN numeric(25,0)
DECLARE @CurrentDatabaseFS nvarchar(max)
DECLARE @CurrentDirectory nvarchar(max)
DECLARE @CurrentDate datetime
DECLARE @CurrentFileName nvarchar(max)
DECLARE @CurrentFilePath nvarchar(max)
DECLARE @CurrentCleanupDate datetime

DECLARE @CurrentCommand01 nvarchar(max)
DECLARE @CurrentCommand02 nvarchar(max)
DECLARE @CurrentCommand03 nvarchar(max)
DECLARE @CurrentCommand04 nvarchar(max)

DECLARE @CurrentCommandOutput01 int
DECLARE @CurrentCommandOutput02 int
DECLARE @CurrentCommandOutput03 int
DECLARE @CurrentCommandOutput04 int

DECLARE @DirectoryInfoCommand nvarchar(max)

DECLARE @DirectoryInfo TABLE (FileExists bit,
                              FileIsADirectory bit,
                              ParentDirectoryExists bit)

DECLARE @tmpDatabases TABLE (ID int IDENTITY PRIMARY KEY,
                             DatabaseName nvarchar(max),
                             Completed bit)

DECLARE @Error int

SET @Error = 0

----------------------------------------------------------------------------------------------------
--// Log initial information                                                                    //--
----------------------------------------------------------------------------------------------------

SET @StartMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Server: ' + CAST(SERVERPROPERTY('ServerName') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Procedure: ' + QUOTENAME(DB_NAME(DB_ID())) + '.' + QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID)) + '.' + QUOTENAME(OBJECT_NAME(@@PROCID)) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Parameters: @Databases = ' + ISNULL('''' + REPLACE(@Databases,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @Directory = ' + ISNULL('''' + REPLACE(@Directory,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @BackupType = ' + ISNULL('''' + REPLACE(@BackupType,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @Verify = ' + ISNULL('''' + REPLACE(@Verify,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + ', @Compress = ' + ISNULL('''' + REPLACE(@Compress,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @CopyOnly = ' + ISNULL('''' + REPLACE(@CopyOnly,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @ChangeBackupType = ' + ISNULL('''' + REPLACE(@ChangeBackupType,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + CHAR(13) + CHAR(10)
SET @StartMessage = REPLACE(@StartMessage,'%','%%')
RAISERROR(@StartMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
--// Select databases                                                                           //--
----------------------------------------------------------------------------------------------------

IF @Databases IS NULL OR @Databases = ''
BEGIN
  SET @ErrorMessage = 'The value for parameter @Databases is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

INSERT INTO @tmpDatabases (DatabaseName, Completed)
SELECT DatabaseName AS DatabaseName,
       0 AS Completed
FROM dbo.DatabaseSelect (@Databases)
ORDER BY DatabaseName ASC

IF @@ERROR <> 0 OR (@@ROWCOUNT = 0 AND @Databases <> 'USER_DATABASES')
BEGIN
  SET @ErrorMessage = 'Error selecting databases.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check directory                                                                            //--
----------------------------------------------------------------------------------------------------

IF NOT (@Directory LIKE '_:' OR @Directory LIKE '_:\%' OR @Directory LIKE '\\%\%') OR @Directory LIKE '%\' OR @Directory IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @Directory is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

SET @DirectoryInfoCommand = 'EXECUTE xp_fileexist N''' + REPLACE(@Directory,'''','''''') + ''''

INSERT INTO @DirectoryInfo (FileExists, FileIsADirectory, ParentDirectoryExists)
EXECUTE(@DirectoryInfoCommand)

IF NOT EXISTS (SELECT * FROM @DirectoryInfo WHERE FileExists = 0 AND FileIsADirectory = 1 AND ParentDirectoryExists = 1)
BEGIN
  SET @ErrorMessage = 'The directory does not exist.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check input parameters                                                                     //--
----------------------------------------------------------------------------------------------------

IF @BackupType NOT IN ('FULL','DIFF','LOG') OR @BackupType IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @BackupType is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @Verify NOT IN ('Y','N') OR @Verify IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @Verify is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @CleanupTime < 0
BEGIN
  SET @ErrorMessage = 'The value for parameter @CleanupTime is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @Compress NOT IN ('Y','N') OR @Compress IS NULL OR (@Compress = 'Y' AND NOT (SERVERPROPERTY('EngineEdition') = 3 AND CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar), CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar)) - 1) AS int) >= 10))
BEGIN
  SET @ErrorMessage = 'The value for parameter @Compress is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @CopyOnly NOT IN ('Y','N') OR @CopyOnly IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @CopyOnly is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @ChangeBackupType NOT IN ('Y','N') OR @ChangeBackupType IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @ChangeBackupType is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check error variable                                                                       //--
----------------------------------------------------------------------------------------------------

IF @Error <> 0 GOTO Logging

----------------------------------------------------------------------------------------------------
--// Execute backup commands                                                                    //--
----------------------------------------------------------------------------------------------------

WHILE EXISTS (SELECT * FROM @tmpDatabases WHERE Completed = 0)
BEGIN

  SELECT TOP 1 @CurrentID = ID,
               @CurrentDatabase = DatabaseName
  FROM @tmpDatabases
  WHERE Completed = 0
  ORDER BY ID ASC

  SELECT @CurrentDifferentialLSN = differential_base_lsn
  FROM sys.master_files
  WHERE database_id = DB_ID(@CurrentDatabase)
  AND [type] = 0
  AND [file_id] = 1

  SELECT @CurrentLogLSN = last_log_backup_lsn
  FROM sys.database_recovery_status
  WHERE database_id = DB_ID(@CurrentDatabase)

  SET @CurrentBackupType = @BackupType

  IF @ChangeBackupType = 'Y'
  BEGIN
    IF @CurrentBackupType = 'LOG' AND DATABASEPROPERTYEX(@CurrentDatabase,'recovery') <> 'SIMPLE' AND @CurrentLogLSN IS NULL AND @CurrentDatabase <> 'master'
    BEGIN
      SET @CurrentBackupType = 'DIFF'
    END
    IF @CurrentBackupType = 'DIFF' AND @CurrentDifferentialLSN IS NULL AND @CurrentDatabase <> 'master'
    BEGIN
      SET @CurrentBackupType = 'FULL'
    END
  END

  -- Set database message
  SET @DatabaseMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Database: ' + QUOTENAME(@CurrentDatabase) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Status: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabase,'status') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Recovery model: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabase,'recovery') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Differential base LSN: ' + ISNULL(CAST(@CurrentDifferentialLSN AS nvarchar),'NULL') + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Last log backup LSN: ' + ISNULL(CAST(@CurrentLogLSN AS nvarchar),'NULL') + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = REPLACE(@DatabaseMessage,'%','%%')
  RAISERROR(@DatabaseMessage,10,1) WITH NOWAIT

  IF DATABASEPROPERTYEX(@CurrentDatabase,'status') = 'ONLINE'
  AND NOT (@CurrentBackupType = 'LOG' AND (DATABASEPROPERTYEX(@CurrentDatabase,'recovery') = 'SIMPLE' OR @CurrentLogLSN IS NULL))
  AND NOT (@CurrentBackupType = 'DIFF' AND @CurrentDifferentialLSN IS NULL)
  AND NOT (@CurrentBackupType IN('DIFF','LOG') AND @CurrentDatabase = 'master')
  BEGIN

    -- Set variables
    SET @CurrentDate = GETDATE()
    SET @CurrentCleanupDate = DATEADD(hh,-(@CleanupTime),GETDATE())

    SET @CurrentDatabaseFS = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@CurrentDatabase,'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|',''),' ','')
    IF @CurrentDatabaseFS = '' SET @CurrentDatabaseFS = '_'

    SELECT @CurrentFileExtension = CASE
    WHEN @CurrentBackupType = 'FULL' THEN 'bak'
    WHEN @CurrentBackupType = 'DIFF' THEN 'bak'
    WHEN @CurrentBackupType = 'LOG' THEN 'trn'
    END

    SET @CurrentFileName = REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') + '_' + @CurrentDatabaseFS + '_' + UPPER(@CurrentBackupType) + '_' + REPLACE(REPLACE(REPLACE((CONVERT(nvarchar,@CurrentDate,120)),'-',''),' ','_'),':','') + '.' + @CurrentFileExtension

    SET @CurrentDirectory = @Directory + '\' + REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') + '\' + @CurrentDatabaseFS + '\' + UPPER(@CurrentBackupType)

    SET @CurrentFilePath = @CurrentDirectory + '\' + @CurrentFileName

    -- Create directory
    SET @CurrentCommand01 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N''' + REPLACE(@CurrentDirectory,'''','''''') + ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'
    EXECUTE @CurrentCommandOutput01 = [dbo].[CommandExecute] @CurrentCommand01, '', 1
    SET @Error = @@ERROR
    IF @Error <> 0 SET @CurrentCommandOutput01 = @Error

    -- Perform a backup
    IF @CurrentCommandOutput01 = 0
    BEGIN
      SELECT @CurrentCommand02 = CASE
      WHEN @CurrentBackupType = 'FULL' THEN 'BACKUP DATABASE ' + QUOTENAME(@CurrentDatabase) + ' TO DISK = ''' + REPLACE(@CurrentFilePath,'''','''''') + ''' WITH CHECKSUM'
      WHEN @CurrentBackupType = 'DIFF' THEN 'BACKUP DATABASE ' + QUOTENAME(@CurrentDatabase) + ' TO DISK = ''' + REPLACE(@CurrentFilePath,'''','''''') + ''' WITH CHECKSUM, DIFFERENTIAL'
      WHEN @CurrentBackupType = 'LOG' THEN 'BACKUP LOG ' + QUOTENAME(@CurrentDatabase) + ' TO DISK = ''' + REPLACE(@CurrentFilePath,'''','''''') + ''' WITH CHECKSUM'
      END
      IF @Compress = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COMPRESSION'
      IF @Compress = 'N' AND CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar), CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar)) - 1) AS int) >= 10 SET @CurrentCommand02 = @CurrentCommand02 + ', NO_COMPRESSION'
      IF @CopyOnly = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COPY_ONLY'

      EXECUTE @CurrentCommandOutput02 = [dbo].[CommandExecute] @CurrentCommand02, '', 1
      SET @Error = @@ERROR
      IF @Error <> 0 SET @CurrentCommandOutput02 = @Error
    END

    -- Verify the backup
    IF @CurrentCommandOutput02 = 0 AND @Verify = 'Y'
    BEGIN
      SET @CurrentCommand03 = 'RESTORE VERIFYONLY FROM DISK = ''' + REPLACE(@CurrentFilePath,'''','''''') + ''' WITH CHECKSUM'
      EXECUTE @CurrentCommandOutput03 = [dbo].[CommandExecute] @CurrentCommand03, '', 1
      SET @Error = @@ERROR
      IF @Error <> 0 SET @CurrentCommandOutput03 = @Error
    END

    -- Delete old backup files
    IF (@CurrentCommandOutput02 = 0 AND @Verify = 'N' AND @CurrentCleanupDate IS NOT NULL)
    OR (@CurrentCommandOutput02 = 0 AND @Verify = 'Y' AND @CurrentCommandOutput03 = 0 AND @CurrentCleanupDate IS NOT NULL)
    BEGIN
      SET @CurrentCommand04 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_delete_file 0, N''' + REPLACE(@CurrentDirectory,'''','''''') + ''', ''' + @CurrentFileExtension + ''', ''' + CONVERT(nvarchar(19),@CurrentCleanupDate,126) + ''' IF @ReturnCode <> 0 RAISERROR(''Error deleting files.'', 16, 1)'
      EXECUTE @CurrentCommandOutput04 = [dbo].[CommandExecute] @CurrentCommand04, '', 1
      SET @Error = @@ERROR
      IF @Error <> 0 SET @CurrentCommandOutput04 = @Error
    END

  END

  -- Update that the database is completed
  UPDATE @tmpDatabases
  SET Completed = 1
  WHERE ID = @CurrentID

  -- Clear variables
  SET @CurrentID = NULL
  SET @CurrentDatabase = NULL
  SET @CurrentBackupType = NULL
  SET @CurrentFileExtension = NULL
  SET @CurrentDifferentialLSN = NULL
  SET @CurrentLogLSN = NULL
  SET @CurrentDatabaseFS = NULL
  SET @CurrentDirectory = NULL
  SET @CurrentDate = NULL
  SET @CurrentFileName = NULL
  SET @CurrentFilePath = NULL
  SET @CurrentCleanupDate = NULL

  SET @CurrentCommand01 = NULL
  SET @CurrentCommand02 = NULL
  SET @CurrentCommand03 = NULL
  SET @CurrentCommand04 = NULL

  SET @CurrentCommandOutput01 = NULL
  SET @CurrentCommandOutput02 = NULL
  SET @CurrentCommandOutput03 = NULL
  SET @CurrentCommandOutput04 = NULL

END

----------------------------------------------------------------------------------------------------
--// Log completing information                                                                 //--
----------------------------------------------------------------------------------------------------

Logging:
SET @EndMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120)
SET @EndMessage = REPLACE(@EndMessage,'%','%%')
RAISERROR(@EndMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DatabaseIntegrityCheck]

@Databases nvarchar(max),
@PhysicalOnly nvarchar(max) = 'N',
@NoIndex nvarchar(max) = 'N'

AS

SET NOCOUNT ON

----------------------------------------------------------------------------------------------------
--// Declare variables                                                                          //--
----------------------------------------------------------------------------------------------------

DECLARE @StartMessage nvarchar(max)
DECLARE @EndMessage nvarchar(max)
DECLARE @DatabaseMessage nvarchar(max)
DECLARE @ErrorMessage nvarchar(max)

DECLARE @CurrentID int
DECLARE @CurrentDatabase nvarchar(max)

DECLARE @CurrentCommand01 nvarchar(max)

DECLARE @CurrentCommandOutput01 int

DECLARE @tmpDatabases TABLE (ID int IDENTITY PRIMARY KEY,
                             DatabaseName nvarchar(max),
                             Completed bit)

DECLARE @Error int

SET @Error = 0

----------------------------------------------------------------------------------------------------
--// Log initial information                                                                    //--
----------------------------------------------------------------------------------------------------

SET @StartMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Server: ' + CAST(SERVERPROPERTY('ServerName') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Procedure: ' + QUOTENAME(DB_NAME(DB_ID())) + '.' + QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID)) + '.' + QUOTENAME(OBJECT_NAME(@@PROCID)) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Parameters: @Databases = ' + ISNULL('''' + REPLACE(@Databases,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @PhysicalOnly = ' + ISNULL('''' + REPLACE(@PhysicalOnly,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @NoIndex = ' + ISNULL('''' + REPLACE(@NoIndex,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + CHAR(13) + CHAR(10)
SET @StartMessage = REPLACE(@StartMessage,'%','%%')
RAISERROR(@StartMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
--// Select databases                                                                           //--
----------------------------------------------------------------------------------------------------

IF @Databases IS NULL OR @Databases = ''
BEGIN
  SET @ErrorMessage = 'The value for parameter @Databases is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

INSERT INTO @tmpDatabases (DatabaseName, Completed)
SELECT DatabaseName AS DatabaseName,
       0 AS Completed
FROM dbo.DatabaseSelect (@Databases)
ORDER BY DatabaseName ASC

IF @@ERROR <> 0 OR (@@ROWCOUNT = 0 AND @Databases <> 'USER_DATABASES')
BEGIN
  SET @ErrorMessage = 'Error selecting databases.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check input parameters                                                                     //--
----------------------------------------------------------------------------------------------------

IF @PhysicalOnly NOT IN ('Y','N') OR @PhysicalOnly IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @PhysicalOnly is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @NoIndex NOT IN ('Y','N') OR @NoIndex IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @NoIndex is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check error variable                                                                       //--
----------------------------------------------------------------------------------------------------

IF @Error <> 0 GOTO Logging

----------------------------------------------------------------------------------------------------
--// Execute commands                                                                           //--
----------------------------------------------------------------------------------------------------

WHILE EXISTS (SELECT * FROM @tmpDatabases WHERE Completed = 0)
BEGIN

  SELECT TOP 1 @CurrentID = ID,
               @CurrentDatabase = DatabaseName
  FROM @tmpDatabases
  WHERE Completed = 0
  ORDER BY ID ASC

  -- Set database message
  SET @DatabaseMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Database: ' + QUOTENAME(@CurrentDatabase) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Status: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabase,'status') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = REPLACE(@DatabaseMessage,'%','%%')
  RAISERROR(@DatabaseMessage,10,1) WITH NOWAIT

  IF DATABASEPROPERTYEX(@CurrentDatabase,'status') = 'ONLINE'
  BEGIN
    SET @CurrentCommand01 = 'DBCC CHECKDB (' + QUOTENAME(@CurrentDatabase)
    IF @NoIndex = 'Y' SET @CurrentCommand01 = @CurrentCommand01 + ', NOINDEX'
    SET @CurrentCommand01 = @CurrentCommand01 + ') WITH NO_INFOMSGS, ALL_ERRORMSGS'
    IF @PhysicalOnly = 'N' SET @CurrentCommand01 = @CurrentCommand01 + ', DATA_PURITY'
    IF @PhysicalOnly = 'Y' SET @CurrentCommand01 = @CurrentCommand01 + ', PHYSICAL_ONLY'

    EXECUTE @CurrentCommandOutput01 = [dbo].[CommandExecute] @CurrentCommand01, '', 1
    SET @Error = @@ERROR
    IF @Error <> 0 SET @CurrentCommandOutput01 = @Error
  END

  -- Update that the database is completed
  UPDATE @tmpDatabases
  SET Completed = 1
  WHERE ID = @CurrentID

  -- Clear variables
  SET @CurrentID = NULL
  SET @CurrentDatabase = NULL

  SET @CurrentCommand01 = NULL

  SET @CurrentCommandOutput01 = NULL

END

----------------------------------------------------------------------------------------------------
--// Log completing information                                                                 //--
----------------------------------------------------------------------------------------------------

Logging:
SET @EndMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120)
SET @EndMessage = REPLACE(@EndMessage,'%','%%')
RAISERROR(@EndMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[IndexOptimize]

@Databases nvarchar(max),
@FragmentationHigh_LOB nvarchar(max) = 'INDEX_REBUILD_OFFLINE',
@FragmentationHigh_NonLOB nvarchar(max) = 'INDEX_REBUILD_OFFLINE',
@FragmentationMedium_LOB nvarchar(max) = 'INDEX_REORGANIZE',
@FragmentationMedium_NonLOB nvarchar(max) = 'INDEX_REORGANIZE',
@FragmentationLow_LOB nvarchar(max) = 'NOTHING',
@FragmentationLow_NonLOB nvarchar(max) = 'NOTHING',
@FragmentationLevel1 tinyint = 5,
@FragmentationLevel2 tinyint = 30,
@PageCountLevel int = 1000,
@SortInTempdb nvarchar(max) = 'N',
@MaxDOP tinyint = NULL,
@FillFactor tinyint = NULL,
@LOBCompaction nvarchar(max) = 'Y',
@StatisticsSample tinyint = NULL

AS

SET NOCOUNT ON

SET LOCK_TIMEOUT 3600000

----------------------------------------------------------------------------------------------------
--// Declare variables                                                                          //--
----------------------------------------------------------------------------------------------------

DECLARE @StartMessage nvarchar(max)
DECLARE @EndMessage nvarchar(max)
DECLARE @DatabaseMessage nvarchar(max)
DECLARE @ErrorMessage nvarchar(max)

DECLARE @CurrentID int
DECLARE @CurrentDatabase nvarchar(max)

DECLARE @CurrentCommandSelect01 nvarchar(max)
DECLARE @CurrentCommandSelect02 nvarchar(max)
DECLARE @CurrentCommandSelect03 nvarchar(max)

DECLARE @CurrentCommand01 nvarchar(max)
DECLARE @CurrentCommand02 nvarchar(max)

DECLARE @CurrentCommandOutput01 int
DECLARE @CurrentCommandOutput02 int

DECLARE @CurrentIxID int
DECLARE @CurrentSchemaID int
DECLARE @CurrentSchemaName nvarchar(max)
DECLARE @CurrentObjectID int
DECLARE @CurrentObjectName nvarchar(max)
DECLARE @CurrentIndexID int
DECLARE @CurrentIndexName nvarchar(max)
DECLARE @CurrentIndexType int
DECLARE @CurrentIndexExists bit
DECLARE @CurrentIsLOB bit
DECLARE @CurrentFragmentationLevel float
DECLARE @CurrentPageCount bigint
DECLARE @CurrentAction nvarchar(max)
DECLARE @CurrentComment nvarchar(max)

DECLARE @tmpDatabases TABLE (ID int IDENTITY PRIMARY KEY,
                             DatabaseName nvarchar(max),
                             Completed bit)

DECLARE @tmpIndexes TABLE (IxID int IDENTITY PRIMARY KEY,
                           SchemaID int,
                           SchemaName nvarchar(max),
                           ObjectID int,
                           ObjectName nvarchar(max),
                           IndexID int,
                           IndexName nvarchar(max),
                           IndexType int,
                           Completed bit)

DECLARE @tmpIndexExists TABLE ([Count] int)

DECLARE @tmpIsLOB TABLE ([Count] int)

DECLARE @Actions TABLE ([Action] nvarchar(max))

INSERT INTO @Actions([Action]) VALUES('INDEX_REBUILD_ONLINE')
INSERT INTO @Actions([Action]) VALUES('INDEX_REBUILD_OFFLINE')
INSERT INTO @Actions([Action]) VALUES('INDEX_REORGANIZE')
INSERT INTO @Actions([Action]) VALUES('STATISTICS_UPDATE')
INSERT INTO @Actions([Action]) VALUES('INDEX_REORGANIZE_STATISTICS_UPDATE')
INSERT INTO @Actions([Action]) VALUES('NOTHING')

DECLARE @Error int

SET @Error = 0

----------------------------------------------------------------------------------------------------
--// Log initial information                                                                    //--
----------------------------------------------------------------------------------------------------

SET @StartMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Server: ' + CAST(SERVERPROPERTY('ServerName') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS nvarchar) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Procedure: ' + QUOTENAME(DB_NAME(DB_ID())) + '.' + QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID)) + '.' + QUOTENAME(OBJECT_NAME(@@PROCID)) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Parameters: @Databases = ' + ISNULL('''' + REPLACE(@Databases,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationHigh_LOB = ' + ISNULL('''' + REPLACE(@FragmentationHigh_LOB,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationHigh_NonLOB = ' + ISNULL('''' + REPLACE(@FragmentationHigh_NonLOB,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationMedium_LOB = ' + ISNULL('''' + REPLACE(@FragmentationMedium_LOB,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationMedium_NonLOB = ' + ISNULL('''' + REPLACE(@FragmentationMedium_NonLOB,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationLow_LOB = ' + ISNULL('''' + REPLACE(@FragmentationLow_LOB,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationLow_NonLOB = ' + ISNULL('''' + REPLACE(@FragmentationLow_NonLOB,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @FragmentationLevel1 = ' + ISNULL(CAST(@FragmentationLevel1 AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + ', @FragmentationLevel2 = ' + ISNULL(CAST(@FragmentationLevel2 AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + ', @PageCountLevel = ' + ISNULL(CAST(@PageCountLevel AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + ', @SortInTempdb = ' + ISNULL('''' + REPLACE(@SortInTempdb,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @MaxDOP = ' + ISNULL(CAST(@MaxDOP AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + ', @FillFactor = ' + ISNULL(CAST(@FillFactor AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + ', @LOBCompaction = ' + ISNULL('''' + REPLACE(@LOBCompaction,'''','''''') + '''','NULL')
SET @StartMessage = @StartMessage + ', @StatisticsSample = ' + ISNULL(CAST(@StatisticsSample AS nvarchar),'NULL')
SET @StartMessage = @StartMessage + CHAR(13) + CHAR(10)
SET @StartMessage = REPLACE(@StartMessage,'%','%%')
RAISERROR(@StartMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
--// Select databases                                                                           //--
----------------------------------------------------------------------------------------------------

IF @Databases IS NULL OR @Databases = ''
BEGIN
  SET @ErrorMessage = 'The value for parameter @Databases is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

INSERT INTO @tmpDatabases (DatabaseName, Completed)
SELECT DatabaseName AS DatabaseName,
       0 AS Completed
FROM dbo.DatabaseSelect (@Databases)
ORDER BY DatabaseName ASC

IF @@ERROR <> 0 OR (@@ROWCOUNT = 0 AND @Databases <> 'USER_DATABASES')
BEGIN
  SET @ErrorMessage = 'Error selecting databases.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check input parameters                                                                     //--
----------------------------------------------------------------------------------------------------

IF @FragmentationHigh_LOB NOT IN(SELECT [Action] FROM @Actions WHERE [Action] <> 'INDEX_REBUILD_ONLINE')
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationHigh_LOB is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationHigh_NonLOB NOT IN(SELECT [Action] FROM @Actions WHERE [Action] <> 'INDEX_REBUILD_ONLINE' OR SERVERPROPERTY('EngineEdition') = 3)
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationHigh_NonLOB is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationMedium_LOB NOT IN(SELECT [Action] FROM @Actions WHERE [Action] <> 'INDEX_REBUILD_ONLINE')
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationMedium_LOB is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationMedium_NonLOB NOT IN(SELECT [Action] FROM @Actions WHERE [Action] <> 'INDEX_REBUILD_ONLINE' OR SERVERPROPERTY('EngineEdition') = 3)
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationMedium_NonLOB is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationLow_LOB NOT IN(SELECT [Action] FROM @Actions WHERE [Action] <> 'INDEX_REBUILD_ONLINE')
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationLow_LOB is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationLow_NonLOB NOT IN(SELECT [Action] FROM @Actions WHERE [Action] <> 'INDEX_REBUILD_ONLINE' OR SERVERPROPERTY('EngineEdition') = 3)
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationLow_NonLOB is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationLevel1 <= 0 OR @FragmentationLevel1 >= 100 OR @FragmentationLevel1 >= @FragmentationLevel2 OR @FragmentationLevel1 IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationLevel1 is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FragmentationLevel2 <= 0 OR @FragmentationLevel2 >= 100 OR @FragmentationLevel2 <= @FragmentationLevel1 OR @FragmentationLevel2 IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @FragmentationLevel2 is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @PageCountLevel < 0 OR @PageCountLevel IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @PageCountLevel is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @SortInTempdb NOT IN('Y','N') OR @SortInTempdb IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @SortInTempdb is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @MaxDOP < 0 OR @MaxDOP > 64
BEGIN
  SET @ErrorMessage = 'The value for parameter @MaxDOP is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @FillFactor <= 0 OR @FillFactor > 100
BEGIN
  SET @ErrorMessage = 'The value for parameter @FillFactor is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @LOBCompaction NOT IN('Y','N') OR @LOBCompaction IS NULL
BEGIN
  SET @ErrorMessage = 'The value for parameter @LOBCompaction is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

IF @StatisticsSample <= 0 OR @StatisticsSample  > 100
BEGIN
  SET @ErrorMessage = 'The value for parameter @StatisticsSample  is not supported.' + CHAR(13) + CHAR(10)
  RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
  SET @Error = @@ERROR
END

----------------------------------------------------------------------------------------------------
--// Check error variable                                                                       //--
----------------------------------------------------------------------------------------------------

IF @Error <> 0 GOTO Logging

----------------------------------------------------------------------------------------------------
--// Execute commands                                                                           //--
----------------------------------------------------------------------------------------------------

WHILE EXISTS (SELECT * FROM @tmpDatabases WHERE Completed = 0)
BEGIN

  SELECT TOP 1 @CurrentID = ID,
               @CurrentDatabase = DatabaseName
  FROM @tmpDatabases
  WHERE Completed = 0
  ORDER BY ID ASC

  -- Set database message
  SET @DatabaseMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Database: ' + QUOTENAME(@CurrentDatabase) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Status: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabase,'status') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = @DatabaseMessage + 'Updateability: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabase,'updateability') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @DatabaseMessage = REPLACE(@DatabaseMessage,'%','%%')
  RAISERROR(@DatabaseMessage,10,1) WITH NOWAIT

  IF DATABASEPROPERTYEX(@CurrentDatabase,'status') = 'ONLINE' AND DATABASEPROPERTYEX(@CurrentDatabase,'updateability') = 'READ_WRITE'
  BEGIN

    -- Select indexes in the current database
    SET @CurrentCommandSelect01 = 'SELECT ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[schema_id], ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[name], ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[object_id], ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[name], ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.index_id, ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[name], ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[type], 0 FROM ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.objects ON ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[object_id] = ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[object_id] INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas ON ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[schema_id] = ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[schema_id] WHERE ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[type] = ''U'' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.is_ms_shipped = 0 AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[type] IN(1,2) AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.is_disabled = 0 AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.is_hypothetical = 0 ORDER BY ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[schema_id] ASC, ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[object_id] ASC, ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.index_id ASC'

    INSERT INTO @tmpIndexes (SchemaID, SchemaName, ObjectID, ObjectName, IndexID, IndexName, IndexType, Completed)
    EXECUTE(@CurrentCommandSelect01)

    WHILE EXISTS (SELECT * FROM @tmpIndexes WHERE Completed = 0)
    BEGIN

      SELECT TOP 1 @CurrentIxID = IxID,
                   @CurrentSchemaID = SchemaID,
                   @CurrentSchemaName = SchemaName,
                   @CurrentObjectID = ObjectID,
                   @CurrentObjectName = ObjectName,
                   @CurrentIndexID = IndexID,
                   @CurrentIndexName = IndexName,
                   @CurrentIndexType = IndexType
      FROM @tmpIndexes
      WHERE Completed = 0
      ORDER BY IxID ASC

      -- Does the index exist?
      SET @CurrentCommandSelect02 = 'SELECT COUNT(*) FROM ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.objects ON ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[object_id] = ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[object_id] INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas ON ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[schema_id] = ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[schema_id] WHERE ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[type] = ''U'' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.is_ms_shipped = 0 AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[type] IN(1,2) AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.is_disabled = 0 AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.is_hypothetical = 0 AND ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[schema_id] = ' + CAST(@CurrentSchemaID AS nvarchar) + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.schemas.[name] = N' + QUOTENAME(@CurrentSchemaName,'''') + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[object_id] = ' + CAST(@CurrentObjectID AS nvarchar) + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.objects.[name] = N' + QUOTENAME(@CurrentObjectName,'''') + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.index_id = ' + CAST(@CurrentIndexID AS nvarchar) + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[name] = N' + QUOTENAME(@CurrentIndexName,'''') + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.indexes.[type] = ' + CAST(@CurrentIndexType AS nvarchar)

      INSERT INTO @tmpIndexExists ([Count])
      EXECUTE(@CurrentCommandSelect02)

      IF (SELECT [Count] FROM @tmpIndexExists) > 0 BEGIN SET @CurrentIndexExists = 1 END ELSE BEGIN SET @CurrentIndexExists = 0 END

      IF @CurrentIndexExists = 0 GOTO NoAction

      -- Does the index contain a LOB?
      IF @CurrentIndexType = 1 SET @CurrentCommandSelect03 = 'SELECT COUNT(*) FROM ' + QUOTENAME(@CurrentDatabase) + '.sys.columns INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.types ON ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.system_type_id = ' + QUOTENAME(@CurrentDatabase) + '.sys.types.user_type_id WHERE ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.[object_id] = ' + CAST(@CurrentObjectID AS nvarchar) + ' AND (' + QUOTENAME(@CurrentDatabase) + '.sys.types.name IN(''xml'',''image'',''text'',''ntext'') OR (' + QUOTENAME(@CurrentDatabase) + '.sys.types.name IN(''varchar'',''nvarchar'',''varbinary'') AND ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.max_length = -1))'
      IF @CurrentIndexType = 2 SET @CurrentCommandSelect03 = 'SELECT COUNT(*) FROM ' + QUOTENAME(@CurrentDatabase) + '.sys.index_columns INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.columns ON ' + QUOTENAME(@CurrentDatabase) + '.sys.index_columns.[object_id] = ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.[object_id] AND ' + QUOTENAME(@CurrentDatabase) + '.sys.index_columns.column_id = ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.column_id INNER JOIN ' + QUOTENAME(@CurrentDatabase) + '.sys.types ON ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.system_type_id = ' + QUOTENAME(@CurrentDatabase) + '.sys.types.user_type_id WHERE ' + QUOTENAME(@CurrentDatabase) + '.sys.index_columns.[object_id] = ' + CAST(@CurrentObjectID AS nvarchar) + ' AND ' + QUOTENAME(@CurrentDatabase) + '.sys.index_columns.index_id = ' + CAST(@CurrentIndexID AS nvarchar) + ' AND (' + QUOTENAME(@CurrentDatabase) + '.sys.types.[name] IN(''xml'',''image'',''text'',''ntext'') OR (' + QUOTENAME(@CurrentDatabase) + '.sys.types.[name] IN(''varchar'',''nvarchar'',''varbinary'') AND ' + QUOTENAME(@CurrentDatabase) + '.sys.columns.max_length = -1))'

      INSERT INTO @tmpIsLOB ([Count])
      EXECUTE(@CurrentCommandSelect03)

      IF (SELECT [Count] FROM @tmpIsLOB) > 0 BEGIN SET @CurrentIsLOB = 1 END ELSE BEGIN SET @CurrentIsLOB = 0 END

      -- Is the index fragmented?
      SELECT @CurrentFragmentationLevel = avg_fragmentation_in_percent,
             @CurrentPageCount = page_count
      FROM sys.dm_db_index_physical_stats(DB_ID(@CurrentDatabase), @CurrentObjectID, @CurrentIndexID, NULL, 'LIMITED')
      WHERE alloc_unit_type_desc = 'IN_ROW_DATA'
      AND index_level = 0
      ORDER BY partition_number ASC
      SET @Error = @@ERROR
      IF @Error = 1222
      BEGIN
        SET @ErrorMessage = 'The object sys.dm_db_index_physical_stats is locked for the index ' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + '.' + QUOTENAME(@CurrentIndexName) + '.' + CHAR(13) + CHAR(10)
        SET @ErrorMessage = REPLACE(@ErrorMessage,'%','%%')
        RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
        GOTO NoAction
      END

      -- Decide action
      SELECT @CurrentAction = CASE
      WHEN @CurrentIsLOB = 1 AND @CurrentFragmentationLevel >= @FragmentationLevel2 AND @CurrentPageCount >= @PageCountLevel THEN @FragmentationHigh_LOB
      WHEN @CurrentIsLOB = 0 AND @CurrentFragmentationLevel >= @FragmentationLevel2 AND @CurrentPageCount >= @PageCountLevel THEN @FragmentationHigh_NonLOB
      WHEN @CurrentIsLOB = 1 AND @CurrentFragmentationLevel >= @FragmentationLevel1 AND @CurrentFragmentationLevel < @FragmentationLevel2 AND @CurrentPageCount >= @PageCountLevel THEN @FragmentationMedium_LOB
      WHEN @CurrentIsLOB = 0 AND @CurrentFragmentationLevel >= @FragmentationLevel1 AND @CurrentFragmentationLevel < @FragmentationLevel2 AND @CurrentPageCount >= @PageCountLevel THEN @FragmentationMedium_NonLOB
      WHEN @CurrentIsLOB = 1 AND (@CurrentFragmentationLevel < @FragmentationLevel1 OR @CurrentPageCount < @PageCountLevel) THEN @FragmentationLow_LOB
      WHEN @CurrentIsLOB = 0 AND (@CurrentFragmentationLevel < @FragmentationLevel1 OR @CurrentPageCount < @PageCountLevel) THEN @FragmentationLow_NonLOB
      END

      -- Create comment
      SET @CurrentComment = 'IndexType: ' + CASE WHEN @CurrentIndexType = 1 THEN 'Clustered' WHEN @CurrentIndexType = 2 THEN 'NonClustered' ELSE 'N/A' END + ', '
      SET @CurrentComment = @CurrentComment + 'LOB: ' + CASE WHEN @CurrentIsLOB = 1 THEN 'Yes' WHEN @CurrentIsLOB = 0 THEN 'No' ELSE 'N/A' END + ', '
      SET @CurrentComment = @CurrentComment + 'PageCount: ' + CAST(@CurrentPageCount AS nvarchar) + ', '
      SET @CurrentComment = @CurrentComment + 'Fragmentation: ' + CAST(@CurrentFragmentationLevel AS nvarchar)

      IF @CurrentAction IN('INDEX_REBUILD_ONLINE','INDEX_REBUILD_OFFLINE','INDEX_REORGANIZE','INDEX_REORGANIZE_STATISTICS_UPDATE')
      BEGIN
        SET @CurrentCommand01 = 'ALTER INDEX ' + QUOTENAME(@CurrentIndexName) + ' ON ' + QUOTENAME(@CurrentDatabase) + '.' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName)

        IF @CurrentAction IN('INDEX_REBUILD_ONLINE','INDEX_REBUILD_OFFLINE')
        BEGIN
          SET @CurrentCommand01 = @CurrentCommand01 + ' REBUILD WITH ('
          IF @SortInTempdb = 'Y' SET @CurrentCommand01 = @CurrentCommand01 + 'SORT_IN_TEMPDB = ON'
          IF @SortInTempdb = 'N' SET @CurrentCommand01 = @CurrentCommand01 + 'SORT_IN_TEMPDB = OFF'
          IF @CurrentAction = 'INDEX_REBUILD_ONLINE' SET @CurrentCommand01 = @CurrentCommand01 + ', ONLINE = ON'
          IF @CurrentAction = 'INDEX_REBUILD_OFFLINE' SET @CurrentCommand01 = @CurrentCommand01 + ', ONLINE = OFF'
          IF @MaxDOP IS NOT NULL SET @CurrentCommand01 = @CurrentCommand01 + ', MAXDOP = ' + CAST(@MaxDOP AS nvarchar)
          IF @FillFactor IS NOT NULL SET @CurrentCommand01 = @CurrentCommand01 + ', FILLFACTOR = ' + CAST(@FillFactor AS nvarchar)
          SET @CurrentCommand01 = @CurrentCommand01 + ')'
        END

        IF @CurrentAction IN('INDEX_REORGANIZE','INDEX_REORGANIZE_STATISTICS_UPDATE')
        BEGIN
          SET @CurrentCommand01 = @CurrentCommand01 + ' REORGANIZE WITH ('
          IF @LOBCompaction = 'Y' SET @CurrentCommand01 = @CurrentCommand01 + 'LOB_COMPACTION = ON'
          IF @LOBCompaction = 'N' SET @CurrentCommand01 = @CurrentCommand01 + 'LOB_COMPACTION = OFF'
          SET @CurrentCommand01 = @CurrentCommand01 + ')'
        END

        EXECUTE @CurrentCommandOutput01 = [dbo].[CommandExecute] @CurrentCommand01, @CurrentComment, 2
        SET @Error = @@ERROR
        IF @Error <> 0 SET @CurrentCommandOutput01 = @Error
      END

      IF @CurrentAction IN('INDEX_REORGANIZE_STATISTICS_UPDATE','STATISTICS_UPDATE')
      BEGIN
        SET @CurrentCommand02 = 'UPDATE STATISTICS ' + QUOTENAME(@CurrentDatabase) + '.' + QUOTENAME(@CurrentSchemaName) + '.' + QUOTENAME(@CurrentObjectName) + ' ' + QUOTENAME(@CurrentIndexName)
        IF @StatisticsSample = 100 SET @CurrentCommand02 = @CurrentCommand02 + ' WITH FULLSCAN'
        IF @StatisticsSample IS NOT NULL AND @StatisticsSample <> 100 SET @CurrentCommand02 = @CurrentCommand02 + ' WITH SAMPLE ' + CAST(@StatisticsSample AS nvarchar) + ' PERCENT'

        EXECUTE @CurrentCommandOutput02 = [dbo].[CommandExecute] @CurrentCommand02, '', 2
        SET @Error = @@ERROR
        IF @Error <> 0 SET @CurrentCommandOutput02 = @Error
      END

      NoAction:

      -- Update that the index is completed
      UPDATE @tmpIndexes
      SET Completed = 1
      WHERE IxID = @CurrentIxID

      -- Clear variables
      SET @CurrentCommandSelect02 = NULL
      SET @CurrentCommandSelect03 = NULL

      SET @CurrentCommand01 = NULL
      SET @CurrentCommand02 = NULL

      SET @CurrentCommandOutput01 = NULL
      SET @CurrentCommandOutput02 = NULL

      SET @CurrentIxID = NULL
      SET @CurrentSchemaID = NULL
      SET @CurrentSchemaName = NULL
      SET @CurrentObjectID = NULL
      SET @CurrentObjectName = NULL
      SET @CurrentIndexID = NULL
      SET @CurrentIndexName = NULL
      SET @CurrentIndexType = NULL
      SET @CurrentIndexExists = NULL
      SET @CurrentIsLOB = NULL
      SET @CurrentFragmentationLevel = NULL
      SET @CurrentPageCount = NULL
      SET @CurrentAction = NULL
      SET @CurrentComment = NULL

      DELETE FROM @tmpIndexExists
      DELETE FROM @tmpIsLOB

    END

  END

  -- Update that the database is completed
  UPDATE @tmpDatabases
  SET Completed = 1
  WHERE ID = @CurrentID

  -- Clear variables
  SET @CurrentID = NULL
  SET @CurrentDatabase = NULL

  SET @CurrentCommandSelect01 = NULL

  DELETE FROM @tmpIndexes

END

----------------------------------------------------------------------------------------------------
--// Log completing information                                                                 //--
----------------------------------------------------------------------------------------------------

Logging:
SET @EndMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120)
SET @EndMessage = REPLACE(@EndMessage,'%','%%')
RAISERROR(@EndMessage,10,1) WITH NOWAIT

----------------------------------------------------------------------------------------------------
GO

