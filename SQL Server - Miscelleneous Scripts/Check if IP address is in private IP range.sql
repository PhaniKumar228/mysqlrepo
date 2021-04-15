iF exists (SELECT * from dbo.sysobjects 
	WHERE id = object_id(N'[dbo].[IsPrivateIP]') 
	AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1)
DROP FUNCTION [dbo].[IsPrivateIP]
GO

CREATE FUNCTION dbo.IsPrivateIP( @vcIPAddress varchar(15))
/**************************************************************************
DESCRIPTION: Returns Numeric IP if not private, otherwise returns null
PARAMETERS:
		@vcIPAddress	- The string containing a valid IP
		
RETURNS:	IP converted to bigint or null if a private IP
		
USAGE:		SELECT dbo.IsPrivateIP( '207.158.26.10')

DEPENDANCIES: 	 dbo.IPStringToNumber() function	

***************************************************************************/

	RETURNS bigint
AS
BEGIN
	DECLARE	@biClassALo bigint ,
		@biClassAHi bigint ,
		@biClassBLo bigint ,
		@biClassBHi bigint ,
		@biClassCLo bigint ,
		@biClassCHi bigint ,
		@biIP	    bigint,
		@bTemp		int 

	SET @biClassALo = 167772160
	SET @biClassAHi = 169549375
	SET @biClassBLo = 2885681152
	SET @biClassBHi = 2887778303
	SET @biClassCLo = 3232235520
	SET @biClassCHi = 3232301055
	
	
	SET @biIP = dbo.IPStringToNumber(@vcIPAddress)
	IF @biIP BETWEEN @biClassALo AND @biClassAHi OR @biIP BETWEEN @biClassBLo AND @biClassBHi 
		OR @biIP BETWEEN @biClassCLo AND @biClassCHi 
		SET @biIP = NULL
		
	RETURN @biIP
END
GO

IF exists (SELECT * from dbo.sysobjects 
	WHERE id = object_id(N'[dbo].[IPStringToNumber]') 
	AND OBJECTPROPERTY(id, N'IsScalarFunction') = 1)
DROP FUNCTION [dbo].[IPStringToNumber]
GO

CREATE FUNCTION dbo.IPStringToNumber( @vcIPAddress varchar(15))
/**************************************************************************
DESCRIPTION: Returns Numeric IP, otherwise returns null

PARAMETERS:
		@vcIPAddress	- The string containing a valid IP
		
RETURNS:	IP converted to bigint or null if not a valid IP
		
USAGE:         SELECT  dbo.IPStringToNumber( '10.255.255.255')
		
***************************************************************************/

	RETURNS bigint
AS
BEGIN
	DECLARE	
		@biOctetA 	bigint,
		@biOctetB	bigint,
		@biOctetC	bigint,
		@biOctetD	bigint,
		@biIP	    	bigint

	DECLARE @tblArray TABLE 
	   (
		OctetID		smallint,  		--Array index
	   	Octet		bigint		   	--Array element contents
	   )

	--split the IP string and insert each octet into a table row
	INSERT INTO @tblArray
	SELECT ElementID, Convert(bigint,Element) FROM dbo.Split(@vcIPAddress, '.')
	
	--check that there are four octets and that they are within valid ranges
	IF (SELECT COUNT(*) FROM @tblArray WHERE Octet BETWEEN 0 AND 255) = 4
	BEGIN
		SET @biOctetA = (SELECT (Octet * 256 * 256 * 256) FROM @tblArray WHERE OctetID = 1)
		SET @biOctetB = (SELECT (Octet * 256 * 256 ) FROM @tblArray WHERE OctetID = 2)
		SET @biOctetC = (SELECT (Octet * 256 ) FROM @tblArray WHERE OctetID = 3)
		SET @biOctetD = (SELECT (Octet) FROM @tblArray WHERE OctetID = 4)
		SET @biIP = @biOctetA + @biOctetB + @biOctetC + @biOctetD
	END
		
	RETURN(@biIP)
END

