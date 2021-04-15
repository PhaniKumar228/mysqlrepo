/*
    
No more orphan users!

I was fed up of manipulating sysusers after restoring a db from one server to another.
Just put thgis script on QA after restoring db. It will check all db users (not tested for secure connections) and will restore orphan users. Check it out!
Hope this script will help.

 
*/

/*
	This Proc verify that all db users have the same sid than those in db master
	You must have Admin rights on server
*/

USE master
--Allow sys updates
EXEC sp_configure 'allow updates', 1
RECONFIGURE WITH OVERRIDE
GO
SET NOCOUNT ON
DECLARE CurdB CURSOR FOR SELECT [name] from master.dbo.sysdatabases WITH (NOLOCK) WHERE (master.dbo.sysdatabases.dbid > 4 ) AND (status<=16)     --(= base utilisateur active)
DECLARE @c nvarchar(500), @Name as nvarchar(300), @sid as varbinary(85), @sidc as varchar(85), @sidMaster as varbinary(85)
DECLARE @nom as sysname, @logindb nvarchar(132), @loginlang nvarchar(132)

--Openning cursor for the user db
OPEN CurdB
FETCH NEXT FROM CurdB into @Name
--all the db users are tested (except dbo)
WHILE @@FETCH_STATUS = 0 
BEGIN
	print '--- Verifying base: ['+@Name +'] ...'
	SET @Name = '['+@Name+']'
	--declare and open cursor on db users for the current db
	SET @c = 'DECLARE CurUsr CURSOR FOR SELECT [name],[sid] from ' + @Name + '..[sysusers] WITH (NOLOCK) WHERE [status]=''2'' AND [issqluser]=''1'''
	EXEC sp_executesql @c
	OPEN CurUsr
	FETCH NEXT FROM CurUsr into @nom, @sid
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--verifying user exists in master db
		IF EXISTS (SELECT sid FROM master..sysxlogins WITH (NOLOCK) WHERE name=@nom) 
		BEGIN
			SELECT @sidMaster = sid FROM master..sysxlogins WITH (NOLOCK) WHERE name=@nom
			EXEC master..xp_varbintohexstr @sidMaster, @sidc out
			--if sid db user<> sid  db master then I put the sid db matser in the sid db user
			IF (@sid <>@sidMaster) AND (@nom NOT LIKE '%dbo%') BEGIN
				SET @c = 'UPDATE '+@Name+'..[sysusers] SET sid='+@sidc+' WHERE name='''+@nom+''''
				EXEC sp_executesql @c
				print '      Database: '+@Name +' - Nom utilisateur: '''+ @nom+''' - Affectation du sid: '+ @sidc+' depuis la base master'
			END ELSE BEGIN
				--sid correct
				IF (@nom NOT LIKE '%dbo%') BEGIN
					print '      L''utilisateur '''+@nom+''' a un sid correct ('+@sidc+')'
				END
			END
		END ELSE BEGIN
			--if user doesn't exist, create it with passwd=login
			IF (@nom NOT LIKE '%dbo%') BEGIN
				SET @loginlang = 'Français'
				SET @logindb = @Name
				exec sp_addlogin @nom, @nom, @logindb, @loginlang
				SELECT @sidMaster = sid FROM master..sysxlogins WITH (NOLOCK) WHERE name=@nom
				EXEC master..xp_varbintohexstr @sidMaster, @sidc out
				SET @c = 'UPDATE '+@Name+'..[sysusers] SET sid='+@sidc+' WHERE name='''+@nom+''''
				EXEC sp_executesql @c
				print '      Database: '+@Name +' - Utilisateur créé: '''+ @nom+''', mot de passe:'''+ @nom +''' - Affectation du sid: '+ @sidc+' depuis la base master'
			END
		END
		FETCH NEXT FROM CurUsr into @nom, @sid
	END
	CLOSE CurUsr
	DEALLOCATE CurUsr
	FETCH NEXT FROM CurdB into @Name
END
CLOSE CurdB
DEALLOCATE CurdB
GO
--Disallow sys updates
EXEC sp_configure 'allow updates', 0
RECONFIGURE WITH OVERRIDE
GO

