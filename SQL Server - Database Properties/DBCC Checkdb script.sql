/*
DBCC Checkdb script

Script that executes DBCC Checkdb in all databases, creates a log file in c:\Checkdb\ in a folder with the current date, and a file with the format: DB_Date.log Also sends each log in an attachment by Email.
*/

/*
**Creation Date 26/01/02
**Script that Executes DBCC ChekDB in all the databases
**and records the result in a log file named C:\CheckDB\Current_Date\Db_Current Date.log
**It is necesary to create a directory in c:\ with the name "Checkdb".
**The Script connects to the server with OSQL and it needs the password of the SA.
**In this script is null, but change it with your own.
*/
Set Nocount on
Declare @dbname varchar(100) 

Declare db Cursor For	--Cursor that holds the names of the databases without Pubs and Northwind
		Select name from master.dbo.sysdatabases
		Where name not in ('Pubs','Northwind')

Declare @date Varchar(20) --Date to name the .log file
Set @date=(Select Convert(Varchar(50),getdate(),110))



Declare @osql varchar(1000)
/*
**Then I create a Subdirectory in c:\Checkdb\ with the date as name.
**Because it use the current date as parameter to create the Subdirectory,
**if you execute the script more that once in the same day, it will show you
**and error because the subdirectory already exist.
*/
Declare @mkdir varchar(100)
Set @mkdir='EXEC master.dbo.xp_cmdshell '+''''+'mkdir c:\CheckDb\'+@date+''''
EXEC (@mkdir)

/*
**I use the cursor to execute the osql statement in all the databases
**wich log every DBCC Checkdb in the path created before.
**If the password of the SA is not null, change it here.
*/

Open db
Fetch Next from db into @dbname
While @@Fetch_status=0
	Begin
		Set @osql='EXEC master.dbo.xp_cmdshell '+''''+'osql -Usa -P -Q"DBCC Checkdb ("'+@dbname+'")" -oC:\CheckDB\'+@date+'\'+@dbname+'_'+@date+'.log'+''''
		EXEC (@osql) --Execute the osql statement
		Fetch Next from db into @dbname	
	End
Close db

/*
**This section is in coments because it enable you to send the log files by E-mail.
**If you want to recieve all the log files by email uncoment this section to enable the script.
**You must have configured a mail client in your server

Declare @mail Varchar(1000)
Open db
Fetch Next from db into @dbname
While @@Fetch_status=0
	Begin
		Set @mail='EXEC master.dbo.xp_sendmail @recipients='+''''+'your@adress.com'+''''+',
				@subject='+''''+'Log of execution of CheckDB in Database '+@dbname+''''+',
				@message='+''''+'Check the log to see if an error ocurred while executing CheckDB in database '+@dbname+''''+',
				@attachments='+''''+'C:\CheckDB\'+@date+'\'+@dbname+'_'+@date+'.log'+''''
		Fetch Next from db into @dbname
		EXEC (@mail)
	End

--Close and Deallocate the Cursor
Close db
**Uncoment up to here to use
*/
Deallocate db
