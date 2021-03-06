USE [DBREFS]
GO
DECLARE	@FromDate datetime 
DECLARE @ToDate datetime 
DECLARE @Mode char(1) 
DECLARE @SQL nvarchar(max)
DECLARE @Enviornment varchar(20)

SET @FromDate = NULL
SET @ToDate = NULL
SET @Mode = 'D'
SET @Enviornment =	'''P'',''R'''
/*	CASE WHEN @@SERVERNAME = 'ECMDEVTEST1' THEN '''D'',''U'''
		 WHEN @@SERVERNAME = 'ECMDB03' THEN '''D'',''U'',''R'',''P'''
	END*/

IF @FromDate IS NULL 
	SET @FromDate = CASE WHEN IsNull(@mode,'D') = 'D' 
						 THEN DateAdd(dd,-1,GetDate())
						 ELSE DateAdd(hh,-1,GetDate())
					END
IF @ToDate IS NULL 
	SET @ToDate = GetDate()

SET @SQL= 'SELECT 
    I.name AS InstanceName
    , J.JobName
    , J.RunDate
    , J.RunDuration
    , Case	WHEN J.[JobRunStatus] = 0 THEN ''Failed'' 
			WHEN J.[JobRunStatus] = 2 THEN ''Retry'' 
			WHEN J.[JobRunStatus] = 3 THEN ''Cancelled'' 
			WHEN J.[JobRunStatus] = 4 THEN ''In Progress'' 
	  END AS RunSatus
	, J.NoOfAttempts
	, Case	WHEN J.[JobRunStatus] = 0 And J.[FailStatus] IS NULL THEN ''Hard'' 
			WHEN J.[JobRunStatus] = 0 And J.[FailStatus] = 1 THEN ''Soft''
			WHEN (J.[JobRunStatus] = 2 Or J.[JobRunStatus] = 3) And J.[FailStatus] = 1 THEN ''Slight''
			WHEN (J.[JobRunStatus] = 2 Or J.[JobRunStatus] = 3) And J.[FailStatus] IS NULL THEN ''''
	  END AS FailStatus
    , J.JobDescription
    , J.Message
    , CASE WHEN J.JobStatus = 1 THEN ''Enabled'' ELSE ''Disabled'' END AS JobStatus
	, J.Category	
    , GetDate() AS CaptureDate
	,'''' AS Reason
	,'''' AS Solution

FROM 
    DBREFS.dbo.t_Failed_Jobs J Inner Join DBREFS.dbo.t_SqlServerInstance I 
ON 
    J.instanceId = I.InstanceId
WHERE
	I.Enviornment IN ( '+@Enviornment+' )
	And J.RunDate Between '''+ Cast(@FromDate As varchar(20))+''' And '''+Cast(@ToDate As varchar(20))+''''

--PRINT @SQL
EXECUTE sp_executesql @SQL