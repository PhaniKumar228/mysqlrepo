/***********************************************************************************************/
/***********************************************************************************************/
/*
/*to implement:
    A-execute sql script to create three stored procedures, usp_fullbackups, usp_diffBackup and
      usp_Tlogbackup.
    B-create visual basic script file by following instructions in VBScript section.
    C-Change all 5 paths in marked areas
        Path change 1, change -BkupDB path to location of full backups
        Path change 2, change this path to point to location of diffBackupFileDelete.VBS
        Path change 3, change path to location of differential backups
        Path change 4, change Path next to -BkUpLog to location of transaction log backups
        Path change 5, change path to physical location of vbscript file
    D-Change length of times to keep full, differential or transaction log backus where marked
        Change retention date 1 next to -DelBkups i.e. 2days, 2weeks, etc.
        Change retention date 2 next to -DelBkups i.e. 2days, 2weeks, etc.
        Change retention date 3, change number to subtract from now date
                i.e. 1 to delete after 1day, etc
    E-In SQL Agent, create and enable following jobs
        1.Full Backups, step one type command: exec dbo.usp_fullbackups
        2.Differential backups, step one type command: exec dbo.usp_diffBackup
        3.Transaction Log Backups, step one type command: exec dbo.usp_tlogBackup. 
        Set each job to run according to policy (e.g. full backups weekly, differential daily,
        and tlogs hourly around full and differential times). 
    F- monitor jobs to ensure they execute and check for sufficient disk space.    
    G-also ensure that sql server and agent accounts have sufficient access to backup and vb script 
      directory. 
   */
/***********************************************************************************************/
/*Full Backup */
/***********************************************************************************************/  
Use Master
GO
Create procedure dbo.usp_fullBackups
As
/*Created by Patty Dunbar 6/3/03*/
/*Procedure to check recovery mode of database
and will backup all databases set to full recovery mode*/
declare @dbname varchar(50), @dbid smallint
declare @svr varchar(50), @cmd nvarchar(255)

declare dbnamecur cursor for
select [name], dbid, host_name() as server from dbo.sysdatabases
open dbnamecur
Fetch next from dbnamecur into
@dbname, @dbid, @svr

While @@fetch_status = 0
Begin 
If (SELECT databasepropertyex(@dbname, 'recovery')) = 'Full'
Begin

--Path change 1, change -BkupDB path to location of full backups
 select @cmd = 'exec xp_sqlmaint ' + char(39) + '-S' + char(32) + @svr + char(32) +
	'-D' + char(32) +  @dbname + char(32) + ' -BkUpDB "G:\MSSQL\Backup\FullDatabase" 
	-BkUpMedia DISK  -DelBkUps 1days -WriteHistory ' + char(39) 
	--change retention date 1 next to -DelBkups i.e. 2days, 2weeks, etc.
	 
-- Execute command to place a record in table that holds backup names       
  exec sp_executesql @cmd

--Print 'database ' + @dbname + ' has full recovery and has been backed up on ' + @svr

End
Else
Begin
--Print 'database ' + @dbname + ' has simple recovery and was not backed up on ' + @svr
End

Fetch next from dbnamecur into
@dbname, @dbid, @svr
END
close dbnamecur
deallocate dbnamecur
GO
/****************************************************************************************/
/*Differential Backup*/
/****************************************************************************************/
Use Master 
GO
Create procedure dbo.usp_diffBackup
/*created by Patty Dunbar 6/6/03*/
/*to implement:
    1- copy vbscript to local folder on sqlserver host
    2-in vbscript, change path next to fdir = to point to location of backups
    3- in this script, next to execute xp_cmdshell, change path to point to vbscript file
    4-execute this script using master database in sql
    5-set sql job to call command: exec dbo.usp_diffBackup as step one
    6-name the job differential backup and schedule per policy */
AS
declare @dbname varchar(50), @dbid smallint
declare @svr varchar(50), @cmd nvarchar(250)
declare @result smallint, @backupfile varchar(50)

/*calls script to delete old backup files*/
--Pathchange 2, change this path to point to location of diffBackupFileDelete.VBS
EXECUTE xp_cmdshell 'CSCRIPT G:\MSSQL\Backup\BackupScript\diffBackupFileDelete.Vbs', no_output


declare dbnamecur cursor for
select [name], dbid, host_name() as server from dbo.sysdatabases 
where  NOT  [name] = 'master'

open dbnamecur

Fetch next from dbnamecur into
@dbname, @dbid, @svr

While @@fetch_status = 0
Begin 
If (SELECT databasepropertyex(@dbname, 'recovery')) = 'Full'
Begin
--Pathchange 3, change path to location of differential backups
    Select @cmd = 'Backup Database' + Char(32) + @dbname +  Char(32) + 'TO Disk='+ Char(32) +
        'N' + Char(39) + 'G:\MSSQL\Backup\DiffDatabase\'+
	@dbname + '_' + CONVERT(char(8),getdate(),112) + Cast(DatePart(HH,getdate()) As Char(2))
    + Cast(DatePart(MI,getdate()) As char(2)) + '.bak' + char(39) + char(32) +
    'With NOINIT, DIFFERENTIAL, Name = N''Diff Backup'', NOSKIP, STATS = 10, NOFORMAT'
    
    exec sp_executesql @cmd  
End

Fetch next from dbnamecur into
@dbname, @dbid, @svr
END

close dbnamecur
deallocate dbnamecur
GO
/*******************************************************************************************/
/*Transaction Log Backups*/
/*******************************************************************************************/
Create procedure usp_tLogBackups
As
/*Created by Patty Dunbar 6/3/03*/
/*Procedure to check recovery mode of database
and will backup all databases set to full recovery mode*/
declare @dbname varchar(50), @dbid smallint
declare @svr varchar(50), @cmd nvarchar(255)

declare dbnamecur cursor for
select [name], dbid, host_name() as server from dbo.sysdatabases
where not [name] = 'master'

open dbnamecur

Fetch next from dbnamecur into
@dbname, @dbid, @svr

While @@fetch_status = 0
Begin 
If (SELECT databasepropertyex(@dbname, 'recovery')) = 'Full'
Begin

--Path change 4, change Path next to -BkUpLog to location of transaction log backups
 select @cmd = 'exec xp_sqlmaint ' + char(39) + '-S' + char(32) + @svr + char(32) +
	'-D' + char(32) +  @dbname + char(32) + ' -BkUpLog "G:\MSSQL\Backup\Logs" -BkUpMedia DISK  
	-DelBkUps 1days -WriteHistory ' + char(39)        
--change retention date 2 next to -DelBkups i.e. 2days, 2weeks, etc.

-- Execute command   
  exec sp_executesql @cmd
End

Fetch next from dbnamecur into
@dbname, @dbid, @svr
END
close dbnamecur
deallocate dbnamecur
GO
/*******************************************************************************************/
/*VBScript*/
/*VBScript to clean up differential backup files
- to implement copy everything in between the do not copy lines into notepad and 
name the file diffBackupFileDelete.vbs .  Ensure the extension is vbs not text or it will not
execute*/
/*******************************************************************************************/
/*Do not copy this line, start one below*/ /*
'Written by Patty Dunbar 6/6/03
'Cleans up differential backup files
'deletes files if older than OldDate
'events are recorded to event log of host computer executing script, preferably sql server host
Option Explicit
Dim fs, f, bFile, fc,  fileDate, results, fDir, OldDate
'path change 5, change path to physical location of vbscript file, ensure that the sql server
'service and agent have permission to this directory
fDir = "C:\restore\DiffBackups\"  
    	'set this directory to the physical location where the backups are stored

OldDate = (Now() - (1)) 
	 ' date to delete, returns todays date minus the number of days to equal deletion date
'Change retention date 3, change number to subtract from now date
'i.e. 1 to delete after 1day, etc
	
Set fs = CreateObject("Scripting.FileSystemObject")
Set f = fs.GetFolder(fDir)

Set fc = f.Files
    'begins loop to retrieve all files 
    For Each bFile In fc
    fileDate = GetFileDate(bFile.Path)
    If (fileDate < OldDate) Then 
        results = results & bFile.name & " created on " & fileDate & " deleted " & vbCrLf 
    	FileDelete(bFile.Path) 'calls sub to remove files
       End IF     
    Next
    If (results = "") Then results = "No backup files older than " & OldDate & " to delete."
       
    LogEvent(results) 'calls sub to log results to event log
    
    'msgbox results  'uncomment for testing
    

'Function to the get the date last modified of a backup file    
Function GetFileDate(filePath)
Dim dtFile
Set dtFile = fs.GetFile(filePath)
GetFileDate = dtFile.DateLastModified
End Function 

'Sub which deletes the file
Sub FileDelete(filePath)
Dim dFile
Set dFile = fs.GetFile(filePath)
on error resume next
dFile.Delete
End Sub 

'sub which logs events
Sub LogEvent(results)
dim logShell
const SUCCESS = 0
const ERROR = 1
const WARNING = 2
const INFORMATION = 4
const AUDIT_SUCCESS = 8
const AUDIT_FAILURE = 16
Set logShell = CreateObject("Wscript.Shell")
logShell.LogEvent INFORMATION, results
End Sub

Do not copy this line, start one above*/
