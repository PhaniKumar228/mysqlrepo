/*
Configure a Block Condition
Description
Sample script that holds locks in order to create a block condition. 
This script requires Microsoft SQL Server 2005. 
Script Code

*/
use Northwind
go
create proc blocker_proc @OrderID int
as

select * from Orders with (holdlock)
where OrderID = @OrderID
waitfor delay '00:00:10'
--- the update will be blocked by Waiter_proc's shared lock
update Orders
set ShippedDate = getdate()
where OrderID = @OrderID
waitfor delay '00:01:30'
go
--- begin a transaction
begin tran
go
exec blocker_proc @OrderID=15000
go
--- uncomment the next statement when you are ready to rollback blocker_proc
--- rollback
go

