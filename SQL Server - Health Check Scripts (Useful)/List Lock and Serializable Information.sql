/*
List Lock and Serializable Information

Description

Sample script that lists lock and serializable information. The Transaction Isolation level is serializable. Note that, when xlocks are requested, key range xlocks are held until the commit. The trace flag 1211 disallows lock escalation. This script, provided by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

use northwind
go
dbcc traceon(1211,-1)
go
set transaction isolation level serializable
go
begin transaction
go
select *
from [Order Details] with (rowlock)  ---,xlock)
where OrderID between 50000 and 50500
go
declare @spid int
select @spid=@@spid
exec sp_lock @spid
--commit
go

