select * , cntr_value_mb = cntr_value / 1024 from sys.dm_os_performance_counters
sp_configure
select * from sys.configurations
select * from sys.sysperfinfo
where object_name like '%Buffer%'
--------------------------------------------------------------------------------------------------------------
select * from sys.dm_os_sys_info 
select [name], page_id, page_level, allocation_unit_id, page_type, row_count, free_space_in_bytes, is_modified 
from sys.dm_os_buffer_descriptors Join sys.databases  on
sys.dm_os_buffer_descriptors.database_id = sys.databases.database_id
select * from sys.databases
select * from sys.allocation_units

SELECT count(*)AS cached_pages_count
    ,CASE database_id 
        WHEN 327680 THEN 'ResourceDb' 
        ELSE db_name(database_id) 
        END AS Database_name
FROM sys.dm_os_buffer_descriptors
GROUP BY db_name(database_id) ,database_id
ORDER BY cached_pages_count DESC;

SELECT count(*)AS cached_pages_count 
    ,name ,index_id 
FROM sys.dm_os_buffer_descriptors AS bd 
    INNER JOIN 
    (
        SELECT object_name(object_id) AS name 
            ,index_id ,allocation_unit_id
        FROM sys.allocation_units AS au
            INNER JOIN sys.partitions AS p 
                ON au.container_id = p.hobt_id 
                    AND (au.type = 1 OR au.type = 3)
        UNION ALL
        SELECT object_name(object_id) AS name   
            ,index_id, allocation_unit_id
        FROM sys.allocation_units AS au
            INNER JOIN sys.partitions AS p 
                ON au.container_id = p.partition_id 
                    AND au.type = 2
    ) AS obj 
        ON bd.allocation_unit_id = obj.allocation_unit_id
WHERE database_id = db_id()
GROUP BY name, index_id 
ORDER BY cached_pages_count DESC;
