/*
    
Get Triggers for the Table

Use this script to get Insert, Update and Delete trigger for all the tables. This script will give you just the first level of triggers. So if you have more than 1 insert trigger, it will give you the first one.
 
*/

select a.name 'Table', i.name 'Insert Trigger', u.name 'Update Trigger', d.name 'Delete Trigger'
from sysObjects a,  sysObjects i, sysObjects u, sysObjects d
where ((a.deltrig>0 or a.instrig>0 or a.updtrig>0) and a.type != 'TR')
and a.instrig *= i.id and a.updtrig *= u.id and a.deltrig *= d.id

--Use the next line for specific table check
-- and a.name = 'TableName'
