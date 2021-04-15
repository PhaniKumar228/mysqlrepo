/*
For SQL 2000 SP that shows clear info from sysindexes

This sp translate all the numeric info from sysindexes and translate it into text. Also, can generate a log file to later view.

*/

Create proc sp_sysindexes
	@db_name Varchar (30) = NULL, 	--Database name where it executes
	@LogFile Char(1) = 'N' 		--Indicates if it generates a log file or not(Y or N) 
As
/*
** Date 08/31/2002
** sp_sysindexes @db_name, @logfile
** It shows clear information from sysindexes For SQL 2000
*/

Set Nocount ON

/*
** If a database name was entered it checks that it exists.
** If it does not exist, it shows an error and the available databases. 
*/
If @db_name is Not Null
	Begin	
		If Not Exists
			(Select name from master.dbo.sysdatabases Where name = @db_name)
			Begin
				Raiserror ('The database does not exist in the server.', 16, 1)
				Print ('Available databases are:')
				EXEC sp_databases
				Return
			End
	End

/*
** It checks if the entered option for the log file is Y or N
** If it is not one of them, shows an error and exits.
*/
If @Logfile<>'Y' And @LogFile<>'N' 
	Begin
		Raiserror ('You must enter Y or N to generate the log file.',16,1)
		Return
	End


/* If no database was entered , it executes the sp in the actual database.*/
If @db_name is NULL 
	Begin
		Set @db_name = (Select db_name())
	End


/*
**Variables
*/
Declare @Select Varchar (1200) 		--it saves the select sentence
Declare @groupid tinyint		--it saves the filegroup id
Declare @name sysname			--it saves the object name
Declare @filegroup_name	Varchar (30)	--it saves the filegroup name
Declare @used int			--it saves used pages
Declare @uid int			--it saves the object owner id

Set @select=	'select 	sysindexes.name, 
				"Status"=
			Case
				When sysindexes.Status = 2 Then '+''''+'Unique index'+''''+'
				When sysindexes.Status = 1 Then '+''''+'Cancel command if attempt to insert duplicate key'+''''+'
				When sysindexes.Status = 4 Then '+''''+'Cancel command if attempt to insert duplicate Row'+''''+'
				When sysindexes.Status = 16 Then '+''''+'Clustered index'+''''+'
				When sysindexes.Status = 64 Then '+''''+'Index allows duplicate rows'+''''+'
				When sysindexes.Status = 2048 Then '+''''+'Index used to enforce PRIMARY KEY constraint'+''''+'
				When sysindexes.Status = 4096 Then '+''''+'Index used to enforce UNIQUE constraint'+''''+'
				Else '+''''+'No Status'+''''+'
			End
				,"Indid"=
			Case
				When Indid = 1 Then '+''''+'Clustered Index'+''''+'
				When Indid > 1 And Indid < 255 Then '+''''+'Nonclustered Index'+''''+'
				When Indid = 255 Then '+''''+'Tables that have text or image data'+''''+'
				When Indid = 0 Then '+''''+'Table'+''''+'
				Else '+''''+'No Indid'+''''+'
			End
				,Groupid
				,used
				,xtype
				,uid				
		From ' + @db_name + '..SysIndexes  sysindexes Inner Join ' + @db_name + '..Sysobjects sysobjects
		On sysobjects.id = sysindexes.id 
		Order By sysindexes.Name'

/*It creates a temp table ##sysindexes to save the select*/
Create Table ##sysindexes
	(Name sysname,
	Status Varchar(50),
	Indid Varchar(36),
	groupid Varchar (30),
	used Varchar (47),
	xtype Char(2),
	uid VarChar (40))

/*It inserts the records in the temp table*/
Insert ##sysindexes
EXEC (@select)

/*
** It creates a cursor to save the name, groupid, used, uid to update the temp table 
** with the filegroup name and the object owner. 
*/
Declare vCursor Cursor For
		Select [name], groupid, used ,uid From ##sysindexes Order By [name]
Declare @user Varchar(100)
Open vCursor --It opens the cursor.
FETCH NEXT FROM vCursor INTO @name, @groupid, @used, @uid
WHILE @@FETCH_STATUS = 0
	BEGIN
		/*It changes the groupid into the filegroup name*/
		Set @filegroup_name=(Select filegroup_name(@groupid)) --It saves the filegroup name.		
		Update ##sysindexes
		Set groupid=@filegroup_name 
		Where name=@name

		/*It changes the used for tables and clustered indexes*/
		Update ##sysindexes
		Set used = 'Number of data pages used: ' + Convert(Varchar (4), @used)
		Where (Indid = 'Clustered Index' Or Indid = 'Table') And [name] = @name

		/*It changes the used for nonclustered indexes*/
		Update ##sysindexes
		Set used = 'Number of index pages used: ' + Convert(Varchar (4), @used)
		Where Indid = 'Nonclustered Index' And [name] = @name

		/*It changes the used for text or image*/
		Update ##sysindexes
		Set used = 'Number of text/image pages used: ' + Convert(Varchar (4), @used)
		Where Indid = 'Tables that have text or image data' And [name] = @name

		/*It changes the uid to the owner
		Update ##sysindexes
		Set uid = (Select user_name(Convert(int,@uid)))
		Where uid = @uid And name = @name*/


		FETCH NEXT FROM vCursor INTO @name, @groupid, @used, @uid
	End	

/*Closes the cursor*/
Close vCursor
Deallocate vCursor

/*It changes the filegroup NULL to 'no Filegroup'*/
Update ##sysindexes
Set groupid='No Filegroup'
Where groupid Is Null

/*It shows the table ##sysindexes*/
Select 	User_name(uid) + '.' + Name  As 'Object name',
		groupid As 'Filegroup',
		Status,
		Indid,
		used As 'Pages Info',
		'Object type' =
			Case
				When xtype = 'U' Then 'Of user'
				When xtype = 'S' Then 'Of system'
			End
	from ##sysindexes
	Order by [Name]


/*
** If Y was specified, it generates the log file
*/
If @Logfile='Y' 
	Begin
		EXEC master.dbo.xp_cmdshell 'Osql -E -Q"Select name,groupid,status,indid,used from ##sysindexes" -oc:\Sysindexes.Log'
		Print 'A log file was generated in C:\ named Sysindexes.log'
	End

/*It deletes the table ###sysindexes*/
Drop table ##sysindexes



