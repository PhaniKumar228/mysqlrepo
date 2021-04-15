/*
Retrieve environment variables

This stored procedure lets you retrieve the environment variables from the server. 
you can pass in a partial name to get the variables that start with the partial match, or bblank to retrieve all the environment variables. 

*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.spEnvironVar    Script Date: 12/18/2002 9:10:09 PM ******/
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[spEnvironVar]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[spEnvironVar]
GO

CREATE PROCEDURE spEnvironVar(@VarName varchar(300) = '')
AS
	DECLARE @env nvarchar(4000)
	
	SET NOCOUNT ON
	SET @env = 'set ' + @VarName
	
	CREATE TABLE #env (outputData varchar(8000))

	INSERT INTO #env EXEC master..xp_cmdshell @env

	SELECT CAST(LEFT(outputData, CHARINDEX('=', outputData) - 1) As varchar(75)) EnvName,
		CAST(RIGHT(outputData, ABS(LEN(outputData) - CHARINDEX('=', outputData))) As varchar(4000)) As EnvValue
	FROM #env
	WHERE outputData IS NOT NULL
	
	SET NOCOUNT OFF
	DROP TABLE #env
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[spEnvironVar]  TO [public]
GO


