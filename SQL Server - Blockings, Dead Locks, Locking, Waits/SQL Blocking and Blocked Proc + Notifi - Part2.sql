/*
SQL Blocking and Blocked Proc + Notifi - Part2

*/
/* STEP 1
Create the st_proc that sends the mail
*/
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_send_cdosysmail]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_send_cdosysmail]
GO
CREATE PROCEDURE [dbo].[sp_send_cdosysmail]
   @From varchar(100) ,
   @To varchar(100) ,
   @Subject varchar(100)=" ",
   @Body varchar(4000) =" "
/*********************************************************************

This stored procedure takes the parameters and sends an e-mail.
All the mail configurations are hard-coded in the stored procedure.
Comments are added to the stored procedure where necessary.
References to the CDOSYS objects are at the following MSDN Web site:
http://msdn.microsoft.com/library/default.asp?url=/library/en-us/cdosys/html/_cdosys_messaging.asp

***********************************************************************/
   AS
   Declare @iMsg int
   Declare @hr int
   Declare @source varchar(255)
   Declare @description varchar(500)
   Declare @output varchar(1000)

--************* Create the CDO.Message Object ************************
   EXEC @hr = sp_OACreate 'CDO.Message', @iMsg OUT

--***************Configuring the Message Object ******************
-- This is to configure a remote SMTP server.
-- http://msdn.microsoft.com/library/default.asp?url=/library/en-us/cdosys/html/_cdosys_schema_configuration_sendusing.asp
   EXEC @hr = sp_OASetProperty @iMsg, 'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusing").Value','2'
-- This is to configure the Server Name or IP address.
-- Replace MailServerName by the name or IP of your SMTP Server.
   EXEC @hr = sp_OASetProperty @iMsg, 'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").Value', 'MailServerName'

-- Save the configurations to the message object.
   EXEC @hr = sp_OAMethod @iMsg, 'Configuration.Fields.Update', null

-- Set the e-mail parameters.
   EXEC @hr = sp_OASetProperty @iMsg, 'To', @To
   EXEC @hr = sp_OASetProperty @iMsg, 'From', @From
   EXEC @hr = sp_OASetProperty @iMsg, 'Subject', @Subject

-- If you are using HTML e-mail, use 'HTMLBody' instead of 'TextBody'.
   EXEC @hr = sp_OASetProperty @iMsg, 'TextBody', @Body
   EXEC @hr = sp_OAMethod @iMsg, 'Send', NULL

-- Sample error handling.
   IF @hr <>0
     select @hr
     BEGIN
       EXEC @hr = sp_OAGetErrorInfo NULL, @source OUT, @description OUT
       IF @hr = 0
         BEGIN
           SELECT @output = '  Source: ' + @source
           PRINT  @output
           SELECT @output = '  Description: ' + @description
           PRINT  @output
         END
       ELSE
         BEGIN
           PRINT '  sp_OAGetErrorInfo failed.'
           RETURN
         END
     END

-- Do some error handling after each step if you have to.
-- Clean up the objects created.
   EXEC @hr = sp_OADestroy @iMsg
   GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

-- STEP2 Create the history table
if exists (select * from dbo.sysobjects where id = object_id(N'[Lock_monitor]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [Lock_monitor]
GO

if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Lock_monitor]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
 BEGIN
CREATE TABLE [Lock_monitor] (
	[Occurs] [datetime] NOT NULL CONSTRAINT [DF_Lock_monitor_Occurs] DEFAULT (getdate()),
	[Proc_blocked] [int] NULL ,
	[Proc_blocking] [int] NULL ,
	[Qry_blocked] [varchar] (255) NULL ,
	[Qry_blocking] [varchar] (255) NULL ,
	[User_Blocking] varchar(100) NULL	
) ON [PRIMARY]
END

GO

-- STEP 3 Create the procedure
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MONITOR_LOCKS]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MONITOR_LOCKS]
GO

CREATE PROCEDURE MONITOR_LOCKS as

create table #procs (eventtype varchar(60), Parameters int  , EventInfo varchar(600))
declare @cmd varchar(250), @spid_1 int, @spid_2 int, @qry1 varchar(255), @qry2 varchar(255), @user1 varchar(100), @user2 varchar(100)

select spid, blocked, loginame
into #temp_proc 
from sysprocesses where blocked >0
declare CUR1 cursor for
select spid, blocked, loginame from #temp_proc
open CUR1
fetch next from CUR1 into @spid_1, @spid_2, @user1
while @@fetch_status = 0
BEGIN
	truncate table #procs
	set @cmd = (select 'dbcc inputbuffer(' + cast(@spid_1 as varchar) + ')')
	insert into #procs (eventtype, Parameters, EventInfo)
	exec (@cmd)
	Insert into dbo.Lock_monitor (Proc_blocked, Proc_blocking, Qry_blocked, [User_Blocking])
	select @spid_1, @spid_2, EventInfo, @user1 from #procs
	truncate table #procs
	set @cmd = (select 'dbcc inputbuffer(' + cast(@spid_2 as varchar) + ')')
	insert into #procs (eventtype, Parameters, EventInfo)
	exec (@cmd)
	update dbo.Lock_monitor set Qry_blocking = (select EventInfo from #procs),
	proc_blocked = @spid_1, proc_blocking = @spid2, user_blocking = @user1
	where Proc_blocked = @spid_1 
	and substring (convert (varchar, Occurs, 121),1,16) = substring (convert (varchar, getdate(), 121),1,16)
	fetch next from CUR1 into @spid_1, @spid_2, @user1 
END
CLOSE CUR1
DEALLOCATE CUR1
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

/* STEP 4 Create the notification TRIGGER. Adjust parameters.
*/
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[NOTIFY_LOCK]') and OBJECTPROPERTY(id, N'IsTrigger') = 1)
drop trigger [dbo].[NOTIFY_LOCK]
GO

CREATE TRIGGER NOTIFY_LOCK on dbo.Lock_monitor FOR UPDATE as
declare @msg varchar(1000)
set @msg=(select 'A process blocked has been detected at (date and time): '+convert (varchar,getdate(),121)+'

Blocking User: ' +isnull(User_Blocking, '') +'
Blocking SPID: '+ convert(varchar(10), proc_Blocking) + '
Blocking Query: '+ isnull(Qry_Blocking, '')+'

Blocked Query: ' + isnull(Qry_Blocked, '') from inserted)

exec sp_send_cdosysmail
   @From='SQLSERVER@YOURCOMPANY' ,
   @To='EMAIL1@YOURCOMPANY;EMAIL2@YOURCOMPANY',
   @Subject= 'PROCESS LOCKED ON YOURSQLSERVER',
   @Body= @msg

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

