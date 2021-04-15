/*
Table Sizes in database

This script uses the same information sp_spaceused does. It just formats it in a different way. 

*/

select
 so.id as [OBJECT_ID],
 so.name as [OBJECT_NAME],
 coalesce(j_rows.rows,0) as [ROWCOUNT],
 coalesce(j_ru.sum_reserved,0) * cast(m.low as dec) / 1024 as [RESERVED (KB)],
 d.data * cast(m.low as dec) / 1024 as [DATA (KB)],
 (coalesce(j_ru.sum_used,0) - d.data) * cast(m.low as dec) / 1024 as [INDEX (KB)],
 (coalesce(j_ru.sum_reserved,0) - coalesce(j_ru.sum_used,0)) * cast(m.low as dec) / 1024 as [UNUSED (KB)]
from
 sysobjects so
 -- rows
 left join sysindexes j_rows
  on j_rows.indid < 2 and j_rows.id = so.id
 /* reserved: sum(reserved) where indid in (0, 1, 255) */
 /* index: sum(used) where indid in (0, 1, 255) - data */
 /* unused: sum(reserved) - sum(used) where indid in (0, 1, 255) */
 left join
  (
  select
   id, sum(reserved) as sum_reserved, sum(used) as sum_used
  from
   sysindexes
  where
   indid in (0, 1, 255)
  group by
   id
  ) j_ru on j_ru.id = so.id
 /*
 ** data: sum(dpages) where indid < 2
 ** + sum(used) where indid = 255 (text)
 */
 left join
  (
  select
   j_dpages.id, coalesce(j_dpages._sum,0) + coalesce(j_used._sum,0) as data
  from
   (
   select
    id, sum(dpages) as _sum
   from
    sysindexes
   where
    indid < 2
   group by
    id
   ) j_dpages left join
   (
   select
    id, sum(used) as _sum
   from
    sysindexes
   where
    indid = 255
   group by
    id
   ) j_used on j_used.id = j_dpages.id
  ) d on d.id = so.id
 inner join master.dbo.spt_values m
  on m.number = 1 and m.type = 'E'
where
 OBJECTPROPERTY(so.id, N'IsUserTable') = 1
order by
 [DATA (KB)] DESC, [ROWCOUNT] ASC


