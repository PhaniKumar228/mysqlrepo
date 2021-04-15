/*
UDF Random Password Generator

UDF Random Password Generator

You can not use the RAND function directly from a User Defined Function. 
So the UDF I wrote "fn_RandomPassword" uses the view "view_RandomPassword8" 
to get the random charaters.

Having the random password generator is useful if you need to insert 
a large number of users into a table with random passwords assigned.

For example ..

INSERT INTO User_Table
( UserLogin, UserPassword )
SELECT UserLogin, dbo.fn_RandomPassword() as UserPassword
FROM Import_Users_Table

.. all the users from the import table could be inserted 
with random passwords very easily. 

*/

/*


You can not use the RAND function directly from a User Defined Function. 
So the UDF I wrote "fn_RandomPassword" uses the view "view_RandomPassword8" 
to get the random charaters.

Having the random password generator is useful if you need to insert 
a large number of users into a table with random passwords assigned.

For example ..

INSERT INTO User_Table
( UserLogin, UserPassword )
SELECT UserLogin, dbo.fn_RandomPassword() as UserPassword
FROM Import_Users_Table

.. all the users from the import table could be inserted 
with random passwords very easily.

*/


-------------------------------------------------------------------
-- Get a random 8 charater password that always starts with a letter
--
-- Select RandomPassword From view_RandomPassword8
-------------------------------------------------------------------
CREATE VIEW view_RandomPassword8 AS 
-- select * from view_RandomPassword8
SELECT
	CASE ROUND(1 + (RAND() * (1)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	ELSE CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	END 
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END
	+
	CASE ROUND(1 + (RAND() * (2)),0)
	WHEN 1 THEN CHAR(ROUND(97 + (RAND() * (25)),0)) -- get random lower case
	WHEN 2 THEN CHAR(ROUND(65 + (RAND() * (25)),0)) -- get random upper case
	ELSE CHAR(ROUND(48 + (RAND() * (9)),0)) -- get random number
	END

	as RandomPassword

GO


-------------------------------------------------------------------
-- Get a random 8 charater password that always starts with a letter
--
-- PRINT dbo.fn_RandomPassword()
-------------------------------------------------------------------
CREATE FUNCTION dbo.fn_RandomPassword()
RETURNS varchar(8)
AS
BEGIN
	DECLARE @RandomPassword varchar(8)

	SELECT @RandomPassword = RandomPassword
	FROM view_RandomPassword8

	RETURN @RandomPassword

END
GO


