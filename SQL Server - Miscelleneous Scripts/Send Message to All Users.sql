/*
Send Message to All Users

A procedure send message to all active SQL Server users
(SQL Server Connections) on your Server.
I use Win command NET SEND. 

*/

/********************************************************************************************	 
**	Name: p_send_message.
**	Desc: Send  message to active SQL Server users on Server. Use Win command NET SEND.
** 
**	Called by: 
**            execute p_send_message 'message'
**      Return code:  0 = good ,1 = bad         
**	Input:          	Output: net-send message
**      ------------------	-----------------------------------

********************************************************************************************/
set quoted_identifier off
go

Create PROCEDURE p_send_message  
     @message   varchar(200) , @loginame     sysname = NULL 
as  

set nocount on  
  
declare  @retcode                  int ,
         @string                   nvarchar(300)  
declare  @HostName                 nchar(128)

declare c cursor for 
	SELECT  DISTINCT hostname      
        from    master.dbo.sysprocesses   (nolock) 
        where   status <> 'background' and hostname is not null and hostname <> ' ' 

--------------------------------------------------------------    
    -- CHECK PERMISSIONS --  
IF (not is_srvrolemember('sysadmin') = 1) and (not is_srvrolemember('serveradmin') = 1)  
Begin     
    Print  'Access denied. Access allow to SA & SysAdmin logins only.'
    deallocate c
    return (1)
End
 
-------

open  c 
fetch c into @HostName 
while @@fetch_status = 0 
begin 
       set @string = 'master..xp_cmdshell "net send ' + @HostName + @message + '"' 
--       print  (@string)
       execute  (@string)  

       fetch c into @HostName
end 
close c 
deallocate c

return (0) 
Go   
 


