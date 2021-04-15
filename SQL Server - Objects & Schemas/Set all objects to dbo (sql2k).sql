/*
Set all objects to dbo (sql2k)

Based on a script from this site, which sets ownership of all objects to dbo, this modification of the 
original author's code simply adds user defined functions (UDF's).  
Script now includes tables, views, procs and functions. 

*/

------------------------------------------------------------------
-- finds objects that are not owned by dbo
-- and changes them to dbo
-- this eliminates the problem with objects accidentally
-- created as being owned by someone other than dbo
-- REVS:
-- Updated to include sql 2000 user defined functions 
------------------------------------------------------------------

CREATE   PROC dbo.up_FixObjOwners 
AS
SET NOCOUNT ON

DECLARE @dynsql varchar(1000)
SET @dynsql = ''

DECLARE @Obj_Owner sysname
SET @Obj_Owner = ''

DECLARE @Obj_Type VARCHAR(30)
SET @Obj_Type = ''

DECLARE @Obj_Name sysname
SET @Obj_Name = ''

DECLARE @ObjCounter INT
SET @ObjCounter = 0

DECLARE @DBO CHAR(3)
SET @DBO = 'DBO'

-- temp table to hold all objects not owned
-- by DBO
create table #ChangeOwners(
	id int identity(1,1),
	Obj_Owner sysname,
	Obj_Name sysname,
	Obj_Type varchar(30))
-- populate it
INSERT #ChangeOwners (Obj_Owner, Obj_Name, Obj_Type)
select
	su.name, 
	so.name, 
	case 
		when type = 'u' then 'table'
		when type = 'p' then 'sproc'
		when type = 'v' then 'view' 
		when type = 'fn' then 'function' 
	end as obj_type
from sysusers su
join sysobjects so
on su.uid = so.uid
where su.name not in ('information_schema', 'dbo')
and so.type in ('p', 'u', 'v', 'fn')
-- select * from #ChangeOwners

SET @ObjCounter = @@rowcount	-- holds the count of rows inserted into #ChangeOwners

WHILE @Objcounter > 0
   BEGIN
	-- construct string for object ownership change
	SELECT @Obj_Name = Obj_Owner + '.' + Obj_Name FROM #ChangeOwners WHERE id = @ObjCounter
	SELECT @Obj_Type = Obj_Type FROM #ChangeOwners WHERE id = @ObjCounter

	SET @dynsql = 'sp_ChangeObjectOwner ''' + @Obj_Name + ''', ' + @DBO
	--select @dynsql
	print 'changing ownership on ' + @Obj_Type + ': ' + @Obj_Name 
	EXEC(@dynsql)
	SET @ObjCounter = @ObjCounter - 1
   END

-- ok all done, collect garbage
drop table #ChangeOwners

