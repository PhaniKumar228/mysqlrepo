/*
Determine Who Has SA Access

This simple view will return the name, loginname,hasaccess,dbname and create date and updatedate where sysadmin or serveradmin is set to 1 from the syslogin table. If the hasaccess column is set to 1 the access is granted. 

*/

create view who_has_sa
as
select name,loginname,hasaccess,dbname,createdate,updatedate from syslogins
	where sysadmin = '1' or serveradmin = '1'
go

select * from who_has_sa   
