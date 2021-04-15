/*
List Queries That Could Benefit From an Index

Description

Sample stored procedure that creates an XML query plan indicating whether or not a query would benefit from an index. Because indexes are alternatives to table scans, the purpose of a proposed index is to avoid big I/Os. The stored procedure, which requires Microsoft SQL Server 2005, indicates that an index could be useful for the query in question only. 

Script Code


*/

dbcc freeproccache
go
use adventureworks2000
go
select 
	CustomerID, 
	CASE ContactType
		WHEN 1 THEN 'Call'
		WHEN 2 THEN 'Meeting'
		WHEN 3 THEN 'E-Mail'
	END ContactType,
	convert(nvarchar(100), ContactDate, 1) Date,
	notes
from customer_contacts
where ContactDate between '1/1/04' and '2/1/04'
and SalesPersonID = 13

