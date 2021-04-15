--Detect server wide roles assigned to users - sysadmins and other roles - works with both SQL 2000 and 2005

USE master

--Sysadmins

SELECT 
	name AS Login, 
	sysadmin =
	CASE
		WHEN sysadmin = 1 THEN 'X'
		ELSE ''
	END,  
	securityadmin =
	CASE
		WHEN securityadmin = 1 THEN 'X'
		ELSE ''
	END, 
	serveradmin =
	CASE
		WHEN serveradmin = 1 THEN 'X'
		ELSE ''
	END,
	setupadmin =
	CASE
		WHEN setupadmin = 1 THEN 'X'
		ELSE ''
	END,
	processadmin =
	CASE
		WHEN processadmin = 1 THEN 'X'
		ELSE ''
	END,
	diskadmin =
	CASE
		WHEN diskadmin = 1 THEN 'X'
		ELSE ''
	END,
	dbcreator =
	CASE
		WHEN dbcreator = 1 THEN 'X'
		ELSE ''
	END,
	bulkadmin =
	CASE
		WHEN bulkadmin = 1 THEN 'X'
		ELSE ''
	END,
	CONVERT(CHAR(16),createdate,120) AS 'DateCreated' 
FROM master.dbo.syslogins 
WHERE 
	sysadmin = 1
ORDER BY NAME

GO
	
--Any other server-wide role, not including ones in the first list above. Works with both SQL 2000 and 2005

SELECT 
	name AS Login, 
	securityadmin =
	CASE
		WHEN securityadmin = 1 THEN 'X'
		ELSE ''
	END, 
	serveradmin =
	CASE
		WHEN serveradmin = 1 THEN 'X'
		ELSE ''
	END,
	setupadmin =
	CASE
		WHEN setupadmin = 1 THEN 'X'
		ELSE ''
	END,
	processadmin =
	CASE
		WHEN processadmin = 1 THEN 'X'
		ELSE ''
	END,
	diskadmin =
	CASE
		WHEN diskadmin = 1 THEN 'X'
		ELSE ''
	END,
	dbcreator =
	CASE
		WHEN dbcreator = 1 THEN 'X'
		ELSE ''
	END,
	bulkadmin =
	CASE
		WHEN bulkadmin = 1 THEN 'X'
		ELSE ''
	END,
	CONVERT(CHAR(16),createdate,120) AS 'DateCreated' 
FROM master.dbo.syslogins 
WHERE 
	(securityadmin = 1
	OR serveradmin = 1
	OR setupadmin = 1
	OR processadmin = 1
	OR diskadmin = 1
	OR dbcreator = 1
	OR bulkadmin = 1)
	AND sysadmin <> 1
ORDER BY NAME

USE master
GO

--Blank or easily guessed passwords. Works with both SQL 2000 and 2005.
IF OBJECT_ID('dbo.spAuditPasswords') IS NOT NULL 
	DROP PROCEDURE dbo.spAuditPasswords
GO

CREATE PROCEDURE dbo.spAuditPasswords

AS 

/* 

Purpose: Perform a simple audit of user's passwords
Location: master database
Output Parameters: None
Return Status: None
Called By: None 
Calls: None
Data Modifications: None
Updates: None 
Date Author Purpose 

*/ 

SET NOCOUNT ON 

--Variables 
DECLARE @lngCounter INTEGER
DECLARE @lngCounter1 INTEGER
DECLARE @lngLogCount INTEGER
DECLARE @strName VARCHAR(256)

--Create table to hold SQL logins 
CREATE TABLE #tLogins
(
numID INTEGER IDENTITY(1,1)
,strLogin sysname NULL 
,lngPass integer NULL 
,Password varchar(500) NULL
,Type int NULL
)

--Insert non ntuser into temp table 
INSERT INTO #tLogins (strLogin)
SELECT name FROM master.dbo.syslogins WHERE isntname = 0
SET @lngLogCount = @@ROWCOUNT 

--Determine if password and name are the ssame 
SET @lngCounter = @lngLogCount

WHILE @lngCounter <> 0
BEGIN 
    SET @strName = (SELECT strLogin FROM #tLogins WHERE numID = @lngCounter)

    UPDATE #tLogins
    SET 
		lngPass = (SELECT PWDCOMPARE (@strName,(SELECT password FROM master.dbo.syslogins WHERE name = @strName))), 
		Type = 
		CASE 
			WHEN (SELECT PWDCOMPARE (@strName,(SELECT password FROM master.dbo.syslogins WHERE name = @strName))) = 1 THEN 2 -- Password same as login
			ELSE NULL
		END		
    WHERE numID = @lngCounter
    AND Type IS NULL

    SET @lngCounter = @lngCounter - 1
END 

--Reset column for next password test 
UPDATE #tLogins
SET lngPass = 0

--Determine if password is only one character long 
SET @lngCounter = @lngLogCount

WHILE @lngCounter <> 0
BEGIN 
    SET @lngCounter1 = 1
    SET @strName = (SELECT strLogin FROM #tLogins WHERE numID = @lngCounter)
    WHILE @lngCounter1 < 256
    BEGIN 
        UPDATE #tLogins
        SET lngPass = (SELECT PWDCOMPARE (CHAR(@lngCounter1),(SELECT password FROM master.dbo.syslogins WHERE name = @strName))), Password = UPPER(CHAR(@lngCounter1)) + ' or ' + LOWER(CHAR(@lngCounter1)), 
		Type = 
		CASE 
			WHEN (SELECT PWDCOMPARE (CHAR(@lngCounter1),(SELECT password FROM master.dbo.syslogins WHERE name = @strName))) = 1 THEN 3 --password is only one character long 
			ELSE NULL
		END
        WHERE numID = @lngCounter
        AND lngPass <> 1
        AND Type IS NULL
        
        SET @lngCounter1 = @lngCounter1 + 1
        
    END 

    SET @lngCounter = @lngCounter - 1
END 

--Return combined results
SELECT name AS 'Login Name', Passsword = '(BLANK)' FROM master.dbo.syslogins 
WHERE password IS NULL 
AND isntname = 0
	UNION ALL
SELECT strLogin AS 'Login Name', Password = strLogin FROM #tLogins WHERE Type = 2
	UNION ALL
SELECT 'Login Name' = strLogin, Password FROM #tLogins WHERE Type = 3
ORDER BY name

GO


--Detect disabled or deleted Windows logins; works with both SQL 2000 and 2005

USE master

EXEC sp_validatelogins

GO

--Detect logins created in last 30 days
SELECT 
	name AS 'Login Name',
	CONVERT(CHAR(16),createdate,120) AS 'Date Created' 
FROM master.dbo.syslogins 
WHERE createdate >= DATEADD(dd,-30,GETDATE()) 
ORDER BY createdate DESC

GO

--Detect orphan users in all dbs on a SQL instance; works in both SQL 2000 and 2005.
USE master
GO

IF OBJECT_ID('rpt_security_detect_db_orphans') IS NOT NULL
	DROP PROCEDURE [dbo].[rpt_security_detect_db_orphans]
GO

CREATE PROCEDURE dbo.rpt_security_detect_db_orphans

AS

/*

	NE 6/11/2007 - Detect orphan users in all dbs on a SQL instance; works in both SQL 2000 and 2005.
	
	EXEC rpt_security_detect_db_orphans

*/

DECLARE 
	@dbname varchar(200),
	@sql varchar(8000)

DECLARE @temp table
(
	dbname VARCHAR(500)
)

CREATE TABLE #dbOrphanUsers
(
	DbName varchar(500),
	[User] varchar(500)
)

INSERT INTO @temp
	SELECT name 
	FROM sysdatabases
	WHERE 
		category IN ('0', '1','16')
		AND 
		name NOT IN ('tempdb', 'model', 'pubs', 'northwind')
		AND 
		name NOT LIKE 'adventurework%' 
		AND DATABASEPROPERTYEX(name, 'status') = 'ONLINE'
	ORDER BY name

SELECT @dbname = MIN(dbname) FROM @temp

WHILE @dbname IS NOT NULL
BEGIN
	
	SET @sql =
	'INSERT INTO #dbOrphanUsers
	(DbName, [User])
	SELECT DbName = ''' + @dbname + ''', name AS [User]
	FROM [' + @dbname + '].dbo.sysusers 
	WHERE 
		issqluser = 1 
		and (sid is not null 
		and sid <> 0x0) 
		and suser_sname(sid) is null'
		
	EXEC(@sql)	
	
	SELECT @dbname = MIN(dbname) FROM @temp WHERE dbname > @dbname

END

SELECT * FROM #dbOrphanUsers ORDER BY DbName, [User]

DROP TABLE #dbOrphanUsers

GO

-- Detect User permissions for all databases and users - SQL 2000 version only
-- Also incuded below is a modified version of sp_helprotect (named as sp_helprotect2) to be called by this.

USE master
GO

IF OBJECT_ID('rpt_security_detect_user_permissions_2000') IS NOT NULL
	DROP PROCEDURE [dbo].[rpt_security_detect_user_permissions_2000]
GO

CREATE PROCEDURE dbo.rpt_security_detect_user_permissions_2000

AS

/*

	Detect User permissions for all databases and users - SQL 2000 version only.
	
	EXEC rpt_security_detect_user_permissions_2000

*/

SET NOCOUNT ON

CREATE TABLE #Permissions (dbname varchar(500), UserName varchar(500), owner varchar(500),object varchar(500),Grantee varchar(500),Grantor varchar(500),ProtectType varchar(500),Act varchar(500),Col varchar(50))

CREATE TABLE #Roles (dbname varchar(500), UserName varchar(500),GroupName varchar(500),LoginName varchar(500),DefDBName varchar(500),UserID varchar(500),SID varchar(50))

DECLARE 
	@dbname varchar(200),
	@sql varchar(8000)

DECLARE @temp table
(
	dbname VARCHAR(500)
)

INSERT INTO @temp
	SELECT name 
	FROM master.dbo.sysdatabases WITH (NOLOCK)
	WHERE 
		category IN ('0', '1','16')
		AND 
		name NOT IN ('tempdb', 'model', 'pubs', 'northwind')
		AND 
		name NOT LIKE 'adventurework%' 
		AND DATABASEPROPERTYEX(name, 'status') = 'ONLINE'
	ORDER BY name

SELECT @dbname = MIN(dbname) FROM @temp

WHILE @dbname IS NOT NULL
BEGIN
	
	SET @sql =
	'use [' + @dbname + '];
	declare @users table([User] varchar(500));
	declare @currUser varchar(500);
	insert into @users

	SELECT [name] 
	FROM [' + @dbname + '].dbo.sysusers WITH (NOLOCK)
	WHERE hasdbaccess = 1 AND [name] <> ''dbo''

	SELECT @currUser = min([User]) from @users;
	WHILE @currUser IS NOT NULL
	BEGIN
		insert into #Permissions
		(owner, object, Grantee, Grantor, ProtectType, Act ,Col)
		exec sp_helprotect2 @username = @currUser
		insert into #Roles
		(UserName, GroupName, LoginName, DefDBName, UserID, SID)
		exec sp_helpuser @name_in_db = @currUser
		
		update #Permissions set dbname = ''' + @dbname + ''', UserName = @currUser where dbname is null
		update #Roles set dbname = ''' + @dbname + ''' where dbname is null
		
		select @currUser = min([User]) from @users where [User] > @currUser
	END'
		
	EXEC(@sql)	
	
	SELECT @dbname = MIN(dbname) FROM @temp WHERE dbname > @dbname
END

SELECT 
	dbname AS DB_Name, 
	UserName, 
	'Permissions' = 'SP_AddRoleMember ''' + RTRIM(GroupName)+''', '''+ RTRIM(UserName)+'''' 
FROM #Roles  
UNION 
SELECT 
	dbname AS DB_Name, 
	UserName, 
	UPPER(RTRIM(ProtectType))+' '+UPPER(RTRIM(Act))+' ON ['+owner+'].['+object+']'+ 
	CASE 
		WHEN (PATINDEX('%All%', Col)=0) AND (Col <> '.') THEN ' ('+Col+')' 
		ELSE '' 
	END
	 + ' TO ['+Grantee+']' 
FROM #Permissions 
ORDER BY dbname, UserName, Permissions DESC

drop table #Permissions
drop table #Roles

GO

-------------------

--Modified version of sp_helprotect (named as sp_helprotect2) - must be used with the SQL 2000 only version above...

USE master
GO

IF OBJECT_ID('sp_helprotect2') IS NOT NULL
	DROP PROCEDURE dbo.sp_helprotect2
GO

CREATE PROCEDURE dbo.sp_helprotect2
	@name				ncharacter varying(776)  = NULL
	,@username			sysname  = NULL
	,@grantorname		sysname  = NULL
	,@permissionarea	character varying(10)  = 'o s'
as

/********
Explanation of the parms...
---------------------------
@name:  Name of [Owner.]Object and Statement; meaning
for sysprotects.id and sysprotects.action at the
same time; thus see parm @permissionarea.
   Examples-   'user2.tb'  , 'CREATE TABLE', null

@username:  Name of the grantee (for sysprotects.uid).
   Examples-   'user2', null

@grantorname:  Name of the grantor (for sysprotects.grantor).
   Examples-   'user2' --Would prevent report rows which would
                       --  have 'dbo' as grantor.

@permissionarea:  O=Object, S=Statement; include all which apply.
   Examples-   'o'  , ',s'  , 'os'  , 'so'  , 's o'  , 's,o'
GeneMi
********/

	Set nocount on

	Declare
	@vc1                   sysname
	,@Int1                  integer

	Declare
	@charMaxLenOwner		character varying(11)
	,@charMaxLenObject		character varying(11)
	,@charMaxLenGrantee		character varying(11)
	,@charMaxLenGrantor		character varying(11)
	,@charMaxLenAction		character varying(11)
	,@charMaxLenColumnName	character varying(11)

	Declare
	@OwnerName				sysname
	,@ObjectStatementName	sysname


	/* Perform temp table DDL here to minimize compilation costs*/
CREATE Table #t1_Prots
	(	Id					int				Null
		,Type1Code			char(6)			collate database_default NOT Null
		,ObjType			char(2)			collate database_default Null

		,ActionName		varchar(20)			collate database_default Null
		,ActionCategory	char(2)				collate database_default Null
		,ProtectTypeName	char(10)		collate database_default Null

		,Columns_Orig		varbinary(32)	Null

		,OwnerName			sysname			collate database_default NOT Null
		,ObjectName			sysname			collate database_default NOT Null
		,GranteeName		sysname			collate database_default NOT Null
		,GrantorName		sysname			collate database_default NOT Null

		,ColumnName			sysname			collate database_default Null
		,ColId				smallint		Null

		,Max_ColId			smallint		Null
		,All_Col_Bits_On	tinyint			Null
		,new_Bit_On			tinyint			Null )  -- 1=yes on


	/*	Check for valid @permissionarea */
	Select @permissionarea = upper( isnull(@permissionarea,'?') )

	IF (	charindex('O',@permissionarea) <= 0
		AND  charindex('S',@permissionarea) <= 0)
	begin
		raiserror(15300,-1,-1 ,@permissionarea,'o,s')
		return (1)
	end

	select @vc1 = parsename(@name,3)

	/* Verified db qualifier is current db*/
	IF (@vc1 is not null and @vc1 <> db_name())
	begin
		raiserror(15302,-1,-1)  --Do not qualify with DB name.
		return (1)
	end

	/*  Derive OwnerName and @ObjectStatementName*/
	select	@OwnerName				=	parsename(@name, 2)
			,@ObjectStatementName	=	parsename(@name, 1)

	IF (@ObjectStatementName is NULL and @name is not null)
	begin
		raiserror(15253,-1,-1,@name)
		return (1)
	end

	/*	Copy info from sysprotects for processing	*/
	IF charindex('O',@permissionarea) > 0
	begin
		/*	Copy info for objects	*/
		INSERT	#t1_Prots
        (	Id
			,Type1Code

			,ObjType
			,ActionName
			,ActionCategory
			,ProtectTypeName

			,Columns_Orig
			,OwnerName
			,ObjectName
			,GranteeName

			,GrantorName
			,ColumnName
            ,ColId

			,Max_ColId
			,All_Col_Bits_On
			,new_Bit_On	)

	/*	1Regul indicates action can be at column level,
		2Simpl indicates action is at the object level */
		SELECT	id
				,case
					when columns is null then '2Simpl'
					else '1Regul'
				end

				,Null
				,val1.name
				,'Ob'
				,val2.name

				,columns
				,user_name(objectproperty( id, 'ownerid' ))
				,object_name(id)
				,user_name(uid)

				,user_name(grantor)
				,case
					when columns is null then '.'
					else Null
				end
				,-123

				,Null
				,Null
				,Null
		FROM	sysprotects sysp
				,master.dbo.spt_values  val1
				,master.dbo.spt_values  val2
		where	(@OwnerName is null or user_name(objectproperty( id, 'ownerid' )) = @OwnerName)
		and	(@ObjectStatementName is null or object_name(id) =  @ObjectStatementName)
		and	(@username is null or user_name(uid) =  @username)
		and	(@grantorname is null or user_name(grantor) =  @grantorname)
		and	val1.type     = 'T'
		and	val1.number   = sysp.action
		and	val2.type     = 'T' --T is overloaded.
		and	val2.number   = sysp.protecttype
		and sysp.id != 0


		IF EXISTS (SELECT * From #t1_Prots)
		begin
			UPDATE	#t1_Prots set ObjType = ob.xtype
			FROM	sysobjects    ob
			WHERE	ob.id	=  #t1_Prots.Id


			UPDATE 	#t1_Prots
			set		Max_ColId = (select max(colid) from syscolumns sysc
								where #t1_Prots.Id = sysc.id)	-- colid may not consecutive if column dropped
			where Type1Code = '1Regul'


			/*	First bit set indicates actions pretains to new columns. (i.e. table-level permission)
				Set new_Bit_On accordinglly							*/
			UPDATE	#t1_Prots SET new_Bit_On =
			CASE	convert(int,substring(Columns_Orig,1,1)) & 1
				WHEN	1 then	1
				ELSE	0
			END
			WHERE	ObjType	<> 'V'	and	 Type1Code = '1Regul'


			/* Views don't get new columns	*/
			UPDATE #t1_Prots set new_Bit_On = 0
			WHERE  ObjType = 'V'


			/*	Indicate enties where column level action pretains to all
				columns in table All_Col_Bits_On = 1					*/
			UPDATE	#t1_Prots	set		All_Col_Bits_On = 1
			where	#t1_Prots.Type1Code	 =  '1Regul'
			and	not exists 
				(select *
				from syscolumns sysc, master..spt_values v
				where #t1_Prots.Id = sysc.id and sysc.colid = v.number
				and v.number <= Max_ColId		-- column may be dropped/added after Max_ColId snap-shot 
				and v.type = 'P' and
			/*	Columns_Orig where first byte is 1 means off means on and on mean off
				where first byte is 0 means off means off and on mean on	*/
					case convert(int,substring(#t1_Prots.Columns_Orig, 1, 1)) & 1
						when 0 then convert(tinyint, substring(#t1_Prots.Columns_Orig, v.low, 1))
						else (~convert(tinyint, isnull(substring(#t1_Prots.Columns_Orig, v.low, 1),0)))
					end & v.high = 0)


			/* Indicate entries where column level action pretains to
				only some of columns in table  All_Col_Bits_On  =  0*/
			UPDATE	#t1_Prots	set  All_Col_Bits_On  =  0
			WHERE	#t1_Prots.Type1Code  =  '1Regul'
			and	All_Col_Bits_On  is  null


			Update #t1_Prots
			set ColumnName  =
			case
				when All_Col_Bits_On = 1 and new_Bit_On = 1 then '(All+New)'
				when All_Col_Bits_On = 1 and new_Bit_On = 0 then '(All)'
				when All_Col_Bits_On = 0 and new_Bit_On = 1 then '(New)'
			end
			from	#t1_Prots
			where	ObjType    IN ('S ' ,'U ', 'V ')
			and	Type1Code = '1Regul'
			and   NOT (All_Col_Bits_On = 0 and new_Bit_On = 0)


			/* Expand and Insert individual column permission rows */
			INSERT	into   #t1_Prots
				(Id
				,Type1Code
				,ObjType
				,ActionName

				,ActionCategory
				,ProtectTypeName
				,OwnerName
				,ObjectName

				,GranteeName
				,GrantorName
				,ColumnName
				,ColId	)
		   SELECT	prot1.Id
					,'1Regul'
					,ObjType
					,ActionName

					,ActionCategory
					,ProtectTypeName
					,OwnerName
					,ObjectName

					,GranteeName
					,GrantorName
					,col_name ( prot1.Id ,val1.number )
					,val1.number
			from	#t1_Prots              prot1
					,master.dbo.spt_values  val1
					,syscolumns sysc
			where	prot1.ObjType    IN ('S ' ,'U ' ,'V ')
				and	prot1.All_Col_Bits_On = 0
				and prot1.Id	= sysc.id
				and	val1.type   = 'P'
				and	val1.number = sysc.colid
				and
				case convert(int,substring(prot1.Columns_Orig, 1, 1)) & 1
					when 0 then convert(tinyint, substring(prot1.Columns_Orig, val1.low, 1))
					else (~convert(tinyint, isnull(substring(prot1.Columns_Orig, val1.low, 1),0)))
				end & val1.high <> 0

			delete from #t1_Prots
					where	ObjType    IN ('S ' ,'U ' ,'V ')
							and	All_Col_Bits_On = 0
							and new_Bit_On = 0
		end
	end


	/* Handle statement permissions here*/
	IF (charindex('S',@permissionarea) > 0)
	begin
	   /*	All statement permissions are 2Simpl */
		INSERT	#t1_Prots
			 (	Id
				,Type1Code
				,ObjType
				,ActionName

				,ActionCategory
				,ProtectTypeName
				,Columns_Orig
				,OwnerName

				,ObjectName
				,GranteeName
				,GrantorName
				,ColumnName

				,ColId
				,Max_ColId
				,All_Col_Bits_On
				,new_Bit_On	)
		SELECT	id
				,'2Simpl'
				,Null
				,val1.name

				,'St'
				,val2.name
				,columns
				,'.'

				,'.'
				,user_name(sysp.uid)
				,user_name(sysp.grantor)
				,'.'
				,-123

				,Null
				,Null
				,Null
		FROM	sysprotects				sysp
				,master.dbo.spt_values	val1
				,master.dbo.spt_values  val2
		where	(@username is null or user_name(sysp.uid) = @username)
			and	(@grantorname is null or user_name(sysp.grantor) = @grantorname)
			and	val1.type     = 'T'
			and	val1.number   =  sysp.action
			and	(@ObjectStatementName is null or val1.name = @ObjectStatementName)
			and	val2.number   = sysp.protecttype
			and	val2.type     = 'T'
			and sysp.id = 0
	end


	IF NOT EXISTS (SELECT * From #t1_Prots)
	begin
-- Commented out by NE - 6/12/2007
--		raiserror(15330,-1,-1)
		return (1)
	end


	/*	Calculate dynamic display col widths		*/
	SELECT
	@charMaxLenOwner       =
		convert ( varchar, max(datalength(OwnerName)))

	,@charMaxLenObject      =
		convert ( varchar, max(datalength(ObjectName)))

	,@charMaxLenGrantee     =
		convert ( varchar, max(datalength(GranteeName)))

	,@charMaxLenGrantor     =
		convert ( varchar, max(datalength(GrantorName)))

	,@charMaxLenAction      =
		convert ( varchar, max(datalength(ActionName)))

	,@charMaxLenColumnName  =
		convert ( varchar, max(datalength(ColumnName)))
	from	#t1_Prots


/*  Output the report	*/
EXECUTE(
'Set nocount off

SELECT	''Owner''		= substring (OwnerName   ,1 ,' + @charMaxLenOwner   + ')

		,''Object''		= substring (ObjectName  ,1 ,' + @charMaxLenObject  + ')

		,''Grantee''	= substring (GranteeName ,1 ,' + @charMaxLenGrantee + ')

		,''Grantor''	= substring (GrantorName ,1 ,' + @charMaxLenGrantor + ')

		,''ProtectType''= ProtectTypeName

		,''Action''		= substring (ActionName ,1 ,' + @charMaxLenAction + ')

		,''Column''		= substring (ColumnName ,1 ,' + @charMaxLenColumnName + ')
   from	#t1_Prots
   order by
		ActionCategory
		,Owner				,Object
		,Grantee			,Grantor
		,ProtectType		,Action
		,ColId  --Multiple  -123s  ( <0 )  possible

Set nocount on'
)

Return (0) -- sp_helprotect2

GO


-- Detect User permissions for all databases and users - SQL 2005 version only
-- Don't need modified version of sp_helprotect (named as sp_helprotect2) in SQL 2005.

USE master
GO

IF OBJECT_ID('rpt_security_detect_user_permissions_2005') IS NOT NULL
	DROP PROCEDURE [dbo].[rpt_security_detect_user_permissions_2005]
GO

CREATE PROCEDURE dbo.rpt_security_detect_user_permissions_2005

AS

/*

	Detect User permissions for all databases and users - SQL 2005 version only.
	
	EXEC rpt_security_detect_user_permissions_2005

*/

SET NOCOUNT ON

CREATE TABLE #Permissions (dbName varchar(500), UserName varchar(500), owner varchar(500),object varchar(500),Grantee varchar(500),Grantor varchar(500),ProtectType varchar(500),Act varchar(500),Col varchar(500))

CREATE TABLE #Roles (dbName varchar(500), UserName varchar(500),GroupName varchar(500),LoginName varchar(500),DefDBName varchar(500), DefSchemaName varchar(500), UserID varchar(500),SID varchar(50))

DECLARE 
	@dbname varchar(500),
	@sql varchar(8000)

DECLARE @temp table
(
	dbname VARCHAR(500)
)

INSERT INTO @temp
	SELECT name 
	FROM master.dbo.sysdatabases WITH (NOLOCK)
	WHERE 
		category IN ('0', '1','16')
		AND 
		name NOT IN ('tempdb', 'model', 'pubs', 'northwind')
		AND 
		name NOT LIKE 'adventurework%' 
		AND DATABASEPROPERTYEX(name, 'status') = 'ONLINE'
	ORDER BY name

SELECT @dbname = MIN(dbname) FROM @temp

WHILE @dbname IS NOT NULL
BEGIN
	
	SET @sql =
	'use [' + @dbname + '];
	declare @users table([User] varchar(500));
	declare @currUser varchar(500);
	insert into @users

	SELECT [name] 
	FROM [' + @dbname + '].dbo.sysusers WITH (NOLOCK)
	WHERE hasdbaccess = 1 AND [name] <> ''dbo''

	SELECT @currUser = min([User]) from @users;
	WHILE @currUser IS NOT NULL
	BEGIN
		insert into #Permissions
		(owner, object, Grantee, Grantor, ProtectType, Act ,Col)
		exec sp_helprotect @username = @currUser
		insert into #Roles
		(UserName, GroupName, LoginName, DefDBName, DefSchemaName, UserID, SID)
		exec sp_helpuser @name_in_db = @currUser
		
		update #Permissions set dbname = ''' + @dbname + ''', UserName = @currUser where dbname is null
		update #Roles set dbname = ''' + @dbname + ''' where dbname is null
		
		select @currUser = min([User]) from @users where [User] > @currUser
	END	
	'
		
	EXEC(@sql)	
	
	SELECT @dbname = MIN(dbname) FROM @temp WHERE dbname > @dbname

END

SELECT 
	dbname AS DB_Name, 
	UserName, 
	'Permissions' = 'SP_AddRoleMember ''' + RTRIM(GroupName)+''', '''+ RTRIM(username)+'''' 
FROM #Roles  
UNION 
SELECT 
	dbname AS DB_Name, 
	UserName, 
	UPPER(RTRIM(ProtectType))+' '+UPPER(RTRIM(Act))+' ON ['+owner+'].['+object+']'+ 
	CASE 
		WHEN (PATINDEX('%All%', Col)=0) AND (Col <> '.') THEN ' ('+Col+')' 
		ELSE '' 
	END
	 + ' TO ['+Grantee+']' 
FROM #Permissions 
ORDER BY dbname, UserName, Permissions DESC

drop table #Permissions
drop table #Roles

GO

--NE - 6/11/2007 - Detect Schemas to which a user belongs within a database; SQL 2005 only.

USE master
GO

IF OBJECT_ID('rpt_security_detect_user_schema_permissions_2005') IS NOT NULL
	DROP PROCEDURE [dbo].[rpt_security_detect_user_schema_permissions_2005]
GO

CREATE PROCEDURE dbo.rpt_security_detect_user_schema_permissions_2005

AS

/*

	Detect User schema permissions for all databases and users - SQL 2005 only.
	
	EXEC rpt_security_detect_user_schema_permissions_2005

*/

DECLARE 
	@dbname varchar(200),
	@sql varchar(8000)

DECLARE @temp table
(
	dbname VARCHAR(500)
)

--The following temporary table is derived from BOL...
CREATE TABLE #prmssnTypes
(Code varchar(200), PermissionName varchar(500))

CREATE TABLE #schemaPermissions
(
	DB_Name varchar(500),
	[User] varchar(500),
	SchemaName varchar(200), 
	[State] varchar(200), 
	PermissionName varchar(500), 
	[Grantor] varchar(200)
)

INSERT INTO #prmssnTypes
SELECT 'AL', 'ALTER'
  UNION ALL
SELECT 'ALAK', 'ALTER ANY ASYMMETRIC KEY'
  UNION ALL
SELECT 'ALAR', 'ALTER ANY APPLICATION ROLE'
  UNION ALL
SELECT 'ALAS', 'ALTER ANY ASSEMBLY'
  UNION ALL
SELECT 'ALCF', 'ALTER ANY CERTIFICATE'
  UNION ALL
SELECT 'ALDS', 'ALTER ANY DATASPACE'
  UNION ALL
SELECT 'ALED', 'ALTER ANY DATABASE EVENT NOTIFICATION'
  UNION ALL
SELECT 'ALFT', 'ALTER ANY FULLTEXT CATALOG'
  UNION ALL
SELECT 'ALMT', 'ALTER ANY MESSAGE TYPE'
  UNION ALL
SELECT 'ALRL', 'ALTER ANY ROLE'
  UNION ALL
SELECT 'ALRT', 'ALTER ANY ROUTE'
  UNION ALL
SELECT 'ALSB', 'ALTER ANY REMOTE SERVICE BINDING'
  UNION ALL
SELECT 'ALSC', 'ALTER ANY CONTRACT'
  UNION ALL
SELECT 'ALSK', 'ALTER ANY SYMMETRIC KEY'
  UNION ALL
SELECT 'ALSM', 'ALTER ANY SCHEMA'
  UNION ALL
SELECT 'ALSV', 'ALTER ANY SERVICE'
  UNION ALL
SELECT 'ALTG', 'ALTER ANY DATABASE DDL TRIGGER'
  UNION ALL
SELECT 'ALUS', 'ALTER ANY USER'
  UNION ALL
SELECT 'AUTH', 'AUTHENTICATE'
  UNION ALL
SELECT 'BADB', 'BACKUP DATABASE'
  UNION ALL
SELECT 'BALO', 'BACKUP LOG'
  UNION ALL
SELECT 'CL', 'CONTROL'
  UNION ALL
SELECT 'CO', 'CONNECT'
  UNION ALL
SELECT 'CORP', 'CONNECT REPLICATION'
  UNION ALL
SELECT 'CP', 'CHECKPOINT'
  UNION ALL
SELECT 'CRAG', 'CREATE AGGREGATE'
  UNION ALL
SELECT 'CRAK', 'CREATE ASYMMETRIC KEY'
  UNION ALL
SELECT 'CRAS', 'CREATE ASSEMBLY'
  UNION ALL
SELECT 'CRCF', 'CREATE CERTIFICATE'
  UNION ALL
SELECT 'CRDB', 'CREATE DATABASE'
  UNION ALL
SELECT 'CRDF', 'CREATE DEFAULT'
  UNION ALL
SELECT 'CRED', 'CREATE DATABASE DDL EVENT NOTIFICATION'
  UNION ALL
SELECT 'CRFN', 'CREATE FUNCTION'
  UNION ALL
SELECT 'CRFT', 'CREATE FULLTEXT CATALOG'
  UNION ALL
SELECT 'CRMT', 'CREATE MESSAGE TYPE'
  UNION ALL
SELECT 'CRPR', 'CREATE PROCEDURE'
  UNION ALL
SELECT 'CRQU', 'CREATE QUEUE'
  UNION ALL
SELECT 'CRRL', 'CREATE ROLE'
  UNION ALL
SELECT 'CRRT', 'CREATE ROUTE'
  UNION ALL
SELECT 'CRRU', 'CREATE RULE'
  UNION ALL
SELECT 'CRSB', 'CREATE REMOTE SERVICE BINDING'
  UNION ALL
SELECT 'CRSC', 'CREATE CONTRACT'
  UNION ALL
SELECT 'CRSK', 'CREATE SYMMETRIC KEY'
  UNION ALL
SELECT 'CRSM', 'CREATE SCHEMA'
  UNION ALL
SELECT 'CRSN', 'CREATE SYNONYM'
  UNION ALL
SELECT 'CRSV', 'CREATE SERVICE'
  UNION ALL
SELECT 'CRTB', 'CREATE TABLE'
  UNION ALL
SELECT 'CRTY', 'CREATE TYPE'
  UNION ALL
SELECT 'CRVW', 'CREATE VIEW'
  UNION ALL
SELECT 'CRXS', 'CREATE XML SCHEMA COLLECTION'
  UNION ALL
SELECT 'DL', 'DELETE'
  UNION ALL
SELECT 'EX', 'EXECUTE'
  UNION ALL
SELECT 'IM', 'IMPERSONATE'
  UNION ALL
SELECT 'IN', 'INSERT'
  UNION ALL
SELECT 'RC', 'RECEIVE'
  UNION ALL
SELECT 'RF', 'REFERENCES'
  UNION ALL
SELECT 'SL', 'SELECT'
  UNION ALL
SELECT 'SN', 'SEND'
  UNION ALL
SELECT 'SPLN', 'SHOWPLAN'
  UNION ALL
SELECT 'SUQN', 'SUBSCRIBE QUERY NOTIFICATIONS'
  UNION ALL
SELECT 'TO', 'TAKE OWNERSHIP'
  UNION ALL
SELECT 'UP', 'UPDATE'
  UNION ALL
SELECT 'VW', 'VIEW DEFINITION'
  UNION ALL
SELECT 'VWDS', 'VIEW DATABASE STATE'

INSERT INTO @temp
	SELECT name 
	FROM master.dbo.sysdatabases WITH (NOLOCK)
	WHERE 
		category IN ('0', '1','16')
		AND 
		name NOT IN ('tempdb', 'model', 'pubs', 'northwind')
		AND 
		name NOT LIKE 'adventurework%' 
		AND DATABASEPROPERTYEX(name, 'status') = 'ONLINE'
	ORDER BY name

SELECT @dbname = MIN(dbname) FROM @temp

WHILE @dbname IS NOT NULL
BEGIN
	
	SET @sql =
	'use [' + @dbname + ']
	declare @users table([User] varchar(500));
	declare @currUser varchar(500);
	insert into @users

	SELECT [name] 
	FROM [' + @dbname + '].dbo.sysusers WITH (NOLOCK)
	WHERE hasdbaccess = 1 AND [name] <> ''dbo''

	SELECT @currUser = min([User]) from @users;
	WHILE @currUser IS NOT NULL
	BEGIN
		INSERT INTO #schemaPermissions
		(SchemaName, [State], PermissionName, [Grantor])
		SELECT
			s.name AS SchemaName,
			prmssn.state_desc as [State],
			t.PermissionName,
			ISNULL(grantor_principal.name, '''') AS [Grantor]
		FROM
			[' + @dbname + '].sys.schemas s
			
			INNER JOIN [' + @dbname + '].sys.database_permissions prmssn 
			ON prmssn.major_id = s.schema_id 
			AND prmssn.minor_id=0 AND prmssn.class=3
			
			INNER JOIN [' + @dbname + '].sys.database_principals grantor_principal 
			ON grantor_principal.principal_id = prmssn.grantor_principal_id
			
			INNER JOIN [' + @dbname + '].sys.database_principals grantee_principal 
			ON grantee_principal.principal_id = prmssn.grantee_principal_id
			
			LEFT JOIN #prmssnTypes t
			ON prmssn.type = t.Code COLLATE Latin1_General_CI_AS_KS_WS
			
		WHERE grantee_principal.name = @currUser
		
		UPDATE #schemaPermissions SET DB_Name = ''' + @dbname + ''', [User] = @currUser WHERE DB_Name IS NULL
		
		select @currUser = min([User]) from @users where [User] > @currUser
	END'
		
	EXEC(@sql)	
	
	SELECT @dbname = MIN(dbname) FROM @temp WHERE dbname > @dbname

END

SELECT 
	DB_Name, 
	[User], 
	SchemaName, 
	[State], 
	PermissionName, 
	[Grantor],
	Statement = 'USE ' + DB_Name + '; ' + [STATE] + ' ' + PermissionName + ' ON SCHEMA::[' + SchemaName + '] TO [' + [User] + ']'
FROM #schemaPermissions 
ORDER BY DB_Name, [User], SchemaName, [State], PermissionName, [Grantor]

DROP TABLE #schemaPermissions
DROP TABLE #prmssnTypes

GO
