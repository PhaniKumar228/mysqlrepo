CREATE TABLE [dbo].[BackupRetention](
	[Name] [varchar](128) NOT NULL,
	[BackupFlagFull] [varchar](1) NOT NULL,
	[BackupFlagDiff] [varchar](1) NOT NULL,
	[BackupFlagLog] [varchar](1)  NOT NULL,
	[RetentionPeriodType] [varchar](10) NOT NULL CONSTRAINT [DF_BackupRetention_RetentionPeriodType]  DEFAULT ('Day'),
	[RetentionPeriodFULL] [int] NOT NULL,
	[RetentionPeriodDIFF] [int] NOT NULL,
	[RetentionPeriodLOG] [int] NOT NULL,
	[RelocationType] [varchar](10) NOT NULL CONSTRAINT [DF_BackupRetention_RelocationType]  DEFAULT ('Copy'),
	[LocalDriveFull] [varchar](100)  NOT NULL,
	[LocalDriveDiff] [varchar](100)  NOT NULL,
	[LocalDriveLog] [varchar](100)  NOT NULL,
	[NetworkShareFull] [varchar](100)  NOT NULL,
	[NetworkShareDiff] [varchar](100)  NOT NULL,
	[NetworkShareLog] [varchar](100)  NOT NULL,
 CONSTRAINT [PK__BackupRetention] PRIMARY KEY NONCLUSTERED 
(
	[Name] ASC
)WITH (IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER TABLE [dbo].[BackupRetention]  
WITH CHECK ADD  CONSTRAINT [CK__BackupRetention__FullFlag] 
CHECK  (([BackupFlagFull]='N' OR [BackupFlagFull]='Y'))
GO
ALTER TABLE [dbo].[BackupRetention]  
WITH CHECK ADD  CONSTRAINT [CK__BackupRetention__DiffFlag] 
CHECK  (([BackupFlagDiff]='N' OR [BackupFlagDiff]='Y'))
GO
ALTER TABLE [dbo].[BackupRetention]  
WITH CHECK ADD  CONSTRAINT [CK__BackupRetention__LogFlag] 
CHECK  (([BackupFlagLog]='N' OR [BackupFlagLog]='Y'))
GO
ALTER TABLE [dbo].[BackupRetention]  
WITH CHECK ADD  CONSTRAINT [CK_BackupRetention_relocationtype] 
CHECK  (([RelocationType]='Move' OR [RelocationType]='Copy'))
GO
ALTER TABLE [dbo].[BackupRetention]  
WITH CHECK ADD  CONSTRAINT [CK_BackupRetention_RetentionPeriod] 
CHECK  (([RetentionPeriodType]='Hour' OR 
[RetentionPeriodType]='Day' OR 
[RetentionPeriodType]='Week' OR 
[RetentionPeriodType]='Month' OR 
[RetentionPeriodType]='Quarter' OR 
[RetentionPeriodType]='Year'))
GO

CREATE Procedure [dbo].[BackupAllDatabases] (
	@Type		VARCHAR(5) = 'FULL', 
	@database	VARCHAR(100) = null
)

AS

BEGIN

SET NOCOUNT ON

DECLARE	@sql						VARCHAR(1000),
		@sql2						VARCHAR(1000),
		@sql3						VARCHAR(1000),
		@sql4						VARCHAR(500),
		@LocalDrive					VARCHAR(100),
		@NetworkShare				VARCHAR(100),
		@Name 						VARCHAR(128),
		@RetentionPeriod			INT,
		@RetentionPeriodType		VARCHAR(5),
		@RelocationType				VARCHAR(10),
		@LastBackupToKeep			VARCHAR(8),
		@ID							INT,
		@MaxID						INT,
		@FileExtension				VARCHAR(40)	

-- Get all database names
	CREATE TABLE #DBName
		(
		ID						INT IDENTITY (1,1) ,
		Name					VARCHAR(128) not null ,
		RetentionPeriod			INT null,
		RetentionPeriodType		VARCHAR(10),
		RelocationType			VARCHAR(10),
		LocalDrive				VARCHAR(100),
		NetworkShare			VARCHAR(100)
		)

-- Determine if backup request is for all or a single database
	IF LEN(@database) > 2 
		BEGIN
			INSERT #DBName (Name)
			SELECT name
			FROM master..sysdatabases
			WHERE name = @database
		END
	ELSE
		BEGIN
			INSERT #DBName (Name)
			SELECT name
			FROM master..sysdatabases
		END	

	DELETE #DBNAME
/* Include any new databases in the backup
RetentionPeriodType is the way the retention period is measured valid values are 
Year, Quarter, Month, Day, Week, Hour
*/
	INSERT BackupRetention (Name, BackupFlagFull, BackupFlagDiff, BackupFlagLog, RetentionPeriodType, RetentionPeriodFull, RetentionPeriodDiff, RetentionPeriodLog, RelocationType, LocalDriveFull, LocalDriveDiff, LocalDriveLog, NetworkShareFull, NetworkShareDiff, NetworkShareLog)
	SELECT	#DBName.Name, 'Y', 'N', 'N', 'Day', '0','0', '0', 'Move', 'D:\Backup\Full\', 'D:\Backup\Diff\', 'D:\Backup\Log\', '\\xxxxx\xxxxxStageBackup\Full\', '\\xxxxx\xxxxxStageBackup\Diff\', '\\xxxxx\xxxxxStageBackup\Log\'
	FROM	#DBName
			LEFT OUTER JOIN BackupRetention ON BackupRetention.Name = #DBName.Name
	WHERE	BackupRetention.Name is null
	
-- Remove any non-existant databases
IF Len(@Database) < 2
	BEGIN
		DELETE	BackupRetention
		WHERE not exists
			(
			select	*
			from	#DBName
			where	#DBName.Name = BackupRetention.Name
			)
	END

	CREATE TABLE #ExistingBackups
		(
		Name VARCHAR(128) ,
		ID INT IDENTITY (1,1)
		)
	
-- loop through databases and set retention period for the type of backup being performed

	BEGIN
		IF UPPER(@Type) = 'DIFF' 
			BEGIN	
				INSERT	#DBName (Name, RetentionPeriod, RetentionPeriodType, RelocationType, LocalDrive, NetworkShare)
					SELECT Name, RetentionPeriodDiff, RetentionPeriodType, RelocationType, LocalDriveDiff, NetworkShareDiff
					FROM BackupRetention
					WHERE BackupFlagDiff = 'Y'
			END
		ELSE IF UPPER(@Type) = 'FULL' 
			BEGIN	
				INSERT	#DBName (Name, RetentionPeriod, RetentionPeriodType, RelocationType, LocalDrive, NetworkShare)
				SELECT Name, RetentionPeriodFull, RetentionPeriodType, RelocationType, LocalDriveFull, NetworkShareFull
				FROM BackupRetention
				WHERE BackupFlagFull = 'Y'
			END
		ELSE 
			BEGIN	
				INSERT	#DBName (Name, RetentionPeriod, RetentionPeriodType, RelocationType, LocalDrive, NetworkShare)
				SELECT Name, RetentionPeriodLog, RetentionPeriodType, RelocationType, LocalDriveLog, NetworkShareLog	
				FROM BackupRetention
				WHERE BackupFlagLog = 'Y'
			END
	IF Len(@database) > 2
		BEGIN
			DELETE FROM #DBNAME
			WHERE Name <> @database
		END
	END
	
	SELECT @MaxID = max(ID)
	FROM #DBName
	
	SET @ID = 0

	WHILE @ID < @MaxID
		BEGIN
			-- Get next database to backup
			SELECT	@ID = MIN(ID) FROM #DBName WHERE ID > @ID
			
			SELECT 	@Name = Name, @RetentionPeriod = RetentionPeriod, @RetentionPeriodType = RetentionPeriodType, @RelocationType = RelocationType,
					@LocalDrive = LocalDrive, @NetworkShare = NetworkShare
			FROM	#DBName
			WHERE	ID = @ID

			-- Ensure #Existingbackups table is empty
			DELETE	#ExistingBackups

			-- Delete old backups	
			SELECT 	@sql = 'dir /B ' + @NetworkShare
			SELECT	@sql = @sql + @Name + '_' + @Type + '*.*'
		
		INSERT	#ExistingBackups exec master..xp_cmdshell @sql

		IF EXISTS (SELECT * FROM #ExistingBackups WHERE Name like '%File Not Found%')
		DELETE #ExistingBackups

		-- Determine last backup to be kept by process
		CREATE TABLE #LastBackupToKeep
			(
				LastBackupToKeep		VARCHAR(100)
			)

		SET @Sql4 = 'SELECT convert(varchar(8), DATEADD(' + @RetentionPeriodType + ', -' + CAST(@RetentionPeriod AS VARCHAR(5)) + ',  + getdate()), 112)'

		INSERT INTO #LastBackupToKeep (LastBackupToKeep)
		EXEC (@Sql4)


		SELECT	@LastBackupToKeep = LastBackupToKeep
		FROM #LastBackupToKeep

		DROP TABLE #LastBackupToKeep

		DELETE	#ExistingBackups WHERE Name > @Name + '_' + @Type + '_' + @LastBackupToKeep

		-- Loop  round and delete all out of date backups
		DECLARE	@eID	INT,
				@eMaxID	INT,
				@eName	VARCHAR(128)
		

		SELECT	@eID = 0,
				@eMaxID = coalesce(max(ID), 0)
		FROM	#ExistingBackups
		
		WHILE @eID < @eMaxID
			BEGIN
				SELECT 	@eID = MIN(ID) FROM #ExistingBackups WHERE ID > @eID
				SELECT	@eName = Name FROM #ExistingBackups WHERE ID = @eID

				-- Delete old files from local and network drive as needed		

				SELECT @sql2 = 'del ' + @NetworkShare + @eName
				EXEC master..xp_cmdShell @sql2

				IF UPPER(@RelocationType) = 'COPY'
					BEGIN
						SELECT @sql = 'del ' + @LocalDrive + @eName
						EXEC master..xp_cmdshell @sql
					END

			END

		DELETE	#ExistingBackups

		/*
		 Set the file extension for the different type of backups.  This method creates a new differential backup each time.  
		 adjust convert function when type = Diff if you only want to keep the latest differential backup
		*/
		SELECT @FileExtension = CASE
									WHEN UPPER(@Type) = 'FULL' THEN '.BAK'
									WHEN UPPER(@Type) = 'DIFF' THEN LEFT(replace(convert(varchar(8),getdate(),108),':',''), 2) + '00' + '.DIF'
									ELSE LEFT(replace(convert(varchar(8),getdate(),108),':',''), 4) + '.TRN'
									END

		-- Perform the backup
		SELECT @sql = @LocalDrive + @Name + '_' + @Type + '_' 
					+ convert(varchar(8),getdate(),112) + @FileExtension

	BEGIN
		IF UPPER(@Type) = 'FULL'
			BEGIN
				BACKUP DATABASE @Name
				TO DISK = @sql 
			END
		ELSE IF UPPER(@Type) = 'DIFF'
			BEGIN
				BACKUP DATABASE @Name
				TO DISK = @sql WITH differential	
			END	
		ELSE
			BEGIN
				BACKUP LOG @Name
				TO DISK = @sql
			END
		-- Move/copy file from the local disk to the network share 
		SELECT @sql3 = @RelocationType + ' ' + @Sql + ' ' + @NetworkShare 
		exec master..xp_cmdshell @sql3
		
	END

END


END


