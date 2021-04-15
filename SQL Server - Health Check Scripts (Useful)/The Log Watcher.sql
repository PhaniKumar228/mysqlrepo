/*
The Log Watcher 

A fast way to get a quick look at all the log sizes and space used in a real time fashion. 

*/

The log watcher is only 3 small files (cklog.sql, cklog.cmd, sleep.exe) and a fast way to get a quick look at all the log sizes and space used in a real time fashion. 

Sleep.exe must be in the working directory.

Take this script for example cklog.sql. 
This method will bring you back a nicely formatted result set called from OSQL in a shell window. You could easily add a where clause and exclude specified databases. [ WHERE DBName Not IN (msdb,model)] 

set nocount on

 DECLARE @sql_command varchar(255) 

CREATE TABLE #TempForLogSpace 

( 

DBName varchar(18), 

[LogSize (MB)] int, 

[LogSpaceUsed (%)] int, 

Status int 

) 

SELECT @sql_command = 'dbcc sqlperf (logspace)' 

INSERT #TempForLogSpace 

EXEC (@sql_command) 

SELECT * FROM #TempForLogSpace 

DROP TABLE #TempForLogSpace 

go

Take this file for example cklog.cmd.
This script will reference spleep.exe (resource kit) to initialize the script every 11 seconds calling cklog.sql.
Also note the path to the cklog.sql file 

@echo off 

:a 

echo %%%%!!!!!!!!!!![SERVERNAME] LOGSTATS !!!!!!!!!!%%%%  

OSQL -U[login] -P[password] -S[servername]-a -n -iC:\Monitor\cklog.sql 

sleep 11

goto :a

pause


