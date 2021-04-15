USE msdb
GO

Select	
	JH.[server],
	--J.[job_id],
	J.[name] As job_name, 
	convert(datetime,
	substring(convert(varchar(10),JH.[run_date]),1,4)+ '/'+
	substring(convert(varchar(10),JH.[run_date]),5,2)+ '/'+
	substring(convert(varchar(10),JH.[run_date]),7,2) + ' ' +
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),1,2)+':'+
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),3,2)+':'+
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),5,2)) 
	As Job_Run_DateTime,
	JH.[run_duration],
	Case When JH.[run_status] = 0 Then 'Failed' 
		 When JH.[run_status] = 2 Then 'Retry' 
		 When JH.[run_status] = 3 Then 'Cancelled' 
		 When JH.[run_status] = 4 Then 'In Progress' 
	End
	As job_run_status,
	JH.[message],
	Case When J.[enabled] = 1 Then 'Enabled' Else 'Disabled' End As job_status,
	J.[description] As job_description, 
	C.[name]as job_category

From msdb..sysjobs J	
Inner Join msdb..sysjobhistory JH On J.[job_id] = JH.[job_id]
Inner Join msdb..syscategories C On J.[category_id] = C.[category_id] 

Where JH.[step_id] = 0 
And (JH.[run_status] = 0 And JH.[run_status] <> 1)  
And convert(datetime,
	substring(convert(varchar(10),JH.[run_date]),1,4)+ '/'+
	substring(convert(varchar(10),JH.[run_date]),5,2)+ '/'+
	substring(convert(varchar(10),JH.[run_date]),7,2) + ' ' +
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),1,2)+':'+
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),3,2)+':'+
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),5,2)) 
	Between DateAdd(hh,-24,getdate()) And getdate()


Order By JH.[run_status],J.[job_id],
convert(datetime,
	substring(convert(varchar(10),JH.[run_date]),1,4)+ '/'+
	substring(convert(varchar(10),JH.[run_date]),5,2)+ '/'+
	substring(convert(varchar(10),JH.[run_date]),7,2) + ' ' +
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),1,2)+':'+
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),3,2)+':'+
	substring(Stuff('000000',6-len(convert(char(6),JH.[run_time]))+1,len(convert(char(6),JH.[run_time])),convert(char(6),JH.[run_time])),5,2)) 

