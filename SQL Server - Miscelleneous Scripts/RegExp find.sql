/*
    
RegExp find

This function will return a table with all matches from a RegExp find.
Also the first 9 SubMatches are returned.

A example execution is included. 
 
*/
-- =============================================
-- Create table function (TF)
-- =============================================
IF EXISTS (SELECT * 
	   FROM   sysobjects 
	   WHERE  name = N'fnRexExpFind')
	DROP FUNCTION fnRexExpFind
GO



CREATE   FUNCTION fnRexExpFind 
(
	@Patern		VARCHAR(8000), 
	@str		TEXT
)
RETURNS @Result TABLE 
(
	NR		NUMERIC,
	Match		VARCHAR ( 4096 ),
	MIndex		NUMERIC,
	MLen		NUMERIC,
	SubMatch1	VARCHAR ( 256 ),
	SubMatch2	VARCHAR ( 256 ),
	SubMatch3	VARCHAR ( 256 ),
	SubMatch4	VARCHAR ( 256 ),
	SubMatch5	VARCHAR ( 256 ),
	SubMatch6	VARCHAR ( 256 ),
	SubMatch7	VARCHAR ( 256 ),
	SubMatch8	VARCHAR ( 256 ),
	SubMatch9	VARCHAR ( 256 )
)
AS
BEGIN
	
	
	DECLARE @hr    		INT  
	
	DECLARE @regExp		INT
	DECLARE	@desc		VARCHAR( 8000 )
	DECLARE @matches	INT
	DECLARE @match		INT
	DECLARE @submatches	INT
	DECLARE @submatch	INT
	
	
	DECLARE	@bMatch		BIT
	
	DECLARE	@Doing		VARCHAR( 256 )
	
	
	DECLARE	@tmpChar	VARCHAR( 8000 )
	DECLARE	@tmpNum		INT
	DECLARE	@tmpNum2	INT
	
	DECLARE	@iNum		NUMERIC
	DECLARE	@Count		INT
	
	DECLARE	@iNum2		NUMERIC
	DECLARE	@Count2		INT
	


	SET	@Doing	= 'Create RegExp object.'
	EXEC	@hr	= master.dbo.sp_OACreate 'VBScript.RegExp', @regExp OUTPUT  
	IF @hr <> 0
		GOTO Error
	
	SET	@Doing	= 'Set pattern.'
	EXEC	@hr	= sp_OASetProperty @regExp, 'Pattern', @Patern
	IF @hr <> 0
		GOTO Error
	
	SET	@Doing	= 'Set Global property.'
	EXEC	@hr	= sp_OASetProperty @regExp, 'Global', 'true'
	IF @hr <> 0
		GOTO Error
	
	SET	@Doing	= 'Set IgnoreCase property.'
	EXEC	@hr	= sp_OASetProperty @regExp, 'IgnoreCase', 'true'
	IF @hr <> 0
		GOTO Error
	
	SET	@Doing	= 'Set Multiline property.'
	EXEC	@hr	= sp_OASetProperty @regExp, 'Multiline', 'true'
	IF @hr <> 0
		GOTO Error
	
	SET	@Doing	= 'Executing "test" method.'
	EXEC	@hr	= sp_OAMethod @regExp, 'Test', @bMatch OUTPUT, @str
	IF @hr <> 0
		GOTO Error
	
	IF @bMatch = 1
	BEGIN
		SET	@Doing	= 'Executing "Execute" method.'
		EXEC	@hr	= sp_OAMethod @regExp, 'Execute', @matches OUTPUT, @str
		IF @hr <> 0
			GOTO Error

	
		SET	@Doing	= 'Executing "Count" method.'
		EXEC	@hr	= sp_OAMethod @matches, 'Count', @Count OUTPUT
		IF @hr <> 0
			GOTO Error
		SET @iNum	= 0
		WHILE @iNum < @Count
		BEGIN
			INSERT INTO @Result	(	NR	)
			VALUES			(	@iNum	)
	
			SET	@Doing		= 'Creating match object.'
			SET	@tmpCHAR	= 'Item(' + CAST(@iNum AS VARCHAR) + ')'
			EXEC	@hr		= sp_OAMethod @matches, @tmpCHAR, @match OUTPUT
			IF @hr <> 0
				GOTO Error
	

			SET	@Doing		= 'Get "Value" property.'
			EXEC	@hr		= sp_OAGetProperty @match, 'Value', @tmpCHAR OUTPUT
			IF @hr <> 0
				GOTO Error

			UPDATE	@Result
			SET	Match	= @tmpCHAR
			WHERE	NR	= @iNum	
	
	
			SET	@Doing		= 'Get "FirstIndex" property.'
			EXEC	@hr		= sp_OAGetProperty @match, 'FirstIndex', @tmpNum OUTPUT
			IF @hr <> 0
				GOTO Error
	
			UPDATE	@Result
			SET	MIndex	= @tmpNum
			WHERE	NR	= @iNum
	
			SET	@Doing		= 'Get "Length" property.'
			EXEC	@hr		= sp_OAGetProperty @match, 'Length', @tmpNum2 OUTPUT
			IF @hr <> 0
				GOTO Error
			UPDATE	@Result
			SET	MLen	= @tmpNum2
			WHERE	NR	= @iNum

			SET	@Doing		= 'Creating submatches object.'
			EXEC	@hr		= sp_OAMethod @match, 'SubMatches', @submatches OUTPUT
			IF @hr <> 0
				GOTO Error
	
	
			EXEC	@hr	= sp_OAMethod @submatches, 'Count' , @Count2 OUTPUT
			IF @hr <> 0
				GOTO Error
	
			SET @iNum2	= 0
			WHILE @iNum2 < @Count2
			BEGIN
				SET	@Doing		= 'Creating submatch object.'
				SET	@tmpCHAR	= 'Item(' + CAST(@iNum2 AS VARCHAR) + ')'
				EXEC	@hr		= sp_OAMethod @submatches, @tmpCHAR , @tmpCHAR OUTPUT
				IF @hr <> 0
					GOTO Error
	
				UPDATE	@Result
				SET	SubMatch1	= CASE @iNum2 WHEN 0 THEN @tmpCHAR ELSE SubMatch1 END,
					SubMatch2	= CASE @iNum2 WHEN 1 THEN @tmpCHAR ELSE SubMatch2 END,
					SubMatch3	= CASE @iNum2 WHEN 2 THEN @tmpCHAR ELSE SubMatch3 END,
					SubMatch4	= CASE @iNum2 WHEN 3 THEN @tmpCHAR ELSE SubMatch4 END,
					SubMatch5	= CASE @iNum2 WHEN 4 THEN @tmpCHAR ELSE SubMatch5 END,
					SubMatch6	= CASE @iNum2 WHEN 5 THEN @tmpCHAR ELSE SubMatch6 END,
					SubMatch7	= CASE @iNum2 WHEN 6 THEN @tmpCHAR ELSE SubMatch7 END,
					SubMatch8	= CASE @iNum2 WHEN 7 THEN @tmpCHAR ELSE SubMatch8 END,
					SubMatch9	= CASE @iNum2 WHEN 8 THEN @tmpCHAR ELSE SubMatch9 END
				WHERE	NR	= @iNum
	
				SET @iNum2	= @iNum2 + 1
			END
	
			SET	@Doing		= 'Destroy Match object.'
			EXEC	@hr		= master.dbo.sp_OADestroy @match
			IF @hr <> 0
				GOTO Error
	
			SET @iNum	= @iNum + 1
		END
	
		SET	@Doing		= 'Destroy Matches object.'
		EXEC	@hr		= master.dbo.sp_OADestroy @matches  
	END

	-- IF we get here the normal way, don't do error
	GOTO Cleanup
	Error:
	EXEC sp_OAGetErrorInfo @regExp, @tmpChar OUT, @desc OUT 

	INSERT INTO @Result ( NR ,Match )
	SELECT		0, 
			'Error ['		+ ISNULL( CAST( convert(varbinary(4),@hr) AS VARCHAR )	, '' ) +
			'], While ['		+ ISNULL( @Doing					, '' ) + 
			'], Source ['		+ ISNULL( @tmpChar					, '' ) + 
			'], Description ['	+ ISNULL( @desc						, '' ) + ']'
			
	GOTO Result
	
	Cleanup:
	EXEC	@hr	= master.dbo.sp_OADestroy @regExp  
	IF @hr <> 0
		GOTO Error
	
	Result: 

	RETURN 
END
GO
-- =============================================
-- Example to execute function
-- =============================================
SELECT * FROM dbo.fnRexExpFind
	( '(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)\d\d.)', '
		Date1: 01/01/2005
		Date2: 31-01-2001
		Date3: 11.12.2005
	')


