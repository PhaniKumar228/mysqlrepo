/* 
This procedure will send a notification if the free disk space on any of the drives
SQL Server resides on is lower than the specified limit.
The alert can either be an email or netsend.

usage: exec master.dbo.sp_diskalert 'test@mail.com', 1000
Will send an email to 'test@mail.com' if the free disk space is less than 1000mb
NB more than one email address can be specified, separate using semi colons

Supports sql server 7 or 2000
You need sql mail configured to send email!
If xp_cmdshell doesn't exist it will be added and dropped as needed
*/
        
USE master
GO

if exists 
(select * from sysobjects where id = object_id(N'[dbo].[sp_diskalert]') 
and OBJECTPROPERTY(id, N'IsProcedure') = 1)
        drop procedure [dbo].[sp_diskalert]
GO

create procedure sp_diskalert
@RCPT VARCHAR(500),
@LIMIT INT

AS
BEGIN
SET NOCOUNT ON

CREATE TABLE #T1(
        DRVLETTER CHAR(1),
        DRVSPACE INT
        )

INSERT INTO #T1 EXEC master.dbo.xp_fixeddrives

/* GENERATE THE MESSAGE */

IF (SELECT COUNT(*) FROM #T1) > 0 AND LEN(@RCPT) > 0 --CHECK THERE IS SOME DATA AND A RECIPIENT
BEGIN
        DECLARE @MSG VARCHAR(400),
               @DLETTER VARCHAR(5),
               @DSPACE INT
        
        SET @DLETTER = (SELECT TOP 1 DRVLETTER FROM #T1 --GET FIRST DRIVE LETTER
                       WHERE DRVSPACE < @LIMIT 
                       ORDER BY DRVLETTER ASC)

        SET @DSPACE = (SELECT DRVSPACE FROM #T1 --GET THE DISK SPACE FOR THE LETTER
                       WHERE DRVLETTER = @DLETTER)

        SET @MSG =  @DLETTER + ' is at ' + CONVERT(VARCHAR,@DSPACE) --PUT THE VARS INTO A MSG
                       + 'MB' + CHAR(13) + CHAR(10)
        

        WHILE (SELECT COUNT(*) FROM #T1 WHERE DRVSPACE < @LIMIT AND DRVLETTER > @DLETTER) > 0
        BEGIN                                 --LOOP THROUGH DRIVE LETTERS AND REPEAT ABOVE   
               SET @DLETTER = (SELECT TOP 1 DRVLETTER FROM #T1 
                               WHERE DRVSPACE < @LIMIT 
                               AND DRVLETTER > @DLETTER 
                               ORDER BY DRVLETTER ASC)
                               
               SET @DSPACE = (SELECT DRVSPACE FROM #T1 
                               WHERE DRVLETTER = @DLETTER)
               SET @MSG = @MSG + @DLETTER + ' is at ' + CONVERT(VARCHAR,@DSPACE) + 'MB' 
                               + CHAR(13) + CHAR(10)
        END

        /* SEND THE MESSAGE */

        IF CHARINDEX('@',@RCPT) > 0    --THERE IS AN @ SYMBOL IN THE RECIPIENT - SEND EMAIL
        BEGIN
               DECLARE @EMAIL VARCHAR(600)
               SET @EMAIL = 'EXEC master.dbo.xp_sendmail 
                               @recipients = ''' + @RCPT + ''', 
                               @message = ''' + @MSG + ''', 
                               @subject = ''!! LOW FREE DISK SPACE ON ' + @@SERVERNAME + ' !!'''
               EXEC (@EMAIL)
        END

        ELSE IF CHARINDEX('@',@RCPT) = 0 --THERE IS NO @ SYMBOL IN THE RECIPIENT - NET SEND
        BEGIN   
               --DETERMINE IF XP_CMDSHELL EXISTS
               DECLARE @FLAG BIT
               SET @FLAG = 1

               IF NOT EXISTS(SELECT NAME FROM master..sysobjects WHERE NAME = 'XP_CMDSHELL')
               SET @FLAG = 0
        
               --IF NOT RECREATE IT
               IF @FLAG = 0
               BEGIN
                       EXEC sp_addextendedproc 'xp_cmdshell', 'xpsql70.dll'
                       PRINT 'ADDING XP_CMDSHELL'
               END
        
               --NET SEND MSG
               DECLARE @NETSEND VARCHAR(600)
               SET @MSG = 'ALERT - LOW FREE DISK SPACE ON ' + @@SERVERNAME + ' : ' + @MSG
               SET @NETSEND = 'xp_cmdshell ''net send "' + RTRIM(@RCPT) + '" ' 
                               + LEFT(RTRIM(REPLACE(@MSG,CHAR(13) + CHAR(10),', ')),LEN(@MSG)-2) + ''''
               EXEC (@NETSEND)

               --DROP XP_CMDSHELL IF IT DIDN'T EXIST
               IF @FLAG = 0
               BEGIN
                       EXEC sp_dropextendedproc 'xp_cmdshell'
                       PRINT 'DROPPING XP_CMDSHELL'
               END

        END
END

/* CLEANUP */

DROP TABLE #T1

END
GO
