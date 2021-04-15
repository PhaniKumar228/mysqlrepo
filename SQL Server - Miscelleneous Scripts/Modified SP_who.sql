/*
    
Modified SP_who

Here is a modified SP_WHO procedure
which returns more information about the current session.
I forgot all the thing that i have added to the sproc, but the last addition shows the last executed TSQL statement.
There might be a better solution to get the values from DBCC rowset, thou I did not have time to think everything through. 

*/

ALTER PROCEDURE sp_who2  --- 1995/11/03 10:16
    @loginame     sysname = NULL,
    @DBName nvarchar(25) = NULL
AS

SET NOCOUNT ON

DECLARE
	@retcode         int

DECLARE
	@sidlow         varbinary(85),
	@sidhigh        varbinary(85), 
	@sid1           varbinary(85), 
	@spidlow         int, 
	@spidhigh        int

DECLARE
	@charMaxLenLoginName      varchar(6),
	@charMaxLenDBName         varchar(6), 
	@charMaxLenCPUTime        varchar(10), 
	@charMaxLenDiskIO         varchar(10), 
	@charMaxLenHostName       varchar(10), 
	@charMaxLenProgramName    varchar(10), 
	@charMaxLenLastBatch      varchar(10), 
	@charMaxLenCommand        varchar(10)

DECLARE
	@charsidlow              varchar(85),
	@charsidhigh             varchar(85),
	@charspidlow              varchar(11),
	@charspidhigh             varchar(11)

--------

SELECT
    @retcode         = 0      -- 0=good ,1=bad.

--------defaults
SELECT @sidlow = convert(varbinary(85), (replicate(char(0), 85)))
SELECT @sidhigh = convert(varbinary(85), (replicate(char(1), 85)))

SELECT
	@spidlow         = 0,
	@spidhigh        = 32767

--------------------------------------------------------------
IF (@loginame IS     NULL)  --Simple default to all LoginNames.
      GOTO LABEL_17PARM1EDITED

--------

-- SELECT @sid1 = suser_sid(@loginame)
SELECT @sid1 = null
IF EXISTS(SELECT * from master.dbo.syslogins where loginname = @loginame)
	SELECT @sid1 = sid from master.dbo.syslogins where loginname = @loginame

IF (@sid1 IS NOT NULL)  --Parm is a recognized login name.
   BEGIN
	   SELECT 
		@sidlow  = suser_sid(@loginame),
		@sidhigh = suser_sid(@loginame)
	   GOTO LABEL_17PARM1EDITED
   END

--------

IF (LOWER(@loginame) IN ('active'))  --Special action, not sleeping.
   BEGIN
	   SELECT @loginame = lower(@loginame)
	   GOTO LABEL_17PARM1EDITED
   END

--------

IF (PATINDEX ('%[^0-9]%' , isnull(@loginame,'z')) = 0)  --Is a number.
   BEGIN
	   SELECT
		@spidlow   = convert(int, @loginame),
		@spidhigh  = convert(int, @loginame)
	   GOTO LABEL_17PARM1EDITED
   END

--------

RAISERROR(15007,-1,-1,@loginame)
SELECT @retcode = 1
GOTO LABEL_86RETURN


LABEL_17PARM1EDITED:


--------------------  Capture consistent sysprocesses.  -------------------

SELECT
	spid,
	status,
	sid,
	hostname,
	program_name,
	cmd,
	cpu,
	physical_io,
	blocked,
	dbid,
	convert(sysname, rtrim(loginame))
	        as loginname,
	spid as 'spid_sort',
	substring( convert(varchar,last_batch,111) ,6  ,5 ) + ' '
	  + substring( convert(varchar,last_batch,113) ,13 ,8 )
	       as 'last_batch_char'
      INTO    #tb1_sysprocesses
      FROM master.dbo.sysprocesses   (nolock)



--------Screen out any rows?

IF (@loginame IN ('active'))
   DELETE #tb1_sysprocesses
         where   lower(status)  = 'sleeping'
         and     upper(cmd)    IN (
                     'AWAITING COMMAND'
                    ,'MIRROR HANDLER'
                    ,'LAZY WRITER'
                    ,'CHECKPOINT SLEEP'
                    ,'RA MANAGER'
                                  )

         and     blocked       = 0



--------Prepare to dynamically optimize column widths.


SELECT
	@charsidlow     = convert(varchar(85),@sidlow),
	@charsidhigh    = convert(varchar(85),@sidhigh),
	@charspidlow     = convert(varchar,@spidlow),
	@charspidhigh    = convert(varchar,@spidhigh)



SELECT
             @charMaxLenLoginName =
                  convert( varchar
                          ,isnull( max( datalength(loginname)) ,5)
                         )

            ,@charMaxLenDBName    =
                  convert( varchar
                          ,isnull( max( datalength( rtrim(convert(varchar(128),db_name(dbid))))) ,6)
                         )

            ,@charMaxLenCPUTime   =
                  convert( varchar
            ,isnull( max( datalength( rtrim(convert(varchar(128),cpu)))) ,7)
                         )

            ,@charMaxLenDiskIO    =
                  convert( varchar
                          ,isnull( max( datalength( rtrim(convert(varchar(128),physical_io)))) ,6)
                         )

            ,@charMaxLenCommand  =
                  convert( varchar
                          ,isnull( max( datalength( rtrim(convert(varchar(128),cmd)))) ,7)
                         )

            ,@charMaxLenHostName  =
                  convert( varchar
                          ,isnull( max( datalength( rtrim(convert(varchar(128),hostname)))) ,8)
                         )

            ,@charMaxLenProgramName =
                  convert( varchar
                          ,isnull( max( datalength( rtrim(convert(varchar(128),program_name)))) ,11)
                         )

            ,@charMaxLenLastBatch =
                  convert( varchar
                          ,isnull( max( datalength( rtrim(convert(varchar(128),last_batch_char)))) ,9)
                         )
      from
             #tb1_sysprocesses
      where
--             sid >= @sidlow
--      and    sid <= @sidhigh
--      and
             spid >= @spidlow
      and    spid <= @spidhigh




--Add EventInfo Column to #tb1_sysprocesses
ALTER TABLE #tb1_sysprocesses
	ADD EventInfo text

--CREATE TEMP TABLE TO INPUT DBCC INFO
CREATE TABLE #tmpDBCCInfo
	(
		EventType varchar(8000),	
		Parameters int,
		EventInfo varchar(8000)
	)
	

DECLARE @DBCCExecute varchar(100)
DECLARE @SPID int
DECLARE dbcc_cursor CURSOR FOR 
	SELECT SPID 
	FROM #tb1_sysprocesses

OPEN dbcc_cursor 
FETCH NEXT FROM dbcc_cursor INTO @SPID
WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @DBCCExecute  = 'DBCC inputbuffer(' + CAST(@SPID as varchar) + ') WITH TABLERESULTS, NO_INFOMSGS'
		INSERT INTO #tmpDBCCInfo 
			EXECUTE(@DBCCExecute)
		UPDATE #tb1_sysprocesses 
			SET EventInfo = (SELECT CAST(EventInfo as varchar(8000)) FROM #tmpDBCCInfo)
		WHERE
			SPID = @SPID

		DELETE FROM #tmpDBCCInfo
		FETCH NEXT FROM dbcc_cursor INTO @SPID
	END	

DEALLOCATE dbcc_cursor


--------Output the report.

DECLARE @SQL varchar(8000)

SET @SQL = 
'SET NOCOUNT ON

SELECT
             SPID          = convert(char(5),spid)

            ,Status        =
                  CASE lower(status)
                     When ''sleeping'' Then lower(status)
                     Else                   upper(status)
                  END

            ,Login         = substring(loginname,1,' + @charMaxLenLoginName + ')

            ,HostName      =
                  CASE hostname
                     When Null  Then ''  .''
                     When '' '' Then ''  .''
                     Else    substring(hostname,1,' + @charMaxLenHostName + ')
                  END

            ,BlkBy         =
                  CASE               isnull(convert(char(5),blocked),''0'')
                     When ''0'' Then ''  .''
                     Else            isnull(convert(char(5),blocked),''0'')
                  END

            ,DBName        = substring(case when dbid = 0 then null when dbid <> 0 then db_name(dbid) END,1,' + @charMaxLenDBName + ')
            ,Command       = substring(cmd,1,' + @charMaxLenCommand + ')

            ,CPUTime       = substring(convert(varchar,cpu),1,' + @charMaxLenCPUTime + ')
            ,DiskIO        = substring(convert(varchar,physical_io),1,' + @charMaxLenDiskIO + ')

            ,LastBatch     = substring(last_batch_char,1,' + @charMaxLenLastBatch + ')

            ,ProgramName   = substring(program_name,1,' + @charMaxLenProgramName + ')
            ,EventInfo
      FROM
             #tb1_sysprocesses  --Usually DB qualification is needed in exec().
      WHERE
             spid >= ' + @charspidlow  + ' and spid <= ' + @charspidhigh + ' '

IF @Loginame IS NOT NULL 
	BEGIN
		SET @SQL = @SQL  + ' AND LoginName = ''' + @loginame + ''''
	END
IF @DBName IS NOT NULL 
	BEGIN
		SET @SQL = @SQL  + ' AND dbid =  db_id(''' + @DBName + ''')'

	END
SET @SQL = @SQL +
'      -- (Seems always auto sorted.)   order by spid_sort


'
PRINT @SQL
EXECUTE (@SQL)
/*****AKUNDONE: removed from where-clause in above EXEC sqlstr
             sid >= ' + @charsidlow  + '
      and    sid <= ' + @charsidhigh + '
      and
**************/

SET NOCOUNT OFF





LABEL_86RETURN:

IF (object_id('tempdb..#tb1_sysprocesses') is not null)
            DROP TABLE #tb1_sysprocesses
IF (object_id('tempdb..#tmpDBCCInfo') is not null)
            DROP TABLE #tmpDBCCInfo



RETURN @retcode -- sp_who2




GO
