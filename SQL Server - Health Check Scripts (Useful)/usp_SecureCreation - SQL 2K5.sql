/*
    
usp_SecurCreation - SQL 2k5

Creates statements for Server level Privileges to User or User Group, Procedures/Functions, Table and Column Level Privileges creation to User or User Group. Useful when migrating a server, for example.

Usage:

To script all users securables: EXEC usp_SecurCreation
To script one user securables: EXEC usp_SecurCreation '<User>'
 
*/

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_SecurCreation]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_SecurCreation]
GO

CREATE PROCEDURE usp_SecurCreation @User NVARCHAR(128) = NULL
AS
--
--  2008-02-25 Pedro Lopes (NovaBase) pedro.lopes@novabase.pt
--
--  All users: EXEC usp_SecurCreation
--
--  One user: EXEC usp_SecurCreation '<User>'
--

SET NOCOUNT ON

DECLARE @SC VARCHAR(4000), @SCUser VARCHAR(4000)
CREATE TABLE #TempSecurables ([State] VARCHAR(100),
			[State2] VARCHAR(100),
			[PermName] VARCHAR(100),
			[Type] NVARCHAR(60),
			[Grantor] VARCHAR(100),
			[User] VARCHAR(100)
			)	
CREATE TABLE #TempSecurables2 ([DBName] sysname,
				[State] VARCHAR(1000)
				)	

IF @User IS NULL
BEGIN
	--Server level Privileges to User or User Group

	INSERT INTO #TempSecurables
	SELECT CASE CAST(p.state AS VARCHAR(100)) WHEN 'D' THEN 'DENY' WHEN 'R' THEN 'REVOKE' WHEN 'G' THEN 'GRANT' WHEN 'W' THEN 'GRANT' END, 
	CASE CAST(p.state AS VARCHAR(100)) WHEN 'W' THEN 'WITH GRANT OPTION' ELSE '' END, CAST(p.permission_name AS VARCHAR(100)), RTRIM(p.class_desc),
	(SELECT [name] FROM sys.server_principals WHERE principal_id = p.grantor_principal_id), CAST(l.name AS VARCHAR(100))
	FROM sys.server_permissions AS p JOIN sys.server_principals AS l 
	ON p.grantee_principal_id = l.principal_id
	AND l.is_disabled = 0
	AND l.type IN ('S', 'U', 'G', 'R')

	INSERT INTO #TempSecurables2
	EXEC master.dbo.sp_MSforeachdb @command1='USE [?] 
	--Privileges for Procedures/Functions to the User
	SELECT ''[?]'', CASE WHEN (b.state_desc COLLATE database_default) = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' ELSE (b.state_desc COLLATE database_default) END + '' EXECUTE ON ['' + c.name + ''].['' + a.name + ''] TO '' + QUOTENAME(USER_NAME(b.grantee_principal_id)) +
	CASE STATE WHEN ''W'' THEN '' WITH GRANT OPTION'' 
	ELSE '''' END FROM sys.all_objects a, sys.database_permissions b, sys.schemas c 
	WHERE a.OBJECT_ID = b.major_id AND a.type IN (''X'',''P'',''FN'') AND b.grantee_principal_id <>0 
	AND b.grantee_principal_id <>2 AND a.schema_id = c.schema_id
	ORDER BY c.name

	--Table Level Privileges to the User
	SELECT ''[?]'', ''GRANT '' + privilege_type + '' ON ['' + table_schema + ''].['' + table_name + ''] TO ['' + grantee + '']'' +
	CASE IS_GRANTABLE WHEN ''YES'' THEN '' WITH GRANT OPTION'' 
	ELSE '''' END FROM INFORMATION_SCHEMA.TABLE_PRIVILEGES
	WHERE GRANTEE <> ''public''

	--Column Level Privileges to the User 
	SELECT ''[?]'', ''GRANT '' + privilege_type + '' ON ['' + table_schema + ''].['' + table_name + ''] ('' + column_name + '') TO ['' + grantee + '']'' +
	CASE IS_GRANTABLE WHEN ''YES'' THEN '' WITH GRANT OPTION'' 
	ELSE '''' END FROM INFORMATION_SCHEMA.COLUMN_PRIVILEGES
	WHERE GRANTEE <> ''public'''
END
ELSE
BEGIN
	--Server level Privileges to User or User Group
	INSERT INTO #TempSecurables
	SELECT CASE CAST(p.state AS VARCHAR(100)) WHEN 'D' THEN 'DENY' WHEN 'R' THEN 'REVOKE' WHEN 'G' THEN 'GRANT' WHEN 'W' THEN 'GRANT' END, 
	CASE CAST(p.state AS VARCHAR(100)) WHEN 'W' THEN 'WITH GRANT OPTION' ELSE '' END, CAST(p.permission_name AS VARCHAR(100)), RTRIM(p.class_desc),
	(SELECT [name] FROM sys.server_principals WHERE principal_id = p.grantor_principal_id), CAST(l.name AS VARCHAR(100))
	FROM sys.server_permissions AS p JOIN sys.server_principals AS l 
	ON p.grantee_principal_id = l.principal_id
	AND l.is_disabled = 0
	AND l.type IN ('S', 'U', 'G', 'R')
	AND QUOTENAME(l.name) = QUOTENAME(@User)

	SET @SCUser = 'USE [?] 
	--Privileges for Procedures/Functions to the User
	SELECT ''[?]'', CASE WHEN (b.state_desc COLLATE database_default) = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' ELSE (b.state_desc COLLATE database_default) END + '' EXECUTE ON ['' + c.name + ''].['' + a.name + ''] TO '' + QUOTENAME(USER_NAME(b.grantee_principal_id)) +
	CASE STATE WHEN ''W'' THEN '' WITH GRANT OPTION'' 
	ELSE '''' END FROM sys.all_objects a, sys.database_permissions b, sys.schemas c 
	WHERE a.OBJECT_ID = b.major_id AND a.type IN (''X'',''P'',''FN'') AND b.grantee_principal_id <>0 
	AND b.grantee_principal_id <>2 AND a.schema_id = c.schema_id
	AND QUOTENAME(USER_NAME(b.grantee_principal_id)) = ''[' + @User + ']''
	ORDER BY c.name

	--Table Level Privileges to the User
	SELECT ''[?]'', ''GRANT '' + privilege_type + '' ON ['' + table_schema + ''].['' + table_name + ''] TO ['' + grantee + '']'' +
	CASE IS_GRANTABLE WHEN ''YES'' THEN '' WITH GRANT OPTION'' 
	ELSE '''' END FROM INFORMATION_SCHEMA.TABLE_PRIVILEGES
	WHERE GRANTEE <> ''public''
	AND grantee = ''[' + @User + ']''

	--Column Level Privileges to the User 
	SELECT ''[?]'', ''GRANT '' + privilege_type + '' ON ['' + table_schema + ''].['' + table_name + ''] ('' + column_name + '') TO ['' + grantee + '']'' +
	CASE IS_GRANTABLE WHEN ''YES'' THEN '' WITH GRANT OPTION'' 
	ELSE '''' END FROM INFORMATION_SCHEMA.COLUMN_PRIVILEGES
	WHERE GRANTEE <> ''public''
	AND grantee = ''[' + @User + ']'''

	INSERT INTO #TempSecurables2
	EXEC master.dbo.sp_MSforeachdb @command1=@SCUser
END

DECLARE @tmpstr NVARCHAR(128)
SET @tmpstr = '** Generated ' + CONVERT (VARCHAR, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
PRINT @tmpstr

PRINT '--##### Server level Privileges to User or User Group #####'

DECLARE cSC CURSOR FOR SELECT 'USE [master];' + CHAR(10) + RTRIM(ts.[State]) + ' ' + RTRIM(ts.[PermName]) + ' TO ' + QUOTENAME(RTRIM(ts.[User])) + ' ' + RTRIM(ts.[State2]) + ';' + CHAR(10) + 'GO' FROM #TempSecurables ts WHERE RTRIM([Type]) = 'SERVER'
OPEN cSC  
FETCH NEXT FROM cSC INTO @SC
WHILE @@FETCH_STATUS = 0 
	BEGIN 
		PRINT @SC
		FETCH NEXT FROM cSC INTO @SC
	END
CLOSE cSC 
DEALLOCATE cSC

DECLARE cSC CURSOR FOR SELECT 'USE [master];' + CHAR(10) + RTRIM(ts.[State]) + ' ' + RTRIM(ts.[PermName]) + ' ON ' + CASE WHEN RTRIM(ts.[Type]) = 'SERVER_PRINCIPAL' THEN 'LOGIN' ELSE 'ENDPOINT' END + '::' + QUOTENAME(RTRIM(ts.[Grantor])) + ' TO ' + QUOTENAME(RTRIM(ts.[User])) + ' ' +RTRIM(ts.[State2]) + ';' + CHAR(10) + 'GO' FROM #TempSecurables ts WHERE RTRIM([Type]) <> 'SERVER'
OPEN cSC  
FETCH NEXT FROM cSC INTO @SC
WHILE @@FETCH_STATUS = 0 
	BEGIN 
		PRINT @SC
		FETCH NEXT FROM cSC INTO @SC
	END
CLOSE cSC 
DEALLOCATE cSC
DROP TABLE #TempSecurables

PRINT '--##### Procedures/Functions, Table and Column Level Privileges to the User #####'

DECLARE cSC CURSOR FOR SELECT 'USE ' + ts2.DBName +';' + CHAR(10) + RTRIM(ts2.[State]) + ';' + CHAR(10) + 'GO' FROM #TempSecurables2 ts2
OPEN cSC  
FETCH NEXT FROM cSC INTO @SC
WHILE @@FETCH_STATUS = 0 
	BEGIN 
		PRINT @SC
		FETCH NEXT FROM cSC INTO @SC
	END
CLOSE cSC 
DEALLOCATE cSC

DROP TABLE #TempSecurables2
GO
