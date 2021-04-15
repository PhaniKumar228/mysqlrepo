/*
Metadata Reportserver

This stored procedure gives you metadata information from the reportserver database about published reports, datasources, directories,authorized users/groups,(shared)schedules and subscriptions.
I integrated this stored procedure in a report in our MS report services environment for auditing purposes 

*/

if exists (select 1 from sysobjects where name = 'metadata_reports' and user_name(uid) = 'dbo' and xtype = 'P ')
   drop procedure [metadata_reports]
go
 

create proc [metadata_reports] 
 
as
  
select  --reportname en path
	C.path,
	
	C.creationdate,
	C.modifiedDate,
	
	--authorized users(groups)
	U.username,

	--(shared)schedule-name
   	S.name as schedule,

	--email/filesharing name
	SU.description as subscription
  
from reportserver.dbo.reportschedule R 
  	left outer  join reportserver.dbo.schedule S on   R.scheduleid = S.scheduleid 
    	right outer join reportserver.dbo.catalog C   on C.itemid = R.reportid
     	join reportserver.dbo.policyuserrole P on P.policyid = C.policyid
     	join reportserver.dbo.users U on U.userid = P.userid
 	left outer join reportserver.dbo.subscriptions SU on SU.subscriptionid = R.subscriptionid

where C.type = 2 
  
	order by 1
 

