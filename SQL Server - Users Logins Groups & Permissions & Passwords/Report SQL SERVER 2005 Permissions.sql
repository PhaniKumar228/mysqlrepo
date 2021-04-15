/*
Report SQL SERVER 2005 Permissions

I wrote this script because I wanted to migrate permissions from one database to another and couldn't easily get a 
hold of the schema-level permissions I knew I had granted.

TO USE:

set the parameters for REPORT, GRID or SCRIPT (DEFAULT IS GRID).

execute

*/

-- =============================================
-- Description: This script generates permisssions (db, schema and table)
-- in three formats:
-- readable REPORT 
-- structured GRID (for reviewing/exporting)
-- executable SCRIPT (for transferring to another database)
-- : SQL SERVER 2005 :
-- =============================================

---------------
-- variable declaration
---------------
declare 
  @rpt_ind char(1)
, @grid_ind char(1)
, @script_ind char(1);

---------------
-- set flags depending on the output you want
---------------
set @rpt_ind    ='N'; -- human readable listing
set @grid_ind   ='Y'; -- structured table output (default)
set @script_ind ='N'; -- scripts out statements to transfer to another database (watch out for the DB level permissions)


---------------
-- Dropping the temp table, if it exists in this session
---------------
if exists(select [id] from tempdb.dbo.sysobjects where id = object_id(N'tempdb..#perms'))
drop table #perms;

---------------
-- Create temp table to hold permissions information
---------------
select 
perm.state_desc
, perm.permission_name perm_nm
, perm.class
, sch.schema_id schema_id
, obj.schema_id obj_schema_id
, obj.name obj_nm
, obj.type_desc obj_type_desc
, grantee.type_desc grantee_type_desc
, grantee.name grantee
, grantor.type_desc grantor_type_desc
, grantor.name grantor
into #perms
from 
sys.database_permissions perm 
join 
sys.database_principals grantor
on perm.grantor_principal_id = grantor.principal_id
join
sys.database_principals grantee
on perm.grantee_principal_id = grantee.principal_id
left join
sys.objects obj
left join sys.schemas obj_sch
on obj.schema_id = obj_sch.schema_id
on obj.object_id = perm.major_id
left join 
sys.schemas sch
on sch.schema_id = perm.major_id
where perm.major_id >= 0;-- exclude system objects (major_id < 0 := system object. major_id = 0 := database)

--------------
-- READABLE FORMAT
---------------
if (@rpt_ind = 'Y')

select 
state_desc
+ ' ' 
+ perm_nm
+' on '
+case 
when class = 0 then 'database::'+db_name()
when class = 3 then 'schema::'+schema_name(schema_id) 
else obj_type_desc+'::'+schema_name(obj_schema_id)+'.'+ obj_nm end 
+ ' to '
+grantee_type_desc+'::'
+ grantee COLLATE SQL_Latin1_General_CP1_CI_AS
+' granted by '
+grantor_type_desc+'::'
+grantor COLLATE SQL_Latin1_General_CP1_CI_AS
+';'
as stmt
from #perms;

--------------
-- GRID FORMAT
---------------
if(@grid_ind = 'Y')

select 
state_desc
, perm_nm 
, case 
when class = 0 then db_name()
when class = 3 then schema_name(schema_id) 
else schema_name(obj_schema_id)+'.'+obj_nm end as sch_obj
, grantee_type_desc
, grantee
, grantor_type_desc
, grantor
from #perms;

-------------------
-- SCRIPT FORMAT
-------------------
if(@script_ind = 'Y')

select 
state_desc
+ ' ' 
+ perm_nm 
+' on '
+case 
when class = 0 then 'database::'+db_name()
when class = 3 then 'schema::'+schema_name(schema_id) 
else obj_type_desc+'::'+schema_name(obj_schema_id)+'.'+obj_nm end 
+ ' to '
+ grantee COLLATE SQL_Latin1_General_CP1_CI_AS
+';'
as scripted_stmt
from #perms;


