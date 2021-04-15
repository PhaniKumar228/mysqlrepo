/*
List Locks and Reads

Description

Sample stored procedure that lists locks and reads. Range locks (serializable) disallows inserting in the range, while key locks (repeatable read) allow inserts (also known as phantoms). This stored procedure, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

begin tran
go
select count(*)
from [Order Details]
where OrderID between 50000 and 50500
go
commit
-- rollback

