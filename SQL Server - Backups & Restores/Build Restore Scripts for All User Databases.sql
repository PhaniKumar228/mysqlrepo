/*
Build Restore Scripts for All User Databases

Something I really hate is typing something repetitive.  
To prepare for our Disaster Recovery plan, I wrote this script.
It is a bit strange in that it requires 2 run iterations to generate the desired result.

I use a naming standard for backup files of the form:

D_DBName.Bak

and a naming standard for database files of the form:

DBName_Dx.Mdf for Primary filegroup file
DBName_Ix.Ndf for Index filegroup file
DBName_L1.Ldf for Log file

I also use a directory structure the same on every volume of the form:
SQL8 
     Backup
     Data
     Index
     Log

Well you get the picture.  You can modify this to suit yourself.
To use, run it. Take results and run it. The last set of results are your restore scripts. 

*/

use master
go
Declare   @BAKDir 	varchar(255)
	 

Set nocount on
Select @BAKDir = 'E:\sql8\backup'

Select 'Use ' + name + char(10) + 'go' + char(10) + 'Set nocount on' + Char(10) + 
'Select ''RESTORE DATABASE '' + Rtrim(db_name()) + '' FROM Disk=''''' + @BAKDir + '\D_'' + rtrim(name) + ''.bak'''' WITH Replace, NORECOVERY '' from master.dbo.sysdatabases where name = Rtrim(db_name())'
+ char(10) + 'Set nocount on' + Char(10) + 'select ''     , MOVE '''''' + rtrim(name) + '''''' TO '''''' + rtrim(filename) + '''''''' from sysfiles order by fileid' 
+ char(10) + 'Set nocount on' + Char(10) + 
'Select ''go'''
+ char(10) + 'go'
  from sysdatabases 
where NOT(name IN ('master','tempdb','model','msdb'))
Order by name 
