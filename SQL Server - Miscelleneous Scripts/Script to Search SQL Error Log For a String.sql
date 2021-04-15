/*
Script to Search SQL Error Log For a String

This script(sproc)uses xp_cmdshell from sql and FINDSTR from DOS to search the current errorlog for a specific string such as kernel or failed login. Compile this in the master db and if you do not pass an input parameter a example usage will display for you. ex: 
*/

create proc sp_dba_sqlerrorlog @lookfor varchar(25)= ''

  AS
/******************************

sql-scripting 04/04/2001 

Visit www.sql-scripting.com 
Edward J Pochinski III 

******************************/ 

 

Declare @cmd varchar(55) 

     if @lookfor = '' 

Begin  

    Print '#################################################' 

    Print char(13)+'Must pass a string to search for.' 

    Print char(13)+'example: exec sp_dba_sqlerrorlog3 kernel ' 

    Print char(13)+'sql-scripting 6/17/01 www.sql-scripting.com ' 

    Print char(13)+'#################################################' 

  Return 

End 

    set @cmd = 'FINDSTR /I /C:"'+@lookfor+'" C:\MSSQL7\Log\errorlog' 

exec xp_cmdshell @cmd 

