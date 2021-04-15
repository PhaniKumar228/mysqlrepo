/*
Improved Move indexes to new file group

This is an improved and expanded version of the previously posted script that moves indexes to a new file group. This version will:
1. Create new filegrup and files for indexes
2. Script out and recreate indexes on new drive
3. NEW* output report to text file
4. NEW* Will run with enclosed wrapper for ALL DATABASES ON THE SERVER. This is helpful if like me, you have over 100 small user databases per instance. 

*/

-- This is the wrapper. This must run after the function and --stored procedure are executed and compiled into the DB

DECLARE @dbcounter int
DECLARE @Db sysname
DECLARE @sql Varchar (20)


Select DBID, Name 
	INTO #DBLIST
From master..SysDatabases WHERE NAME like ('%zz_Test%')

Set @DBCounter = 1
While @DbCounter <= (Select sum(dbID) from #DbList)

BEGIN 

	SELECT @DB = MIN(NAME) FROM #DBLIST 

	SET @SQL = 'USE '+@db+' GO'
	
	PRINT @SQL
	
	EXEC DBA.Dbo.DBA_MoveIndexes @dbname = @Db, @NCPATH = 'L:\_SQL\INDEXES\'

	DELETE #DBLIST WHERE NAME = @DB

	SET @DBCOUNTER = (@DBCOUNTER + 1)

END

Drop Table #DBList
	
--=========================================================================================================

ALTER Function dbo.UFN_TextFileOutput
(
	@FileName varchar(1000), @Text1 varchar(1000)
)
RETURNS VARCHAR(100) 
AS
BEGIN
	DECLARE @status VARCHAR(100), @eof VARCHAR(10)
	SET @status = 'SUCCESS'
	DECLARE @FS int, @OLEResult int, @FileID int
	
	EXECUTE @OLEResult = sp_OACreate 'Scripting.FileSystemObject', @FS OUT
	
	IF @OLEResult <> 0 
		SET @status= 'Error: Scripting.FileSystemObject'
	
	--Open a file
	execute @OLEResult = sp_OAMethod @FS, 'OpenTextFile', @FileID OUT,@FileName, 8, 1
	
	IF @OLEResult <>0 
		SET @status ='Error: OpenTextFile'
	
	--Write Text
	execute @OLEResult = sp_OAMethod @FileID, 'WriteLine', Null, @Text1
	IF @OLEResult <> 0 
		SET @status= 'Error : WriteLine'
	
	EXECUTE @OLEResult = sp_OADestroy @FileID
	EXECUTE @OLEResult = sp_OADestroy @FS
	RETURN @status
END
GO
--=========================================================================================================


/*
	@CPATH - the path to the clustered index datafiles
	@NCPATH - the path to the nonclustered index datafiles
	@numcfiles - how many files in the Cindex file group
	@numncfiles - how many files in the NCindex file group
	@startsize - the size the data files start at
	@maxsize - the maximum size of the datafiles
	@growthsize - how many megabytes the file grows in.
*/

--EXECUTE DBA_MoveIndexes

ALTER Procedure DBA_MoveIndexes
@NCPATH varchar(100), 
@startsize int=1000, 
@maxsize int = 210000, 
@growthsize int = 1500,
@dbname sysname


AS  
  
 declare @objid int,   -- the object id of the table    
   @indid smallint, -- the index id of an index    
   @groupid smallint,  -- the filegroup id of an index    
   @indname sysname,    
   @groupname sysname,    
   @status int,    
   @keys nvarchar(2126), --Length (16*max_identifierLength)+(15x2)+(16x3)    
   @OBJNAME nvarchar(776),  
   @FILLFACT TINYINT,  
   @ISQL VARCHAR(5000),  
   @kill int,  
   @counter int  
     
set @counter = 1  

--SET DATABASE NAME AS CURRENT DATABASE NAME IF ONE IS NOT SUPPLIED
If @dbname is null
	Begin
		set @dbname = (select name from master..sysdatabases d, master..sysprocesses p where spid = @@spid and d.dbid = p.dbid )  
	End


--CREATE AND EXECUTE KILL LOOP FOR KILLING ALL CONNECTIONS TO THE DATABASE IN QUESTION
BEGIN
 SELECT SPID INTO #TMPSPID FROM MASTER..SYSPROCESSES 
					INNER JOIN master..SYSDATABASES ON master..SYSPROCESSES.DBID = master..SYSDATABASES.DBID
					WHERE SPID > 49 AND SPID <> @@SPID AND master..SYSDATABASES.NAME = @DBNAME
	
	While @counter <= (SELECT COUNT(SPID) FROM MASTER..SYSPROCESSES 
						INNER JOIN master..SYSDATABASES ON master..SYSPROCESSES.DBID = master..SYSDATABASES.DBID
						WHERE SPID > 49 AND SPID <> @@SPID AND master..SYSDATABASES.NAME = @DBNAME)
	BEGIN
		SELECT @KILL = MIN(SPID) FROM #TMPSPID
		SET @ISQL = 'kill '+convert(varchar(5),@kill)  
		EXEC (@ISQL)  
		SET @counter = @counter +1
		DELETE FROM #TMPSPID WHERE SPID = @Kill
	END

END


--ALTER DATABASE STATEMENTS AND ERROR CHECKING
--		SELECT @ISQL= 'IF NOT EXISTS (SELECT * FROM '+@DBNAME+'..Sysfilegroups Where Name = ''NCINDEX'')'
--		EXEC (@ISQL)
--		PRINT ' FileGroup Does Not Exist, will now create'
				BEGIN
						set @ISQL = 'ALTER DATABASE '+@dbname+ ' ADD FILEGROUP NCINDEX'  
						exec (@ISQL)  
						print @ISQL+' File Group NCINDEX Has been Created'  
				END

--		SELECT @ISQL= 'IF NOT EXISTS (SELECT * FROM '+@DBNAME+'..Sysfiles Where Name like ''%NCINDEX%'')'
--		EXEC (@ISQL)
--		PRINT ' File Does Not Exist, will now create'

				BEGIN

						set @ISQL = 'ALTER DATABASE '+@dbname+ ' ADD File (Name = NCINDEXData'+@dbname+',		
									FILENAME = ' + '"' + @NCPATH +'NCINDEXData'+@dbname+'.ndf'+'"'+',  
									SIZE = '+convert(varchar(5),@startsize) + 'MB, MAXSIZE = '+convert(varchar(10),@maxsize)+'MB, 
									FILEGROWTH = '+convert(varchar(10),@growthsize)+'MB) TO FILEGROUP NCINDEX'  
						exec (@ISQL)  
						print @ISQL+' File NCINDEXDATA'+convert(varchar(2), @counter)+' has been created'  
				END




--LOOP TO GO THROUGH TABLES AND GRAB THEIR INDEXES
DECLARE TCURSOR CURSOR FOR SELECT NAME FROM SYSOBJECTS WHERE TYPE = 'U' ORDER BY NAME ASC  
OPEN TCURSOR  
FETCH NEXT FROM TCURSOR INTO @OBJNAME  
WHILE @@FETCH_STATUS = 0  
BEGIN  
   
   select @objid = object_id(@OBJNAME)    
   

	create table #spindtab    
     (    
     index_name   sysname collate database_default NOT NULL,    
     stats    int,    
     groupname   sysname collate database_default NOT NULL,    
     index_keys   nvarchar(2126) collate database_default NOT NULL, -- see @keys above for length descr    
     FILLFACT TINYINT  
     )    
  

declare ms_crs_ind cursor local static for (select indid, groupid, name, status, ORIGFILLFACTOR 
		from sysindexes where id = object_id(@OBJNAME) and indid > 0 and indid < 255 and (status & 64)= 0)


 
	open ms_crs_ind    
		fetch ms_crs_ind into @indid, @groupid, @indname, @status, @FILLFACT  
    
				 while @@fetch_status >= 0    
				 begin    
				  declare @i int, 
						  @thiskey nvarchar(131) -- 128+3    
				    
							select @keys = index_col(@OBJNAME, @indid, 1), @i = 2    
							  if (indexkey_property(@objid, @indid, 1, 'isdescending') = 1)    
								   select @keys = @keys  + '(-)'    
				    
							select @thiskey = index_col(@OBJNAME, @indid, @i)    
								if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))    
									select @thiskey = @thiskey + '(-)'    
				    
								  while (@thiskey is not null )    
										begin    
										   select @keys = @keys + ', ' + @thiskey, @i = @i + 1    
										   select @thiskey = index_col(@OBJNAME, @indid, @i)    
										   if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))    
											select @thiskey = @thiskey + '(-)'    
										end    
    
					
		select @groupname = groupname 
		from sysfilegroups 
		where groupid = @groupid    
    
		insert into #spindtab 
		values (@indname, @status, @groupname, @keys, @FILLFACT)    

    
  -- Next index    
		fetch ms_crs_ind into @indid, @groupid, @indname, @status, @FILLFACT    
 end    
CLOSE ms_crs_ind 
deallocate ms_crs_ind    

    
 -- SET UP SOME CONSTANT VALUES FOR OUTPUT QUERY    
 declare @empty varchar(1) select @empty = ''    
-- 35 matches spt_values     
declare 
@des1   varchar(35), 
@des2   varchar(35),
@des4   varchar(35), 
@des32 varchar(35),
@des64   varchar(35),
@des2048  varchar(35),
@des4096  varchar(35),
@des8388608  varchar(35),
@des16777216 varchar(35)    

	select @des1 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 1    
	 select @des2 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 2    
	 select @des4 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 4    
	 select @des32 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 32    
	 select @des64 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 64    
	 select @des2048 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 2048    
	 select @des4096 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 4096    
	 select @des8388608 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 8388608    
	 select @des16777216 = name from master.dbo.spt_values 
			where type = 'I' 
			and number = 16777216    
    
 -- DISPLAY THE RESULTS    
declare @tcount int  
	set @tcount = (select count(name) from sysobjects where type = 'U' and name > @OBJNAME)  


--GET DOWN TO BUSINESS
	Set @ISQL = ''	
	PRINT 'Recreating Indexes for Table ' + @OBJNAME + '.  ' + convert(varchar(5),@tcount) + ' Tables Remaining!'  


--ISSUE CREATE INDEX STATEMENTS WITH DROP EXISTING
DECLARE @INAME VARCHAR(100)  
DECLARE ICURSOR CURSOR FOR SELECT INDEX_NAME FROM #SPINDTAB ORDER BY INDEX_NAME   
		OPEN ICURSOR  
				FETCH NEXT FROM ICURSOR INTO @INAME  
						WHILE @@FETCH_STATUS = 0   

							BEGIN  
							( select @ISQL= 'Create  ' + case when (stats & 2)<>0 
													then @des2 + '  ' 
													else @empty 
													END +  
								
												 case when (stats & 16)=0 	
													then ' INDEX ' 	
													end 

							+ index_name + ' ON ' + @OBJNAME + ' ('+index_keys +') WITH '+  

												CASE WHEN FILLFACT = 0 
													THEN ' DROP_EXISTING' 
													ELSE ' FILLFACTOR = '+CONVERT(CHAR(2),FILLFACT)+',DROP_EXISTING' 
													END 
							+' ON '+ 	
												case when (stats & 16)=0	
													then ' [NCINDEX]' 
													end

							 from #spindtab  WHERE INDEX_NAME = @INAME)  



				  
				EXEC (@ISQL)  
			FETCH NEXT FROM ICURSOR INTO @INAME  
		END  
		CLOSE ICURSOR  
DEALLOCATE ICURSOR  


DROP TABLE #spindtab  
FETCH NEXT FROM TCURSOR INTO @OBJNAME  
END  
CLOSE TCURSOR  
DEALLOCATE TCURSOR  


--Write Completion Report to File
DECLARE 
	@FILE VARCHAR(30),
	@DriveLetter varchar(3)
  
SET @DriveLetter = SubString(@NCPATH,1,3)
SELECT @File = '"'+@Driveletter+'Index Move Output.txt"'
SET @ISQL = 'Indexes for Database '+@dbname+' have been moved'

exec UFN_TextFileOutput @file, @ISQL --'"'+@Driveletter+'Index Move Output.txt"',  'Indexes for Database '+@dbname+' have been moved'
