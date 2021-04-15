/*
List Locks and Repeatable Reads

Description

Sample script that lists locks and repeatable reads. The Transaction Isolation level is set to repeatable read. Note that, when xlocks are requested, key xlocks are held until the commit. The trace flag 1211 disallows lock escalation. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

use northwind
go
dbcc traceon(1211,-1)
go
set transaction isolation level repeatable read
go
begin transaction
go
select *
from [Order Details] with (rowlock)  --,xlock)
where OrderID between 50000 and 50500
go
declare @spid int
select @spid=@@spid
exec sp_lock @spid
--commit
go

