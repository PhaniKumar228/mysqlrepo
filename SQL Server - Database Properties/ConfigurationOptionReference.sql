drop PROCEDURE [hx_ConfigurationOptionReference]
go

/* 	
	Desc: Displays Configuration option references and current set values.

*/

CREATE PROCEDURE [hx_ConfigurationOptionReference] AS

set nocount on
select substring(Comment,1,75) as [Configuration Option Name],
'Status'=case
WHEN master..syscurconfigs.status = 0 THEN 'Static (The setting takes effect when the server is restarted.)' 
WHEN master..syscurconfigs.status = 1 THEN 'Dynamic (The variable takes effect when the RECONFIGURE statement is executed.)'
WHEN master..syscurconfigs.status = 2 THEN 'Advanced (The variable is displayed only when the show advanced option is set.)'
WHEN master..syscurconfigs.status = 3 THEN 'Dynamic and advanced' 
end,
master..syscurconfigs.value as 'Current Value'
from master..syscurconfigs
