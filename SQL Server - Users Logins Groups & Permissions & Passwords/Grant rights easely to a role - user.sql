/*
Grant rights easely to a role /user

This simple script shows how to easely grant rights to user objects (tables,stored procedure,user-defined functions) to a role (public in example), in SQL Server 2000.The script can be used to grant rights to a specific NT /sql login account by replacing [public] with the desired name. 

*/

--RE : use a storage table for sql GRANT statements
declare @t_rights table(query nvarchar(100))

--RE : create sql GRANT statements for stored procedures,udf
insert @t_rights select 'grant EXECUTE on '+ name + ' to [public]' from sysobjects
where (xtype='p' or xtype='fn')  and name not like 'dt%' order by name

--RE : cursor to loop between data statement to be processed
declare xcur cursor for select query from @t_rights
--RE : the current GRANT statement 
declare @q nvarchar(100)
open xcur
FETCH xcur into @q
while(@@FETCH_STATUS=0)
begin 
	execute sp_executesql @q
	fetch xcur into @q
end
close xcur
delete from @t_rights

insert @t_rights select 'grant SELECT,INSERT,UPDATE,DELETE on '+ name + ' to [public]' from sysobjects
where xtype='u' and name not like 'dt%' order by name

open xcur
FETCH xcur into @q
while(@@FETCH_STATUS=0)
begin 
	execute sp_executesql @q
	fetch xcur into @q
end
close xcur
deallocate xcur
