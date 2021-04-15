/*
Quick and Dirty Server/Instance information

I do a lot of SQL Server Desktop Edition instance testing and I cobbled together this script from BOL and other scripts 
I've seen posted.  It is intended to show version, service pack level, machine and instance name and the security type among other information.  Hopefully someone else may find it of use.  

*/

SELECT SERVERPROPERTY('ProductVersion') as Product_Version
,SERVERPROPERTY('Edition') as Edition
,SERVERPROPERTY('ProductLevel') as Product_Level
,SERVERPROPERTY('ServerName') as Server_Name
,SERVERPROPERTY('MachineName') as Machine_Name
,SERVERPROPERTY('InstanceName') as Instance_Name
go
select SERVERPROPERTY('LicenseType') as License_Type
,(CASE 
  WHEN CONVERT(char(5), SERVERPROPERTY('ISIntegratedSecurityOnly')) = 1
   THEN 'Integrated or Windows Security'
  WHEN CONVERT(char(5), SERVERPROPERTY('ISIntegratedSecurityOnly')) = 0
   --0 is not integrated
   THEN 'SQL Server Security'
  ELSE 'INVALID INPUT/ERROR'
  END) AS Security_Type
,SERVERPROPERTY('Collation') as Collation
go
