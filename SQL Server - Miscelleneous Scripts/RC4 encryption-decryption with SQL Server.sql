CREATE FUNCTION dbo.fnInitRc4
(
	@Pwd VARCHAR(256)
)
RETURNS @Box TABLE (i TINYINT, v TINYINT)
AS

BEGIN
	DECLARE	@Key TABLE (i TINYINT, v TINYINT)

	DECLARE	@Index SMALLINT,
		@PwdLen TINYINT

	SELECT	@Index = 0,
		@PwdLen = LEN(@Pwd)

	WHILE @Index <= 255
		BEGIN
			INSERT	@Key
				(
					i,
					v
				)
			VALUES	(
					@Index,
					 ASCII(SUBSTRING(@Pwd, @Index % @PwdLen + 1, 1))
				)

			INSERT	@Box
				(
					i,
					v
				)
			VALUES	(
					@Index,
					@Index
				)

			SELECT	@Index = @Index + 1
		END


	DECLARE	@t TINYINT,
		@b SMALLINT

	SELECT	@Index = 0,
		@b = 0

	WHILE @Index <= 255
		BEGIN
			SELECT		@b = (@b + b.v + k.v) % 256
			FROM		@Box AS b
			INNER JOIN	@Key AS k ON k.i = b.i
			WHERE		b.i = @Index

			SELECT	@t = v
			FROM	@Box
			WHERE	i = @Index

			UPDATE	b1
			SET	b1.v = (SELECT b2.v FROM @Box b2 WHERE b2.i = @b)
			FROM	@Box b1
			WHERE	b1.i = @Index

			UPDATE	@Box
			SET	v = @t
			WHERE	i = @b

			SELECT	@Index = @Index + 1
		END

	RETURN
END
GO
CREATE FUNCTION dbo.fnEncDecRc4
(
	@Pwd VARCHAR(256),
	@Text VARCHAR(8000)
)
RETURNS	VARCHAR(8000)
AS

BEGIN
	DECLARE	@Box TABLE (i TINYINT, v TINYINT)

	INSERT	@Box
		(
			i,
			v
		)
	SELECT	i,
		v
	FROM	dbo.fnInitRc4(@Pwd)

	DECLARE	@Index SMALLINT,
		@i SMALLINT,
		@j SMALLINT,
		@t TINYINT,
		@k SMALLINT,
      		@CipherBy TINYINT,
      		@Cipher VARCHAR(8000)

	SELECT	@Index = 1,
		@i = 0,
		@j = 0,
		@Cipher = ''

	WHILE @Index <= DATALENGTH(@Text)
		BEGIN
			SELECT	@i = (@i + 1) % 256

			SELECT	@j = (@j + b.v) % 256
			FROM	@Box b
			WHERE	b.i = @i

			SELECT	@t = v
			FROM	@Box
			WHERE	i = @i

			UPDATE	b
			SET	b.v = (SELECT w.v FROM @Box w WHERE w.i = @j)
			FROM	@Box b
			WHERE	b.i = @i

			UPDATE	@Box
			SET	v = @t
			WHERE	i = @j

			SELECT	@k = v
			FROM	@Box
			WHERE	i = @i

			SELECT	@k = (@k + v) % 256
			FROM	@Box
			WHERE	i = @j

			SELECT	@k = v
			FROM	@Box
			WHERE	i = @k

			SELECT	@CipherBy = ASCII(SUBSTRING(@Text, @Index, 1)) ^ @k,
				@Cipher = @Cipher + CHAR(@CipherBy)

			SELECT	@Index = @Index  +1
      		END

	RETURN	@Cipher
END
