/*
Automatically Restore Backup Files for SQL 2005

Last year I made a script which will automatically restore multiple backup files in 1 go which is only available 
for sql 2000. What this script does is the same thing but for sql version 2005
*/

/*************************************************************
--=LIMITATIONS=--
- This script is tested for backup files ".BAK" only 
-- SCRIPT NEEDS TO BE ALTERED IF BACKUP EXTENSION IS NOT ".BAK"
*************************************************************/
SET NOCOUNT ON
--Drop Tables if it exists in the database
if exists (select name from sysobjects where name = 'migration_lester')
DROP TABLE migration_lester
if exists (select name from sysobjects where name = 'header_lester')
DROP TABLE header_lester
if exists (select name from sysobjects where name = 'cmdshell_lester')
DROP TABLE cmdshell_lester

--Create Tables 
--(cmdshell_lester table for the cmdshell command)
--(migration_lester table for the restore filelistonly command)
--(header_lester table for the restore headeronly command)
CREATE TABLE cmdshell_lester( fentry varchar(1000))

CREATE TABLE migration_lester(
 LogicalName nvarchar(128),
 PhysicalName nvarchar(260),
 type char(1),
 FileGroupName nvarchar(128),
 size numeric(20,0),
 MaxSize numeric(20,0),
 FileID bigint, 
 CreateLSN numeric(25,0),
 DropLSN numeric(25,0),
 UniqueID uniqueidentifier,
 ReadOnlyLSN numeric(25,0),
 ReadWriteLSN numeric(25,0),
 BackupSizeInBytes bigint,
 SourceBlockSize int,
 FileGroupID int,
 LogGroupGUID uniqueidentifier,
 DifferentialBaseLSN numeric(25,0),
 DifferentialBaseGUID uniqueidentifier,
 IsReadOnly bit,
 IsPresent bit
)

CREATE TABLE header_lester (
 BackupName nvarchar(128) ,
 BackupDescription nvarchar(255),
 BackupType smallint,
 ExpirationDate datetime,
 Compressed tinyint,
 Position smallint,
 DeviceType tinyint,
 UserName nvarchar(128),
 ServerName nvarchar(128),
 DatabaseName nvarchar(128),
 DatabaseVersion int,
 DatabaseCreationDate datetime,
 BackupSize numeric(20,0),
 FirstLsn numeric(25,0),
 LastLsn numeric(25,0),
 CheckpointLsn numeric(25,0),
 DifferentialBackupLsn numeric(25,0),
 BackupStartDate datetime,
 BackupFinishDate datetime,
 SortOrder smallint,
 CodePage smallint,
 UnicodeLocaleid int,
 UnicodeComparisonStyle int,
 CompatibilityLevel tinyint,
 SoftwareVendorId int,
 SoftwareVersionMajor int,
 SoftwareVersionMinor int,
 SoftwareVersionBuild int,
 MachineName nvarchar(128),
 Flags int,
 BindingId uniqueidentifier,
 RecoveryForkId uniqueidentifier,
 Collation nvarchar(128), 
 FamilyGUID uniqueidentifier,
 HasBulkLoggedData bit,
 IsSnapshot bit,
 IsReadOnly bit, 
 IsSingleUser bit, 
 HasBackupChecksums bit,
 IsDamaged Int, 
 BeginsLogChain bit, 
 HAsIncompleteMetaData bit, 
 IsForceOFfline bit, 
 IsCopyOnly bit, 
 FirstRecoveryForkID uniqueidentifier,
 ForkPointLSN numeric(25,0),
 RecoveryModel nvarchar(60),
 DifferentialBaseLSN numeric(25,0),
 DifferentialBAseGUID uniqueidentifier,
 BackupTypeDescription nvarchar(60),
 BackupSetGUID uniqueidentifier
)

--Declare Variables
DECLARE @path varchar(1024),@restore varchar(1024)
DECLARE @restoredb varchar(2000),@extension varchar(1024),@newpath_ldf varchar(1024)
DECLARE @pathension varchar(1024),@newpath_mdf varchar(1024),@header varchar(500)

--Set Values to the variables
SET @newpath_mdf = 'C:\' --new path wherein you will put the mdf
SET @newpath_ldf = 'D:\' --new path wherein you will put the ldf
SET @path = 'D:\' --Path of the Backup File
SET @extension = 'BAK'
SET @pathension = 'dir /OD '+@Path+'*.'+@Extension

--Insert the value of the command shell to the table
INSERT INTO cmdshell_lester exec master..xp_cmdshell @pathension
--Delete non backup files data, delete null values
DELETE FROM cmdshell_lester WHERE FEntry NOT LIKE '%.BAK%' 
DELETE FROM cmdshell_lester WHERE FEntry is NULL
--Create a cursor to scan all backup files needed to generate the restore script
DECLARE @migrate varchar(1024)
DECLARE migrate CURSOR FOR
select substring(FEntry,40,50) as 'FEntry'from cmdshell_lester 
OPEN migrate
FETCH NEXT FROM migrate INTO @migrate
WHILE (@@FETCH_STATUS = 0)BEGIN
--Added feature to get the dbname of the backup file
SET @header = 'RESTORE HEADERONLY FROM DISK = '+''''+@path+@Migrate+''''
INSERT INTO header_lester exec (@header)
--Get the names of the mdf and ldf
set @restore = 'RESTORE FILELISTONLY FROM DISK = '+''''+@path+@migrate+''''
INSERT INTO migration_lester EXEC (@restore)
--Update value of the table to add the new path+mdf/ldf names
UPDATE migration_lester SET physicalname = reverse(physicalname)
UPDATE migration_lester SET physicalname = 
substring(physicalname,1,charindex('\',physicalname)-1)

UPDATE migration_lester SET physicalname = @newpath_mdf+reverse(physicalname) where type = 'D'
UPDATE migration_lester SET physicalname = @newpath_ldf+reverse(physicalname) where type = 'L'
--@@@@@@@@@@@@@@@@@@@@
--Set a value to the @restoredb variable to hold the restore database script
IF (select count(*) from migration_lester) = 2
BEGIN
SET @restoredb = 'RESTORE DATABASE '+(select top 1 DatabaseName from header_lester)
+' FROM DISK = '+ ''''+@path+@migrate+''''+' WITH MOVE '+''''
+(select logicalname from migration_lester where type = 'D')+''''
+' TO '+ ''''+( select physicalname from migration_lester WHERE physicalname like '%mdf%')
+''''+', MOVE '+''''+ (select logicalname from migration_lester where type = 'L')
+''''+' TO '+''''+( select physicalname from migration_lester 
WHERE physicalname like '%ldf%')+''''
print (@restoredb) 
END

IF (select count(*) from migration_lester) > 2
BEGIN
SET @restoredb = 
'RESTORE DATABASE '+(select top 1 DatabaseName from header_lester)+
' FROM DISK = '+''''+@path+@migrate+''''+'WITH MOVE '
DECLARE @multiple varchar(1000),@physical varchar(1000)
DECLARE multiple CURSOR FOR
Select logicalname,physicalname from migration_lester
OPEN multiple
FETCH NEXT FROM multiple INTO @multiple,@physical
WHILE(@@FETCH_STATUS = 0)
BEGIN
SET @restoredb=@restoredb+''''+@multiple+''''+' TO '+''''+@physical+''''+','+'MOVE '+''
FETCH NEXT FROM multiple INTO @multiple,@physical
END
CLOSE multiple
DEALLOCATE multiple
SET @restoredb = substring(@restoredb,1,len(@restoredb)-5)
print (@restoredb)
END

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Run print @restoredb first to view the databases to be restored
-- When ready, run exec (@restoredb)
-- EXEC (@restoredb)

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--Clear data inside the tables to give way for the next 
--set of informations to be put in the @restoredb variable 
TRUNCATE TABLE migration_lester
TRUNCATE TABLE header_lester
FETCH NEXT FROM migrate INTO @migrate
END
CLOSE migrate
DEALLOCATE migrate
--@@@@@@@@@@@@@@@@@@@

--Drop Tables 
DROP TABLE migration_lester
DROP TABLE cmdshell_lester
DROP TABLE header_lester




