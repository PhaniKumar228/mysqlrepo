/*

Seach any DB object across database server. 

This procedure will help you to find particular database object in all databases across database server. 
Like search gives you all objects from all databases whos name includes seach word critera. 

*/

/*
Purpose- Search object across database server.
Input Parameters
@object_name= Name of object to be searched part of object nameto be searched
@ExactORLikeSearch= If no parameters are passed Sp will search for exact object names.
			if 'L' is passes as parameter it will to like seach.
*/


Create procedure sp_find_object -- 'product_master','L'
@object_name varchar(100),
@ExactORLikeSearch char(1)=E --E/L
as
begin 
	set nocount on
	declare @databases table (colid int identity ,dbname varchar(50))
	create table ##object_db  (dbName varchar(100), objectName varchar(100),objectType varchar(100))
	insert into @databases (dbname) select name  from sysdatabases where dbid>4 and name not in ('pubs','northwind')
	declare @max_dbs int
	select @max_dbs=max(colid) from @databases
	declare @current_db varchar(100)

	declare @Qstr nvarchar(2000)
	declare @Qstr1 nvarchar(2000)
	set @Qstr='insert into  ##object_db select  '
	set @Qstr1=''

	declare @i int
	set @i=1

	while @i<=@max_dbs
				begin 
								select @current_db=dbname from @databases where colid=@i
---------------------------------------------------------------------------------------
								if @ExactORLikeSearch='E'

								set @Qstr1=@Qstr+''''+@current_db+''''+',name, case xtype when '+''''+'U'+''''  +' then ' +''''+'table'+''''+'  when ' +''''+'P'+''''+' then '+''''+'procedure'+''''+' when '+''''+'F'+''''+' then '+''''+'function'+''''+' when '+''''+'V'+''''+' then '+''''+'view'+''''+ ' end as ObjectType 
 from ' +@current_db+'.dbo.sysobjects  where name='+''''+@object_name+''''
---------------------------------------------------------------------------------------
								if @ExactORLikeSearch='L'

								set @Qstr1=@Qstr+''''+@current_db+''''+',name, case xtype when '+''''+'U'+''''  +' then ' +''''+'table'+''''+'  when ' +''''+'P'+''''+' then '+''''+'procedure'+''''+' when '+''''+'F'+''''+' then '+''''+'function'+''''+' when '+''''+'V'+''''+' then '+''''+'view'+''''+ ' end as ObjectType 
 from ' +@current_db+'.dbo.sysobjects  where name like'+''''+'%'+@object_name+'%'+'''' +'and xtype in ('+''''+'U'+''''+','+''''+'P'+''''+','+''''+'F'+','+''''+''''+'V'+''''+')'
---------------------------------------------------------------------------------------
								
														exec sp_executesql @Qstr1
								set @i=@i+1
				end

	select * from ##object_db
	drop table ##object_db

end 


