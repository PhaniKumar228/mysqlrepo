/*
Generate "CREATE...FOR ATTACH" stmt. dynamically

In instances where you have over 16 data files, or you need to move data files to a new location when you are moving a database you must use a CREATE...FOR ATTACH statement.  

This script will generate the CREATE...FOR ATTACH statement dynamically given a database name.  
It will take into consideration the file sizes, growths (automatically determines if it's MB or percentage), filegroups, locations and names. 

We've found this quite useful in migrating a VLDB from production to development, which has a completely different drive setup.  Execute this script in the context of master.

Here is an example scenario-

On a weekly basis, you must refresh a development server.  The drive letters are the same on production and development.  In order to accomplish this using this script, you would:

1) Backup your production database.
2) Run this script in the context of master.  Save the SQL statement to a safe place!!!
3) Kill all user processes, and detach your database on production.
4) Kill all user processes, and detach your database on development.
5) Copy the data and log files from production to development.
6) Run the SQL statement generated from step 2 on both production and development.  Your database should be back in normal operating condition. 

*/

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[pr_ForAttachSQL]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[pr_ForAttachSQL]
GO

/******************************************************
 Procedure: pr_ForAttachSQL
 Parameters: @dbname - name of the database (REQUIRED)
 Purpose: Given a database name, this script will
          generate the CREATE...FOR ATTACH statement
          to be used after detaching the database.
 Usage: pr_ForAttachSQL 'MyDatabase'

 NOTE- Use at your own risk.  I have thoroughly tested and
 used this script, but I assume no responsibility if you 
 detach your database and cannot reattach it!  Always test 
 this first on a non-production server, and have a backup 
 prepared in the case you cannot reattach your database.
*/

CREATE PROCEDURE pr_ForAttachSQL (
	@dbname AS varchar(255)
) 
AS

/******************************************************
 @dbname is REQUIRED
*/

IF @dbname IS NULL
BEGIN
	RAISERROR(15250,-1,-1)
	RETURN(1)
END

DECLARE @sql varchar(8000)
DECLARE @file varchar(255)
DECLARE @size varchar(15)
DECLARE @growth varchar(15)
DECLARE @name varchar(255)
DECLARE @group varchar(255)
DECLARE @prevgroup varchar(255)

SET NOCOUNT ON

/******************************************************
 Drop and recreate the temp table we'll use to 
 temporarily store table data
*/

IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE name = N'DetachData')
 	DROP TABLE [tempdb].[dbo].[DetachData]

CREATE TABLE [tempdb].[dbo].[DetachData] (
	[id] [int] IDENTITY (1, 1) NOT NULL ,
	[File] [varchar] (255) NOT NULL ,
	[Size] [varchar] (15) NOT NULL ,
	[Growth] [varchar] (15) NOT NULL ,
	[Name] [varchar] (255) NOT NULL ,
	[Group] [varchar] (255) NULL ,
	[FileType] [char] (1) NOT NULL
) ON [PRIMARY]

/*******************************************************/
/* This will get the data file(s)
*/

SET @sql = 'INSERT INTO TempDB..DetachData ([File],[Size],Growth,[Name],[Group],FileType) '
SET @sql = @sql + '(SELECT sf.filename, '
SET @sql = @sql + 'CASE WHEN sf.size < 129 THEN CONVERT(nvarchar(15),(sf.size*8)/1024) ELSE CONVERT(nvarchar(15),(sf.size*8)/1024) + 1 END size, '
SET @sql = @sql + 'CASE sf.status & 0x100000 WHEN 0x100000 THEN	CONVERT(nvarchar(3), sf.growth) + N''%'' ELSE CONVERT(nvarchar(15), sf.growth * 8) + N'' KB'' END growth, '
SET @sql = @sql + 'sf.name, '
SET @sql = @sql + 'sfg.groupname, '
SET @sql = @sql + '''D'' AS filetype '
SET @sql = @sql + 'FROM ' + @dbname + '..sysfiles sf INNER JOIN ' + @dbname + '..sysfilegroups sfg ON sf.groupid = sfg.groupid) '
SET @sql = @sql + 'ORDER BY sfg.groupid,sf.fileid'

EXECUTE (@sql)
SET @sql = ''

/*******************************************************/
/* This will get the log file(s)
*/

SET @sql = 'INSERT INTO TempDB..DetachData ([File], [Size], Growth, [Name], FileType) '
SET @sql = @sql + 'SELECT sf.filename, '
SET @sql = @sql + 'CASE WHEN sf.size < 129 THEN CONVERT(nvarchar(15),(sf.size*8)/1024) ELSE CONVERT(nvarchar(15),(sf.size*8)/1024) + 1 END size, '
SET @sql = @sql + 'CASE sf.status & 0x100000 WHEN 0x100000 THEN	CONVERT(nvarchar(3), sf.growth) + N''%'' ELSE CONVERT(nvarchar(15), sf.growth * 8) + N'' KB'' END growth, '
SET @sql = @sql + 'sf.name, '
SET @sql = @sql + '''L'' AS filetype '
SET @sql = @sql + 'FROM ' + @dbname + '..sysfiles sf '
SET @sql = @sql + 'WHERE groupid = 0'

EXECUTE (@sql)
SET @sql = ''

/******************************************************
 Dynamically create the statement by looping through
 the temp table we've created
*/

SET @sql = 'CREATE DATABASE ' + RTRIM(@dbname) + ' ON PRIMARY '

DECLARE DetachData CURSOR FOR
	SELECT [File], [Size], [Growth], [Name], [Group]		
	FROM TempDB..DetachData
	WHERE FileType = 'D'

OPEN DetachData
FETCH NEXT FROM DetachData INTO @file, @size, @growth, @name, @group
WHILE @@FETCH_STATUS = 0
  BEGIN	
		IF RTRIM(@group) = 'PRIMARY'
		    SET @sql = @sql
	   	ELSE IF @group != @prevgroup
	       	    SET @sql = @sql +  ' FILEGROUP ' + @group + ' '

  		SET @prevgroup = @group
			
  		SET @sql = @sql + '('
      		SET @sql = @sql + 'NAME = ''' + RTRIM(@name) + ''','
  		SET @sql = @sql + 'FILENAME = ''' + RTRIM(@file) + ''','
  		SET @sql = @sql + 'SIZE = ' + @size + ','
	   	SET @sql = @sql + 'FILEGROWTH = ' + @growth
		SET @sql = @sql + ')'
      FETCH NEXT FROM DetachData INTO @file, @size, @growth, @name, @group
    	
      IF @@FETCH_STATUS = 0
        SET @sql = @sql + ','
  END

CLOSE DetachData
DEALLOCATE DetachData

SET @sql = @sql + ' LOG ON '

DECLARE DetachData CURSOR FOR
	SELECT [File], [Size], [Growth], [Name], [Group]		
	FROM TempDB..DetachData
	WHERE FileType = 'L'

OPEN DetachData
FETCH NEXT FROM DetachData INTO @file, @size, @growth, @name, @group
WHILE @@FETCH_STATUS = 0
  BEGIN
		  	
  		SET @sql = @sql + '('
  		SET @sql = @sql + 'NAME = ''' + RTRIM(@name) + ''','
  		SET @sql = @sql + 'FILENAME = ''' + RTRIM(@file) + ''','
  		SET @sql = @sql + 'SIZE = ' + @size + ','
	   	SET @sql = @sql + 'FILEGROWTH = ' + @growth
		  SET @sql = @sql + ')'
      FETCH NEXT FROM DetachData INTO @file, @size, @growth, @name, @group
    	
      IF @@FETCH_STATUS = 0
        SET @sql = @sql + ','
  END

CLOSE DetachData
DEALLOCATE DetachData

SET @sql = @sql + ' FOR ATTACH '

/******************************************************
 Finally, print the statement to the screen
*/

PRINT @sql

/******************************************************
 Drop the temp table
*/

IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE name = N'DetachData')
 	DROP TABLE [tempdb].[dbo].[DetachData]



