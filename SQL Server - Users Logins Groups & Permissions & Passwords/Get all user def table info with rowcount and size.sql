CREATE TABLE #temp 
(TableName NVARCHAR (128)
, RowsCnt VARCHAR (11)
, ReservedSpace VARCHAR(18)
, DataSpace VARCHAR(18)
, CombinedIndexSpace VARCHAR(18)
, UnusedSpace VARCHAR(18)
)

EXEC sp_MSforeachtable 'INSERT INTO #temp 
(TableName
, RowsCnt
, ReservedSpace
, DataSpace
, CombinedIndexSpace
, UnusedSpace
) 
EXEC sp_spaceused ''?'', FALSE'

SELECT TableName
, RowsCnt
, ReservedSpace
, DataSpace
, CombinedIndexSpace
, UnusedSpace 

FROM #temp
ORDER BY TableName
DROP TABLE #temp
