set nocount on
set ansi_warnings off
select 	
	left(@@servername,60) as servername,
	getdate() as capturedate,
	left(db.name,60) as name,
	db.filename,
	ISNULL(bset1.backup_finish_date,'01/01/1900') as backup_finish_date,
	ISNULL(restore1.restore_finish_date,'01/01/1900') as restore_finish_date,
	ISNULL(bset2.backup_size,0) as backup_size,
	left(bmf.physical_device_name,100) as BackupFile,
	left(bmf2.physical_device_name,100) as RestoreFile,
	ISNULL(bset2.media_set_id,-40) as media_set_id
from
	master.dbo.sysdatabases db left outer join 
	(select database_name, backup_finish_date=max(backup_finish_date)
		from msdb.dbo.backupset
		where type ='L'
		group by database_name) bset1 on db.name=bset1.database_name --and db.name not in ('pubs','Northwind','tempbd')
	left outer join 
	(select destination_database_name, restore_finish_date=max(restore_date)
		from msdb.dbo.restorehistory
		where restore_type ='L'
		group by destination_database_name) restore1 on db.name=restore1.destination_database_name 
	left outer join 
	msdb.dbo.backupset bset2 on bset1.backup_finish_date=bset2.backup_finish_date and bset2.type='L'
	left outer join 
	msdb.dbo.restorehistory restore2 on restore2.restore_date=restore1.restore_finish_date
	left outer join 
	msdb.dbo.backupset bset3 on bset3.backup_set_id=restore2.backup_set_id
	left outer join 
	msdb.dbo.backupmediafamily bmf on bset2.media_set_id=bmf.media_set_id
	left outer join 
	msdb.dbo.backupmediafamily bmf2 on bset3.media_set_id=bmf2.media_set_id

where db.name not in ('pubs','Northwind','tempdb') 
order by db.name
--select max(restore_date) from msdb.dbo.restorehistory where destination_database_name='PROD'
