/*
GetPage - paging functionality

All what you need to do is to set the values of a couple of variables; NAME OF the TABLE you want to query (or you can write your own select statement here), NAMES OF COLUMNS you want to display, name of COLUMN for SORTING, define NUMBER OF ROWS on one page, NUMBER OF REQUIRED PAGE and ASCENDING/DESCENDING flag for sorting of final output.

Name of the variable Description 
@table_name name of table (or view, or function, or definition of query) 
@col_names, default = * name of columns to be displayed 
@order_cols name of column to be used as sorting key 
@pg_number number of the page, you want to see 
@row_in_page number of rows on one page 
@asc_flag (0,1) default=0 ascending sorting flag 

examples of usage
--simple use

dbo.GetPage @table_name='sysobjects', @col_names='*',@order_cols='name',
@asc_flag='0',@row_in_page='2',@pg_number='1' 

-advanced use
if you want to create your own select (eg. join over more table or select containing where, group by etc. clause), still it is possible touse GetPage stored procedure to limit the result set according to your needs.

--if you want to use SELECT with  group by condition
dbo.GetPage '(select left(name,2) a1,count(name) a2 from sysobjects group by left(name,2)) as x','*','a1','1','3','4' 

*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


CREATE PROCEDURE dbo.GetPage
(
@table_name varchar(500), --name of table to be queried
@col_names varchar(500) ='*', --name of columns to be part of resultset, default = all columns
@order_cols varchar(500) ='-1', --name of columns to be sorted after, default=physicall order
@pg_number int, --number of page, to be returned
@row_in_page int, --number of rows in page
@asc_flag bit=0 --preferable sorting order, default is set to ASC
)
AS

declare @sql_str1 as varchar(2500)
declare @sql_str2 as varchar(2500)
declare @sql_str3 as varchar(2500)

set @Sql_str1='(select top '+cast(@pg_number*@row_in_page as varchar)+' '+@col_names+' from '+@table_name+' order by '+@order_cols+' ASC) as sql1'

set @Sql_str2='(select top '+cast(@row_in_page as varchar)+' '+@col_names+' from '+@sql_str1 + ' order by '+@order_cols+' DESC) as sql2'

set @Sql_str3='select top '+cast(@row_in_page as varchar)+' '+@col_names+' from '+@sql_str2+ ' order by '+@order_cols+' ASC'

if @asc_flag=1
begin
set @sql_str3=Replace(@sql_str3,'ASC) as sql','DESC) as sql')
set @sql_str3=Replace(@sql_str3,'DESC) as sql2','ASC) as sql2')
end

if @order_cols='-1' 
begin
set @sql_str3=Replace(@sql_str3, 'order by -1 DESC','')
set @sql_str3=Replace(@sql_str3, 'order by -1 ASC','')
end

--print @sql_str3
exec (@sql_str3)

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
