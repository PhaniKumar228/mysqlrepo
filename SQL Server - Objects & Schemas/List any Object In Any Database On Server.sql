/*

List any Object In Any Database On Server

I found my self in a fimilar situation where I wanted to modify a table but was not sure how heavily it was used. So I started out with a script that just searched for a table. 

Then I tought to my self...self...
What about all those times you want to expand a column or drop it all together? So I created this little sript that will look for what ever you pass in.

*/

CREATE PROCEDURE spFindObjectUsage
 @ObjectToFind	NVARCHAR(100) = ''
,@ResultMessage	VARCHAR(200) = '' OUTPUT
AS
DECLARE
	 @ReturnCode		INT
	,@StringToExecute	NVARCHAR(1500)
	,@DBToProcess		INT
	,@ServerName		VARCHAR(200)
	,@TableWithServer	VARCHAR(200)
	,@NameOfDatabase	VARCHAR(50)
--
DECLARE	@ServerDatabaseTables TABLE
(TempTblID	INT NOT NULL IDENTITY(1,1)
,DBName		VARCHAR(100) NOT NULL DEFAULT ''
,Processed	BIT NOT NULL DEFAULT 0)
--
CREATE TABLE #ServerDatabaseObjectUsage 
(UsageID		INT NOT NULL IDENTITY(1,1)
,DBName			VARCHAR(100) NOT NULL DEFAULT ''
,ObjectUsedIn		VARCHAR(200) NOT NULL DEFAULT ''
,TypeOfObject		VARCHAR(50)  NOT NULL DEFAULT ''
,IsColumnOfTable 	BIT NOT NULL DEFAULT 0)
--
-- first get all the databases on the current server
--
INSERT INTO @ServerDatabaseTables
	(DBName)
SELECT
	name
FROM master.dbo.sysdatabases
--
SET @TableWithServer = ''
SET @NameOfDatabase  = ''
--
SET NOCOUNT ON
-- each database has it's own listing of System Objects so inorder to get
-- a correct listing we will need to go through every database.
-- the only way I know to do this is using sqlexec.
-- I know it is not the best way but we will need the ability to dynamically
-- tell the query what system tables to use. Ex: master.dbo.systemobjects or production.dbo.systemobjects...ect
WHILE EXISTS(SELECT * FROM @ServerDatabaseTables WHERE Processed = 0) BEGIN
	SET @DBToProcess = (SELECT MIN(TempTblID) FROM @ServerDatabaseTables WHERE Processed = 0)
	--
	SELECT   @ServerName 	  = DBName + '.dbo.'
		,@NameOfDatabase  = DBName
	FROM @ServerDatabaseTables
	WHERE TempTblID = @DBToProcess
	--
	SET @StringToExecute =  'INSERT INTO #ServerDatabaseObjectUsage ' +
			        '(DBName' +
				',ObjectUsedIn' +
				',TypeOfObject' + 
				',IsColumnOfTable) ' +
				'SELECT DISTINCT ' +
				char(39)+@NameOfDatabase+char(39)+ 
				',obj.NAME' + 
				',(CASE obj.XTYPE  WHEN ' + char(39) + 'P' + char(39) + 
						 ' THEN ' + char(39) + 'PROCEDURE' + char(39) +
						 ' WHEN ' + char(39) + 'V' + char(39) + 
						 ' THEN ' + char(39) + 'VIEW' + char(39) +
						 ' WHEN ' + char(39) + 'U' + char(39) + 
						 ' THEN ' + char(39) + 'USER TABLE' + char(39) +
						 ' WHEN ' + char(39) + 'D' + char(39) + 
						 ' THEN ' + char(39) + 'DEFAULT CONSTRAINT' + char(39) +
						 ' WHEN ' + char(39) + 'F' + char(39) + 
						 ' THEN ' + char(39) + 'FOREIGN KEY' + char(39) +
						 ' WHEN ' + char(39) + 'IF' + char(39) + 
						 ' THEN ' + char(39) + 'INLINE TABLE OR FUNCTION' + char(39) +
						 ' WHEN ' + char(39) + 'FN' + char(39) + 
						 ' THEN ' + char(39) + 'SCALAR FUNCTION' + char(39) +
						 ' WHEN ' + char(39) + 'TF' + char(39) + 
						 ' THEN ' + char(39) + 'TABLE FUNCTION' + char(39) +
						 ' ELSE CAST( ' + char(39) + 'UNKNOWN TYPE ' + char(39) + ' + obj.XTYPE AS VARCHAR(50)) END)' +
				',(CASE WHEN (SELECT count(*) FROM '+@ServerName+'syscolumns where name='+char(39)+@ObjectToFind+char(39) + ') > 0 ' +
					'THEN 1 ELSE 0 END)' + 
				'FROM ' + @ServerName + 'sysobjects as obj ' + 
				'LEFT JOIN ' + @ServerName + 'syscomments as helpText ON obj.ID = helpText.ID ' + 
				'LEFT JOIN ' + @ServerName + 'syscolumns as syscol ON syscol.ID = obj.ID ' + 
				'WHERE helpText.Text LIKE ' + char(39) + '%' + ltrim(rtrim(@ObjectToFind)) + '%' + char(39) + 
				' OR syscol.name LIKE '  + char(39) + '%' + ltrim(rtrim(@ObjectToFind)) + '%' + char(39) + 
				' ORDER BY obj.name '
	SET @StringToExecute = LTRIM(RTRIM(@StringToExecute))
	PRINT LEN(@StringToExecute)
	--
	exec sp_executesql @StringToExecute
	--
	IF (@@ERROR != 0) BEGIN
		SET @ReturnCode = 1
		GOTO END_PROCEDURE
	END
	--
	UPDATE @ServerDatabaseTables
	SET Processed = 1
	WHERE TempTblID = @DBToProcess
END
--
SELECT * FROM #ServerDatabaseObjectUsage
--
DROP TABLE #ServerDatabaseObjectUsage
--
SET @ReturnCode = 0

END_PROCEDURE:
	IF (@ReturnCode != 0) BEGIN
		SET @ResultMessage = 'A NON ZERO Return code has occured, Please investigate this problem ' + CAST(@ReturnCode AS VARCHAR(2))
	END ELSE BEGIN
		SET @ResultMessage = 'OK'
	END
RETURN @ReturnCode

