/*
    
Lock SQLServer

During some maintenance task, you might not want any one to connect to a database. This script would help you do that. 

If you need to run this script, you might also need my other script to kill connections. 
 
 
*/

Create Proc LockSQL(@dbName varchar(128), @Value bit)
as
if @Value = 1 
begin	
	Exec master.dbo.Kill_Connections @dbName
	Exec SP_DBOption @dbname, 'Single_User', True
end
else
begin
	Exec Master.dbo.Kill_Connections @dbName
	Exec SP_DBOption @dbname, 'Single_User', False
end


