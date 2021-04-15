/*

When the last time Database used 

This Procedure will display info regard to when the last time database was used. 

How to use it
--------------
Exec master.dbo.Sp_LastTimeDBUsed 'pubs'


*/

Use master
Go
Create  Procedure Sp_LastTimeDBUsed 
@DBName sysname
As

Declare @DBFile nvarchar(260)
declare @i int
Declare @k int 

CREATE  TABLE #ATTRIBS (
 alternate_name  VARCHAR(128),
 [size]   INT,
 creation_date  INT,
 creation_time  INT,
 last_written_date INT,
 last_written_time INT,
 last_accessed_date INT,
 last_accessed_time INT,
 attributes  INT)

Declare @FName Table ( FID smallint IDENTITY(1,1), DBFile nvarchar(260))

set nocount on

Insert  @FName (DBFile) Select filename  from master.dbo.sysaltfiles 
where dbid = (select  dbid from master.dbo.sysdatabases where name = @DBName)

Set @k = @@IDENTITY
set @DBFile = ''
set @i = 1 

While  @k +1 > @i
   Begin
      Select @DBFile = RTrim(DBFile) from @FName where FID = @i

      INSERT INTO #ATTRIBS EXEC master.dbo.xp_getfiledetails @DBFile

      Set @i = @i + 1 
   End

Select @DBName + ' last time used on ' +  cast(cast(cast(max(last_accessed_date) as varchar(20)) as datetime) as varchar(12)) from #ATTRIBS


