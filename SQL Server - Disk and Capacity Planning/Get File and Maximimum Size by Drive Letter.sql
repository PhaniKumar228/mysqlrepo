/*
Get File and Maximimum Size by Drive Letter

Utility Script to assist when you are thinking about expanding a database file. 
When Used in combination with srvinfo you can know just how far you can expand a file to keep the maximum file sizes from getting over the capacity of the drive. 
*/

create table #max(file_name varchar(30),
drive_name char(1),
max_size int,
file_size int)
go

exec master.dbo.sp_MSforeachdb "use [?] 

insert into #max
select convert(varchar(30),name)filename, substring(filename,1,1) drive,
		'maxsize' = convert(int, maxsize * 8 / 1024),
'size' = convert(int, size * 8 / 1024)
				
	from sysfiles"

select drive_name, sum(file_size) 'file size', sum(max_size) 'max_size'
from #max
group by drive_name
order by drive_name
go
