/*
Script to gather informations on databases 


The script is design to gather informations on the growth of the databases per server (except the system ones).
It is collecting in the 'databases' table of the master database for current information and in 'histodatabases' for old ones.
It is possible to schedule the stored procedure.
The column Serveur is only for gathering information on one server 
The 'pourcentlibre' column provide information on the free pourcentage of the database


*/

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[hisdatabases]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[hisdatabases]
GO

CREATE TABLE [dbo].[hisdatabases] (
	[Serveur] [varchar] (15)  NOT NULL ,
	[DATABASE_NAME] [sysname] NOT NULL ,
	[SIZE] [varchar] (50)  NULL ,
	[RUN_DT] [datetime] NOT NULL ,
	[TYPE] [varchar] (4) NOT NULL ,
	[FREE] [varchar] (50) NULL ,
	[PourcentLibre] [varchar] (50) NULL ,
	[lname] [varchar] (40) NULL ,
	[pname] [varchar] (255) NULL 
) ON [PRIMARY]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[databases]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[databases]
GO

CREATE TABLE [dbo].[databases] (
	[Serveur] [varchar] (15)  NOT NULL ,
	[DATABASE_NAME] [sysname] NOT NULL ,
	[SIZE] [varchar] (50)  NULL ,
	[RUN_DT] [datetime] NOT NULL ,
	[TYPE] [varchar] (4) NOT NULL ,
	[FREE] [varchar] (50) NULL ,
	[PourcentLibre] [varchar] (50) NULL ,
	[lname] [varchar] (40) NULL ,
	[pname] [varchar] (255) NULL 
) ON [PRIMARY]
GO



if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_databases]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_databases]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

create proc sp_databases

as
/*          Procedure for 8.0 server 
Sert à récupérer dans une table ( temporaire ) les infos 
sur la taille des bases du serveur en question, excepté les base systemes */

set nocount on
declare 
@name sysname,
@size dec,
@unallocated_space varchar(20),
@dbsize int,
@logsize int,
@bytesperpage int,
@pagesperMB int,
@somme varchar(50),
@taille varchar(50),
@lpname varchar(20),
@pourcent dec(15,2),
@compte int,
@SQL nvarchar(600)
/* Use temporary table to sum up database size w/o using group by */
create table #databases (
DATABASE_NAME sysname NOT NULL,
size int NOT NULL,
name varchar(255),
Free int )
declare c1 cursor for select name from master.dbo.sysdatabases where has_dbaccess(name) = 1 and dbid > 4 -- Only look at databases to which we have access
open c1
fetch c1 into @name
while @@fetch_status >= 0
begin
select @SQL = 'insert into #databases
select N'''+ @name + ''',size,''Data'',(select sum(convert(dec(15),reserved))
					from '+quotename(@name)+'.dbo.sysindexes
						where indid in (0, 1, 255)) from '+ QuoteName(@name) + '.dbo.sysfiles where  (status & 64 = 0)'
print @SQL
/* Insert row for each database on data */
execute (@SQL)

select @SQL = 'insert into #databases
select N'''+ @name + ''',size,''Log'',0 from '+ QuoteName(@name) + '.dbo.sysfiles where (status & 64 <> 0)'

print @SQL
/* Insert row for each database on log */
execute (@SQL)

fetch  c1 into @name
end
deallocate c1
select @bytesperpage = low
		from master.dbo.spt_values
		where number = 1
			and type = 'E'
select @pagesperMB = 1048576 / @bytesperpage


select @compte = (select count(*) from databases)
print @compte
if @compte > 1 
BEGIN 
insert into hisdatabases select * from databases
delete from databases
END
insert into databases(Serveur,DATABASE_NAME,SIZE,RUN_DT,TYPE,FREE,PourcentLibre) select @@SERVERNAME,DATABASE_NAME,DATABASE_SIZE_en_MO = str(convert(dec(15), SIZE)*(select low from master.dbo.spt_values where type = 'E' and number = 1) / 1048576,10,2),/* Convert from 8192 byte pages to MO, if so, verify on spt_value*/RUN_DT=GETDATE(),name,'unallocated space' =
			(ltrim(str((convert(dec(15), SIZE) -  free) / @pagesperMB,15,2))),0 from #databases order by 1


update databases set free=0 where type='Log'

declare freec cursor for select DATABASE_NAME,size,free from databases where type='Data'
open freec
fetch freec into @name,@taille,@somme

while @@fetch_status >= 0
BEGIN
--print 'Taille: '+@taille+' somme:'+@somme
select @pourcent= CONVERT(dec(15,2),(100 / CONVERT(dec(15,2),@taille)* ABS(CONVERT(dec(15,2),@somme))))
--PRINT @pourcent
update databases set PourcentLibre=@pourcent where DATABASE_NAME =@name and Type='Data'

fetch freec into @name,@taille,@somme
end
deallocate freec

declare lpname cursor for select database_name from databases
open lpname
fetch lpname into @lpname
while @@fetch_status >= 0
BEGIN
select @sql='update databases set Lname=(select name from '+@lpname+'..sysfiles where groupid=1) 
where database_name='''+@lpname+''''+'and type='''+'Data'+''''
print @SQL
execute (@SQL)
select @sql='update databases set Lname=(select name from '+@lpname+'..sysfiles where groupid=0) 
where database_name='''+@lpname+''''+'and type='''+'Log'+''''
print @SQL
execute (@SQL)
select @sql='update databases set Pname=(select filename from '+@lpname+'..sysfiles where groupid=1 )
where database_name='''+@lpname+''''+'and type='''+'Data'+''''
print @SQL
execute (@SQL)
select @sql='update databases set Pname=(select filename from '+@lpname+'..sysfiles where groupid=0 )
where database_name='''+@lpname+''''+'and type='''+'Log'+''''
print @SQL
execute (@SQL)
fetch lpname into @lpname
end
deallocate lpname


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

