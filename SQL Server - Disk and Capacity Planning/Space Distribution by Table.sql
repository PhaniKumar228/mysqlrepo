--How to know space distribution by table?
--After MS SQL Server 2005 
--you may use sys.dm_db_partition_stats DMV to find out this information 

select  OBJECT_NAME(object_id) as objname
        , SUM (reserved_page_count) * 8192/ 1024 as reserved_kb
        , SUM(used_page_count) * 8192 / 1024 as used_kb
from sys.dm_db_partition_stats
group by OBJECT_NAME(object_id)
order by reserved_kb desc

--Prior to sql server 2005 (for sql server 2000)  you may use following
if object_id ('tempdb..#table') is not null
  drop table #table
create table #table (
  name varchar(8000)
, rows int, reserved varchar(50)
, data varchar(50)
, index_size varchar(50)
, unused varchar(50))

insert into #table
exec sp_msforeachtable 'sp_spaceused ''?'''
select name, rows, reserved = REPLACE (reserved, 'KB','')
, data = REPLACE (data, 'KB',''),index_size = REPLACE (index_size, 'KB','')
,unused = REPLACE (unused, 'KB','')
from #table
order by convert ( int , REPLACE (reserved, 'KB','')) desc

drop table #table
