/*
alert on blocking chains via email

This is a script I use to watch for blocking chains on a server there are four 
variables to be set. 
@Duration tells it how long to run. This will be an active thread for the duration. 
@IntervalSec how often to poll for blocking. 
@maxwaittime time in miliseconds a thread that is blocked that you wish to alert on 
30000 is 30 seconds. If a thread has been blocked that long alerts will start going out. 
@recivers, people who get the emails.

You can set it up as a job to start it will always show as executing until the 
duration runs out. I have it set to run every minute just in case there is a 
thread exit it will restart the job again.
*/
---------------------------------------------------------------------------------------------------
--pull input buffer from blocked threads 
--This query pulls spids and then processes those spids through the dbcc inputbuffer to get
--what they are doing. This is to aid in troubleshooting problems by getting as much detail
--as possible on running spids
---------------------------------------------------------------------------------------------------
/*
--this is the table to write the data to
CREATE TABLE [dbo].[blocking] (
	[tstamp] [datetime] NOT NULL ,
	[spid] [int] NULL ,
	[blocked] [int] NULL ,
	[waittype] [varchar] (255) NULL ,
	[waittime] [bigint] NULL ,
	[physical_io] [bigint] NULL ,
	[cpu_in_seconds] [bigint] NULL ,
	[memusage] [bigint] NULL ,
	[name] [nvarchar] (128)  NOT NULL ,
	[open_tran] [tinyint] NULL ,
	[status] [varchar] (20)  NULL ,
	[hostname] [varchar] (50)  NULL ,
	[program_name] [varchar] (100)  NULL ,
	[cmd] [varchar] (100)  NULL ,
	[nt_domain] [varchar] (100)  NULL ,
	[nt_username] [varchar] (200)  NULL ,
	[loginame] [varchar] (100)  NULL ,
	[EventType] [varchar] (255)  NULL ,
	[Parameters] [varchar] (255)  NULL ,
	[EventInfo] [varchar] (255)  NULL ,
	[text] [text]  NULL 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

*/
set nocount on

use <database you want data written to>

CREATE TABLE #tbl_fn_get_sql (
	[dbid] [smallint] NULL ,
	[objectid] [int] NULL ,
	[number] [smallint] NULL ,
	[encrypted] [bit] NOT NULL ,
	[text] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
) 

create table #active_spids
(
	spid int,
	blocked int,
	waittype varchar(255),
	waittime bigint,
	physical_io bigint,
	cpu bigint,
	memusage bigint,
	dbid int,
	open_tran tinyint,
	status varchar(20),
	hostname varchar(50),
	program_name varchar(100),
	cmd varchar(100),
	nt_domain varchar(100),
	nt_username varchar(200),
	loginame varchar(100),
	[sql_handle] [binary] (20) NOT NULL ,
	[stmt_start] [int] NOT NULL ,
	[stmt_end] [int] NOT NULL 

)

create table #active_spids_info
(
	spid int,
	blocked int,
	waittype varchar(255),
	waittime bigint,
	physical_io bigint,
	cpu bigint,
	memusage bigint,
	dbid int,
	open_tran tinyint,
	status varchar(20),
	hostname varchar(50),
	program_name varchar(100),
	cmd varchar(100),
	nt_domain varchar(100),
	nt_username varchar(200),
	loginame varchar(100),
	[sql_handle] [binary] (20) NOT NULL ,
	[stmt_start] [int] NOT NULL ,
	[stmt_end] [int] NOT NULL,
	EventType varchar(255),
	Parameters varchar(255),
	EventInfo varchar(255),
	[text] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
)

create table #event_info
(
	spid int,
	EventType varchar(255),
	Parameters varchar(255),
	EventInfo varchar(255)
)


DECLARE 
	@TerminateGatheringDT  datetime -- when to stop gathering
	, @WaitFor_Interval datetime
	, @LastRecordingDT datetime
	, @RecordingDT datetime
	, @myError int            -- Local copy of @@ERROR
	, @myRowCount int         -- Local copy of @@RowCount
	, @msgText nvarchar(4000) -- for error messages
	, @dbname varchar(255)
	, @svrname varchar(255)	
	, @datestart as datetime
	, @Duration datetime -- Duration of data collection
	, @IntervalSec int -- Approx sec in the gathering interval
	, @tstamp varchar(255)
	, @spid1 varchar(255)
	, @dbname1 varchar(255)
	, @status varchar(255)
	, @hostname varchar(255)
	, @programname varchar(255)
	, @cmd varchar(255)
	, @nt_domain varchar(255)
	, @nt_username varchar(255)
	, @loginame varchar(255)
	, @text varchar(8000)
	, @msg varchar(8000)
	, @sub varchar(8000)
	, @timestamp as datetime
	, @spid int
	, @sqlhandle binary(20)
	, @tsqlhandle as varchar(255)
	, @waittime varchar(255)
	, @waittype varchar(255)
	, @buffer varchar(255)
	, @maxwaittime int
	, @recivers varchar(8000)
	, @diffmsec bigint
set nocount on

	set @Duration = '08:00:00' -- Duration of data collection
	set @IntervalSec = 30 -- Approx sec in the gathering interval
	set @maxwaittime = 28000 -- This is in miliseconds!!!
	set @recivers = '<email addresses here>' --who all gets the emails
	SET @diffmsec = DATEDIFF(ms
                             , CONVERT(datetime, '00:00:00', 8)
                             , @Duration)

SELECT @WaitFor_Interval = DATEADD (s, @IntervalSec , 
	CONVERT (datetime, '00:00:00', 108)
                                 )
     , @TerminateGatheringDT = DATEADD(ms, @diffmsec,getdate())

WHILE getdate() <= @TerminateGatheringDT BEGIN

truncate table #active_spids
truncate table #active_spids_info
truncate table #event_info
truncate table #tbl_fn_get_sql

insert into #active_spids
select 
	spid,
	blocked,
	waittype,
	waittime,
	physical_io,
	cpu,
	[memusage],
	a.dbid,
	open_tran,
	a.status,
	hostname,
	program_name,
	cmd,
	nt_domain,
	nt_username,
	loginame,
	[sql_handle],
	[stmt_start],
	[stmt_end]
from
	(
		select 
			spid,
			blocked,
			'waittype' = 
			CASE
				WHEN waittype = 0x0001 THEN 	'Exclusive table lock'
				WHEN waittype = 0x0003 THEN 	'Exclusive intent lock'
				WHEN waittype = 0x0004 THEN 	'Shared table lock'
				WHEN waittype = 0x0005 THEN 	'Exclusive page lock'
				WHEN waittype = 0x0006 THEN 	'Shared page lock'
				WHEN waittype = 0x0007 THEN 	'Update page lock'
				WHEN waittype = 0x0013 THEN 	'Buffer resource lock (exclusive) request'
				WHEN waittype = 0x0013 THEN 	'Miscellaneous I/O (sort, audit, direct xact log I/O)'
				WHEN waittype = 0x0020 THEN 	'Buffer in I/O'
				WHEN waittype = 0x0022 THEN 	'Buffer being dirtied'
				WHEN waittype = 0x0023 THEN 	'Buffer being dumped'
				WHEN waittype = 0x0081 THEN 	'Write the TLog'
				WHEN waittype = 0x0200 THEN 	'Parallel query coordination'
				WHEN waittype = 0x0208 THEN 	'Parallel query coordination'
				WHEN waittype = 0x0420 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0421 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0422 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0423 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0424 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0425 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0800 THEN 	'Network I/O completion'
				WHEN waittype = 0x8001 THEN 	'Exclusive table lock'
				WHEN waittype = 0x8003 THEN 	'Exclusive intent lock'
				WHEN waittype = 0x8004 THEN 	'Shared table lock'
				WHEN waittype = 0x8005 THEN 	'Exclusive page lock'
				WHEN waittype = 0x8006 THEN 	'Shared page lock'
				WHEN waittype = 0x8007 THEN 	'Update page lock'
				WHEN waittype = 0x8011 THEN 	'Buffer resource lock (shared) request'
			ELSE	'OLEDB/Miscellaneous'
			END,
			waittime,
			physical_io,
			cpu,
			[memusage],
			dbid,
			open_tran,
			status,
			hostname,
			program_name,
			cmd,
			nt_domain,
			nt_username,
			loginame,
			[sql_handle],
			[stmt_start],
			[stmt_end]
 		from 
			master.dbo.sysprocesses with(NOLOCK)
		where 
			blocked > 0 and waittime > @maxwaittime
		union all
		select 
			spid,
			blocked,
			'waittype' = 
			CASE
				WHEN waittype = 0x0001 THEN 	'Exclusive table lock'
				WHEN waittype = 0x0003 THEN 	'Exclusive intent lock'
				WHEN waittype = 0x0004 THEN 	'Shared table lock'
				WHEN waittype = 0x0005 THEN 	'Exclusive page lock'
				WHEN waittype = 0x0006 THEN 	'Shared page lock'
				WHEN waittype = 0x0007 THEN 	'Update page lock'
				WHEN waittype = 0x0013 THEN 	'Buffer resource lock (exclusive) request'
				WHEN waittype = 0x0013 THEN 	'Miscellaneous I/O (sort, audit, direct xact log I/O)'
				WHEN waittype = 0x0020 THEN 	'Buffer in I/O'
				WHEN waittype = 0x0022 THEN 	'Buffer being dirtied'
				WHEN waittype = 0x0023 THEN 	'Buffer being dumped'
				WHEN waittype = 0x0081 THEN 	'Write the TLog'
				WHEN waittype = 0x0200 THEN 	'Parallel query coordination'
				WHEN waittype = 0x0208 THEN 	'Parallel query coordination'
				WHEN waittype = 0x0420 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0421 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0422 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0423 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0424 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0425 THEN 	'Buffer I/O latch'
				WHEN waittype = 0x0800 THEN 	'Network I/O completion'
				WHEN waittype = 0x8001 THEN 	'Exclusive table lock'
				WHEN waittype = 0x8003 THEN 	'Exclusive intent lock'
				WHEN waittype = 0x8004 THEN 	'Shared table lock'
				WHEN waittype = 0x8005 THEN 	'Exclusive page lock'
				WHEN waittype = 0x8006 THEN 	'Shared page lock'
				WHEN waittype = 0x8007 THEN 	'Update page lock'
				WHEN waittype = 0x8011 THEN 	'Buffer resource lock (shared) request'
			ELSE	'OLEDB/Miscellaneous'
			END,
			waittime,
			physical_io,
			cpu,
			[memusage],
			dbid,
			open_tran,
			status,
			hostname,
			program_name,
			cmd,
			nt_domain,
			nt_username,
			loginame,
			[sql_handle],
			[stmt_start],
			[stmt_end]
		from 
			master.dbo.sysprocesses with(NOLOCK)
		where
			spid in
			( 
				select 
					blocked 
				from 
					master.dbo.sysprocesses with(NOLOCK)
				where 
					blocked > 0 and waittime > @maxwaittime
			) 
	) a
order by blocked

--loop through the spids without a cursor
while (select count(spid) from #active_spids) > 0
begin
	set @spid = (select top 1 spid from #active_spids order by spid)
	--grab the top spid
	insert into #active_spids_info 
	(
		spid,
		blocked,
		waittype,
		waittime,
		physical_io,
		cpu,
		[memusage],
		dbid,
		open_tran,
		status,
		hostname,
		program_name,
		cmd,
		nt_domain,
		nt_username,
		loginame,
		[sql_handle],
		[stmt_start],
		[stmt_end] 
	)
	select top 1
		spid,
		blocked,
		waittype,
		waittime,
		physical_io,
		cpu,
		[memusage],
		dbid,
		open_tran,
		status,
		hostname,
		program_name,
		cmd,
		nt_domain,
		nt_username,
		loginame,
		[sql_handle],
		[stmt_start],
		[stmt_end] 
	from 
		#active_spids 
	order by 
		spid

	insert into #event_info (EventType,Parameters,EventInfo) EXEC('DBCC INPUTBUFFER (' + @spid + ') WITH NO_INFOMSGS')
	--get the inputbuffer 

	exec('update #event_info set spid = '+@spid+' where spid IS NULL')
	--add the spid to the input buffer data

	select @sqlhandle = sql_handle from #active_spids where spid = @spid

	insert into #tbl_fn_get_sql 
	select * from ::fn_get_sql(@sqlhandle)

	UPDATE #active_spids_info 
		SET 
		#active_spids_info.text = #tbl_fn_get_sql.text
		FROM
			#active_spids_info,#tbl_fn_get_sql
		WHERE 
			#active_spids_info.spid = @spid

	truncate table #tbl_fn_get_sql

	delete from #active_spids where spid = @spid
	--remove the spid processed
end

UPDATE #active_spids_info 
	SET 
	#active_spids_info.EventType = #event_info.EventType,
	#active_spids_info.Parameters = #event_info.Parameters,
	#active_spids_info.EventInfo = #event_info.EventInfo
	FROM
		#active_spids_info, #event_info
	WHERE 
		#active_spids_info.spid = #event_info.spid
--join all the info into one table

set @timestamp = getdate()
--select statement to return results 
insert into management.dbo.blocking
select	@timestamp as tstamp,
	a.spid,
	a.blocked,
	a.waittype,
	a.waittime,
	a.physical_io,
	(a.cpu/1000) as cpu_in_seconds,
	a.[memusage],
	b.[name],
	a.open_tran,
	a.status,
	a.hostname,
	a.program_name,
	a.cmd,
	a.nt_domain,
	a.nt_username,
	a.loginame,
	a.EventType,
	a.Parameters,
	a.EventInfo,
	a.text
from 
	#active_spids_info a
inner join
	master.dbo.sysdatabases b
on
	a.dbid = b.dbid
if ((select max(tstamp) from management.dbo.blocking where blocked = 0) = @timestamp)
begin
	select @sub = 'Blocking Issues - '+cast(serverproperty('servername') as varchar(255))
	
	select 
		@tstamp = tstamp,
		@spid1 = spid,
		@status = status,
		@hostname = isnull(hostname,''),
		@programname = isnull(program_name,''),
		@cmd = isnull(cmd,''),
		@nt_domain = isnull(nt_domain,''),
		@nt_username = isnull(nt_username,''),
		@loginame = isnull(loginame,''),
		@text = isnull([text],''),
		@waittime = (select max(waittime) from management.dbo.blocking where tstamp = (select max(tstamp) from management.dbo.blocking)),
		@waittype = isnull(waittype,''),
		@buffer = isnull(EventInfo,'')
	
	from  
		management.dbo.blocking 
	where 
		tstamp = (
				select max(tstamp) 
				from 
					management.dbo.blocking) and blocked = 0


	select @msg ='The user below is at the head of the blocking chain on the listed server:'+char(13)+
	'__________________________________________________________________________'+char(13)+
	'TimeStamp: '+@tstamp+char(13)+
	'SPID: '+@spid1+char(13)+
	'Login Name: '+@loginame+char(13)+
	'NT Domain: '+@nt_domain+char(13)+
	'NT Username: '+@nt_username+char(13)+
	'Host Name: '+@hostname+char(13)+
	'Command: '+@cmd+char(13)+
	'Program Name: '+@programname+char(13)+
	'Wait Type: '+@waittype+char(13)+
	'Maximum Wait Time For Blocked Thread: '+@waittime+char(13)+char(13)+
	'Input Buffer: '+@buffer+char(13)+
	'Status: '+@status+char(13)+
	'SQL String:'+char(13)+
	'--WARNING CAN BE LONG AND MAY NOT BE THE WHOLE TEXT!!!--'+char(13)+@text
	
	EXEC master.dbo.xp_sendmail @recipients = @recivers, 
	   @subject = @sub,
	   @message = @msg


/*
--	just used to debug and make sure email is running	
	EXEC master.dbo.xp_sendmail @recipients = 'wbrown@thescooterstore.com', 
	@subject = 'test',
	@message = 'test'
*/
end

WAITFOR DELAY @WaitFor_Interval   -- delay      
END

drop table #active_spids
drop table #active_spids_info
drop table #event_info
drop table #tbl_fn_get_sql
set nocount off




