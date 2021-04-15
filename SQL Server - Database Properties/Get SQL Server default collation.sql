/*
Get SQL Server default collation

PROCEDURE used to find the server's default collation 
not shown in EM in servers properties 
*/

create proc sp_default_collation 
as 
set nocount on 
declare @servercollation sysname 
select @servercollation = convert(sysname, serverproperty('collation')) 

if @servercollation is not NULL 
      BEGIN 
      select 'Server default collation' = description 
            from ::fn_helpcollations() C 
            where @servercollation = C.name 
      END 

set nocount off 
go 

