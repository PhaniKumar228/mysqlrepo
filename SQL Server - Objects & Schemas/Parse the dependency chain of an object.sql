/*
Parse the dependency chain of an object

This code works (in SQL 2005), by creating a temp table, #DepTree, and inserting dependency relations into it. it starts with the current object in question, and inserts it into #DepTree at level 0. Then it moves into a loop which will continue as long as an insert was made in the body of the loop. It uses the int identity column of #DepTree to do this.

The dependency parsing goes in both directions - it will report all objects dependent on the one in question, and all objects on which it is dependent. That is the use of the DepLevel column. Positive values represent objects on which the starting one depends, whereas negative ones depend on the starting object. You can think of these as parent/child relations in the dependency chain.

Both of the blocks of code that check @DepLevel will process the one row where @DepLevel = 0, but this is the ONLY value that will be checked in both directions. The reason is that we don't want to go up a level, and then check the objects down from there; we would end up in an infinite cycle moving up and down the dependency chain between the first two objects.

Run it by simply replacing the string 'ENTER_YOUR_OBJECT_NAME_HERE' with the object of interest. Your choice is unrestricted by type (you can enter a table, stored procedure, etc.), but when I wrote this I had in mind reporting on the chain of stored procedure calls.

One important note - if a stored procedure references a second stored procedure that did not exist at the time the first one was created, no entry will be made into the sysdepends table, and the dependency chain will thus be broken. Check out the articles Fixing SysDepends and Finding Real Dependencies for an interesting take on this.

*/

CREATE TABLE #DepTree (ObjNum int identity(1,1) not null, Name varchar(1000), DependsOn varchar(1000), ObjectType char(2), DepLevel smallint)

INSERT INTO #DepTree (Name, DependsOn, ObjectType, DepLevel)
SELECT DependsOn = S.Name, S.Name, ObjectType = S.XType, DepLevel = 0
FROM sys.sysobjects S
WHERE S.Name = 'ENTER_YOUR_OBJECT_NAME_HERE'

DECLARE @Name varchar(1000)
DECLARE @DependsOn varchar(1000)
DECLARE @DepLevel smallint
DECLARE @ObjNum int
SET @ObjNum = 1
WHILE EXISTS(SELECT 1 FROM #DepTree WHERE ObjNum = @ObjNum)
BEGIN
	SELECT @Name = Name, @DependsOn = DependsOn, @DepLevel = DepLevel FROM #DepTree WHERE ObjNum = @ObjNum

	-- this block finds objects that the current object of interest depends on (moving _down_ the dependency chain):
	IF @DepLevel >= 0
		INSERT INTO #DepTree (Name, DependsOn, ObjectType, DepLevel)
		SELECT DISTINCT S1.Name, DependsOn = S2.Name, ObjectType = S2.XType, DepLevel = @DepLevel + 1
		FROM sys.sysdepends DP
		JOIN sys.sysobjects S1 ON S1.ID = DP.ID
		JOIN sys.sysobjects S2 ON S2.ID = DP.DepID
		WHERE S1.Name = @DependsOn
		ORDER BY 1, 3, 2

	-- this block finds objects that depend on the current object of interest (moving _up_ the dependency chain):
	IF @DepLevel <= 0
		INSERT INTO #DepTree (Name, DependsOn, ObjectType, DepLevel)
		SELECT DISTINCT S2.Name, DependsOn = S1.Name, ObjectType = S2.XType, DepLevel = @DepLevel - 1
		FROM sys.sysdepends DP
		JOIN sys.sysobjects S1 ON S1.ID = DP.DepID
		JOIN sys.sysobjects S2 ON S2.ID = DP.ID
		WHERE S1.Name = @Name
		ORDER BY 1, 3, 2

	SET @ObjNum = @ObjNum + 1
END

SELECT * FROM #DepTree
DROP TABLE #DepTree

