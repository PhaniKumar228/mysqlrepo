exec master.dbo.sp_msforeachdb 
"USE [?] 
select	db_name()
from	sysobjects
where	name = 'CapacityPlanning'
" 
