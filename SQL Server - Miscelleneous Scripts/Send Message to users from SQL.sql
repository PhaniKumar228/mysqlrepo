/*
Send Message to users from SQL 

This is simple Sql command to send Message to users connected in Windows NT Environment. The Xp_cmdshell stored procedure can be used along with WinNT net send command. 
*/

exec xp_cmdshell 'net send manish  "Please Logout " '
