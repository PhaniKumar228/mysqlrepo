/*
Function to get a valid user error number

This function allows you to capture the next valid error number to use in the sp_addmessage sp. 
No matter how much user errors you have define, you will always get the next available error number. 

*/

GO
IF EXISTS (SELECT * FROM sysobjects WHERE name = 'fn_NroError' AND xtype = 'FN')
DROP FUNCTION fn_NroError
GO
CREATE FUNCTION fn_NroError
()
RETURNS INT
AS
BEGIN
	/* Capture the last error number */
	DECLARE @ErrorNro AS INT
	SELECT @ErrorNro = MAX(Error) FROM master.dbo.sysmessages

	/* if it is minor that 50000 then it is a system error, so I use 50001 */
	IF @ErrorNro < 50000
		SELECT @ErrorNro = 50001
	/* if it is bigger then I use the next one */
	ELSE
		SELECT @ErrorNro = @ErrorNro + 1

	/* returns the value */
	RETURN @ErrorNro
END
GO

