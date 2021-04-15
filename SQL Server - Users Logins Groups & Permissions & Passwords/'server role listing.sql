set nocount on 
select left(@@servername,60) as servername,getdate() as capturedate,name,role,sid from (
select isnull(name,loginname) name,'sysadmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where sysadmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'securityadmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where securityadmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'serveradmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where serveradmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'setupadmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where setupadmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'processadmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where processadmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'diskadmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where diskadmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'dbcreator' as role,sid
	from master.dbo.syslogins (NOLOCK)  where dbcreator=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'bulkadmin' as role,sid
	from master.dbo.syslogins (NOLOCK)  where diskadmin=1
	--and name not in ('sa')
union
select isnull(name,loginname) name,'No ServerRole Defined' as role,sid
	from master.dbo.syslogins (NOLOCK)
	where
		sysadmin=0 and 
		securityadmin=0 and 
		serveradmin=0 and 
		setupadmin=0 and 
		processadmin=0 and 
		diskadmin=0 and 
		dbcreator=0 and 
		diskadmin=0
) t
order by name


