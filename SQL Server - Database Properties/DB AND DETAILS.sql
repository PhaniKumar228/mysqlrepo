-----------------------------------------------------------------------

Exec sp_track_db_growth

----------------------------- Procedure to track db growth ------------
USE master
GO

CREATE PROC sp_track_db_growth
(
@dbnameParam sysname = NULL
)
AS
BEGIN

DECLARE @dbname sysname

/* Work with current database if a database name is not specified */

SET @dbname = COALESCE(@dbnameParam, DB_NAME())

SELECT	CONVERT(char, backup_start_date, 111) AS [Date], --yyyy/mm/dd format
	CONVERT(char, backup_start_date, 108) AS [Time],
	@dbname AS [Database Name], [filegroup_name] AS [Filegroup Name], logical_name AS [Logical Filename], 
	physical_name AS [Physical Filename], CONVERT(numeric(9,2),file_size/1048576) AS [File Size (MB)],
	Growth AS [Growth Percentage (%)]
FROM
(
	SELECT	b.backup_start_date, a.backup_set_id, a.file_size, a.logical_name, a.[filegroup_name], a.physical_name,
		(
			SELECT	CONVERT(numeric(5,2),((a.file_size * 100.00)/i1.file_size)-100)
			FROM	msdb.dbo.backupfile i1
			WHERE 	i1.backup_set_id = 
						(
							SELECT	MAX(i2.backup_set_id) 
							FROM	msdb.dbo.backupfile i2 JOIN msdb.dbo.backupset i3
								ON i2.backup_set_id = i3.backup_set_id
							WHERE	i2.backup_set_id < a.backup_set_id AND 
								i2.file_type='D' AND
								i3.database_name = @dbname AND
								i2.logical_name = a.logical_name AND
								i2.logical_name = i1.logical_name AND
								i3.type = 'D'
						) AND
				i1.file_type = 'D' 
		) AS Growth
	FROM	msdb.dbo.backupfile a JOIN msdb.dbo.backupset b 
		ON a.backup_set_id = b.backup_set_id
	WHERE	b.database_name = @dbname AND
		a.file_type = 'D' AND
		b.type = 'D'
		
) as Derived
WHERE (Growth <> 0.0) OR (Growth IS NULL)
ORDER BY logical_name, [Date]

END
----------------------------------------


DBCC SqlPerf(LogSpace)

Exec xp_cmdshell 'ipconfig'

Exec sp_helpserver

Select Name, FileName
From SysDatabases

Exec sp_readerrorlog 1

---Query To Trap Error Log Details----------

Create Table #ErrorLog
(
 ErrorLog sysname,
 ContinuationRow sysname,
 test1 sysname
)

Insert InTo #ErrorLog Exec xp_readerrorlog

Select * From #ErrorLog
Where ErrorLog Like '%Fail%' Or ErrorLog Like '%I/O%'

--------------------------------------------------------------------------------
/*
Create Table PDBSize
(
  Database_Name Varchar(100),
  YestSize Varchar(100),
  TodaySize Varchar(100),	
  YMdfSize Decimal(15,3),
  YLdfSize Decimal(15,3),
  TMdfSize Decimal(15,3),
  TLdfSize Decimal(15,3)
)

Insert InTo PDBSize (Database_Name, YestSize)
Select Database_Name, Database_Size
From #DataSize

Select *
From PDBSize

Update PDBSize
Set TodaySize = #DataSize.Database_Size, TMdfSize = #DataSize.MdfSize, TLdfSize = #DataSize.LdfSize
From PDBSize
Inner Join #DataSize
On PDBSize.Database_Name = #DataSize.Database_Name

*/

----------New Query To Find Database Size ---------------------------------------

--Drop Table #DBSize
--Drop Table #DataSize

Create Table #DBSize
(
  MdfSize Decimal(15,3),
  LdfSize Decimal(15,3),
  BytesPerPage Decimal(15,3)	
)

Create Table #DataSize
(
  Database_Name Varchar(100),
  Database_Size Varchar(100),
  MdfSize Decimal(15,3),
  LdfSize Decimal(15,3),
  [Unallocate Space] Varchar(100)	
)

Declare @DataBaseName VarChar(255), @DbName SysName, @SqlCmd NVarchar(2000), @FileName VarChar(100), @VarName Varchar(20), @VarName1 Varchar(20)

Declare @dbsize dec(15,0)
Declare @logsize dec(15,0)
Declare @bytesperpage dec(15,0)
Declare @pagesperMB	dec(15,0)

Declare CrDataBase Cursor For
Select Name 
From Master.Dbo.SysDatabases

Open CrDataBase

Fetch Next From CrDataBase InTo @DataBaseName
While @@Fetch_Status = 0
Begin

    Set @DBName = @DataBaseName

	--exec (N'use ' + N'[' + @DBName + N']')	

	dbcc updateusage(@DBName) with no_infomsgs

	Set @SqlCmd = 'Select Sum(Convert(Dec(15),Size)), 0, 0 
				   From ' + @DBName + '.dbo.SysFiles 
				   Where (Status & 64 = 0)'

	Insert InTo #DBSize Exec (@SqlCmd)
	
	Set @SqlCmd = 'UpDate #DBSize Set LdfSize = (Select Sum(Convert(Dec(15),Size)) 
				   From ' + @DBName + '.dbo.SysFiles 
				   Where (Status & 64 <> 0))
                   		   From #DBSize'
	
	Exec (@SqlCmd)

	Set @VarName = '''E'''	

	Set @SqlCmd = 'UpDate #DBSize Set bytesperpage = (Select low 
				   From Master.dbo.spt_values
				   Where Number = 1 And Type = ' + @VarName + ')	
				   From #DBSize'

	Exec (@SqlCmd)
		
	Set @VarName = '''Unallocated Space'''
	Set @VarName1 = '''  MB'''
	
	Set @DataBaseName = '''' + @DataBaseName
	Set @DataBaseName = @DataBaseName + ''''

	Set @SqlCmd = 'Select Database_Name = ' + @DataBaseName + ',
						  Database_size = LTrim(Str(((Select MdfSize From #DBSize) + (Select LdfSize From #DBSize)) / (1048576 / (Select BytesPerPage From #DBSize)),15,2) + ' + @VarName1 + '), (Select MdfSize From #DBSize) / (1048576 / (Select BytesPerPage From #DBSize)),  (Select LdfSize From #DBSize) / (1048576 / (Select BytesPerPage From #DBSize)), ' 
						  + @VarName + ' = 
							LTrim(Str(((Select MdfSize From #DBSize) -
								(Select Sum(Convert(dec(15), Reserved))
									From ' + @DBName + '.dbo.Sysindexes
										Where indid in (0, 1, 255)
								)) / (1048576 / (Select BytesPerPage From #DBSize)),15,2)+ ' + @VarName1 + ')'
	--Print @SqlCmd
	
	Insert InTo #DataSize Exec (@SqlCmd)

	Truncate Table #DBSize 
	 
    Fetch Next From CrDataBase InTo @DataBaseName
End

Close CrDataBase

DeAllocate CrDataBase

Select *
From #DataSize


-----Find Database Size For a given Database Query --------------------------------------------------

Sp_MsForEachDb 'Use ? Exec Sp_SpaceUsed'

-------Ready Query For Failed Jobs --------------
CREATE procedure usp_failed_jobs_report as

declare @RPT_BEGIN_DATE datetime
declare @NUMBER_OF_DAYS int
-- Set the number of days to go back to calculate the report begin date
set @NUMBER_OF_DAYS = -1
-- If the current date is Monday, then have the report start on Friday.
if datepart(dw,getdate()) = 2
  set @NUMBER_OF_DAYS = -3
-- Get the report begin date and time
set @RPT_BEGIN_DATE = dateadd(day,@NUMBER_OF_DAYS,getdate()) 
-- Get todays date in YYMMDD format
-- Create temporary table to hold report
create table ##temp_text (
email_text char(100))
-- Generate report heading and column headers
insert into ##temp_text values('The following jobs/steps failed since ' + 
                               cast(@RPT_BEGIN_DATE as char(20)) )
insert into ##temp_text values ('job                                         step_name                         failed datetime    ')
insert into ##temp_text values ('------------------------------------------- --------------------------------- -------------------')
-- Generate report detail for failed jobs/steps
insert into ##temp_text (email_text)
 select substring(j.name,1,43)+ 
        substring('                                           ',
        len(j.name),43) + substring(jh.step_name,1,33) + 
        substring('                                 ',
        len(jh.step_name),33) + 
        -- Calculate fail datetime
        -- Add Run Duration Seconds
        cast(dateadd(ss,
        cast(substring(cast(run_duration + 1000000 as char(7)),6,2) as int),
        -- Add Run Duration Minutes 
        dateadd(mi,
        cast(substring(cast(run_duration + 1000000 as char(7)),4,2) as int),
        -- Add Run Duration Hours
        dateadd(hh,
        cast(substring(cast(run_duration + 1000000 as char(7)),2,2) as int),
        -- Add Start Time Seconds
        dateadd(ss,
        cast(substring(cast(run_time + 1000000 as char(7)),6,2) as int),
        -- Add Start Time Minutes 
        dateadd(mi,
        cast(substring(cast(run_time + 1000000 as char(7)),4,2) as int),
        -- Add Start Time Hours
        dateadd(hh,
        cast(substring(cast(run_time + 1000000 as char(7)),2,2) as int),
        convert(datetime,cast (run_date as char(8))))
           ))))) as char(19))
   from msdb..sysjobhistory jh join msdb..sysjobs j on jh.job_id=j.job_id
   where   (getdate() >
               -- Calculate fail datetime
               -- Add Run Duration Seconds
               dateadd(ss,
               cast(substring(cast(run_duration + 1000000 as char(7)),6,2) as int),
               -- Add Run Duration Minutes 
               dateadd(mi,
               cast(substring(cast(run_duration + 1000000 as char(7)),4,2) as int),
               -- Add Run Duration Hours
               dateadd(hh,
               cast(substring(cast(run_duration + 1000000 as char(7)),2,2) as int),
               -- Add Start Time Seconds
               dateadd(ss,
               cast(substring(cast(run_time + 1000000 as char(7)),6,2) as int),
               -- Add Start Time Minutes 
               dateadd(mi,
               cast(substring(cast(run_time + 1000000 as char(7)),4,2) as int),
               -- Add Start Time Hours
               dateadd(hh,
               cast(substring(cast(run_time + 1000000 as char(7)),2,2) as int),
               convert(datetime,cast (run_date as char(8))))
               )))))) 
and  (@RPT_BEGIN_DATE < -- Calculate fail datetime
               -- Add Run Duration Seconds
               dateadd(ss,
               cast(substring(cast(run_duration + 1000000 as char(7)),6,2) as int),
               -- Add Run Duration Minutes 
               dateadd(mi,
               cast(substring(cast(run_duration + 1000000 as char(7)),4,2) as int),
               -- Add Run Duration Hours
               dateadd(hh,
               cast(substring(cast(run_duration + 1000000 as char(7)),2,2) as int),
               -- Add Start Time Seconds
               dateadd(ss,
               cast(substring(cast(run_time + 1000000 as char(7)),6,2) as int),
               -- Add Start Time Minutes 
               dateadd(mi,
               cast(substring(cast(run_time + 1000000 as char(7)),4,2) as int),
               -- Add Start Time Hours
               dateadd(hh,
               cast(substring(cast(run_time + 1000000 as char(7)),2,2) as int),
               convert(datetime,cast (run_date as char(8))))
               )))))) 
      
      and jh.run_status = 0
-- Email report to DBA distribution list
--exec master.dbo.xp_sendmail @recipients='Greg.Larsen@sqlservercentral.com',
--              @subject='Check for Failed Jobs - Contains jobs/steps that have failed.', 
--              @query='select * from ##temp_text' , @no_header='true', @width=150
-- Drop temporary table
--drop table ##temp_text
 

Exec usp_failed_jobs_report

Select * From ##temp_text

-------------- Temp Db Full Issue ----------------------------
use tempdb

Exec Sp_SpaceUsed

Select [Name]
From TempDb..SysObjects

Select Object_Name(id), RowCnt
From TempDb..SysIndexes
Where Object_Name(Id) Like '#%'

DBCC OpenTran('TempDb')

Exec Sp_HelpDb 'TempDb'

Select Databasepropertyex('tempdb','db_size')

------------------------------------------