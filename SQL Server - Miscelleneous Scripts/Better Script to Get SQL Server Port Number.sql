/*
Better Script to Get SQL Server Port Number
You don't have to try and decipher what instance you are running. 
The extended stored procedure xp_instance_regread does all the functionality of xp_regread and automatically knows 
which instance in the registry it should look at. 
*/
DECLARE @test varchar(15),@value_name varchar(15),@RegistryPath varchar(200)

SET @RegistryPath = 'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp'

EXEC master..xp_instance_regread @rootkey='HKEY_LOCAL_MACHINE' ,
@key=@RegistryPath,@value_name='TcpPort',
@value=@test OUTPUT

Print 'The Port Number is '+ char(13)+ @test  
