--================================
/* you'll need a couple of views */
--================================

USE testsa
GO

--================================
/* here's a view for extended properties */
--================================
CREATE VIEW dbo.vis_properties
AS

/* This part shows 'Column Level' properties */
SELECT
convert(varchar(80), o.name) AS table_name,
convert(varchar(80), c.name) AS column_name, 
convert(varchar(80), p.name) AS property_name,
convert(varchar(80), p.[value]) AS property_value
FROM    dbo.sysobjects o
	INNER JOIN dbo.syscolumns c ON c.id = o.id
	INNER JOIN dbo.sysproperties p ON p.id = c.id AND p.smallid = c.colid

UNION ALL

/* This next part shows the 'Table Level' properties */
SELECT
convert(varchar(80), o.name) AS table_name,
'' AS column_name,
convert(varchar(80), p.name) AS property_name,
convert(varchar(80), p.[value]) AS property_value
FROM	dbo.sysobjects o
	INNER JOIN dbo.sysproperties p on p.id = o.id 
WHERE p.smallid=0

GO

--================================
/* here's a view for all columns 
   if you use other data_types you'll need to play with it a little.
*/
--================================
CREATE VIEW vis_columns
as
SELECT 
TABLE_CATALOG, 
TABLE_SCHEMA, 
TABLE_NAME, 
COLUMN_NAME, 
ORDINAL_POSITION, 
COLUMN_DEFAULT, 
IS_NULLABLE, 
data_type+ case data_type 
	when 'INT' then '' 
	when 'Decimal' then '('+cast(numeric_precision as varchar)+', '+cast(numeric_scale as varchar)+')'
	when 'tinyint' then '' when 'Smallint' then '' 
	when 'Bigint' then '' 
	when 'Bit' then '' 
	when 'Money' then '('+cast(numeric_precision as varchar)+', '+cast(numeric_scale as varchar)+')'
	when 'Float' then '('+cast(numeric_precision as varchar)+', '+cast(numeric_scale as varchar)+')'
	when 'sql_variant' then ''
	when 'smalldatetime' then ''
	when 'Binary' then ''
	when 'Varbinary' then ''
	when 'Image' then ''
	when 'Real' then ''
	when 'Ntext' then ''
	when 'Numeric' then '('+cast(numeric_precision as varchar)+', '+cast(numeric_scale as varchar)+')'
	when 'Datetime' then ''
	when 'Text' then '' else '('+cast(character_maximum_length as varchar)+')' end as CONDENSED_DATATYPE,
DATA_TYPE, 
CHARACTER_MAXIMUM_LENGTH, 
CHARACTER_OCTET_LENGTH, 
NUMERIC_PRECISION, 
NUMERIC_PRECISION_RADIX, 
NUMERIC_SCALE, 
DATETIME_PRECISION, 
CHARACTER_SET_CATALOG, 
CHARACTER_SET_SCHEMA, 
CHARACTER_SET_NAME, 
COLLATION_CATALOG, 
COLLATION_SCHEMA, 
COLLATION_NAME, 
DOMAIN_CATALOG, 
DOMAIN_SCHEMA, 
DOMAIN_NAME
FROM INFORMATION_SCHEMA.COLUMNS

GO

-- =======================================
/* this scripts statements to drop/add existing table level extended properties */
-- =======================================
select
'exec sp_dropextendedproperty N'''+ property_name+ ''', N''user'', N''dbo'', N''table'', N'''+table_name+'''',
'exec sp_addextendedproperty N'''+ property_name+ ''', N'''+table_name+''', N''user'', N''dbo'', N''table'', N'''+table_name+''''
from vis_properties where column_name = ''
GO

-- =======================================
/* this scripts statements to drop/add existing column level extended properties */
-- =======================================
select 
'exec sp_dropextendedproperty '''+ property_name+ ''', ''user'', dbo, ''table'', '''+table_name+''', ''column'', '''+column_name+'''',
'exec sp_addextendedproperty N'''+ property_name+ ''', '''+ property_value+ ''', N''user'', N''dbo'', N''table'', N'''+table_name+''', N''column'', N'''+column_name+''''
from vis_properties where column_name <> ''
GO

--================================
/* Script to add a particular extended property called 'Required': */
--================================
select 'exec sp_addextendedproperty ''Required'', ''True'', ''user'', dbo, ''table'', ['+ table_name+'], '+ '''column'', ['+ column_name+ ']'
from vis_columns
where 
table_name+'.'+column_name not in (select table_name+'.'+column_name from vis_properties where property_name = 'Required')
/* you can specify table names, column names, etc too... obviously */
GO

/* this is the result */
exec sp_addextendedproperty 'Required', 'True', 'user', dbo, 'table', [Orders], 'column', [OrderID]
exec sp_addextendedproperty 'Required', 'True', 'user', dbo, 'table', [Orders], 'column', [CustomerID]
GO

--================================
/* this is how it looks */
--================================
select * from vis_properties

--================================
/* Here to drop a specific extended property. In this case 'Required' */
--================================
select 'exec sp_dropextendedproperty ''Required'', ''user'', dbo, ''table'', ['+ table_name+'], ''column'', ['+ column_name+ ']'
from vis_properties where property_name = 'Required'
order by table_name
GO

/* this is the result */
exec sp_dropextendedproperty 'Required', 'user', dbo, 'table', [Orders], 'column', [OrderID]
exec sp_dropextendedproperty 'Required', 'user', dbo, 'table', [Orders], 'column', [CustomerID]
GO
