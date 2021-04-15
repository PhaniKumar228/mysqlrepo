if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_RunningCheck]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_RunningCheck]
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

CREATE PROCEDURE dbo.sp_RunningCheck
	(  
	   @SQLBatch 	 	nvarchar(255)   = NULL
	)

AS 

/********1*********2*********3*********4*********5*********6*********8*********9*********0*********1*********2*****
**
**  $Archive$
**  $Revision$
**  $Author$ 
**  $Modtime$
**
*******************************************************************************************************************
**
**  $Log$
**
*******************************************************************************************************************
**
**	Name: sp_RunningCheck
**	Desc: This procedure checks to see if a TSQL batch is currently running.
**		
**	USAGE: 
**		
**	Return values: 0 = Not Detected, -1 if detected, 1 if no parameter, error number if failed
**              
*******************************************************************************************************************/

Declare @Err 		int
,		@cmd1 		nvarchar(4000)
,		@counts 	int
,		@SPID 		int
Select @Err = 0

If @SQLBatch is Null
Begin
	Return 1
End

Set nocount on

	
Create Table ##tmpRunningCheck1
	(
	fld1	nvarchar(30),
	fld2	int,
	fld3	nvarchar(255)
	)

DECLARE curSPID  CURSOR FORWARD_ONLY STATIC FOR  -- Cursor creates a temp table in tempdb
 SELECT spid FROM sysprocesses (nolock) where spid > 20 and cmd <> 'AWAITING COMMAND' ORDER BY spid

OPEN curSPID -- CURSOR


FETCH NEXT FROM curSPID INTO @SPID
while @@fetch_status = 0
	begin
		Select @cmd1 = 'dbcc inputbuffer(' + cast(@SPID as varchar(5)) + ')' 
		Insert ##tmpRunningCheck1 EXEC (@cmd1)
		Select @Err = @@Error
		FETCH NEXT FROM curSPID INTO @SPID
	end


CLOSE curSPID
DEALLOCATE curSPID
--select * from ##tmpRunningCheck1
Select @counts = Count(*) from ##tmpRunningCheck1 where fld3 like '%' + @SQLBatch + '%'


Select @Err = @@Error
drop table ##tmpRunningCheck1
If @Err <> 0 
Begin
	Return @Err
End
If @counts > 1  -- this procedure includes the batch too !
begin 
	Return -1
end
else
begin
	Return 0
end

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[sp_RunningCheck]  TO [public]
GO