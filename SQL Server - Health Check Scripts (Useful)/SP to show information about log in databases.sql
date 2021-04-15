/*
SP to show information about log in databases

It calculates log free space in mb and in percent for all databases, and also show the quantity of different objects for one databases. 

*/

Create Proc proc_logSpace
@dbname Varchar(20)=Null
AS
/*
**proc_logSpace: It shows the log space used, free and size for all databases
**or for the one you specified, it also shows you the total count of objects
**in the specified database.
**It also warns you if the log used is too high.
*/

Set Nocount On
/*
**I create a temp table that will hold the information
**extracted from DBCC SQLPERF(Logspace). This will be used
**either you enter a database or not.
*/
Create table #logspace
	(
		Dbname Varchar(50),
		LogSize Decimal(9,3),
		Logused decimal(9,3),
		Status int
	)

Declare @dbcc Varchar(50)
Set @dbcc='DBCC Sqlperf(Logspace)'

Insert #logspace
EXEC (@dbcc)

Declare @logsizeMb Decimal(9,3) --Total size in Mb
Declare @logfreeMb Decimal(9,3) --Log free in Mb
Declare @logusedMb Decimal(9,3) --Log used in Mb
Declare @logusedPercent Decimal(9,3) --Log used in percent
Declare @logfreePercent Decimal(9,3) --Log free in percent

/*
**If a database is entered I check that exists.
**And also calculate the log space for that database
**and the total quantity of objects
**in that database.
*/
--Exist?
If @dbname Is Not null
Begin
	If Not Exists (
			Select * from master.dbo.sysdatabases
			Where name =@dbname
			)
		Begin
			Print 'The databases does not exists.'
			Print 'Available databases are:'
			Select name As "Databases"
			From master.dbo.sysdatabases
			Return
		End

--Calculation of Log space
Set @logsizeMb=(
		Select Logsize
		From #logspace
		Where dbname=@dbname
		)
Set @logusedpercent=(
		Select logused
		From #logspace
		Where dbname=@dbname
			)

Set @logusedMb=(
		Select (@logusedpercent*@logsizeMb)/100
		)
Set @logfreeMb =(
		Select @logsizeMb-@logusedMb
		)
Set @logfreepercent=(
		Select 100-@logusedpercent
			)

--Total quantity of objects
/*
**I need to create a temp table that will hold all the objects
**in the database so I can count each of the types
*/
Create table #type
	(
	name Varchar(100),
	xtype Varchar(10)
	)
Declare @select Varchar(60)
Set @select='Select name,xtype from '+@dbname+'.dbo.sysobjects order by xtype'

Insert #type
EXEC (@select)

Declare @total int, @check int,@default int, @fk int, @pk int
Declare @log int, @sp int, @rule int, @replication int
Declare @system int , @trigger int, @user int , @view int, @xp int

Set @total=(Select count(*) from #type)
Set @check=(Select count(*) from #type where xtype='C')
Set @default=(Select count(*) from #type where xtype='D')
Set @fk=(Select count(*) from #type where xtype='F')
Set @pk=(Select count(*) from #type where xtype='K')
Set @log=(Select count(*) from #type where xtype='L')
Set @sp=(Select count(*) from #type where xtype='P')
Set @rule=(Select count(*) from #type where xtype='R')
Set @replication=(Select count(*) from #type where xtype='RF')
Set @system=(Select count(*) from #type where xtype='S')
Set @trigger=(Select count(*) from #type where xtype='TR')
Set @user=(Select count(*) from #type where xtype='U')
Set @view=(Select count(*) from #type where xtype='V')
Set @xp=(Select count(*) from #type where xtype='X')

Drop Table #type

/*
**Now that I have the information of the log
**and the objects i printed it to the screem
*/
Print '					Information for Database "'+@dbname+'"'
Print ''
Print 'Log information'
Print '---------------'
Print 'Log Size in Mb: '+Convert(Varchar(10),@logsizeMb)
Print 'Log Used in Mb: '+Convert(Varchar(10),@logusedMb)+'	Log Used in Percent: '+Convert(Varchar(10),@logusedPercent)
Print 'Log Free in Mb: '+Convert(Varchar(10),@logfreeMb)+'	Log Free in Percent: '+Convert(Varchar(10),@logfreepercent)
		/*
		**I put some kind of alert that warns you if the log used percent is 
		**above 90 percent.
		*/
		If @logusedpercent>90
			Print '!!!WARNING Log Used is too high. Backup the log'

Print ''
Print 'Quantity of objects'
Print '-------------------'
Print 'Check: '+Convert(Varchar(3),@check)+'		Trigger: '+Convert(Varchar(3),@trigger)
Print 'Default: '+Convert(Varchar(3),@default)+'		Rule: '+Convert(Varchar(3),@rule)
Print 'Foreign Key: '+Convert(Varchar(3),@fk)+'		System: '+Convert(Varchar(3),@system)
Print 'Primary Key/Unique: '+Convert(Varchar(3),@pk)+'	View: '+Convert(Varchar(3),@view)
Print 'Log: '+Convert(Varchar(3),@log)+'			Replication Filter SP: '+Convert(Varchar(3),@replication)
Print 'Stored Procedure: '+Convert(Varchar(3),@sp)+'	User: '+Convert(Varchar(3),@user)
Print 'Extended Procedure: '+Convert(Varchar(3),@xp)
Return
End
/*
**Now I show the log information for all Databases
*/

Print ''
Print '					Log information for all databases'
Print '					---------------------------------'
Print '(To see information for only one database re-run the stored procedure with the database name)'
Print ''
Print ''
Declare log Cursor For
			Select dbname From #logspace
Open log
Fetch Next from log into @dbname
While @@Fetch_status=0
	Begin
		Print 'Database "'+@dbname+'"'
		Set @logsizeMb=(
			Select Logsize
			From #logspace
			Where dbname=@dbname
			)
		Set @logusedpercent=(
				Select logused
				From #logspace
				Where dbname=@dbname
					)

		Set @logusedMb=(
				Select (@logusedpercent*@logsizeMb)/100
				)
		Set @logfreeMb =(
				Select @logsizeMb-@logusedMb
				)
		Set @logfreepercent=(
				Select 100-@logusedpercent
					)
		Print 'Log Size in Mb: '+Convert(Varchar(10),@logsizeMb)
		Print 'Log Used in Mb: '+Convert(Varchar(10),@logusedMb)+'	Log Used in Percent: '+Convert(Varchar(10),@logusedPercent)
		Print 'Log Free in Mb: '+Convert(Varchar(10),@logfreeMb)+'	Log Free in Percent: '+Convert(Varchar(10),@logfreepercent)
		/*
		**I put some kind of alert that warns you if the log used percent is 
		**above 90 percent.
		*/
		If @logusedpercent>90
			Print '!!!WARNING Log Used is too high. Backup the log'
		Print ''
		Fetch Next from log into @dbname
		
	End
Close log
Deallocate Log
