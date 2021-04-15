/*
    
sp_GetBackupInfo

  This will report all backup activity for all databases, sorted by date, so you see the last backup activity first.  
You can filter this one by a db name as well, and only see the backup info for said database. 
 
 
*/

/**********************************************************
  sp_GetBackupInfo
**********************************************************/


if
  exists
  (
    select * from SysObjects
      where ID = Object_ID('sp_GetBackupInfo')
        and ObjectProperty(ID, 'IsProcedure') = 1
  )
begin
  drop procedure sp_GetBackupInfo
end
go

create procedure sp_GetBackupInfo
  @Name varchar(100) = '%'
with Encryption
as
  set NoCount on

  declare 
    @result int

  --try

    select 
        (substring ( database_name, 1, 32)) as Database_Name,
        abs(DateDiff(day, GetDate(), backup_finish_date)) as DaysSinceBackup,
        backup_finish_date
      from msdb.dbo.backupset
      where Database_Name like @Name
      order by Database_Name, backup_finish_date desc

  --finally
    SuccessProc:
    return 0  /* success */

  --except
    ErrorProc:
    return 1 /* failure */
  --end
go

grant execute on sp_GetBackupInfo to Public
go



/*

sp_GetBackupInfo 'hgp'

*/

