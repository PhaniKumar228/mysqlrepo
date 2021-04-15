/*
Get Data, Log, Backup, and Binn Directory (SQL Server 2005)

Run in SSMS or Query Analyzer
*/

Set nocount on

declare @tblpaths table (
			[property]		varchar (100),
			[path]			varchar (200)
			)

declare 
@returncode		int,
@instancename	varchar (100),
@path				nvarchar(4000)

/*
get instance name
*/
Select @instancename = @@servername
insert into @tblpaths ([property], [path])
select 'Instance Name', @instancename


/*
find default data path
*/


exec @returncode = master.dbo.xp_instance_regread N'hkey_local_machine',N'software\microsoft\mssqlserver\mssqlserver',N'defaultdata', @path output, 'no_output'

if @path is null
begin

exec @returncode = master.dbo.xp_instance_regread N'hkey_local_machine',N'software\microsoft\mssqlserver\setup',N'sqldataroot', @path output, 'no_output'
set @path = @path + '\data'
insert into @tblpaths ([property], [path])
select 'Database Data Directory', @path
end
else
begin
insert into @tblpaths ([property], [path])
select 'Database Data Directory',  @path
end

/*
find default log path
*/

exec @returncode = master.dbo.xp_instance_regread N'hkey_local_machine',N'software\microsoft\mssqlserver\mssqlserver',N'defaultlog', @path output, 'no_output'

if @path is null
begin

exec @returncode = master.dbo.xp_instance_regread N'hkey_local_machine',N'software\microsoft\mssqlserver\setup',N'sqldataroot', @path output, 'no_output'
set @path = @path + '\data'
insert into @tblpaths ([property], [path])
select 'Database Log Directory', @path
end
else
begin
insert into @tblpaths ([property], [path])
select 'Database Log Directory', @path
end


/*
find binn directory
*/
exec @returncode = master.dbo.xp_instance_regread N'hkey_local_machine',N'software\microsoft\mssqlserver\setup',N'sqlbinroot', @path output, 'no_output'

insert into @tblpaths ([property], [path])
select 'Binn Directory', @path


/*
find backup directory
*/
exec @returncode = master.dbo.xp_instance_regread N'hkey_local_machine',N'software\microsoft\mssqlserver\mssqlserver',N'backupdirectory', @path output, 'no_output'
insert into @tblpaths ([property], [path])
select 'Backup Directory', @path

select * from @tblpaths