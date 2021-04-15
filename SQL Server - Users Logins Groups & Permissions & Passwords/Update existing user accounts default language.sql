/*
Update existing user accounts default language.

When changing the default language of a server it is neccessary to run sp_defaultlangauge against any existing logins. The reason is default language only effects any new accounts created after this change is made. This script is designed to help you quickly make the adjustment for all existing accounts. Note: this has been tested under the US version and cannot guarantee will work on non-english servers. If you find it does or doesn't work but can provide a fix please let me know and I will update. 

*/

CREATE PROCEDURE sp_SetExistAcctLang
	@NewLang sysname = 'us_english'
AS

SET NOCOUNT ON

DECLARE @name sysname
DECLARE @ret int

IF NOT EXISTS (SELECT * FROM syslanguages WHERE alias = @NewLang OR [name] = @NewLang)
BEGIN
	RAISERROR('You have entered an invalid language value. Please use a value from the following list. Note: Input either the alias or the name',16,-1)
	SELECT alias, [name] FROM syslanguages
	RETURN
END

WHILE EXISTS (SELECT TOP 1 [name] FROM syslogins WHERE language != @NewLang)
BEGIN
	SET @name = (SELECT TOP 1 [name] FROM syslogins WHERE language != @NewLang)

	EXEC @ret = sp_defaultlanguage @name, @NewLang

	IF @ret = 0
		PRINT 'Success'
	ELSE
		PRINT 'Failed'
END

PRINT 'Language Update Complete. See messages for any failures. Not new langauage will not take effect until user logsoff then back on if currently attached.'
