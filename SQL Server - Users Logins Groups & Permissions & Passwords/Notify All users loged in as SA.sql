/*
Notify All users loged in as SA

Procedure that net sends a message to any user who logged in as SA.
IN. had to use this once in the company where SA password was blank for a while and managment did not want to set a password on the account. 
You can also set it to work with any username or for users that login to SQL Server from other machines.
With couple of more statements you can also automatically kill the process of that user. 

*/

CREATE PROCEDURE Notify_Users_Logged_In_As_SA
AS
	DECLARE @HOST varchar(50)
	DECLARE @Login varchar(50)
	DECLARE @Message varchar(1000)
	DECLARE @Program_Name varchar(500)
	
	DECLARE whois CURSOR 
	FOR SELECT DISTINCT   
		   rtrim(hostname) as hostname,
		   rtrim(loginame) as loginame,
		   program_name
	FROM  master.dbo.sysprocesses
	WHERE
		hostname not in ('','YOURServer') AND
		loginame = 'sa'
		
	OPEN whois
	
	FETCH NEXT FROM whois INTO  @HOST, @Login, @Program_Name
	
	WHILE @@fetch_status = 0 
		BEGIN 
			SELECT @Message = 'xp_cmdshell ' + char(39) + 'net send ' + @host + ' You are logged in to SQL Server as SA from ' + @Program_name + '. Please log off and reconnect with your login name!' + char(39)
			
			EXECUTE (@Message)
			PRINT (@Message)
	
			FETCH NEXT FROM whois INTO @HOST, @Login, @Program_Name
		END
	DEALLOCATE whois





 