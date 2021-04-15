/*
sp_SearchObjectsAllDBs 


Examples: 
To search for a table named 'customer' : exec master..usp_SearchObjectsAllDBs @searchname = 'customer', @type = 'U' 

To search for a procedure named 'customer' : exec master..usp_SearchObjectsAllDBs @searchname = 'customer', @type = 'P' 

*/

Use Master
GO
Create procedure sp_SearchObjectsAllDBs @searchname sysname, @type varchar(5),@excludeSystemDBs tinyint = 1
AS
/*  'U' type = tables  Look in sysobjects table in any user database to determine other types*/

Declare @dbid int,@dbname sysname, @sql varchar(200), @exeSQL varchar(200)
Select	@sql = '.dbo.sp_ob @name = ' + '''' + @searchname + '''' + ', @type = ' + '''' + rtrim(ltrim(@type)) + ''''

	If @excludeSystemDBs = 1 
		Begin
			Select @dbid = min(dbid) from master..sysdatabases where dbid > 4
		End
	Else
		Begin
			Select @dbid = min(dbid) from master..sysdatabases
		End


	While @dbID is not null
		Begin
			Select @dbname = name from sysdatabases where dbid = @dbid
			Select @dbName as 'Searching '
			Select	@exeSQL = @dbname + @sql
			exec(@exeSQL)	
			Select @dbid = min(dbid) from master..sysdatabases where dbid > @dbid
		End
GO

