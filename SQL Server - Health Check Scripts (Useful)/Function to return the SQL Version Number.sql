IF  EXISTS (SELECT * FROM dbo.sysobjects 
WHERE id = OBJECT_ID(N'[dbo].[fnGetSQLVerNumber]') AND 
	xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnGetSQLVerNumber]
GO

CREATE FUNCTION [dbo].[fnGetSQLVerNumber] () RETURNS int AS
BEGIN
	RETURN SUBSTRING(@@VERSION, CHARINDEX( N' - ', @@VERSION)+3,1)
END





