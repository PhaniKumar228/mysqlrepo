use master
go

create procedure sp_object_from_page 
(
   @page int,      -- database page number
   @file int = 1   -- if not the default, specify filenumber
)
as
/*
   Used to get an object name from a page number (some
   deadlock traces tend to report just a page number)
   Run the procedure in the database the object resides
   Use at own risk !!
*/
set nocount on

declare @cmd nvarchar(300)
declare @id varchar(50)
create table #page(ParentObject sysname,
                   Object       sysname,
                   Field        sysname,
                   Value        sysname)

set @cmd = N'dbcc page(''' + DB_NAME() + N''',' +
             cast(@file as nvarchar(5)) + N',' +
             cast(@page as nvarchar(10)) + N',0) with tableresults,no_infomsgs'

insert #page
exec(@cmd)

select @id = Value from #page
where ParentObject = 'PAGE HEADER:'
and Field = 'm_objId'

select ISNULL(object_name(@id),'Not Found') as 'Object Name'

drop table #page
return
go

--Usage of the Script

exec sp_object_from_page 7
