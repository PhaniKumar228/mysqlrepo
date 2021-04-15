/*
OSQL Process Watcher

These 2 files plus sleep.exe (Resource kit) gives an administrator a good view of important blocking statistics in almost a real time fashion. You can use this with profiler to obtain some unique information very fast on a lead blocker if your gathering the right counters in profiler and dumping them in a table and querying it correctly. Put all 3 files in the same directory. You will want to adjust the properties of the cmd window screen buffer size regarding height and width so you can scroll around. 

*/

The cmd file that calls the script chk_blockW_cpu.sql below (if you have multiple servers use a naming convention like ckblocked_servername.cmd)for this cmd file. 
@echo off 

:a echo %%%%%%%%****** Server Name ******%%%%%%%% 

OSQL -Uuser -Ppassword -Sserver -n  -iD:\MonitorScripts\chk_blockW_cpu.sql 

sleep 20 

goto :a 

pause 


/******************************
The T-sql script to do the work [ chk_blockW_cpu.sql ] 
Visit www.sql-scripting.com 
******************************/ 

set nocount on 

select spid , 

  hostname=convert (char (10), hostname) , 

  UserName=convert (char (10), nt_username) , 

  blkby=convert(char(5),blocked) , 

  Application=convert (char (14), program_name) , 

  status=convert (char (8), status) , 

  dbname= convert ( char (8), db_name(dbid)) , 

  cmd=convert (char (8),cmd) , 

  CPU=convert (char(6),cpu) , 

  physIO=convert(char (7),physical_io)  

from master.dbo.sysprocesses 

where status <> "background" and cmd not in 

      ('signal handler', 'lock monitor', 'log writer', 'lazy writer', 'checkpoint sleep',   'awaiting command') 

and hostname not in (' Your machine name ') 

declare @activeproc char (3) 

select @activeproc=count (*) from sysprocesses 

where status <> "background" and cmd not in 

               ('signal handler', 'lockmonitor',           

               'log writer', 'lazy writer', 'checkpoint sleep', 'awaiting command') 

and hostname <> "Your machine name" 

declare @blocked char (3) 

select @blocked=count (*) from sysprocesses where status <> "background" and cmd not in 

('signal handler', 'lock monitor', 'log writer', 'lazy writer', 'checkpoint sleep', 'awaiting command') 

and hostname <> "Your machine name" and blocked <>0 

print 'current active processes: ' + @activeproc + " " + 'blocked processes: ' + @blocked print "" 

print "" 



