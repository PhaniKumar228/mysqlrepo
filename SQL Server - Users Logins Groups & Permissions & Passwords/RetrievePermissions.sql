--exec RetrievePermissions 'Admin', '',0


CREATE PROCEDURE dbo.RetrievePermissions (@uidname Varchar(200), @newuidname Varchar(200), @RolePermissions SmallInt = NULL) 
AS

	
-- 	If @newuidname = '' will reverse engineer all permissions for @uidname 
-- 	If @newuidname <> '' will reverse engineer all permissions for @uidname where
--                       @newuidname does not already have same permissions/roles as @uidname.
--						 This is helpful if you want to give a user same permissions as another user
--						 eg. exec RetrievePermissions 'Olduser', 'WantSamePermissionsAsOldUser'
--	This sp can be compiled on any database since it scrolls through all databases on the server
--  If @RolePermissions = 1 the permissions of the roles @uidname belong to will also be scripted.
--	Set results to text in order for line break to work!

SET NOCOUNT ON

 CREATE TABLE #rightstable
 (uid int, 
  objectid varchar(255),
  protecttype varchar(255),
  action varchar(255),
  databases varchar(200),
  username varchar(200))
 
 CREATE TABLE #righttext
 (textcolumn varchar(4000))


DECLARE @groupid int
DECLARE @gname varchar(200)
DECLARE @database nVarchar(200)
DECLARE @sql nVarchar(4000)
DECLARE @sql2 nVarchar(4000)

DECLARE databasecursor CURSOR FOR 
SELECT name 
FROM master..sysdatabases
WHERE status&512 <> 512

OPEN databasecursor

FETCH NEXT FROM databasecursor
INTO @database 

WHILE @@FETCH_STATUS = 0
BEGIN
	
	SELECT @sql = 'Declare @gname varchar(200) '+
	'DECLARE @groupid int '+
	'INSERT INTO #rightstable '+
	'SELECT sp.grantee, so.name, sptcts.protecttype, sptcts.action, '''+@database+''', su.name '+
	'FROM '+@database+'..syspermissions sp, '+@database+'..sysobjects so, '+@database+'..sysprotects sptcts, '+@database+'..sysusers su '+
	'WHERE su.name = '''+convert(varchar(255),@uidname)+''' '+
	'and su.uid = sp.grantee '+
	'and so.id = sp.id '+
	'and sptcts.uid = sp.grantee '+
	'and so.id = sptcts.id  '+
	'DECLARE rolescursor CURSOR FOR  '+
	'SELECT groupuid '+
	'FROM '+@database+'..sysmembers , '+@database+'..sysusers  su '+
	'WHERE memberuid = su.uid and su.name = '''+convert(varchar(255),@uidname) +''' '+
	'and (select count(*)  '+
	'	  from '+@database+'..sysmembers z , '+@database+'..sysusers su '+
	'	  where z.memberuid = su.uid and su.name = '''+convert(varchar(255),@newuidname)+''' ) = 0 '+
	'OPEN rolescursor '+
	'FETCH NEXT FROM rolescursor '+
	'INTO @groupid '+
	'WHILE @@FETCH_STATUS = 0  '+
	'BEGIN '+
	'	SELECT @gname = name '+
	'	FROM '+@database+'..sysusers '+
	'	WHERE uid =  @groupid'+
	'	INSERT INTO #righttext '+
	'	SELECT ''--''+'''+@database+'''+char(10)+''EXEC sp_addrolemember ''+@gname+'', '+convert(varchar(255),@uidname)+'''+Char(10)+''GO'' '+
	'	IF '+Convert(Varchar,IsNull(@RolePermissions,0))+' = 1 '+
	'  BEGIN '+
	'INSERT INTO #rightstable '+
	' SELECT sp.grantee, so.name, sptcts.protecttype, sptcts.action, '''+@database+''', su.name '+
	'  FROM '+@database+'..syspermissions sp, '+@database+'..sysobjects so, '+@database+'..sysprotects sptcts, '+@database+'..sysusers su '+
	'  WHERE su.name = @gname '+
	'  and su.uid = sp.grantee '+
	'  and so.id = sp.id '+
	'  and sptcts.uid = sp.grantee '+
	'  and so.id = sptcts.id  '+
	'  END '+
	'	FETCH NEXT FROM rolescursor '+
	'	INTO @groupid '+
	'END '+
	'CLOSE rolescursor '+
	'DEALLOCATE rolescursor '
	EXEC(@sql) 

UPDATE #rightstable
SET protecttype = (case when protecttype = 204 then 'GRANT_W_GRANT' 
								when protecttype = 205 then 'GRANT' 
								when protecttype = 204 then 'DENY' end),
	 [action] = (case when [action] = 26 then 'REFERENCES' 
WHEN [action] = 178 then 'CREATE FUNCTION' 
WHEN [action] = 193 then 'SELECT' 
WHEN [action] = 195 then 'INSERT' 
WHEN [action] = 196 then 'DELETE' 
WHEN [action] = 197 then 'UPDATE' 
WHEN [action] = 203 then 'CREATE DATABASE' 
WHEN [action] = 207 then 'CREATE VIEW' 
WHEN [action] = 222 then 'CREATE PROCEDURE' 
WHEN [action] = 224 then 'EXECUTE' 
WHEN [action] = 228 then 'BACKUP DATABASE' 
WHEN [action] = 233 then 'CREATE DEFAULT' 
WHEN [action] = 235 then 'BACKUP LOG' 
WHEN [action] = 236 then 'CREATE RULE' end)
where databases = @database

--select @sql2 = 'select name from '''+@database+'''..sysusers where uid 

INSERT INTO #righttext 
SELECT '--'+databases+char(10)+ protecttype + ' ' + action + ' ON ' + objectID + ' TO ' + username + CHAR(10)+ 'GO'
FROM #rightstable
where databases = @database
ORDER BY databases


	FETCH NEXT FROM databasecursor
	INTO @database 
END 

CLOSE databasecursor
DEALLOCATE databasecursor

SELECT * FROM #righttext
DROP TABLE #rightstable
DROP TABLE #righttext

SET NOCOUNT OFF

go