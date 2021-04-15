CREATE TABLE #DbRoles (dbname varchar(60),sysuser varchar(120),dbrole varchar(60),sid varbinary (85) null,alias varchar(20))
set nocount on
declare @dbname varchar(80), @sql varchar(2000),@servername varchar(60)
set @servername=@@servername
select @sql='select name into ##db from ['+@servername+'].master.dbo.sysdatabases 
	where name not in (''pubs'',''Northwind'',''tempdb'') 
	and databaseproperty(name,''isinload'')=0 
	and databaseproperty(name,''isoffline'')=0 
	order by name'
exec(@sql)
select @dbname=min(name) from ##db where databaseproperty(name,'isinload')=0
while @dbname is not null
begin
--          print @dbname
            set @sql='select su.dbn,su.sysuser,isnull(dbrole,isnull(''Aliased ''+su.alias,''No Role Defined'')) as dbrole,su.sid as sid,su.Alias from (
			select '''+@dbname+''' as dbn,r.name as dbrole ,m.name as sysuser,m.sid as sid
			from	
			['+rtrim(@servername)+'].['+rtrim(@dbname)+'].dbo.sysusers r, 
                        ['+rtrim(@servername)+'].['+rtrim(@dbname)+'].dbo.sysusers m,
                        ['+rtrim(@servername)+'].['+rtrim(@dbname)+'].dbo.sysmembers sm 
                        where 
                                    r.issqlrole=1 
                        and       r.uid=sm.groupuid
                        and       m.uid=sm.memberuid
			) sur
			right outer join 
			(select '''+@dbname+''' as dbn,r.name as sysuser,r.sid as sid,Alias=case when r.altuid=1 then ''db_owner'' else alt.name end
                        from      ['+rtrim(@servername)+'].['+rtrim(@dbname)+'].dbo.sysusers r 
						left outer join ['+rtrim(@servername)+'].['+rtrim(@dbname)+'].dbo.sysusers alt on r.altuid=alt.uid 
                        where 
                                    r.issqlrole<>1 
			) su
			on sur.dbn=su.dbn and sur.sysuser=su.sysuser'
                      --  print @sql
                        insert #DbRoles
                        exec (@sql)
            select @dbname=min(name) from ##db where name>@dbname and databaseproperty(name,'isinload')=0
end
select left(@@servername,60) as servername,getdate() as capturedate,dbname ,sysuser ,dbrole ,isnull(sid,0x00),alias from #DbRoles
order by servername,dbname,sysuser
drop table ##db
drop table #DbRoles
