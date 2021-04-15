/*
Data Paging

Makes a paged query with the sql parameters to build it and page parameters to filter.
Add "No","CurrentPage","TotalPages" columns to the query to manage paging at user interface.
The query Lose the identity column order.
*/

/*
----------------------------------------------------
Samples:
EXEC spDataPaging 'Orders','OrderID,CustomerID','OrderID > 10258','','',15,30
EXEC spDataPaging 'Orders','COUNT(OrderID)OrdersCount ,CustomerId','','CustomerID','CustomerID',2,30
EXEC spDataPaging 'Customers','*','','','',2,30
----------------------------------------------------
*/

ALTER PROC spDataPaging
	@TableOrView	VARCHAR(128),
	@Columns	VARCHAR(1000) = '*',
	@Where		VARCHAR(1000) = '',
	@GroupBy	VARCHAR(1000) = '',
	@OrderBy	VARCHAR(1000) = '',
	@Page		INTEGER = 1,
	@PageSize	INTEGER = 30
	
AS
DECLARE @TableTemp	VARCHAR(100),
	@IdentityName  	VARCHAR(50),
	@IdentityType  	VARCHAR(20),
	@SQLScript	VARCHAR(5000),
	@Criteria	VARCHAR(3000)

SET NOCOUNT ON

SET @Columns = REPLACE(@Columns,' ','')
IF @Where != ''   SET @Where = ' WHERE ' + @Where
IF @GroupBy != '' SET @GroupBy = ' GROUP BY ' + @GroupBy
IF @OrderBy != '' SET @OrderBy = ' ORDER BY ' + @OrderBy

SET @Criteria = @Where + @GroupBy + @OrderBy

SET  @TableTemp = '#' + @TableOrView

SELECT @IdentityName = b.name,@IdentityType = c.DATA_TYPE
FROM sysobjects a, syscolumns b,Information_Schema.COLUMNS c
WHERE a.id = b.id
AND a.name = @TableOrView
AND c.TABLE_NAME = a.name
AND c.COLUMN_NAME = b.name
AND c.TABLE_CATALOG = DB_NAME()
AND b.status = 128

IF 	@IdentityName IS NOT NULL
	AND ((LEN(@Columns) != LEN(REPLACE(@Columns,@IdentityName,'')))OR @Columns = '*')
	AND ((LEN(@Columns) = LEN(REPLACE(@Columns,'(' + @IdentityName + ')',''))) OR @Columns = '*')
 BEGIN
	SELECT @SQLScript = 	' SELECT ' + @Columns  + ',CAST('  + @IdentityName +  ' AS ' + @IdentityType + ') Num INTO ' + @TableTemp + ' FROM ' + @TableOrView + @Criteria +
				' ALTER TABLE ' + @TableTemp + ' DROP COLUMN '  + @IdentityName + 
				' ALTER TABLE ' + @TableTemp + ' ADD No ' + @IdentityType + ' IDENTITY' + 
				' SELECT * INTO ' + @TableTemp +  '2 FROM ' + @TableTemp +
				' SELECT *,CAST(Num AS ' + @IdentityType + ') ' + @IdentityName + ' INTO ' + @TableTemp + '3 FROM ' + @TableTemp + '2 WHERE (No BETWEEN ' + CAST((@Page * @PageSize - @PageSize + 1) AS VARCHAR(20)) + ' AND ' + CAST((@Page * @PageSize) AS VARCHAR(20)) + ')' +
				' ALTER TABLE ' + @TableTemp + '3 DROP COLUMN Num' + 
				' SELECT *,' + CAST(@Page AS VARCHAR(20)) + ' CurrentPage,CEILING((SELECT COUNT(*) FROM ' + @TableTemp + '2)/' + CAST(@PageSize AS VARCHAR(20)) + ' + 1) TotalPages FROM ' +  @TableTemp + '3'
 END
ELSE
 BEGIN
	SELECT @SQLScript = 	' SELECT ' + @Columns  + ' INTO ' + @TableTemp + ' FROM ' + @TableOrView + @Criteria +
				' ALTER TABLE ' + @TableTemp + ' ADD No INT IDENTITY' + 
				' SELECT * INTO ' + @TableTemp +  '2 FROM ' + @TableTemp +
				' SELECT * INTO ' + @TableTemp + '3 FROM ' + @TableTemp + '2 WHERE (No BETWEEN ' + CAST((@Page * @PageSize - @PageSize + 1) AS VARCHAR(20)) + ' AND ' + CAST((@Page * @PageSize) AS VARCHAR(20)) + ')' +
				' SELECT *,' + CAST(@Page AS VARCHAR(20)) + ' CurrentPage,CEILING((SELECT COUNT(*) FROM ' + @TableTemp + '2)/' + CAST(@PageSize AS VARCHAR(20)) + ' + 1) TotalPages FROM ' +  @TableTemp + '3'
 END

EXEC(@SQLScript)
