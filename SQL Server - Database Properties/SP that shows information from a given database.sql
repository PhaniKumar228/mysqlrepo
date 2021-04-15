/*
SP that shows information from a given database

It is used to show information from a database. 
It shows the creation date, it calculates the time in days, months and hours since its creation and it shows all the users with rights in that database. 
*/

Create Proc proc_dbinfo
@dbname Varchar(20)=Null
As
/*

This SP shows information for a given database.
It list  de dbid, creation date and days since its creation,
directory of the primary data files and a list of the users 
with permissions in that database.

**Use EXEC proc_dbinfo @dbname=whatever
*/

Set nocount on
--If no db name is especified, it shows a list of all databases in the server
Declare @servername varchar(50)
If @dbname is Null
	Begin
		Set @servername=(Select @@servername)
		Print 'No databases name was especified. Re run the SP with a database listed below.'
		Print 'Databases in Server '+@servername+'...'
		Select name As "Database Name" from master.dbo.sysdatabases
		Return
	End

--If the database name doesn't exists in the data dictionary, it shows a list of available databases
If Not Exists (
		Select * from master.dbo.sysdatabases
		Where name=@dbname
		)
	Begin
		Set @servername=(Select @@servername)
		Print 'The database use especified doesn'+''''+'t exists. Re run the SP	with a database listed below.'
		Print 'Databases in Server '+@servername+'...'
		Select name As "Database Name" from master.dbo.sysdatabases
		Return
	End

--The database name inserted exists, so I go on.
/*
**I declare all the variables that I need to show the information.
**The difdate is the time since the creation and the months, days and hours are
**declared separately to show it correctly
*/
Declare @dbid int
Declare @crdate datetime
Declare @difdate datetime
Declare @filename varchar(300)
Declare @months varchar(2)
Declare @days varchar(2)
Declare @hours varchar(2)
Declare @years varchar(4)
Set @dbid=(Select dbid from master.dbo.sysdatabases where name=@dbname)
Set @crdate=(Select crdate from master.dbo.sysdatabases where name=@dbname)
Set @difdate=(Select getdate()-@crdate)
Set @hours=Substring(Convert(varchar(100),@difdate,120),12,2)
Set @days=Substring(Convert(varchar(100),@difdate,120),9,2)
Set @months=Substring(Convert(varchar(100),@difdate,120),6,2)
Set @years=Substring(Convert(varchar(100),@difdate,120),3,2)
If @hours<24 And @days=1
	Begin
		Set @months=0
		Set @days=0
	End

If @days<30 And @months=1
	Begin
		Set @months=0
	End

If @months<12 and @years='1900'
	Begin
		Set @years=0
	End

Set @filename=(Select filename from master.dbo.sysdatabases where name=@dbname)
Print 'Information for Database '+@dbname+':'
Print ''
Print 'Database Id: '+Convert(Varchar(4),@dbid)
Print 'Creation date: '+Convert(varchar(100),@crdate,120)
Print 'Days since creation: '+@years+' years, '+@months+' months, '+@days+' days and '+@hours+' hours.'
Print 'Directory of primary file: '+@filename
Print ''
Print 'Users with permissions in database: '

--Lists the users in the database
Declare @select varchar(300)
Set @select='select Substring(name,1,34) as " " from '+@dbname+'.dbo.sysusers where name not like '+''''+'db_%'+''''+' and name<>'+''''+'INFORMATION_SCHEMA'+''''
EXEC (@select)





