/*
Compare Locking and Repeatable Reads
Description
Sample script that compares locking and repeatable reads. Range locks (serializable) disallows inserting in the range,
while key locks (r repeatable reads) allow inserts (also known as phantoms). 
Script Code
*/

set lock_timeout 5000
go
begin tran
go
Insert into [Order Details]
values (50001,51,42.00,10,0)
go
-- rollback

