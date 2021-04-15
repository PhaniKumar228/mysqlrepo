/*
Blocking Notification
This script will send a mail whenever it detects a Blocking process. 
You need SQL Mail configured on this server in order to use or you can specify the pager number @company.com
*/

Declare @BESubj Varchar(500)
Select @BESubj = 'Blocking Detected ON  ' + @@SERVERNAME
Declare @SPID int
Declare @cmd Varchar(150)
--Declare @BESubj Varchar(500)
Select @BESubj = 'Blocking Detected ON  ' + @@SERVERNAME
Select SPID
,HostName=convert (char (15), hostname)
,UserName=convert (char (15), nt_username)
,BlokedBy=convert(char(5) ,blocked)
,Application=convert (char (25), program_name)
--,status=convert (char (8), status)
,DBname= convert ( char (10), db_name(dbid))
,SQL=convert (char (150),cmd)
--,CPU=convert (char(6),cpu)
--,physIO=convert(char (7),physical_io)  
into Transit..Blocked_Rows
from master.dbo.sysprocesses
where status <> 'background'
AND cmd NOT IN ('signal handler','lock monitor','log writer','lazy writer','checkpoint sleep','awaiting command')
And blocked <> 0
OR
SPID IN (Select Blocked 
		from  master..sysprocesses SP)
          AND Blocked = 0
      ORDER BY Blocked,SPID

 
If (Select Count(*) from Transit..Blocked_Rows) <> 0
Begin
	if Not exists (select * from dbo.sysobjects where id = object_id(N'Process_Info') )
	create table Process_Info(
	EventType varchar(150) ,
	Parameters int ,
	EventInfo varchar(150)
			)
	Declare Blocking_SPIDS Cursor Fast_Forward For
	Select SPID FROM Transit..Blocked_Rows

	OPEN Blocking_SPIDS

	FETCH NEXT FROM Blocking_SPIDS INTO @SPID
	WHILE @@FETCH_STATUS = 0
		BEGIN

		SET @cmd =  'DBCC INPUTBUFFER(' + CONVERT(varchar, @SPID) + ')'
	
		INSERT INTO Process_Info
		EXEC(@cmd)
	
		SELECT @cmd = EventInfo
		FROM Process_Info

		Update Transit..blocked_rows
		Set SQL= @cmd 
		Where SPID = @SPID

		FETCH NEXT FROM Blocking_SPIDS INTO @SPID

		END
CLOSE Blocking_SPIDS
DEALLOCATE Blocking_SPIDS

EXEC master..xp_sendmail @recipients = '<Email_List>'
,@query = 'Select * from DB..Blocked_Rows Order By SPID'
,@subject = @BESubj
,@message = 'Blocking has been Detected...Pls see the Attached'
,@attach_results = 'TRUE'
,@width = 250
End
Drop table Transit..Blocked_Rows

