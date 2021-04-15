-- Create Blocked Process script
--
-- Search for %%% for areas that need customization
--
-- %%% Change Log database name
USE pubs
GO

PRINT 'Create BlockedProcess table'
if exists (select * from dbo.sysobjects where OBJECTPROPERTY(id, N'IsUserTable') = 1 
		AND id = object_id(N'dbo.BlockedProcess') )
	drop table dbo.BlockedProcess
GO
-- Create the log table
CREATE TABLE dbo.BlockedProcess (
	BlockedProcessNo_PK int IDENTITY (1,1) NOT NULL ,
	spid smallint NULL ,
	blocked smallint NULL ,
	open_tran smallint NULL ,
	login_time datetime NULL ,
	last_batch datetime NULL ,
	loginname varchar (20) NULL ,
	hostname varchar (70) NULL ,
	secs money NULL ,
	db varchar (20) ,
	input_buffer varchar(1000)
	CreateDate datetime NOT NULL 
) ON [PRIMARY]
GO

ALTER TABLE dbo.BlockedProcess WITH NOCHECK ADD 
	CONSTRAINT BlockedProcess_CreateDate_DF DEFAULT (getdate()) FOR CreateDate,
	CONSTRAINT BlockedProcess_PK PRIMARY KEY CLUSTERED 
	(BlockedProcessNo_PK) ON [PRIMARY] 
GO

-- Create CheckForBlocking stored procedure
PRINT 'sp_CheckForBlocking'
IF EXISTS (SELECT * FROM sysobjects WHERE sysstat & 0xf = 4
		AND id = object_id('dbo.sp_CheckForBlocking') )
	DROP PROCEDURE dbo.sp_CheckForBlocking
GO
CREATE PROCEDURE sp_CheckForBlocking
AS
DECLARE @spid smallint
	, @hostname varchar(70)
	, @ExecStr varchar(8000)
	, @rc int
	, @msg varchar(8000)
	, @Active_DB varchar(20)
	, @InputBuffer varchar(1000)

-- %%% Change Monitored database name
SET @Active_DB = 'Northwind'

SET NOCOUNT ON
IF EXISTS(SELECT blocked FROM master.dbo.sysprocesses 
	WHERE dbid = DB_ID(@Active_DB) AND blocked > 0
		-- %%% In EM, Management, Current Activity..., Process Info
		-- Use the desired Application value(s)
	 	AND program_name IN('Visual Basic ', 'MyApplication') )
BEGIN -- block exists
	-- get the blocking spid
	SELECT @spid = spid, @hostname = hostname FROM master.dbo.sysprocesses
		-- %%% Adjust > 120 to the number of seconds a processes has been blocked
		-- before loging the data, notifying, and killing the Blocking process
		WHERE blocked = 0 AND (convert(money,getdate()-last_batch)* 86400.0) > 120
			AND spid IN (SELECT DISTINCT blocked FROM master.dbo.sysprocesses 
				WHERE dbid = DB_ID(@Active_DB) AND blocked > 0
					-- %%% In EM, Management, Current Activity..., Process Info
					-- Use the desired Application value(s)
				 	AND program_name IN('Visual Basic ', 'MyApplication') )
	IF @spid IS NOT NULL
		BEGIN
			CREATE TABLE #ProcInfo(
				EventType varchar(30),
				Parameters int,
				EventInfo varchar(255) )
			SET @ExecStr = 'DBCC INPUTBUFFER(' + CONVERT(varchar, @spid) + ') WITH NO_INFOMSGS'
			INSERT INTO #ProcInfo
			EXEC(@ExecStr)
			SELECT @InputBuffer = ISNULL('Type: '+EventType+', ','')
				+ISNULL('Param: '+CONVERT(varchar,Parameters)+', ','')
				+ISNULL('Buffer: '+EventInfo,'')
			FROM #ProcInfo
			DROP TABLE #ProcInfo
			-- record all processes affected by the blocking 
			-- blocker has blocked = 0 and last_batch that IS NOT NULL
			INSERT INTO BlockedProcess (spid, blocked, open_tran, login_time, 
				last_batch, loginname, hostname, secs, db, input_buffer)
			SELECT spid
				, blocked
				, open_tran
				, login_time
				, last_batch
				, convert(varchar(20),loginame)
				, convert(varchar(70),hostname)
				, convert(money,getdate()-last_batch)*86400.0
				, convert(varchar(20),DB_NAME(dbid))
				, CASE WHEN spid=@spid THEN @InputBuffer ELSE NULL END
			FROM master.dbo.sysprocesses
			WHERE (dbid = DB_ID(@Active_DB) AND blocked > 0
				-- %%% In EM, Management, Current Activity..., Process Info
				-- Use the desired Application value(s)
			 	AND program_name IN('Visual Basic ', 'MyApplication') ) 
				OR spid = @spid
			-- send message to user	
			-- %%% Change Application name [optional]
			SET @msg = 'Shut down application and restart' 
			SET @ExecStr='net send '+@hostname+' '+@msg
			-- %%% Comment if you do not wish to net send to the Blocking user
  			EXEC @rc=master.dbo.xp_cmdshell @ExecStr, no_output
			-- send email with all processes
			SET @msg = ''
			SELECT @msg = @msg+'SPID: '+CONVERT(varchar,spid)+CHAR(13)+CHAR(10)+ 
				'Blocked: '+CONVERT(varchar,blocked)+CHAR(13)+CHAR(10)+ 
				'Open Trans: '+CONVERT(varchar,open_tran)+CHAR(13)+CHAR(10)+ 
				'Login: '+CONVERT(varchar,login_time,121)+CHAR(13)+CHAR(10)+ 
				'Last Batch: '+CONVERT(varchar,last_batch,121)+CHAR(13)+CHAR(10)+ 
				'User: '+CONVERT(varchar,loginame)+CHAR(13)+CHAR(10)+ 
				'Machine: '+CONVERT(varchar,hostname)+CHAR(13)+CHAR(10)+ 
				'Seconds: '+CONVERT(varchar,CONVERT(money,getdate()-last_batch)*86400.0)+CHAR(13)+CHAR(10)+
				CASE WHEN spid=@spid THEN ISNULL('Blocker CMD: '+@InputBuffer,'') ELSE '' END +
				CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10) 
			FROM master.dbo.sysprocesses
			WHERE (dbid = DB_ID(@Active_DB) AND blocked > 0
				-- %%% In EM, Management, Current Activity..., Process Info
				-- Use the desired Application value(s)
			 	AND program_name IN('Visual Basic ', 'MyApplication') )
				OR spid = @spid
			-- %%% Change email address(es) for notification
			-- %%% Comment if you do not wish to send email
			EXEC master.dbo.xp_sendmail @recipients = 'notify@domain.com; admin@domain.com', 
				@message = @msg,
				-- %%% Change Application name [optional]
				@subject = 'Blocked process correction for application'
  			-- kill process
			SET @ExecStr = 'KILL '+CONVERT(varchar,@spid)
			-- %%% Comment if you do not wish to kill the blocking process
			EXEC (@ExecStr)
		END -- @spid IS NOT NULL
END -- block exists
SET NOCOUNT OFF
GO

PRINT 'Now create a scheduled job to EXEC sp_CheckForBlocking'
PRINT 'Suggest that the Job be scheduled for the same value in minutes as ' 
PRINT '  the value used above for the number of seconds a processes has '
PRINT '  been blocked, that way your worst case is a process is left '
PRINT '  blocking for less than twice this value'
PRINT ''
PRINT 'Finished Create Blocked Process script'
go

