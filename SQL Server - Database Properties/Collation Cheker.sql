USE [master]
GO
/****** Object:  StoredProcedure [dbo].[sp_collation_checker]    
Script Date: 07/13/2007 15:58:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[sp_collation_checker]
as
-- this procedure checks the collation as follows :-
-- databases that have different collations from server
-- databases that have different collations of columns within
-- databases that have column collations different from database collation
--
-- it returns some text with a description of the issue e.g :-
-- "there are no databases that have a different collation from master"
-- "the pgr_test database has more than one collation"
-- "the col2 column collation (Latin1_General_CS_AS) in the pgr_test database does not match 
-- the database collation (Latin1_General_CI_AS)"
--
-- this procedure has been tested on sql server 2000 sp4 and SQL Server 2005 sp2
-- any problems email pgr_consulting @ yahoo.com

set nocount on
declare @msg varchar(2000), @master_collation varchar(255)

SELECT @master_collation=convert(sysname,DatabasePropertyEx('master','Collation'))

SELECT 'the ' + name + ' database has a different collation from master, ' + 
convert(sysname,DatabasePropertyEx(name,'Collation')) + ' (master=' + @master_collation+')' 
as 'server/database collation check'
into #temp_collations
from sysdatabases
where convert(sysname,DatabasePropertyEx('master','Collation')) <>
convert(sysname,DatabasePropertyEx(name,'Collation'))
order by name

if @@rowcount = 0
begin
   select 'there are no databases that have a different collation from master' 
   as 'server/database collation check'
end
else
begin
    select * from #temp_collations
end

set nocount on

create table #databases (dbid int identity(1,1), dbname varchar(100), collation varchar(100))
create table #database_collations (dbname varchar(100), collation varchar(100))
create table #database_collations_by_column (dbname varchar(100), colname varchar(100), collation varchar(100))

declare @number_of_dbs int, @counter int, @sql varchar(8000), @dbname varchar(100)

insert into #databases
select name, convert(sysname,DatabasePropertyEx(name,'Collation')) as collation
from master..sysdatabases
order by name

select @number_of_dbs = count(*) from #databases
select @counter=1

while @counter <= @number_of_dbs
begin

	select @dbname = dbname from #databases where dbid=@counter

	select @sql= 'insert into #database_collations select ''' + @dbname + ''' as dbname, sc.collation from ' +
    @dbname + '..syscolumns sc, ' + @dbname + '..sysobjects so, ' + @dbname + '..systypes st
	where so.id=sc.id
	and so.type=''U''
	and st.xtype=sc.xtype
	and sc.xtype in (select xtype from systypes
	where name in (''char'',''nchar'',''nvarchar'',''varchar''))
	and so.name not like ''dt%''
	group by sc.collation'
    
	exec (@sql)

	select @sql= ' insert into #database_collations_by_column select ''' + @dbname + 
    ''' as dbname, sc.name , sc.collation '+ 
    ' from ' +
    @dbname + '..syscolumns sc, ' + @dbname + '..sysobjects so, ' + @dbname + '..systypes st
	where so.id=sc.id
	and so.type=''U''
	and st.xtype=sc.xtype
	and sc.xtype in (select xtype from systypes
	where name in (''char'',''nchar'',''nvarchar'',''varchar''))
	and so.name not like ''dt%''
	group by sc.name, sc.collation'
    
	exec (@sql)

select @counter=@counter+1

end
select 'the ' + dbname + ' database has more than one collation' as 'multiple collations in one database check'
into #different_collations
from #database_collations
group by dbname
having count(*)>1

if @@rowcount=0
begin
    select 'there are no databases with different collations within' 
    as 'multiple collations in one database check'
end 
else
begin
    select * from #different_collations
end
-- databases with column collations different from database collation

select 'the ' + dc.colname + ' column collation (' + dc.collation + ') in the '+ dc.dbname + 
       ' database does not match the database collation (' + d.collation + ')'
as 'database v column collation check'
into #column_collations
from #database_collations_by_column dc, #databases d
where dc.dbname=d.dbname
and dc.collation<>d.collation

if @@rowcount=0
begin
    select 'there are no databases that have columns that do not match its database collation' 
    as 'database v column collation check'
end 
else
begin
    select * from #column_collations
end

-- tidy up

drop table #databases
drop table #column_collations
drop table #database_collations
drop table #different_collations
drop table #database_collations_by_column
go

