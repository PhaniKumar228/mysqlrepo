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
	bmf.physical_device_name,
	ISNULL(bset2.media_set_id,-40) as media_set_id
from
	master.dbo.sysdatabases db left outer join 
	(select database_name, backup_finish_date=max(backup_finish_date)
		from msdb.dbo.backupset
		where type ='D'
		group by database_name) bset1 on db.name=bset1.database_name --and db.name not in ('pubs','Northwind','tempbd')
	left outer join 
	(select destination_database_name, restore_finish_date=max(restore_date)
		from msdb.dbo.restorehistory
		where restore_type ='D'
		group by destination_database_name) restore1 on db.name=restore1.destination_database_name --and db.name not in ('pubs','Northwind','tempbd')
	left outer join 
	msdb.dbo.backupset bset2 on bset1.backup_finish_date=bset2.backup_finish_date and type='D' and db.name=bset2.database_name
	left outer join 
	msdb.dbo.backupmediafamily bmf on bset2.media_set_id=bmf.media_set_id
where db.name not in ('pubs','Northwind','tempdb') 
order by db.name
--select max(restore_date) from restorehistory where destination_database_name='MAILGRAM'
