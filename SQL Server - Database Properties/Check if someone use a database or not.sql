/*
Check if someone use a database or not
I manage quite a few hundred databases across the company. 
Time to time I get a question if I can check wheather a database is being used or not, and if it is, by whom?

There are probably a 1000 ways to do this, but I've created a script for creating a scheduled job that runs in 
tempdb and checks the database i want to know about. I've rewritten it a bit, since I also had a part that send 
a signal to our ControlCenter when someone used the database (this is skipped in this script).

The script creates three objects. One table and one stored procedure on tempdb and a scheduled job that the script 
start automaticlly.

It's written so that you can check more then 1 database on a server at the same time.

If either the sproc or the table created in tempdb already exists when the script is run, it will delete them 
without notice. The scheduled job created will not delete the objects in tempdb, since this will be deleted 
whenever the sql-server is restarted.
You can then modify the created job to report to you or someone else whenever your criteria has been met. 
Use for example net send operator or just send a mail.
Good luck! 
*/

USE tempdb
GO

DECLARE	@db			VARCHAR(255),
		@interval	INT,
		@stopat		DATETIME,
		@totalusers	INT,
		@reportfile	VARCHAR(500)

/*************************************************************************************
**	PURPOSE:                                                                        **
**		Check if a database is beeing used or not                                   **
**                                                                                  **
**	COMPATIBLE WITH:                                                                **
**		SQL 7.0                                                                     **
**		SQL 8.0                                                                     **
**                                                                                  **
**	VARIABLES:                                                                      **
**		NAME			DESCRIPTION                                                 **
**		============	==========================================================  **
**		@db				What database to check                                      **
**						cannot be NULL                                              **
**		@interval		How many milliseconds between each check                    **
**						minimum value: 1                                            **
**						maximum value: 999                                          **
**						default 1 (each millisecond)                                **
**		@stopat			When the schudeled task will end                            **
**						default NULL (never stop)                                   **
**						FORMAT yyyy-mm-dd hh:mm:ss.mmm                              **
**		@totalusers		How many users have to logon before reporting               **
**						default 1                                                   **
**		@reportfile		Full local path and filename on the server for report       **
**						default NULL (do not create reportfile).rpt"                **
**		============	==========================================================  **
**                                                                                  **
**	OBJECTS CREATED:                                                                **
**		tempdb.dbo.database_<db>_usage_table                                        **
**		tempdb.dbo.database_<db>_usage_proc                                         **
**		A checkulded job named:                                                     **
**		DATABASE USAGE CHECK - <mydb>                                               **
**		@reportfile (if not NULL)                                                   **
**                                                                                  **
**************************************************************************************/

SELECT @db = 'mydb'
SELECT @interval = 10
SELECT @stopat = '2003-12-31'
SELECT @totalusers = 1
SELECT @reportfile = 'C:\MyReportFile.rpt'

SET NOCOUNT ON

DECLARE	@jobname		VARCHAR(255),
		@job_id			UNIQUEIDENTIFIER,
		@job_step_id	UNIQUEIDENTIFIER,
		@tempvar		VARCHAR(255)

-- CHECK AND SET VARIABLES
IF ( @db IS NULL )
BEGIN
	PRINT 'Variable @db has to be set'
	GOTO the_end
END
IF NOT EXISTS ( SELECT * FROM master.dbo.sysdatabases WHERE name = @db )
BEGIN
	PRINT 'DATABASE ' + @db + ' NOT FOUND ON THIS SERVER'
	GOTO the_end
END
IF ( @interval IS NULL OR @interval < 1 OR @interval > 999 )
BEGIN
	PRINT 'Variable @interval has to be an integer between 1 and 999'
	GOTO the_end
END
IF ( @stopat < GETDATE() )
BEGIN
	PRINT 'Variabel @stopat has to be after current time'
	GOTO the_end
END
IF ( @stopat IS NULL )
	SELECT @stopat = '9999-12-31'
IF ( @totalusers IS NULL )
	SELECT @totalusers = 1

-- Create a temporary table in tempdb
IF EXISTS (
	SELECT	*
	FROM	dbo.sysobjects
	WHERE	name = 'database_' + @db + '_usage_table' AND
			type = 'U' )
	EXEC('DROP TABLE dbo.database_' + @db + '_usage_table')

EXEC ('
		create table dbo.database_' + @db + '_usage_table (
		checkdate		smalldatetime	null,
		db				varchar(50)		null,
		loginame		varchar(255)	null,
		nt_username		nchar(128)		null,
		hostname		nchar(128)		null
		)
	')

-- Create a proc to run in tempdb
IF EXISTS (
	SELECT	*
	FROM	dbo.sysobjects
	WHERE	name = 'database_' + @db + '_usage_proc' AND
			type = 'P' )
	EXEC('DROP PROCEDURE dbo.database_' + @db + '_usage_proc')

EXEC ('
	CREATE PROC dbo.database_' + @db + '_usage_proc
		@stopat		DATETIME,
		@interval	INT,
		@totalusers	INT
	AS

	SET NOCOUNT ON

	IF ( @stopat < GETDATE() )
		RAISERROR (''Variabel @stopat has to be after current time'', 16, 1)

	DECLARE	@waitfor DATETIME
	SELECT	@waitfor = GETDATE()

	WHILE ( GETDATE() < @stopat )
	BEGIN
		-- Check if there are any users using the database
		INSERT INTO dbo.database_' + @db + '_usage_table (
			checkdate,
			db,
			loginame,
			nt_username,
			hostname
		)
		SELECT	DISTINCT
				GETDATE(),
				DB_NAME(sp.dbid),
				RTRIM(sp.loginame),
				RTRIM(sp.nt_username),
				RTRIM(sp.hostname)
		FROM	master.dbo.sysprocesses sp
				LEFT OUTER JOIN dbo.database_' + @db + '_usage_table dut ON sp.loginame = dut.loginame
		WHERE	DB_NAME(sp.dbid) = ''' + @db + '''
					AND dut.loginame IS NULL

		-- Check if total users logged has been met
		IF ( SELECT COUNT(*) FROM dbo.database_' + @db + '_usage_table ) >= @totalusers
			GOTO out_of_loop

		SELECT	@waitfor = DATEADD(ms, @interval , GETDATE())

		WAITFOR TIME @waitfor
	END

	out_of_loop:
		SELECT	*
		FROM	dbo.database_' + @db + '_usage_table
		ORDER BY
				checkdate
')

-- Create the sceduled job
SELECT	@jobname = 'DATABASE USAGE CHECK - ' +  @db

IF EXISTS (
	SELECT	*
	FROM	msdb.dbo.sysjobs
	WHERE	name = @jobname )
	BEGIN
		PRINT 'The scheduled job ''' + @jobname + ''' already exists'
		GOTO the_end
	END

-- Add the job
EXEC	msdb.dbo.sp_add_job
		@job_name =						@jobname,
		@description =					'Job for checking database usage',
		@start_step_id =				1,
		@owner_login_name =				'sa',
		@notify_level_eventlog =		2, -- on failure
		@job_id =						@job_id OUTPUT

-- Add the jobstep
SELECT	@tempvar =
'EXEC dbo.database_' + @db + '_usage_proc
	@stopat = ''' + CONVERT(VARCHAR, @stopat, 21) + ''', -- yyyy-mm-dd hh:mm:ss.mmm
	@interval = ' + CONVERT(VARCHAR, @interval) + ', -- min 0, max 999
	@totalusers = ' + CONVERT(VARCHAR, @totalusers) + ' -- min 1, max 2^31-1'

EXEC	msdb.dbo.sp_add_jobstep
		@job_id =				@job_id,
		@step_id = 				1,
		@step_name =			@jobname,
		@subsystem =			'TSQL',
		@command =				@tempvar,
		@cmdexec_success_code =	0,
		@on_success_action =	1, -- quit with success
		@on_fail_action =		2, -- quit with failure
		@database_name =		'tempdb'

-- Shall there be a reportfile
IF ( @reportfile IS NOT NULL )
	EXEC msdb.dbo.sp_update_jobstep
		@job_id =			@job_id,
		@step_id =			1,
		@step_name =		@jobname,
		@output_file_name =	@reportfile

-- Set target server to local server
EXEC msdb.dbo.sp_add_jobserver
	@job_id = @job_id,
	@server_name = '(local)' 

-- Start the job
EXEC msdb.dbo.sp_start_job @job_id = @job_id

the_end:
GO

