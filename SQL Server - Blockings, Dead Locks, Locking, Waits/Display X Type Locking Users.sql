/*
Display X Type Locking Users

This script creates a stored procedure that shows you a list of all the users that are locking objects on the database with mode X. It shows a full and detailed description on the user and object locked. 

*/

CREATE PROCEDURE proc_lock
AS

SET NOCOUNT ON

CREATE TABLE #lock
	(spid int,
	dbid int,
	objid int,
	indid int,
	type varchar(10),
	resource varchar(40),
	mode varchar(10),
	status varchar(30))

CREATE TABLE #who
	(spid int,
	 status varchar(30),
	loginame varchar(20),
	hostname varchar(15),
	blk int,
	dbname varchar(20),
	cmd varchar(60))

INSERT INTO #who EXEC sp_who

INSERT INTO #lock EXEC sp_lock


	SELECT 'X Type Lockins'='The user '+w.loginame+'(id:'+CONVERT(VARCHAR(5),w.spid)+') in Server '+w.hostname+' using the Database '+d.name+'(id:'+CONVERT(VARCHAR(5),l.dbid)+') is locking a '+l.type+' with mode '+l.mode
	FROM #who w INNER JOIN #lock l
	ON w.spid=l.spid
	INNER JOIN master..sysdatabases d
	ON d.dbid=l.dbid
	where l.mode like '%X%'


DROP TABLE #who
DROP TABLE #lock
