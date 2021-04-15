/*
List Only User Tables

A simple stored procedure that only shows the user tables. It is like sp_tables but fixed to give a simpler vision of the tables. 

*/

CREATE PROCEDURE proc_tables
AS

SET NOCOUNT ON
CREATE TABLE #tables
		(table_qualifier varchar(20),
		table_owner varchar(20),
		table_name varchar(40),
		table_type varchar(50),
		remarks varchar(20))

INSERT INTO #tables EXEC sp_tables

SELECT table_owner+'.'+table_name AS'Owner and Table name'
FROM #tables
WHERE table_type='Table'

DROP TABLE #tables



