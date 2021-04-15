/*

Script To Get the Report Execution log, ex. timetaken .

this script lists the report Execution History ex: timetaken to render, retreive data, number of records retreived and their size etc.. in descending order of its execution time
Reports the 
ReportName, its Path , 
TimeTaken to 
execute the report,
retreive the data, 
render the report,
total count of rows returned and the total data returned in bytes 

*/

declare 
	@ReportName nvarchar(425) 
	, @ReportPath nvarchar(425)
	, @ReportId uniqueIdentifier


set @ReportName = 'your report name'
set @ReportPath = '/' + 'your folder name' 


if(@ReportName is null) 
	set @ReportName = ''
if(@ReportPath is null)
	set @ReportPath = ''


select 
	c.[Name],
	el.InstanceName, el.TimeEnd - el.TimeStart, 
	el.TimeDataRetrieval, el.TimeProcessing, el.TimeRendering, el.Status, el.ByteCount, el.[RowCount]
from 	
	[ReportServer].[dbo].catalog c 	inner join [ReportServer].[dbo].ExecutionLog el on c.ItemID = el.ReportId
where 
	c.[Name] like @ReportName + '%'
	and c.path like @ReportPath + '%'
order by 
	TimeEnd desc
GO


