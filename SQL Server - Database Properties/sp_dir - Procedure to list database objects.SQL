/*
sp_dir - Procedure to list database objects
Lists objects from database. 
Similar to 'dir' command from DOS :-)

Typical usage 
sp_dir 't' 'order*', 1     - returns list of all tables whose name start with 'order' plus their columns and data types
sp_dir 'p' 'custom*_sp' -  returns list of all stored procedures whose name start with 'custom' and end up with '_sp'

For list of all options please see procedure. 
This is just version 0.5. There is more to follow, of course, if you like this.

*/

CREATE PROCEDURE sp_dir @switch varchar(10) = NULL, @wildcard varchar(30) = NULL, @ExInfo bit = 0 AS

/*

Object: sp_dir
Description: Lists objects from database. Similar to 'dir' command from DOS
Supported options:

for @switch you may use:

'T' - List of user tables
'S' - List of system tables
'V' - List of views
'C' - List of CHECK constraint
'D' - List of Default or DEFAULT constraint
'F' - List of FOREIGN KEY constraint
'L' - List of Logs  (??? who knows what is this supposed to show?)
'P' - List of Stored procedure
'PK' - List of PRIMARY KEY constraint (type is K)
'RF' - List of Replication filter stored procedure 
'TR' - List of Trigger
'UQ' - List of UNIQUE constraint (type is K)
'X' - List of Extended stored procedure

@wilcard can be any object name, full or partial. 
'*' wildcard characted is supported (one per string).

@ExInfo - if you pass 1, it gives you list of coulums for specified table or view, or list of parameters for stored procedure

Typical usage:

sp_dir 't' 'order*', 1 		-  returns list of all tables whose name start with 'order' plus their columns and datatypes
sp_dir 'p' 'custom*_sp' 		-  returns list of all stored procedures whose name start with 'custom' and end with '_sp'

*/

SET NOCOUNT ON

DECLARE @Command varchar(255) 
DECLARE @Addition varchar(100)

IF @wildcard IS NOT NULL 
	BEGIN
		DECLARE @PlaceFound INT
		SELECT @PlaceFound = charindex('*', @wildcard)

		IF @PlaceFound > 0 
			BEGIN 


			IF charindex('*', @wildcard, @PlaceFound+1) > @PlaceFound
				BEGIN	
				RAISERROR ('Sorry, only one wildcard character per string is supported!',16, 1)
				RETURN
				END


			IF @PlaceFound = 1 SET @Addition = ' AND Name LIKE ''%' + Substring(@wildcard, 2, 30) + ''''
			ELSE IF @PlaceFound = Len(@wildcard) SET @Addition = ' AND Name LIKE ''' + Left(@wildcard, Len(@wildcard)-1) + '%'''
			ELSE IF @PlaceFound > 1 AND @PlaceFound < Len(@wildcard) 
				SET @Addition = ' AND Name LIKE ''' + Left(@wildcard, @PlaceFound-1) + '%'' AND name LIKE ''%' + Substring(@wildcard, @PlaceFound +1, 30) + ''''
			END
		ELSE SET @Addition = ' AND Name = ''' + @wildcard + ''''

	END		

		

ELSE SET @Addition = ''

SET @Command = 'INSERT INTO #dirresult(Name, ID) SELECT name, ID  FROM sysobjects WHERE xtype = '

IF @switch = 'T' SET @Command = @Command +  '''U'''
ELSE IF @switch = 'S' SET @Command = @Command +  '''S'''
ELSE IF @switch = 'V' SET @Command = @Command +  '''V'''
ELSE IF @switch = 'P' SET @Command = @Command +  '''P'''
ELSE IF @switch = 'C' SET @Command = @Command +  '''C'''
ELSE IF @switch = 'D' SET @Command = @Command +  '''D'''
ELSE IF @switch = 'F' SET @Command = @Command +  '''F'''
ELSE IF @switch = 'L' SET @Command = @Command +  '''L'''
ELSE IF @switch = 'PK' SET @Command = @Command +  '''PK'''
ELSE IF @switch = 'RF' SET @Command = @Command +  '''RF'''
ELSE IF @switch = 'TR' SET @Command = @Command +  '''TR'''
ELSE IF @switch = 'UQ' SET @Command = @Command +  '''UQ'''
ELSE IF @switch = 'X' SET @Command = @Command +  '''X'''

ELSE 
	BEGIN
	RAISERROR ('Unsuported switch!',16, 1)
	RETURN
	END

SET @Command = @Command + @Addition
SET @Command = @Command + ' ORDER BY name'

--SELECT @Command
 
Create table #dirresult ( Name sysname, ID int)


EXEC (@Command)

IF @ExInfo = 0 SELECT * FROM #dirresult
ELSE 
	BEGIN --@ExInfo = 0

	DECLARE @ExtCommand varchar(500)

	DECLARE @Name sysname, @ID int
	DECLARE ObjCursor CURSOR LOCAL FOR SELECT Name, ID FROM #dirresult
	OPEN ObjCursor 
	FETCH NEXT FROM ObjCursor INTO @Name, @ID
		WHILE @@FETCH_STATUS = 0
		BEGIN

		IF @switch = 'T'  OR @switch = 'P' OR @switch = 'V' 
			BEGIN
			SET @ExtCommand = 'SELECT ''           '', left(t1.name,30) AS ColParName, CASE t2.status WHEN 2 THEN LEFT(t2.Name + ''('' + CONVERT(varchar, t1.length) + '')'',30) ELSE Left(t2.Name,30) END AS Type'
			SET @ExtCommand = @ExtCommand + ' FROM syscolumns t1 INNER JOIN systypes t2 on t1.xtype = t2.xtype where ID = ' + convert(varchar, @ID) + '  AND t2.Status <> 3 Order by t1.colid' 
			END
		PRINT @Name
		EXEC (@ExtCommand)

		
		 FETCH NEXT FROM ObjCursor INTO @Name, @ID
		 END	
	CLOSE ObjCursor 
	DEALLOCATE ObjCursor


	END --@ExInfo = 0
DROP TABLE #dirresult

SET NOCOUNT OFF


