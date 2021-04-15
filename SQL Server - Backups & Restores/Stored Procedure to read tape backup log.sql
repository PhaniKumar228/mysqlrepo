/*
Stored Procedure to read tape backup log

If you need to check that the tape back of your database backup files was successful, you would generally read the errorlog for the backup software.

If you are just interested in today's results or a particular day's log it can be a pain to get.  
You could have a shortcut on the desktop or you could get SQL to do the reading for you.  

I wrote this stored procedure to give me todays content from the tape backup log.  
If I pass it a string containing the date e.g. '20020202' it will return entries for that day.

It can be easily adapted for reading just about any text file. 

*/

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_BackupLog]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_BackupLog]
GO


/****** Object:  Stored Procedure dbo.sp_BackupLog    Script Date: 01/06/2001 11:24:58 ******/

CREATE procedure dbo.sp_BackupLog
	(@Date1 nvarchar(20) = NULL)
as


Declare   @OUTPATH nvarchar(300)
	, @Year  int
	, @Month int
	, @Day int
	, @vcYear  varchar (4)
	, @vcMonth varchar (2)
	, @vcDay varchar (2)
	, @vcDate1 nvarchar(20)
	, @xDate2 datetime
	, @cmd nvarchar(512)

set nocount on
If @Date1 is null
	
	Begin
		Select @xDate2 = GETDATE() 
		Select @Year = Year(@xDate2), @Month = Month(@xDate2), @Day = Day(@xDate2) 
	end
	else
	
	Begin
		Select @Year = Substring(@Date1,1,4), @Month = Substring(@Date1,5,2), @Day = Substring(@Date1,7,2) 
	end

Select @vcYear = CAST(@Year AS Varchar(4))
, @vcMonth=RIGHT('0' + CAST(@month AS Varchar(2)), 2) 
, @vcDay  =RIGHT('0' + CAST(@Day   AS Varchar(2)), 2)

select   @vcDate1 = '"' +  @vcYear + @vcMonth + @vcDay + '"'
	,@OUTPATH = ' "C:\Program Files\ComputerAssociates\ARCserve\LOG\Arcserve.log"'  -- Replace this with your backup software log file and path
-- findstr /c:"20020202" "C:\Program Files\ComputerAssociates\ARCserve\LOG\Arcserve.log" > C:\BackupStatus.txt
Select	@cmd = 'findstr /c:' + @vcDate1 + @OUTPATH + ' > C:\BackupStatus.txt'
EXEC master..xp_cmdshell @cmd, no_output
EXEC master..xp_cmdshell 'type C:\BackupStatus.txt'

return 0
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO




