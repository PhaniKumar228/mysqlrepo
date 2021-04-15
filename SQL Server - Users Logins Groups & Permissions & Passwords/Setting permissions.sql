/*
Setting permissions (fix for no dbo users)

*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[spSetPermissionsGlobally]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[spSetPermissionsGlobally]
GO

CREATE  PROCEDURE spSetPermissionsGlobally(@name nvarchar(128) = 'public', 
	@printonly bit = 1,
	@revokeOldRights as bit = 1,
	@processViews bit = 1,
	@processProcs bit = 1,
	@processTables bit = 0) AS

	SET NOCOUNT ON
	
	DECLARE permissions_cursor CURSOR FOR 
	SELECT u.[name] + '.' + s.[name], 
		s.xtype		
	FROM sysobjects s, sysusers u 
	WHERE ((OBJECTPROPERTY(s.id, N'IsView') = 1 AND @processViews = 1) -- <--Stored Procs, Tables, and Views, OH MY!
		OR (OBJECTPROPERTY(s.id, N'IsProcedure') = 1 AND @processProcs = 1)
		OR (OBJECTPROPERTY(s.id, N'IsTable') = 1 AND @processTables = 1))
		AND  OBJECTPROPERTY(s.id, N'IsMSShipped') = 0 -- <--ask for any object that did not come with SQL Server
		AND s.[name] <> 'spSetPermissionsGlobally'
		AND s.uid = u.uid
	ORDER BY s.xtype, 
		s.[name] -- <--makes it run slower, but easier to find items in the QA output window(of course there is CTRL+F :P )

	DECLARE @objname nvarchar(128),
		@type char(1),
		@sql varchar(200), 
		@sqlrevoke varchar(200)
	
	OPEN permissions_cursor
	
	FETCH NEXT FROM permissions_cursor 
	INTO @objname, @type
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF(LOWER(@objname) <> LOWER('spSetPermissionsGlobally'))
		BEGIN
			IF(@type = 'V') -- VIEW
				SET @sql = 'GRANT  SELECT  ON ' + @objname + ' TO ' + @name
		
			IF(@type = 'P') -- STORED PROC
				SET @sql = 'GRANT  EXECUTE  ON ' + @objname + ' TO ' + @name
		
			IF(@type = 'U') -- TABLE
				SET @sql = 'GRANT  SELECT, UPDATE, INSERT, DELETE ON ' + @objname + ' TO ' + @name

			SET @sqlrevoke = 'REVOKE ALL ON ' + @objname + ' TO ' + @name
			
			IF @printonly = 0
				PRINT '--*****Setting permissions for : ' + @objname + '*****'
			ELSE
				PRINT 'PRINT ''*****Setting permissions for : ' + @objname + '*****'''

			IF(@revokeOldRights = 1) --revoke the old rights?
			BEGIN
				PRINT @sqlrevoke
				IF @printonly = 0
					EXEC (@sqlrevoke)
				ELSE
					PRINT 'GO'
			END

			PRINT @sql 
			IF @printonly = 0
				EXEC (@sql)
			ELSE
				PRINT 'GO'

			PRINT ''
		END
	
		FETCH NEXT FROM permissions_cursor 
		INTO @objname, @type
	END
	
	CLOSE permissions_cursor
	DEALLOCATE permissions_cursor


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO




