/*
Rename SQL Server

Utilizing sp_dropserver and sp_addserver system procedures we will change local SQL Server name to a specified one, or, by default, to the WINS machine name. 
Just another utility in my DBAservice toolbox database.
Notes:
1.Tested in SQL Server7.
2. In some cases it is necessary to rerun sql server setup in order to start the server after renaming. Neither data nor version is affected. 

*/

Create proc uspRenameServer 
@pNewName varchar(256)=null--If NULL we will attempt to rename server to the WINS machine name
/*
Purpose: renames SQL server. 
Server: all
Database: DBAservice
*/
AS
Declare @OldName varchar(256)
Declare @NewName varchar(256)
set @OldName=''
select @OldName=isnull(srvname,'') from  master.dbo.sysservers where srvid=0 
If @pNewName is NULL
Begin
	create table #NName (NName varchar (256))
	insert #NName exec master.dbo.xp_getnetname
	select @NewName=Nname from #Nname
	drop table #Nname
End
ELSE If @pNewName is not NULL
Begin
	select @NewName=ltrim(rtrim(@pNewName))
End

If @OldName<>@NewName
BEGIN
	IF @OldName <>''
	BEGIN
		print 'Attempting to drop server '+@OldName
		Exec master.dbo.sp_dropserver  @OldName
	END
	print 'Attempting to add server '+@NewName
	Exec master.dbo.sp_addserver @NewName,'local'	
END
If isnull(@@Servername,'')<>@NewName 
Begin
	Print 'Please shut down and restart SQL Server in order to complete renaming.' 
End
Else If isnull(@@Servername,'')=@NewName 
Begin
	Print 'SQL Server is already named ' +@NewName
End










