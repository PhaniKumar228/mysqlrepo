SET NOCOUNT ON

--
-- Get the name of all databases
--
DECLARE AllDatabases CURSOR FOR

SELECT name FROM master..sysdatabases where name ###Complete Clause here###
  

OPEN AllDatabases


DECLARE @DB NVARCHAR(128)
DECLARE @COMMAND NVARCHAR(128) 

FETCH NEXT FROM AllDatabases INTO @DB


WHILE (@@FETCH_STATUS = 0)

BEGIN
PRINT 'Setting up permissions for '+@DB  
			DECLARE
		@TabName varchar(100),
		@SPName varchar(100),
		@ViewName varchar(100),
		@Cursor nvarchar(255)

		-- Tables 
		
		select @cursor=('DECLARE TabCursor CURSOR FAST_FORWARD GLOBAL FOR ' +
		'SELECT TABLE_NAME FROM '+@DB+'.information_schema.tables WHERE TABLE_TYPE=''BASE TABLE''')
		exec sp_executesql @cursor
		OPEN TabCursor

		FETCH NEXT FROM TabCursor INTO @TabName
		WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC ('USE '+@DB+' GRANT ###Permission### ON [' + @TabName + '] TO ###Enter User or Role here###')
				FETCH NEXT FROM TabCursor INTO @TabName
			END
		CLOSE TabCursor
		DEALLOCATE TabCursor


		-- Views
		select @cursor=('DECLARE VCursor CURSOR FAST_FORWARD GLOBAL FOR ' + 
		'SELECT TABLE_NAME FROM '+@DB+'.information_schema.views')
		exec sp_executesql @cursor
		OPEN VCursor
	
		FETCH NEXT FROM VCursor INTO @ViewName
		WHILE @@FETCH_STATUS = 0
			BEGIN
					EXEC ('USE '+@DB+' GRANT ###Permission### ON [' + @ViewName + '] TO ###Enter User or Role here###')
					FETCH NEXT FROM VCursor INTO @ViewName
			END
		CLOSE VCursor
		DEALLOCATE VCursor
		-- Procedures
		select @cursor=('DECLARE SCursor CURSOR FAST_FORWARD GLOBAL FOR
		SELECT name FROM '+@DB+'..sysobjects WHERE type = ''p''')
		exec sp_executesql @cursor
		OPEN SCursor

		FETCH NEXT FROM SCursor INTO @SPName
		WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC ('USE '+@DB+' GRANT ###Permission### ON [' + @SPName + '] TO ###Enter User or Role here###')
				FETCH NEXT FROM SCursor INTO @SPName
			END
		CLOSE SCursor
		DEALLOCATE SCursor



  	FETCH NEXT FROM AllDatabases INTO @DB

END

   CLOSE AllDatabases

   DEALLOCATE AllDatabases
GO
