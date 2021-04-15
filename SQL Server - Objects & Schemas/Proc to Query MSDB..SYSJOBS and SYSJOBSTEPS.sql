/*
Proc to Query MSDB..SYSJOBS and SYSJOBSTEPS

TSQL:Procedure to Lookup Jobs

Have you ever kept altering the same query to look for different items in you database?
I took a hint from MS with all the sp_help and other system stored procedures and made 
a two scripts this one to query for databases scheduled tasks or jobs as they are now called.

The other one performs a similar query on syscomments for phrase or objects.

Here is the script and make sure you don't grant access to public. this was a quick solution 
and there are tons of ways to probably improve it. I just need some thing to get me started to 
in my search to help Identify certain dependent objects or attributes within jobs.
It does not go into DTS packages and search for code, but a good starting place. 

*/

SET QUOTED_IDENTIFIER OFF 

IF EXISTS(SELECT NAME FROM SYSOBJECTS WHERE NAME = 'LOOK_UP_JOBS_NONPROD')
DROP PROCEDURE LOOK_UP_JOBS_NONPROD 
GO 

CREATE PROCEDURE LOOK_UP_JOBS_NONPROD 
--EX. Exec LOOK_UP_JOBS_NONPROD 'STEP NAME
--EX. Exec LOOK_UP_JOBS_NONPROD 'USER_TABLE_1
--EX. Exec LOOK_UP_JOBS_NONPROD 'SP_
--EX. Exec LOOK_UP_JOBS_NONPROD 'select id from idtable' 
--EX. Exec LOOK_UP_JOBS_NONPROD 'SP_GET_DATA_LOOKUP'
--
--Local Variable 
--
@SEARCH_STRING VARCHAR(255) 
AS 
--
--Clean up Search String
--
SELECT @SEARCH_STRING = RTRIM(@SEARCH_STRING) 
SELECT @SEARCH_STRING = LTRIM(@SEARCH_STRING) 
SELECT @SEARCH_STRING = REPLACE(@SEARCH_STRING,' ','%') 
SELECT @SEARCH_STRING = REPLACE(@SEARCH_STRING,'"','%') 
SELECT @SEARCH_STRING = REPLACE(@SEARCH_STRING,"'",'%') 
SELECT @SEARCH_STRING = REPLACE(@SEARCH_STRING,'','%') 
SELECT @SEARCH_STRING = '%'+ @SEARCH_STRING +'%' 
--------------------------------------------------------------- 
SELECT @SEARCH_STRING AS 'SEARCH_STRING_USED' 
--------------------------------------------------------------- 

SELECT  CONVERT(VARCHAR(10),@@SERVERNAME) AS SEVER_NAME, 
        CONVERT(VARCHAR(42),J.NAME) AS 'JOBNAME', 
        JS.STEP_ID, 
        CONVERT(VARCHAR(50),JS.STEP_NAME) AS 'STEP_NAME', 
        JS.LAST_RUN_DATE, 
        JS.LAST_RUN_TIME, 
        CONVERT(VARCHAR(35),JS.DATABASE_NAME)AS DATABASE_NAME , 
        CASE J.ENABLED WHEN 1 THEN 'YES' ELSE 'NO' END AS 'ENABLED' 
        FROM    MSDB..SYSJOBS AS J JOIN 
                MSDB..SYSJOBSTEPS AS JS ON J.JOB_ID=JS.JOB_ID 
        WHERE   J.NAME NOT LIKE 'Backup %' 
                AND (J.NAME LIKE @SEARCH_STRING         
                        OR JS.COMMAND LIKE @SEARCH_STRING 
                        OR J.NAME LIKE @SEARCH_STRING 
                        OR JS.STEP_NAME LIKE @SEARCH_STRING 
                        OR JS.DATABASE_USER_NAME LIKE @SEARCH_STRING 
                        OR JS.DATABASE_NAME LIKE @SEARCH_STRING 
                        OR JS.OUTPUT_FILE_NAME LIKE @SEARCH_STRING 
                        OR JS.LAST_RUN_DATE LIKE @SEARCH_STRING 
                        OR JS.LAST_RUN_TIME LIKE @SEARCH_STRING 
                        OR JS.SERVER LIKE @SEARCH_STRING) 
        
        GROUP BY J.NAME,JS.STEP_ID,JS.STEP_NAME,J.ENABLED,JS.LAST_RUN_DATE, 
                        JS.LAST_RUN_TIME,JS.DATABASE_NAME,JS.DATABASE_USER_NAME 
        
        ORDER BY J.NAME,JS.STEP_ID,JS.STEP_NAME,JS.LAST_RUN_DATE,JS.LAST_RUN_TIME,JS.DATABASE_NAME 
GO 


