/*
    
List Where SQL Server Files

This SP checks the path where SQL Server is installed, and then lists all the .mdf and .ldf files. 
Also list the quantity of tables, views, sp, xp and users on the given database. 

*/


CREATE PROCEDURE proc_list_ing
@dbname varchar(20)= NULL
AS
SET NOCOUNT ON
IF @dbname IS NULL
	BEGIN
		PRINT '*****************************************'
		PRINT '**You must enter a Database Name       **'
		PRINT '**to continue.                         **'
		PRINT '*****************************************'
		PRINT ''
		PRINT 'Available Databases...'
		EXEC master..sp_databases
		RETURN
	END

IF NOT EXISTS (
		SELECT name 
		FROM master..sysdatabases
		WHERE name=@dbname
		)
	BEGIN
		PRINT '*****************************************'
		PRINT '**The database does not exists.        **'
		PRINT '**Available databases...               **'
		PRINT '*****************************************'
		PRINT ''
		EXEC master..sp_databases
		RETURN	
	END	


/*
**Gets the path where the db files are located
**and then puts the list in temp tables.
*/
DECLARE @lenght_db varchar(300)
DECLARE @path_db varchar(300)
DECLARE @numero_db int
SET @lenght_db=(
		SELECT  filename
		FROM master..sysfiles
		WHERE name='master'
			)
		SET @path_db=(
			SELECT filename
			FROM master..sysfiles
			WHERE name='master'
				)
		set @lenght_db=LEN (@lenght_db)
		set @numero_db=@lenght_db-10
		SET @path_db= left(@path_db,@numero_db)

DECLARE @cmd_mdf varchar(300)
DECLARE @cmd_ldf varchar(300)

SET @cmd_mdf='EXEC master..xp_cmdshell "dir /B '+@path_db+'*.mdf"'
SET @cmd_ldf='EXEC master..xp_cmdshell "dir /B '+@path_db+'*.ldf"'

CREATE TABLE #datafiles_mdf
	(mdf varchar(40))

CREATE TABLE #datafiles_ldf
	(ldf varchar(40))

/*MDF's y LDF's saved on tables*/
INSERT INTO #datafiles_mdf EXEC (@cmd_mdf)
INSERT INTO #datafiles_ldf EXEC (@cmd_ldf)

-----------------------------------------------
/*
**Checks the user tables on the db
*/
DECLARE @select_table varchar(100)
SET @select_table='SELECT count(name)AS "Users Tables" FROM '+@dbname+'..sysobjects where xtype="u"' 


-----------------------------------------------
/*
**Checks the views
*/
DECLARE @select_view varchar(100)
SET @select_view='SELECT count(name) AS "Views" FROM '+@dbname+'..sysobjects where xtype="v" '


-----------------------------------------------
/*
**Checks the system tables
*/
DECLARE @select_sistema varchar(100)
SET @select_sistema='SELECT count(name)AS "system Tables" FROM '+@dbname+'..sysobjects where xtype="s" '


-----------------------------------------------
/*
**Checks the SP
*/
DECLARE @select_sp varchar(100)
SET @select_sp='SELECT count(name) AS "Stored Procedures" FROM '+@dbname+'..sysobjects where xtype="p"'


-----------------------------------------------
/*
**Checks the XP
*/
DECLARE @select_xp varchar(100)
SET @select_xp='SELECT count(name) AS "Extended Procedures" FROM '+@dbname+'..sysobjects where xtype="x"'

-----------------------------------------------
/*
**Checks the user names
*/
DECLARE @select_users varchar(100)
SET @select_users='SELECT name AS "Users names" FROM '+@dbname+'..sysusers where name not like "db_%"' 


-----------------------------------------------------------------
/*
**Print the result
*/
PRINT 'List of .mdf files on the path '+@path_db
select mdf as 'Data files' from #datafiles_mdf 
PRINT 'List of .ldf files on the path '+@path_db
select ldf AS 'Log files' from #datafiles_ldf 
print 'Quantity of user tables on the database '+@dbname
EXEC (@select_table)
print 'Quantity of system tables on the database '+@dbname
EXEC (@select_sistema)
print 'Quantity of views on the database '+@dbname
EXEC (@select_view)
print 'Quantity of Stored Procedures on the database '+@dbname
EXEC (@select_sp)
print 'Quantity of Extended Procedures on the database '+@dbname
EXEC (@select_xp)
PRINT 'Users on the database '+@dbname
EXEC (@select_users)


