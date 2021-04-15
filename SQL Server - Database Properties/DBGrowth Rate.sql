--PART 1
If exists (Select name from sys.objects where name = 'DBGrowthRate' and Type = 'U')
  Drop Table dbo.DBGrowthRate

Create Table dbo.DBGrowthRate (DBGrowthID int identity(1,1), DBName varchar(100), DBID int,
NumPages int, OrigSize decimal(10,2), CurSize decimal(10,2), GrowthAmt varchar(100), 
MetricDate datetime)

Select sd.name as DBName, mf.name as FileName, mf.database_id, file_id, size
into #TempDBSize
from sys.databases sd
join sys.master_files mf
on sd.database_ID = mf.database_ID
Order by mf.database_id, sd.name

Insert into dbo.DBGrowthRate (DBName, DBID, NumPages, OrigSize, CurSize, GrowthAmt, MetricDate)
(Select tds.DBName, tds.database_ID, Sum(tds.Size) as NumPages, 
Convert(decimal(10,2),(((Sum(Convert(decimal(10,2),tds.Size)) * 8000)/1024)/1024)) as OrigSize,
Convert(decimal(10,2),(((Sum(Convert(decimal(10,2),tds.Size)) * 8000)/1024)/1024)) as CurSize,
'0.00 MB' as GrowthAmt, GetDate() as MetricDate
from #TempDBSize tds
where tds.database_ID not in (Select Distinct DBID from DBGrowthRate 
									where DBName = tds.database_ID)
Group by tds.database_ID, tds.DBName)

Drop table #TempDBSize

Select *
from DBGrowthRate
--Above creates initial table and checks initial data

--PART 2
--Below is the code run weekly to check the growth.
Select sd.name as DBName, mf.name as FileName, mf.database_id, file_id, size
into #TempDBSize2
from sys.databases sd
join sys.master_files mf
on sd.database_ID = mf.database_ID
Order by mf.database_id, sd.name

If Exists (Select Distinct DBName from #TempDBSize2 
				where DBName in (Select Distinct DBName from DBGrowthRate))
	and Convert(varchar(10),GetDate(),101) > (Select Distinct Convert(varchar(10),Max(MetricDate),101) as MetricDate 
																				from DBGrowthRate)
  Begin
		Insert into dbo.DBGrowthRate (DBName, DBID, NumPages, OrigSize, CurSize, GrowthAmt, MetricDate)
		(Select tds.DBName, tds.database_ID, Sum(tds.Size) as NumPages, 
		dgr.CurSize as OrigSize,
		Convert(decimal(10,2),(((Sum(Convert(decimal(10,2),tds.Size)) * 8000)/1024)/1024)) as CurSize,
		Convert(varchar(100),(Convert(decimal(10,2),(((Sum(Convert(decimal(10,2),tds.Size)) * 8000)/1024)/1024)) 
					- dgr.CurSize)) + ' MB' as GrowthAmt, GetDate() as MetricDate
		from #TempDBSize2 tds
		join DBGrowthRate dgr
		on tds.database_ID = dgr.DBID
		Where DBGrowthID = (Select Distinct Max(DBGrowthID) from DBGrowthRate
														where DBID = dgr.DBID)
		Group by tds.database_ID, tds.DBName, dgr.CurSize)
  End
 Else
   IF Not Exists (Select Distinct DBName from #TempDBSize2 
				where DBName in (Select Distinct DBName from DBGrowthRate))
		Begin
			Insert into dbo.DBGrowthRate (DBName, DBID, NumPages, OrigSize, CurSize, GrowthAmt, MetricDate)
			(Select tds.DBName, tds.database_ID, Sum(tds.Size) as NumPages, 
			Convert(decimal(10,2),(((Sum(Convert(decimal(10,2),tds.Size)) * 8000)/1024)/1024)) as OrigSize,
			Convert(decimal(10,2),(((Sum(Convert(decimal(10,2),tds.Size)) * 8000)/1024)/1024)) as CurSize,
			'0.00 MB' as GrowthAmt, GetDate() as MetricDate
			from #TempDBSize2 tds
			where tds.database_ID not in (Select Distinct DBID from DBGrowthRate 
															where DBName = tds.database_ID)
			Group by tds.database_ID, tds.DBName)
		End

--Select *
--from DBGrowthRate
----Verifies values were entered

Drop table #TempDBSize2