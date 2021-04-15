
/*

Verify all DBs are part of a Maintenance Plan


This is a script you can run on a per-server basis, from any database in Query Analyzer or incorporate into a stored procedure, that will examine all databases on that instance of SQL and show what Maintenance Plan(s) they are part of, if any. Shows clearly any databases that are not currently part of a Plan. Very useful for auditing your servers periodically to make sure you are not missing any databases. Verified to work for both SQL 7 and SQL 2000.

Notes: If you use the All system databases or All user databases options in your Maintenance Plans, individual dbs will not be listed as linked to those plans. 

*/

CREATE TABLE [#Temp] (
	[MaintPlan] [varchar] (500) NULL ,
	[DBNames] [varchar] (500) NULL 
) ON [PRIMARY]

INSERT INTO #Temp
SELECT CAST(b.plan_name as varchar(500)), CAST(a.database_name as varchar(500))
FROM msdb..sysdbmaintplan_databases a INNER JOIN msdb..sysdbmaintplans b ON a.plan_id =
b.plan_id
WHERE a.database_name IN ('All User Databases', 'All System Databases')

INSERT INTO #Temp
SELECT CAST(d.plan_name as varchar(500)), CAST(e.name as varchar(500))
FROM msdb..sysdbmaintplan_databases c
INNER JOIN msdb..sysdbmaintplans d ON c.plan_id =
d.plan_id 
Right OUTER JOIN master..sysdatabases e on c.database_name = e.name
order by c.database_name, d.plan_name, e.name

SELECT ISNULL(MaintPlan, '') AS MaintPlan, ISNULL(DBNames, '') AS DBNames FROM #Temp

Drop Table #Temp
