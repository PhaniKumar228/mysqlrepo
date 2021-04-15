/*
sp_GetLastBackup

  This will get the last date a database was backuped.  It allows you to report this date on all databases on a server, or pass in a db name, and it'll report the date that db was last backed up

*/

/**********************************************************
  sp_GetLastBackup
**********************************************************/

if
  exists
  (
    select * from SysObjects
      where ID = Object_ID('sp_GetLastBackup')
        and ObjectProperty(ID, 'IsProcedure') = 1
  )
begin
  drop procedure sp_GetLastBackup
end
go

create procedure sp_GetLastBackup
  @Name varchar(100) = '%'
with Encryption
as
  set NoCount on

  declare 
    @result int

  --try

    select 
        (substring ( database_name, 1, 32)) as Database_Name,
        abs(DateDiff(day, GetDate(), Max(backup_finish_date))) as DaysSinceBackup,
        Max(backup_finish_date)
      from msdb.dbo.backupset
      where Database_Name like @Name
      group by Database_Name
      order by Database_Name

  --finally
    SuccessProc:
    return 0  /* success */

  --except
    ErrorProc:
    return 1 /* failure */
  --end
go

grant execute on sp_GetLastBackup to Public
go



/*

sp_GetLastBackup 'hgp'

*/
