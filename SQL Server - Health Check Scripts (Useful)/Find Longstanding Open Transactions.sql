/*
Find Longstanding Open Transactions

Ever forget to commit a transaction and then find out hours later that there is deadlocked transactions all over your database server? Worse yet has one of your coworkers done this to your database server? Never again, this stored procedure will net send the machine that has an open transaction, and send you (The DBA) an email message about who or what has the open transaction. The email message could easily be sent to a pager. It also creates a table called open_transactions_history that stores historical data for you. Simply add the stored procedure and then set it up as a reoccurring job. If you want to report on transactions that have been open for 15 - 30 Minutes set it up to run every 15 Minutes. Enjoy :) 
*/

CREATE PROCEDURE FindOpenTransactions AS

declare @emailAddress varchar(128)
set @emailAddress = 'youremail@whereever.com'

--Create the required Tables if they do not exist
IF NOT EXISTS (select * from sysobjects where type = 'u' and name = 'open_transactions')
Begin
	CREATE TABLE open_transactions
	(spid int NULL,
	login varchar(32) NULL,
	db varchar(128) NULL,
	hostname varchar(64) NULL)
end

IF NOT EXISTS (select * from sysobjects where type = 'u' and name = 'open_transactions_history')
Begin
	CREATE TABLE dbo.open_transactions_history
	(Found_Date datetime NULL,
	spid int NULL,
	login varchar(32) NULL,
	db varchar(128) NULL,
	hostname varchar(64) NULL,
	program_name varchar(128) NULL)
end

declare c4 cursor for select spid,dbid,hostname,loginame,program_name from master..sysprocesses where open_tran > 0
declare  @spid int, @hostname varchar(64), @login varchar(32), @cmd varchar(4000), @database varchar(128), @program_name varchar(128), @dbid int, @spidlist varchar(2000), @wehavedata int
select @spidlist = ''
open c4
fetch next from c4 into @spid,@dbid,@hostname,@login, @program_name
while @@fetch_status = 0
begin 
set @wehavedata = 1
select @database = name from master..sysdatabases where dbid = @dbid
If exists (select * from open_transactions where spid = @spid and login = @login and db = @database and hostname = @hostname)
	Begin
	insert into open_transactions_history (Found_Date,spid,login,db,hostname,program_name) values (getdate(),@spid,@login,@database,@hostname,@program_name)
	select @cmd = 'net send ' + @hostname + '"Your machine has an open transaction to ' + @database + '"'
	exec master..xp_cmdshell @cmd
	select @cmd = 'Host: ' + @hostname + char(13)
	select @cmd = @cmd + 'Login: ' + @login + char(13)
	select @cmd = @cmd + 'Database: ' + @database + char(13)
	select @cmd = @cmd + 'SPID: ' + convert(varchar(6),@spid) + char(13)
	select @cmd = @cmd + 'Program: ' + convert(varchar(6),@program_name) + char(13)
	exec master..xp_sendmail @recipients = @emailAddress, @subject = 'Open Transactions', @message = @cmd
	End
else 
insert into open_transactions (spid,login,db,hostname) values (@spid,@login,@database,@hostname)

select @spidlist = @spidlist + convert(varchar(32),@spid) + ','
fetch next from c4 into @spid,@dbid,@hostname,@login, @program_name
end

--Cleanup

if @wehavedata = 1
begin
	select @spidlist = substring(@spidlist,1,len(@spidlist)-1)
	select @cmd = 'delete from open_transactions where spid not in (' + @spidlist + ')' + char(13)
	print @cmd
	exec (@cmd)
end
else
	delete from open_transactions

close c4
deallocate c4
GO

