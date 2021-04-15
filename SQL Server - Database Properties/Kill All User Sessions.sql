/*
Kill All User Sessions

This script kills all the user sessions except its own.
This T-SQL block can be converted into a stored procedure by adding following lines in the begining of the script - 

Create Proc Kill_Sessions 
As 

*/


Begin
 declare @database          sysname
          ,@Login           sysname
          ,@Host            sysname
          ,@OsUser          sysname 
          ,@SP_ID           smallint
          ,@CRLF            varchar(2)
          ,@SQL_Stmt        nVarchar(500)
          ,@NotifyMsg	    nVarchar(500) 

   declare cr_processes cursor for
    select spid,
	   db_name(dbid) as DbName,
           loginame      as Login,
           hostname      as Host,
           nt_username   as OSUser
     from master..sysprocesses  where db_name(dbid) = (select top 1 db_name(dbid)
     from master..sysprocesses where spid=@@spid)   and spid <> @@SPID and spid >=50

    -- close/kill all connections for this database
    open cr_processes
    while 1 = 1
    begin
        fetch cr_processes INTO @SP_ID, @database, @Login, @Host, @OSUser
        if @@FETCH_STATUS <> 0 break   

        print 'Killing Process : ' + cast( @SP_ID as varchar(10))   
        select @SQL_Stmt = N'kill ' + cast( @SP_ID as varchar(10))
        print @SQL_Stmt
        execute sp_executesql @SQL_Stmt
    end
    close cr_processes

    deallocate cr_processes
End
