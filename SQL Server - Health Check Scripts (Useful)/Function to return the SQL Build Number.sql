IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[fnGetSQLBuild]') AND xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnGetSQLBuild]
GO

CREATE FUNCTION [dbo].[fnGetSQLBuild] () RETURNS nvarchar(20) AS
BEGIN
	RETURN SUBSTRING(@@VERSION, CHARINDEX( N' - ', @@VERSION)+3, CHARINDEX(N' (', @@VERSION) - (CHARINDEX( N' - ', @@VERSION)+3))
END
