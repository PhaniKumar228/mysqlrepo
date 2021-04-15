set nocount on
CREATE TABLE [dbo].[#Databases_ObjectPermissions] (
	[dbname] [varchar] (60)  ,
	[objectname] [nvarchar] (128) ,
	[objecttype] [varchar] (60) ,
	[sysuser] [nvarchar] (128) ,
	[permissiontype] [varchar](2) ,
	[permissionname] [varchar](60) ,
	[statetype] [varchar] (2) ,
	[statedesc] [varchar] (60)
) ON [PRIMARY]
set nocount on
declare @dbname varchar(80), @sql varchar(2000)
select @dbname=min(name) from master.dbo.sysdatabases where databaseproperty(name,'Isinload')=0 and  databaseproperty(name,'IsOffline')=0
while @dbname is not null
begin
    set @sql=
	'select '''+@dbname+''' as dbname, so.name as objectname,so.type_desc as objecttype,su.name as sysuser,sp.type,sp.permission_name,sp.state,sp.state_desc
	from 
		['+RTRIM(@dbname)+'].sys.all_objects so,
		['+RTRIM(@dbname)+'].sys.database_principals su,
		['+RTRIM(@dbname)+'].sys.database_permissions sp
	where 
		sp.major_id=so.object_id AND sp.minor_id=0 AND sp.class=1
		and su.principal_id = sp.grantee_principal_id
		order by so.name'
--        print @sql
        insert #Databases_ObjectPermissions
        exec (@sql)
    select @dbname=min(name) from master.dbo.sysdatabases  where name>@dbname and databaseproperty(name,'Isinload')=0  and  databaseproperty(name,'IsOffline')=0
end
select 
	left(@@servername,60) as servername,
	getdate() as capturedate,
	[dbname],
	[objectname],
	[objecttype],
	[sysuser],
	left([permissiontype],2) as pt,
	[permissionname],
	left([statetype],2) as st,
	[statedesc]
from #Databases_ObjectPermissions p 
order by dbname,objectname,sysuser
DROP TABLE #Databases_ObjectPermissions
-- 
GO
