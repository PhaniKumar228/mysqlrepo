/*
Function to desencrypt passwords

With this function you can recover from your table all the password save encripted with another function posted before (check this site to find the script). 
The function recieves an encripted password and changes every character to return the right password. 
*/
IF EXISTS (SELECT * FROM sysobjects WHERE name = 'fn_DesEncriptar' AND xtype = 'FN')
DROP FUNCTION dbo.fn_DesEncriptar
GO
CREATE FUNCTION dbo.fn_DesEncriptar
(@Password VARCHAR(100))
RETURNS VARCHAR(20)
WITH ENCRYPTION 
AS
/*
** Ultima Modificacion --
** Desencript the password
*/
BEGIN
	DECLARE @I AS INT,
		@Letra AS CHAR(1),
		@PassWordDes AS VARCHAR(20),
		@LenPass AS INT

	SELECT @I = 1
	SELECT @LenPass = LEN(@Password)
	SELECT @PassWordDes = ''

	/* Aca necesito dar vuelta la password, antes de comenzar, ya que al encriptarla, esto fue lo ultimo que hice */
	SELECT @PassWord = REVERSE(@PassWord)

	/* entro en el loop */
	WHILE @I < @LenPass + 1
	BEGIN		
		/* desencripto la letra */
		SELECT @Letra = CONVERT(CHAR(1),CHAR(CONVERT(INT,ASCII(SUBSTRING(@Password, @I, @I + 1))) -3))

		/* se la apendeo a la contraseña */
		SELECT @PassWordDes = @PassWordDes + ISNULL(@Letra, '0')

		/* aumento el contador */
		SELECT @I = @I + 1
	END
	
	/* devuelve la contraseña sin encriptar */
	RETURN @PassWordDes
END
