drop PROCEDURE hx_dbMaintancePlans
go

/* 	
	output:	Table format
	Desc:	Displays Maintance plan history if any. I used distinct to filter out and return 
		only what is relevent to what I need. You may not wish this for your purposes. 
		Feel free to make changes. See Warning.
	Warnings: Be patient. Depending on the number of rows in the sysdbmaintplan_history table this could take time.
*/

CREATE PROCEDURE hx_dbMaintancePlans AS

set nocount on
SELECT DISTINCT 
  substring(msdb..sysdbmaintplan_history.plan_name,1,40) AS 'Plan name', 
  substring(msdb..sysdbmaintplan_databases.database_name,1,50) as 'Database name',
  substring(msdb..sysdbmaintplans.owner,1,15) as Owner, 
  msdb..sysdbmaintplans.date_created, 
  substring(msdb..sysdbmaintplan_history.server_name,1,25) as 'Server name', 
  substring(msdb..sysdbmaintplan_history.activity,1,35) as Activity, 
	'Succeeded'=case
	WHEN msdb..sysdbmaintplan_history.succeeded = 0 THEN 'No'
	WHEN msdb..sysdbmaintplan_history.succeeded = 1 THEN 'Yes'
	end,
  msdb..sysdbmaintplan_history.start_time, 
  msdb..sysdbmaintplan_history.end_time, 
  msdb..sysdbmaintplan_history.message, 
  msdb..sysdbmaintplan_history.error_number
FROM msdb..sysdbmaintplan_history INNER JOIN
  msdb..sysdbmaintplan_databases ON 
  msdb..sysdbmaintplan_history.plan_id = msdb..sysdbmaintplan_databases.plan_id
  INNER JOIN
  msdb..sysdbmaintplans ON 
  msdb..sysdbmaintplan_history.plan_id = msdb..sysdbmaintplans.plan_id
