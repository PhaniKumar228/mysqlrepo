USE Master
GO
IF EXISTS (SELECT * FROM sysobjects WHERE name = 'sp_who3' AND xtype = 'P')
DROP PROCEDURE sp_who3
GO
CREATE PROCEDURE sp_who3
@spid INT = NULL,
@Login SYSNAME = NULL,
@HostName VARCHAR(30) = NULL,
@DBName SYSNAME = NULL
AS
SET NOCOUNT ON

/* Crea la tabla temporal que guarda la salida del sp_who2 */
CREATE TABLE #tmp_who2
(spid INT NOT NULL,
STATUS VARCHAR(60) NULL,
Login SYSNAME NULL,
HostName VARCHAR(50) NULL,
BlkBy VARCHAR(10) NULL,
DBName SYSNAME NULL,
Command VARCHAR(300) NULL,
CPUTime INT NULL,
DISKIO INT NULL,
LastBatch VARCHAR(100) NULL,
ProgramName VARCHAR(300) NULL,
spid2 INT NOT NULL)


/* Llena la tabla */
INSERT INTO #tmp_who2
EXEC sp_who2

IF @@ROWCOUNT = 0
BEGIN
	RAISERROR ('No se pudo capturar la informacion del sp_who2.', 16, 1)
	RETURN -1
END


DECLARE @I AS INT,
	@strWhere AS VARCHAR(1000),
	@strSelect AS VARCHAR(1000)

SELECT @I = 0
SELECT @strWhere = NULL

/* Evalua si se le ingresa un spid */
IF @spid IS NOT NULL
BEGIN
	/* si no es numerico sale con error */
	IF ISNUMERIC(@spid) <> 1
	BEGIN
		RAISERROR ('El spid ingresado no es numerico.', 16, 1)
		RETURN -1
	END

	/* Significa que es el primer filtro */
	IF @I = 0
		SELECT @strWhere = ' spid = ' + CONVERT(VARCHAR,@spid)
	ELSE
		SELECT @strWhere = @strWhere + ' AND spid = ' + CONVERT(VARCHAR,@spid)

	SELECT @I = 1		

	/* Si le agrego el spid si o si me tiene que devolver un solo registro, entonces calculo eh INPUTBUFFER */
	DBCC INPUTBUFFER(@spid)
END

/* Evalua si se le ingresa un login */
IF @Login IS NOT NULL
BEGIN
	/* Chequea que exista el login */
	IF NOT EXISTS (SELECT name FROM master.dbo.sysxlogins 	WHERE name = @Login)
	BEGIN
		RAISERROR ('El Login especificado no existe.', 16, 1)
		RETURN -1
	END

	/* Significa que es el primer filtro */
	IF @I = 0
		SELECT @strWhere = ' Login = ' + '''' + CONVERT(VARCHAR,@Login) + ''''
	ELSE
		SELECT @strWhere = @strWhere + ' AND Login = ' + '''' +CONVERT(VARCHAR,@Login) + ''''

	SELECT @I = 1		
	
END

/* Evalua si se le ingresa un HostName */
IF @HostName IS NOT NULL
BEGIN
	/* Significa que es el primer filtro */
	IF @I = 0
		SELECT @strWhere = ' HostName = ' + '''' + CONVERT(VARCHAR,@HostName) + ''''
	ELSE
		SELECT @strWhere = @strWhere + ' AND HostName = ' + '''' + CONVERT(VARCHAR,@HostName) + ''''

	SELECT @I = 1		
	
END


/* Evalua si se le ingresa un HostName */
IF @DBName IS NOT NULL
BEGIN
	/* Chequea que exista la base */
	IF NOT EXISTS ( SELECT * FROM master.dbo.sysdatabases WHERE name = @DBName)
	BEGIN
		RAISERROR ('La base de datos especificada no existe.', 16, 1)
		RETURN -1
	END

	/* Significa que es el primer filtro */
	IF @I = 0
		SELECT @strWhere = ' DBName = ' + '''' + CONVERT(VARCHAR,@DBName) + ''''
	ELSE
		SELECT @strWhere = @strWhere + ' AND DBName = ' + '''' + CONVERT(VARCHAR,@DBName) + ''''

	SELECT @I = 1		
	
END


/* Arma la sentencia del select de la tabla temporal incluyendo o no el where */
SELECT @strSelect = 'SELECT * FROM #tmp_who2 '

IF @strWhere IS NOT NULL
SELECT @strSelect = @strSelect + ' WHERE ' + @strWhere

EXEC (@strSelect)
