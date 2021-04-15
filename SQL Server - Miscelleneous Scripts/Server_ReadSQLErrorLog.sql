CREATE TABLE #ErrorLog (
	LogDate datetime,
	ProcessInfo sysname,
	ErrorText nvarchar(max)	)

INSERT INTO #ErrorLog EXEC sp_readerrorlog

SELECT @@servername AS ServerName,GetDate() AS Capture_Date,LogDate,ProcessInfo,ErrorText 
FROM #ErrorLog WHERE LogDate Between DateAdd(hh,-24,GetDate()) And GetDate()
AND (ErrorText LIKE '%error%' OR ErrorText LIKE '%fail%')
AND (ErrorText NOT LIKE '%CHECKDB%'  
--OR	 ErrorText NOT LIKE '%Logging SQL Server messages in%' 
--OR	 ErrorText NOT LIKE '%The error log has been reinitialized.%'
)
ORDER BY LogDate DESC
DROP TABLE #ErrorLog
/*
For SQL 2000

Declare @errorlog table (
	ErrorText nvarchar(max)	,
	Contiuation Row int )

insert into @errorlog exec sp_readerrorlog

select * from @errorlog
where LogDate Between DateAdd(hh,-24,GetDate()) And GetDate()
And ErrorText not like '%Log was backed up.%'
And ErrorText not like '%Database backed up.%'
And ErrorText not like '%DBCC CHECKDB%'

*/