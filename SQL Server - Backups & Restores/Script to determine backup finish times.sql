/*
Script to determine backup finish times


SQL Server provides the RESTORE HEADERONLY command which helps users determine backup completion times.  
What if you have the need to use this completion time for comparison, perhaps to set up a job that only restores the file if it is xx hours old.  

This script can be used to determine the maximum backup finish date for a particular file.  
The script reads this field from the backupset system table in the msdb database.

It then joins to the backupmediafamily table to allow the user to specify the exact physical device location.  

Make sure to use the full path to the location of the device.  

After this code completes, you can compare @FinishDate to the current date (using GETDATE) to determine if the file should be restored.  These steps can be placed in a SQL Server job, then scheduled for easy administration.

*/

DECLARE @FinishDate datetime

SELECT @FinishDate = MAX(backup_finish_date)
FROM backupset B
INNER JOIN backupmediafamily BF
ON B.media_set_id = BF.media_set_id
WHERE physical_device_name = 'full_path_to_device_location'
