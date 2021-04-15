/*
Get total file size of backup for last full backup

The information for backup size is stored in the backup_size column of the backupset table in the msdb database as the total bytes for that backup. 
This script allow you to look at the total back to tape or file so you can plan space needs for those devices. 
This is a simple piece of code so you may need to adjust for your specific needs, but the basic outline of it should help you in looking at your backups in whatever situation you need. 
Also files have a header and maybe footer so there are some extra bytes added beyond what is stored in the database for this information which is 1536 and has been calculated in.

Some Options you should be aware of when using this code.

backupmediafamily device_type
2 = File
5 = Tape

backupset type
L = Log
I = Differential
D = Full

(Note: May be other options but these are the ones I find on my system and can identify.) 

*/

SELECT
	(SUM(backup_size) + SUM(1536)) As SizeInBytes,
	(SUM(backup_size) + SUM(1536)) / 1024 As SizeInKBs,
	(SUM(backup_size) + SUM(1536)) / 1024 / 1024 As SizeInMBs,
	(SUM(backup_size) + SUM(1536)) /1024 / 1024 / 1024 As SizeInGBs
FROM
	backupset
INNER JOIN
(
	SELECT 
		database_name, 
		MAX(backup_start_date) as LastFullBackupDate 
	FROM 
		backupset 
	WHERE 
		media_set_id IN (SELECT media_set_id FROM backupmediafamily WHERE device_type = 5) AND 
		type = 'D'
	GROUP BY 
		database_name
) AS GetLastDate
ON
	backupset.database_name = GetLastDate.database_name AND
	backupset.backup_start_date = GetLastDate.LastFullBackupDate
