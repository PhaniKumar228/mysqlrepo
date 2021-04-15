/*
Easy & Fast way to check Backup details
*/

USE msdb
go
	SELECT Server_Name, Database_Name, 
		CASE Type 
			WHEN 'D' THEN 'Full' 
			WHEN 'L' THEN 'Transaction Log' 
			WHEN 'I' THEN 'Differential' 
			WHEN 'F' THEN 'FileGroup' 
		END 
AS Backup_Type, max(database_creation_date) as DB_Creation_Date, max(backup_finish_date) as Last_Backup_Date
FROM backupset
GROUP BY server_name, database_name, Type
ORDER BY 1,2

