use master
go

-- Switch_Database.sql

-- usage from Query Analyzer:

-- 	Switch_Database.sql

-- Note: Because of OS level file name changes this script must be run on 
-- the physial server where the SQL database files reside.  Script currently 
-- pointing to databases on the E:\... drive.

-- Note: Prior to integration of replication/snapshot delivery, in order to 
-- demonstrate this script, manually put "staging_snap_b" on the server.

-- Note: Bug when exporting from one SQL DB to another SQL DB.  The default
-- locations are not used and DBs end up on c:\ drive when they should be on
-- the e:\ drive.  Create DB first and THEN export to it from Northwind DB.

-- This process also creates the DB names consistently with "LOG" and "DATA"
-- embedded in the name.  This script was written for this format.

-- Description:

-- This script is used to drop the old database from yesterday's load.
-- It is then used to switch the active database to become tomorrow's old DB,
-- and then to switch the new database to become the "active" database.

-- The "staging_snap" database is always the "active" database.
-- The "staging_snap_a" database is always the "old" database from yesterday.
-- The "staging_snap_b" database is always the "new" database from replication/snapshot.

-- In addition to changing the database name, we must also change the logical 
-- names and the physical names of the database files at the Operating System 
-- (OS) level.  In order to accomplish these tasks the databases must be in 
-- single_user mode, and/or detached.

-- Single-user mode only allows one user to be connected at a time.  Any users 
-- who are connected when this script is run will have un-committed transactions 
-- rolled back and they will be disconnected from the database.  User connections 
-- will have to then be re-established in order to access the newly named databases.

-- The following messages are returned upon successful completion of script:
--
-- Nonqualified transactions are being rolled back. Estimated rollback completion: 100%. (OPTIONAL)
-- Deleting database file 'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_a_Log.ldf'.
-- Deleting database file 'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_a_Data.mdf'.
-- The database name 'staging_snap_a' has been set.
-- The database name 'staging_snap' has been set.
-- The file name 'staging_snap_data' has been set.
-- The file name 'staging_snap_log' has been set.
-- The file name 'staging_snap_a_data' has been set.
-- The file name 'staging_snap_a_log' has been set.
-- The CREATE DATABASE process is allocating 1.00 MB on disk 'staging_snap_b_Data'.
-- The CREATE DATABASE process is allocating 1.00 MB on disk 'staging_snap_b_Log'.
-- 
-- Switch_Database.sql has completed


-- Put databases involved in name switch into single_user mode

ALTER DATABASE "staging_snap"
SET single_user WITH ROLLBACK IMMEDIATE
GO

ALTER DATABASE "staging_snap_a"
SET single_user WITH ROLLBACK IMMEDIATE
GO

ALTER DATABASE "staging_snap_b"
SET single_user WITH ROLLBACK IMMEDIATE
GO

-- delete the old database from yesterday's load
-- Note: you will not see these DBs in Query Analyzer when in single_user mode

DROP DATABASE staging_snap_a
GO

-- rename the active database to become the new "old" database
-- this will not be deleted until tomorrow (just in case)

exec sp_renamedb "staging_snap", "staging_snap_a"
GO

-- rename the new database (from replication/snapshot) to become the active database

exec sp_renamedb "staging_snap_b", "staging_snap"
GO

-- detach databases to rename files in the Operating System

exec sp_detach_db "staging_snap_a", "true"
GO

exec sp_detach_db "staging_snap", "true"
GO

-- rename files for staging_snap (active) to staging_snap_a (old)
-- rename files for staging_snap_b (new) to staging_snap (active)

xp_cmdshell 'ren E:\Progra~1\Micros~1\MSSQL\Data\staging_snap_Data.mdf staging_snap_a_Data.mdf', NO_OUTPUT
GO
xp_cmdshell 'ren E:\Progra~1\Micros~1\MSSQL\Data\staging_snap_Log.ldf staging_snap_a_Log.ldf', NO_OUTPUT
GO
xp_cmdshell 'ren E:\Progra~1\Micros~1\MSSQL\Data\staging_snap_b_Data.mdf staging_snap_Data.mdf', NO_OUTPUT
GO
xp_cmdshell 'ren E:\Progra~1\Micros~1\MSSQL\Data\staging_snap_b_Log.ldf staging_snap_Log.ldf', NO_OUTPUT
GO

-- Attach the databases with syntax to define physical file names

exec sp_attach_db @dbname = N'staging_snap',
   @filename1 = N'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_Data.mdf', 
   @filename2 = N'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_Log.ldf'

exec sp_attach_db @dbname = N'staging_snap_a',
   @filename1 = N'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_a_Data.mdf', 
   @filename2 = N'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_a_Log.ldf'

-- logical name for new DB changed to active DB

alter database staging_snap
MODIFY FILE (NAME = staging_snap_b_data, NEWNAME = staging_snap_data)
GO

alter database staging_snap
MODIFY FILE (NAME = staging_snap_b_log, NEWNAME = staging_snap_log)
GO

-- logical name for active DB changed to old DB

alter database staging_snap_a
MODIFY FILE (NAME = staging_snap_data, NEWNAME = staging_snap_a_data)
GO

alter database staging_snap_a
MODIFY FILE (NAME = staging_snap_log, NEWNAME = staging_snap_a_log)
GO

-- return the active and OLD databases to multi-user mode

alter database "staging_snap"
set multi_user WITH ROLLBACK IMMEDIATE
GO

alter database "staging_snap_a"
set multi_user WITH ROLLBACK IMMEDIATE
GO

-- create a new target database (staging_snap_b) for tomorrow

CREATE DATABASE [staging_snap_b]  ON (NAME = N'staging_snap_b_Data', FILENAME = N'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_b_Data.MDF' , SIZE = 1, FILEGROWTH = 10%) LOG ON (NAME = N'staging_snap_b_Log', FILENAME = N'E:\Program Files\Microsoft SQL Server\MSSQL\Data\staging_snap_b_Log.LDF' , SIZE = 1, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO

exec sp_dboption N'staging_snap_b', N'autoclose', N'false'
GO

exec sp_dboption N'staging_snap_b', N'bulkcopy', N'false'
GO

exec sp_dboption N'staging_snap_b', N'trunc. log', N'false'
GO

exec sp_dboption N'staging_snap_b', N'torn page detection', N'true'
GO

exec sp_dboption N'staging_snap_b', N'read only', N'false'
GO

exec sp_dboption N'staging_snap_b', N'dbo use', N'false'
GO

exec sp_dboption N'staging_snap_b', N'single', N'false'
GO

exec sp_dboption N'staging_snap_b', N'autoshrink', N'false'
GO

exec sp_dboption N'staging_snap_b', N'ANSI null default', N'false'
GO

exec sp_dboption N'staging_snap_b', N'recursive triggers', N'false'
GO

exec sp_dboption N'staging_snap_b', N'ANSI nulls', N'false'
GO

exec sp_dboption N'staging_snap_b', N'concat null yields null', N'false'
GO

exec sp_dboption N'staging_snap_b', N'cursor close on commit', N'false'
GO

exec sp_dboption N'staging_snap_b', N'default to local cursor', N'false'
GO

exec sp_dboption N'staging_snap_b', N'quoted identifier', N'false'
GO

exec sp_dboption N'staging_snap_b', N'ANSI warnings', N'false'
GO

exec sp_dboption N'staging_snap_b', N'auto create statistics', N'true'
GO

exec sp_dboption N'staging_snap_b', N'auto update statistics', N'true'
GO

if( (@@microsoftversion / power(2, 24) = 8) and (@@microsoftversion & 0xffff >= 724) )
	exec sp_dboption N'staging_snap_b', N'db chaining', N'false'
GO

-- just a little maintence while we can....

use staging_snap
GO
checkpoint
GO
DBCC SHRINKFILE (staging_snap_log)WITH NO_INFOMSGS 
GO
print ''
GO
print 'Switch_Database.sql has completed'
GO
