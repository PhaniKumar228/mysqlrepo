SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO
Create table #temp
(op_text varchar(max) )
GO

DECLARE @FileNameWithPath varchar(max);
DECLARE @FileName varchar(max);
DECLARE @ServerName varchar(max);
DECLARE @BackupDetailID int;
DECLARE @cmd sysname;
DECLARE @Counter int;
DECLARE @rowcount int;
DECLARE @SQLString nvarchar(500);
DECLARE @ParmDefinition nvarchar(500);
DECLARE @count int;


Declare BackupFile Cursor For
SELECT BackupDetailID,ServerName,
	CASE WHEN CHARINDEX(':',BackupFileName,1) > 0
		 THEN '\\'+ CASE WHEN CHARINDEX('\',ServerName,1)>0 
						 THEN SUBSTRING(ServerName,1,CHARINDEX('\',ServerName,1)-1)+SUBSTRING(BackupFileName, CHARINDEX(':',BackupFileName,1)+1, len(BackupFileName))
						 ELSE ServerName+SUBSTRING(BackupFileName, CHARINDEX(':',BackupFileName,1)+1, len(BackupFileName))
					END
		 WHEN CHARINDEX('$',BackupFileName,1) > 0 AND CHARINDEX('\\',BackupFileName,1) > 0
		 THEN SUBSTRING(BackupFileName,1,CHARINDEX('$',BackupFileName,1)-3)+
				SUBSTRING(BackupFileName, CHARINDEX('$',BackupFileName,1)+1, len(BackupFileName))
		 ELSE BackupFileName
	END 
	,REVERSE(SUBSTRING(REVERSE(BackupFileName),1,CHARINDEX('\',REVERSE(BackupFileName),1)-1)) 
FROM DBREFS..t_Backup_Details 
WHERE BackupFinishDate Between DateAdd(hh,-48,GetDate()) And GetDate()
and ServerName = 'DRECMCALC1'

Open BackupFile

Fetch Next From BackupFile Into @BackupDetailID,@ServerName,@FileNameWithPath,@FileName



Set @Counter = 1
while @@fetch_status = 0 
Begin
	Set @cmd = 'dir ' + @FileNameWithPath;
--print @cmd
	Delete from #temp 
	insert into #temp execute master..xp_cmdshell @cmd
	--SET @ParmDefinition = N'@file varchar(max), @countOUT int OUTPUT';
	--SET @SQLString = 'select @countOUT=count(*) from #temp where op_text like ''%@file%''';
--print @SQLString
	--execute sp_executesql @SQLString,@ParmDefinition,@file=@FileName,@countOUT=@count OUTPUT;
--print @count
	--IF @@ROWCOUNT > 0 
	IF EXISTS (SELECT * FROM #temp WHERE op_text like'%.bak%')
	BEGIN
		Print @ServerName +' -> File '+@FileNameWithPath+' exists.'
		--Update DBREFS..t_Backup_Details Set FileExists = 1 
			--Where BackupDetailID = @BackupDetailID
		Set @Counter = @Counter + 1
	END
	ELSE
		Print @ServerName + ' -> File '+@FileNameWithPath+' does not exists.'
--	Set @Counter = @Counter + 1
	Fetch Next From BackupFile Into @BackupDetailID,@ServerName,@FileNameWithPath,@FileName
End
Close BackupFile
Deallocate BackupFile
Print 'No. of Files ' + Cast(@Counter As varchar(10))
drop table #temp
GO
SET NOCOUNT OFF
GO
