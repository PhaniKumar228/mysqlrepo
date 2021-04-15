/*
Script to transfer logins to second server

Puts out a script to add new logins or change the password of existing logins.
I insert the output into a table in my production-db. 
insert database.dbo.login_table exec master.dbo.dr_script_logins
That way its backed up with the data, and the logins can be restored anywhere by the script i added at the bottom.
After transfering the logins you should run the last script to correct the login ID's
*/  

CREATE PROCEDURE DR_Script_logins 
AS

DECLARE @login_name    sysname  
DECLARE @name          sysname
DECLARE @xstatus       int
DECLARE @dbnm          sysname
DECLARE @binpwd        varbinary (256)
DECLARE @txtpwd        sysname
DECLARE @tmpstr        varchar   (4000)
DECLARE @SID_varbinary varbinary  (85)
DECLARE @SID_string    varchar   (256)
DECLARE @loopCnt       int

-------------------------------------------------------------------------------------------------
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! --
--
--  >>>>>>>>>>>>  IF master has been restored with an alternate name change below,  <<<<<<<<<<<<
--                  e.g. restoring multiple servers onto one  
--
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! --
------------------------------------------------------------------------------------------------

DECLARE login_curs CURSOR FOR 
 SELECT l.sid, l.name, xstatus, password, d.name
   FROM master..sysxlogins l                            -- <<<<<<<<<<<<<<<<<<  change here
   JOIN master..sysdatabases d on d.dbid =  l.dbid      -- <<<<<<<<<<<<<<<<<<  change here
  WHERE srvid IS NULL AND l.name <> 'sa'
  --  uncomment if master restored with an alternate name and to exclude existing logins
  --  AND NOT EXISTS (SELECT 1 FROM master..sysxlogins where master..sysxlogins.name = l.name)

OPEN login_curs 
FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @xstatus, @binpwd, @dbnm

IF (@@fetch_status = -1)
  BEGIN
    PRINT 'No login(s) found.'
    CLOSE login_curs 
    DEALLOCATE login_curs 
    GOTO ScriptEnd
  END

--PRINT ''
--PRINT 'DECLARE @pwd sysname'

WHILE (@@fetch_status <> -1)
  BEGIN 
    IF (@@fetch_status <> -2)
      BEGIN
--        PRINT ''
--        SET @tmpstr = '-- Login: ' + @name
--        PRINT @tmpstr 
-- Inserted by Karl Klingler
 SET @tmpstr = 'DECLARE @pwd sysname '+char(13)    --+'--EXEC master.dbo.sp_user_droppen '''+@name+''' '
-- PRINT @tmpstr 
-- SET @tmpstr = @tmpstr + char(13)+' --EXEC master.dbo.sp_droplogin '''+@name+''' '
-- PRINT @tmpstr 
        IF (@xstatus & 4) = 4
          BEGIN -- NT authenticated account/group
            IF (@xstatus & 1) = 1
              BEGIN -- NT login is denied access
                SET @tmpstr = @tmpstr + char(13)+' EXEC master.dbo.sp_denylogin ''' + @name + ''''
--                PRINT @tmpstr 
              END
            ELSE 
              BEGIN -- NT login has access
                SET @tmpstr = @tmpstr + char(13)+' EXEC master.dbo.sp_grantlogin ''' + @name + ''''
--                PRINT @tmpstr 
              END
          END
        ELSE  -- NT authenticated account/group
          BEGIN -- SQL Server authentication
            IF (@binpwd IS NOT NULL)
              BEGIN -- Non-null password
                EXEC sp_hexadecimal @binpwd, @txtpwd OUT
                IF (@xstatus & 2048) = 2048
                  SET @tmpstr = @tmpstr +char(13)+ ' SET @pwd = CONVERT (varchar(256), ' + @txtpwd + ')'
                ELSE
                  SET @tmpstr = @tmpstr +char(13)+ ' SET @pwd = CONVERT (varbinary(256), ' + @txtpwd + ')'

--                PRINT @tmpstr
                EXEC sp_hexadecimal @SID_varbinary,@SID_string OUT
                SET @tmpstr = @tmpstr + char(13)+'if (select 1 from master.dbo.sysxlogins where name='''+@name+''') is null  begin '+char(13)+'   EXEC master.dbo.sp_addlogin ''' + @name 
                        + ''', @pwd, @encryptopt = '
              END -- Non-null password
            ELSE 
              BEGIN  -- Null password
                EXEC sp_hexadecimal @SID_varbinary,@SID_string OUT
                SET @tmpstr = @tmpstr + char(13)+' EXEC master.dbo.sp_addlogin ''' + @name 
                    + ''', NULL, @encryptopt = '
              END  -- Null password

              IF (@xstatus & 2048) = 2048
                -- login upgraded from 6.5
                SET @tmpstr = @tmpstr + '''skip_encryption_old''' 
              ELSE 
                SET @tmpstr = @tmpstr + '''skip_encryption'''

--             PRINT @tmpstr 
          END -- SQL Server authentication

      SET @tmpstr = @tmpstr + char(13)+' if exists (select 1 from master.dbo.sysdatabases where name = ''' +@dbnm+ ''')'
--      PRINT @tmpstr 
      SET @tmpstr = @tmpstr +char(13)+ '     EXEC sp_defaultdb @loginame = ''' + @name + ''',  @defdb = ''' +@dbnm+ ''''
--      PRINT @tmpstr 

      -- add fixed server roles
      set @loopCnt = 4
      while @loopCnt < 13
         begin
           if (POWER(2,@loopCnt) & @xstatus)>15  begin 
             select @tmpstr = @tmpstr +char(13)+ ' EXEC sp_addsrvrolemember @loginame = ''' + @name + ''',  @rolename = ''' + 
                  CASE POWER(2,@loopCnt) & @xstatus 
                  WHEN 16      THEN 'sysadmin'
                  WHEN 32      THEN 'securityadmin' 
                  WHEN 64      THEN 'serveradmin'
                  WHEN 128     THEN 'setupadmin'
                  WHEN 256     THEN 'processadmin' 
                  WHEN 512     THEN 'diskadmin'
                  WHEN 1024    THEN 'dbcreator'
	       WHEN 4096    THEN 'bulkadmin'
--              ELSE null      
                 ELSE ''      
               END  + ''' '
            end
--          if @tmpstr is not null
--            PRINT @tmpstr 

          set @loopCnt = @loopCnt + 1

          if @loopCnt = 11 --skip 2048
            set @loopCnt = @loopCnt + 1

        end
        select @tmpstr = @tmpstr + char(13) +' END 
else    -- CHANGE THE PASSWORD --
 begin
  update master.dbo.sysxlogins
             set password = CONVERT (varbinary(256),@pwd), xdate2 = getdate(), xstatus = xstatus & (~2048)
	where name = '''+@name+''' and srvid IS NULL

  -- UPDATE PROTECTION TIMESTAMP FOR MASTER DB, TO INDICATE SYSLOGINS CHANGE --
  exec(''use master grant all to null'')
end'  

select @name,@tmpstr
          if @tmpstr is not null
            PRINT @tmpstr 

    END  -- @@fetch_status <> -2
    FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @xstatus, @binpwd, @dbnm
  END  -- WHILE LOOP

CLOSE login_curs 
DEALLOCATE login_curs 

PRINT ''

-- PRINT 'Logins that already exist in master:'
-- SELECT name, sid, xstatus FROM [spdb4-2.intra.ads-root.de]master..sysxlogins 
--   WHERE srvid IS NULL AND name <> 'sa'
--     AND  EXISTS (SELECT 1 FROM master..sysxlogins where master..sysxlogins.name = [spdb4-2.intra.ads-root.de]master..sysxlogins.name)

ScriptEnd:
GO

-------------- Table to hold the commands ------------------------
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[login_table]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[login_table]
GO

CREATE TABLE [dbo].[login_table] (
	[log_id] [bigint] IDENTITY (1, 1) NOT NULL ,
	[login] [char] (50) COLLATE Latin1_General_CI_AS NULL ,
	[command] [varchar] (4000) COLLATE Latin1_General_CI_AS NULL 
) ON [Data Filegroup 1]
GO



-------------- script to execute the commands from a table --------
declare @cmd varchar(4000)

declare log_cur cursor for 
select command 
from server.database.dbo.login_table 

open log_cur

fetch next from log_cur into @cmd

while (@@FETCH_STATUS <> -1) begin
  exec(@cmd)
  print ''
  print @cmd
  fetch next from log_cur into @cmd
end

close log_cur
deallocate log_cur

-------------- script to correct login IDs --------
declare @login sysname
declare log_curs cursor for
select name from sysusers where upper(name) <>'DBO' and status=2

open log_curs
fetch next from log_curs into @login
WHILE (@@FETCH_STATUS <> -1)
BEGIN
   IF (@@FETCH_STATUS <> -2)
   BEGIN   
      exec sp_change_users_login 'Update_One', @login, @login
      Print 'Login angepasst: "' + @login + '".'
   END
   FETCH NEXT FROM log_curs INTO @login
END
CLOSE log_curs
DEALLOCATE log_curs



