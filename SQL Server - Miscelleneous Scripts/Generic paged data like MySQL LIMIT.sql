/*
    
Generic paged data like MySQL LIMIT

This works, however code is creating a live temp_1 table in the database instead of using a #temp_1 temporary table because is just would not work.

The next idea I had was to use a unique table name per connection for temp_1, but I would really rather use temporary tables.

I am hoping some SQL guru's can suggest some improvements to this script.
 
*/

CREATE PROCEDURE mp_paged_data 
	@sql nvarchar(2000),
	@start_row int = 1,
	@row_limit int = 10,
	@total_rows int = 0 OUTPUT
AS

-- This works, however code is creating a live temp_1 table in the database 
-- instead of using a #temp_1 temporary table because is just would not work
-- Better solution maybe to get data into a cursor and loop through it until 
-- desired page of records is found

SET NOCOUNT ON

-- Run SQL passed as parameter and place in temp table
SET @sql = REPLACE(@sql,'FROM ' , 'INTO temp_1 FROM ')
EXECUTE(@sql)
--PRINT @sql

SET @total_rows = @@ROWCOUNT

-- Add column to determine row numbers
ALTER TABLE temp_1
ADD row_num int IDENTITY  NOT NULL UNIQUE

-- Copy into intermediate table
-- as row_num was not recognised as a valid column
-- for a WHERE clause from the first temp table
SELECT * 
INTO #temp_2
FROM temp_1

-- Delete temp table from memory
DROP TABLE temp_1

-- Select desired page based on 
-- StartRow and NumRows
SET ROWCOUNT @row_limit
SELECT * FROM #temp_2
WHERE row_num >= @start_row
ORDER BY row_num

-- Delete temp table from memory
DROP TABLE #temp_2
GO

