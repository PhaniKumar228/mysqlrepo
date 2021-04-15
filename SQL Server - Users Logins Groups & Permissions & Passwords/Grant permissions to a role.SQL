/*
Grant permissions to a role

A very simple script that will first create a role (if it does not exist yet) and then grant full permissions on tables, views and stored procedures to the newly created role. Of course, you can add any filtering (i.e. grant permissions only for tables beginning with "abc") or grant partial permissions (SELECT or DELETE only) for certain roles. 
*/

IF NOT EXISTS (SELECT * FROM dbo.sysusers WHERE name = N'MyNewRole' AND uid > 16399)
	EXEC sp_addrole N'MyNewRole'
GO

DECLARE
@TabName varchar(100),
@SPName varchar(100),
@ViewName varchar(100)
-- Tables 
DECLARE TabCursor CURSOR FAST_FORWARD LOCAL FOR
SELECT TABLE_NAME FROM information_schema.tables WHERE TABLE_TYPE='BASE TABLE'
OPEN TabCursor

FETCH NEXT FROM TabCursor INTO @TabName
WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC ('GRANT ALL ON [' + @TabName + '] TO MyNewRole')
		FETCH NEXT FROM TabCursor INTO @TabName
	END
CLOSE TabCursor
DEALLOCATE TabCursor
-- Views
DECLARE VCursor CURSOR FAST FORWARD LOCAL FOR
SELECT TABLE_NAME FROM information_schema.views
OPEN VCursor

FETCH NEXT FROM VCursor INTO @ViewName
WHILE @@FETCH_STATUS = 0
	BEGIN
			EXEC ('GRANT ALL ON [' + @ViewName + '] TO MyNewRole')
			FETCH NEXT FROM VCursor INTO @ViewName
	END
CLOSE VCursor
DEALLOCATE VCursor
-- Procedures
DECLARE SCursor CURSOR FAST_FORWARD LOCAL FOR
SELECT name FROM sysobjects WHERE type = 'p'
OPEN SCursor

FETCH NEXT FROM SCursor INTO @SPName
WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC ('GRANT ALL ON [' + @SPName + '] TO MyNewRole')
		FETCH NEXT FROM SCursor INTO @SPName
	END
CLOSE SCursor
DEALLOCATE SCursor


