/*
Get Table Sizes and Percent of Database Size

This script uses two undocumented stored procedures that retrieve all tables in the database in which it is run and lists the data and index sizes, the sum of these sizes, and the table's size percentage of the entire database. 

The results are presented in descending order of the sum of the data and index size.

Simply run this in Query Analyzer in the database you want to query. 

*/

-- Create the temp table for further querying
CREATE TABLE #temp(
	rec_id		int IDENTITY (1, 1),
	table_name	varchar(128),
	nbr_of_rows	int,
	data_space	decimal(15,2),
	index_space	decimal(15,2),
	total_size	decimal(15,2),
	percent_of_db	decimal(15,12),
	db_size		decimal(15,2))

-- Get all tables, names, and sizes
EXEC sp_msforeachtable @command1="insert into #temp(nbr_of_rows, data_space, index_space) exec sp_mstablespace '?'",
			@command2="update #temp set table_name = '?' where rec_id = (select max(rec_id) from #temp)"

-- Set the total_size and total database size fields
UPDATE #temp
SET total_size = (data_space + index_space), db_size = (SELECT SUM(data_space + index_space) FROM #temp)

-- Set the percent of the total database size
UPDATE #temp
SET percent_of_db = (total_size/db_size) * 100

-- Get the data
SELECT *
FROM #temp
ORDER BY total_size DESC

-- Comment out the following line if you want to do further querying
DROP TABLE #temp
