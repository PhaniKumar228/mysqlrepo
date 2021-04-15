[X is a INT]

SQL 2000 version
select * from master.dbo.syslogins
Where createdate >=getdate()-X 
[Replace X with Logins created in the last X=number of days]

SQL 2005 Version

Select * from sys.server_principals 
Where create_date >= GETDATE()-X
[Replace X with Logins created in the last X=number of days] 