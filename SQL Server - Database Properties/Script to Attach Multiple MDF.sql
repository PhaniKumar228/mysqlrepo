/*
Script to Attach Multiple MDF

Copies mdf files located in a directory on a client and attaches them to the connected server. 
This is the winning solution to the contest that was presented in an article posted at http://www.sqlservercentral.com/columnists/awarren/reattachingdatabases-somecodeandacontest!.asp. 
That article shows how to do the same thing using DMO. Wynn Muse is the author of this stored procedure. 

*/

IF EXISTS (SELECT name  FROM   sysobjects  WHERE  name = N'sp_attach_db_from_dir'  AND type = 'P')
    DROP PROCEDURE sp_attach_db_from_dir
GO

CREATE PROCEDURE sp_attach_db_from_dir 
	@MDFpath varchar (255), 
	@serverMDFpath varchar (255) = NULL,
	@sExclude varchar (8000) = 'msdbdata, northwnd'
/*
	Procedure sp_attach_db_from_dir
	Copies mdf files located in a directory on a client and attaches them to the connected server

	Usage
	sp_attach_db_from_dir @MDFpath=directory which contains the mdf files for attaching
	[,@serverMDFpath=path to the server's main db folder as seen from the server (default, NULL)]
	[,@sExclude=mask specifying which existing MDFpath files to exclude (default, 'msdbdata, northwnd']


	Notes
	* Most of the time the @MDFpath will not be the path that the server can use to access the MDF files 
	   These three things can happen -
	   	1) The @MDFpath is used and modifed to UNC using the admin share) (ex. '\\machinename\C$\Temp\db')  
		2) If the sp is run locally, the @MDFpath is used without modifications.
		3) If the @MDFpath is entered in UNC notation to begin with, then the @MDFpath is used without modifications.
	* Since the admin share is used, your MSSQLSERVER service must be started by an account with admin rights (the LocalSystem won't work)
		You can, if you are using the LocalSystem account, just run the sp locally on the server (the MDFpath must also be accessible to LocalSystem)
		Or you can use UNC to access a share that has "everyone" access (accessible to LocalSystem).
	* When @serverMDFpath is NULL the DATA path entered during the SQL Server installation is used	(ex. 'C:\Program Files\Microsoft SQL Server\MSSQL\Data')
	* Enter @sExclude values as a comma separated string (ex. 'mydb1, mydb2, mydb3')
	* There is no need to exclude existing dbs, these are automagically removed from the attach process - except for the defaults ('msdbdata, northwnd')
	* This procedure exploits the fact that SQL 2K can attach a db without the existence of the LDF - No LDF are used in the copy and attach process
	* This procedure assumes that all user dbs are named with the "databasename_data.mdf" convention.

	Contact
	wynn.muse@routematch.com	
*/
AS

-- For the populating the temptable & the cursor
DECLARE  @strExec varchar (8000)
-- For the cursor
DECLARE @filename varchar(255)
DECLARE @logfilename varchar(255)
DECLARE @dbname varchar(255)
DECLARE @res int
-- For the Exclusions
DECLARE  @value varchar (8000)
DECLARE @iSnag smallint
-- For resolving the MDFpath for the server
DECLARE @MDFpathFromServer varchar (255)


SET NOCOUNT ON

IF @MDFpath IS NULL OR @MDFpath = ''
		BEGIN
			RAISERROR ('The MDFpath entered does not exist.',16,1)						
			RETURN	
		END	
-- =============================================
-- 	Resolve the MDFpathFromServer
-- =============================================
IF HOST_NAME() <> SERVERPROPERTY('MachineName')
	BEGIN
		IF LEFT(@MDFpath, 2) = '\\'
			SET @MDFpathFromServer = @MDFpath
		ELSE
			SET @MDFpathFromServer ='\\'+(SELECT HOST_NAME())+'\'+STUFF(@MDFpath,2,1,'$')
	END
ELSE
	SET @MDFpathFromServer = @MDFpath

IF RIGHT(@MDFpathFromServer,1) <> '\'
	SET @MDFpathFromServer =	@MDFpathFromServer+'\'

EXEC master..sp_MSget_file_existence @MDFpathFromServer, @res out
IF (@res = 0)
		BEGIN
			RAISERROR ('Either the MDFPath <%s> does not exist or the MSSQLSERVER Service Account can''t access it.',16,1, @MDFpathFromServer)						
			RETURN	
		END

-- =============================================
-- 	Resolve the serverpath 
-- =============================================

IF @serverMDFpath IS NULL OR @serverMDFpath = ''
	BEGIN
		EXEC sp_MSget_setup_paths '', @serverMDFpath OUT
		SET @serverMDFpath =	@serverMDFpath+'\Data'
	END		
IF RIGHT(@serverMDFpath,1) <> '\'
	SET @serverMDFpath =	@serverMDFpath+'\'	

-- =============================================
-- 	Manage the exclusions
-- 	Take the array and throw it into a table
-- =============================================
IF CHARINDEX('msdbdata',@sExclude)=0
	SET @sExclude = @sExclude +', msdbdata'
IF CHARINDEX('northwnd',@sExclude)=0
	SET @sExclude = @sExclude +', Northwnd'

IF OBJECT_ID('tempdb..#tDbName') IS NOT NULL
	DROP TABLE tempdb.#tDbName
CREATE TABLE #tDbName (dbname varchar(8000))
WHILE CHARINDEX(',', @sExclude)>0
	BEGIN
		SET @value = SUBSTRING(@sExclude,1, CHARINDEX(',',@sExclude)-1)
		INSERT #tDbName VALUES(@value)
		SET @iSnag = DATALENGTH(@value) + 1
		SET @sExclude = LTrim(Right(@sExclude,DATALENGTH(@sExclude) - @iSnag))
	END
INSERT #tDbName VALUES (@sExclude)

-- =================================================
-- 	Create and populate a temp table with the MDFpath filenames
-- =================================================

IF OBJECT_ID('tempdb..#dir_result') IS NOT NULL
	DROP TABLE tempdb.#dir_result
CREATE TABLE #dir_result (filename varchar (255), dbname varchar(255))

EXEC master..xp_sprintf @strExec OUTPUT, 'dir /b %s*.mdf', @MDFpathFromServer

INSERT #dir_result (filename)
EXEC master..xp_cmdshell @strExec

IF NOT EXISTS(SELECT * FROM #dir_result) 
	BEGIN
		RAISERROR ('No MDFs to attach: Check your directory.',16,1)						
		RETURN
	END 
IF EXISTS(SELECT * FROM #dir_result WHERE filename LIKE '%d.') 
	BEGIN
		RAISERROR ('No MDFs to attach: Check your directory.',16,1)						
		RETURN
	END
-- =============================================
-- 	Clean-up the temp table:
-- 		Remove the server's existing dbnames
-- 		Remove the null field carried over from the dir
-- 		Remove any exclusions
-- =============================================

UPDATE #dir_result 
SET dbname = LEFT(filename,CHARINDEX('.MDF',filename)-1)
WHERE CHARINDEX('_', filename)=0

UPDATE #dir_result
SET dbname = LEFT(filename,CHARINDEX('_',filename,LEN(filename)-9)-1)
-- We have some dbnames that include the underscore, hence the third argument in the CHARINDEX
WHERE CHARINDEX('_', filename)>0

DELETE #dir_result 
WHERE dbname  IN
	(SELECT CATALOG_NAME
	FROM INFORMATION_SCHEMA.SCHEMATA) 
OR filename IS NULL
OR dbname IN
	(SELECT dbname from #tDbName)

IF NOT EXISTS(SELECT * FROM #dir_result) 
	BEGIN
		RAISERROR ('No MDFs to attach:  Either your exclusions are filtering them all out or these dbs have already been attached.',16,1)						
		RETURN
	END 

-- =============================================
-- 	Copy the database(s) form client to server
-- 	Attach the database(s)	
-- =============================================
IF OBJECT_ID('tempdb..#copy_result') IS NOT NULL
	DROP TABLE tempdb.#copy_result
CREATE TABLE #copy_result (filename varchar (255), dbname varchar(255))

DECLARE cAttach CURSOR
READ_ONLY
FOR SELECT filename, dbname FROM #dir_result

OPEN cAttach

FETCH NEXT FROM cAttach INTO @filename, @dbname
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		-- xcopy the files to the server and ensure that it was successful
		EXEC master..xp_sprintf @strExec OUTPUT, 'xcopy "%s%s" "%s"', @MDFpathFromServer, @filename, @serverMDFpath
		DELETE #copy_result
		INSERT #copy_result (filename)
 		EXEC master..xp_cmdshell @strExec 
		IF NOT EXISTS (SELECT * FROM #copy_result WHERE filename LIKE '%file(s) copied%')
			RAISERROR('xcopy not successful, file may be in use, check permissions, etc.',16,1)
		SET @filename = @serverMDFpath+@filename
		--insurance against any lingering log files
			SET @logfilename = stuff(@filename,datalength(@filename)-7,10,'log.ldf')
			EXEC master..xp_sprintf @strExec OUTPUT, 'del "%s"', @logfilename
	 		EXEC master..xp_cmdshell @strExec , NO_OUTPUT
		EXEC @res=sp_attach_db @dbname, @filename
		IF (@res <> 0)
			RAISERROR ('Error attaching %s database.',16,1,@dbname)			
		ELSE
			PRINT Char(13) + 'Attach operation of ' + @dbname + ' successful'
	END
	FETCH NEXT FROM cAttach INTO @filename, @dbname
END

CLOSE cAttach
DEALLOCATE cAttach
GO


