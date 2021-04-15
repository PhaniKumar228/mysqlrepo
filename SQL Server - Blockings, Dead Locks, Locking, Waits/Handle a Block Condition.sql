/*
Handle a Block Condition

Description

Sample script for handling a block condition. A block situation is set up by running the script Create a Blocker Condition prior to running this procedure. This script requires Microsoft SQL Server 2005. 

Script Code


*/

use Northwind
go
create proc waiter_proc @OrderID int
as

select * from Orders with (holdlock)
where OrderID = @OrderID
waitfor delay '00:01:30'
---- this update will cause a deadlock if you execute blocker_proc just prior
update Orders
set ShippedDate = getdate()
where OrderID = @OrderID
go
begin tran
go
exec waiter_proc @OrderID=15000
go
rollback
go

