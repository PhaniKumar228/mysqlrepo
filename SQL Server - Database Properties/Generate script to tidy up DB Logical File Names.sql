/*
Generate script to tidy up DB Logical File Names

You may be a tidy person who likes to keep naming standards for everything in SQL Server.  
It is a good practice since it makes generating scripts for everyday DBA tasks a lot simpler.  
I make all database files follow the following standard:
DBName_D1.mdf     for primary filegroup data
DBName_I1.ndf     for index filegroup
DBName_L1.ldf     for transaction log file

The number increments for subsequent files.  
The logical filenames are used by lots of things such as RESTORE DATABASE WITH MOVE.

If you run Select name, filename from master..sysaltfiles you can see the state of your filenames at a glance. 
I'm not concerned with the system files but I am very consistent with user databases.

Change the operating system file is as simple as detach db, rename file, reattach using new names.

Changing the Logical File Name requires an ALTER DATABASE statement.  I don't like repetitive typing so I just run the following stored procedure from the target database to generate the statement for me.

Usage:
DECLARE @RC int, @xDBName varchar(85)
-- Set parameter values
Select @xDBNAme = DB_Name()
EXEC @RC = [dbo].[sp_AlterLogicalNames] @xDBNAme 

*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
Use master
go
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_AlterLogicalNames]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_AlterLogicalNames]
GO

Create Procedure dbo.sp_AlterLogicalNames
	@DBName as varchar(85)
AS
Declare @PrimaryID varchar(2), @LogID varchar(2), @IndexID varchar(2), @CMD varchar(4000)


Set nocount on

Select @PrimaryID = '_D', @LogID = '_L', @IndexID = '_I'
-- Primary Filegroup Data files 
Select @CMD = 'select IDENTITY(int, 1, 1) AS rowID,  A.fileid, A.groupid, A.name as LogicalName, ''' + @DBName + ''' As DBName into ##tmpFileInfo1  from ' + @DBName + '.dbo.sysfiles A Where A.groupid = 1 order by A.name, A.fileid'
Exec(@CMD)
-- Log Files
Select @CMD = 'select IDENTITY(int, 1, 1) AS rowID, A.fileid, A.groupid, A.name as LogicalName, ''' + @DBName + ''' As DBName into ##tmpFileInfo2 from ' + @DBName + '.dbo.sysfiles A Where A.groupid = 0 order by A.name, A.fileid'
Exec(@CMD)
-- Other Filegroup Files 
Select @CMD = 'select IDENTITY(int, 1, 1) AS rowID, A.fileid, A.groupid, A.name as LogicalName, ''' + @DBName + ''' As DBName into ##tmpFileInfo3 from ' + @DBName + '.dbo.sysfiles A Where A.groupid > 1  order by A.name, A.fileid'
Exec(@CMD)

Select 'ALTER DATABASE ' + rtrim(DBName) + ' MODIFY FILE (NAME =''' + rtrim(LogicalName) + ''', NEWNAME =''' + rtrim(DBName) + @PrimaryID + cast(rowid as varchar(3)) + ''')' + char(10) + 'go' from ##tmpFileInfo1
Select 'ALTER DATABASE ' + rtrim(DBName) + ' MODIFY FILE (NAME =''' + rtrim(LogicalName) + ''', NEWNAME =''' + rtrim(DBName) + @LogID + cast(rowid as varchar(3)) + ''')' + char(10) + 'go' from ##tmpFileInfo2
Select 'ALTER DATABASE ' + rtrim(DBName) + ' MODIFY FILE (NAME =''' + rtrim(LogicalName) + ''', NEWNAME =''' + rtrim(DBName) + @IndexID + cast(rowid as varchar(3)) + ''')' + char(10) + 'go' from ##tmpFileInfo3

drop table ##tmpFileInfo1, ##tmpFileInfo2, ##tmpFileInfo3



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


