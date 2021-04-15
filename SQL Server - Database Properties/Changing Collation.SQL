/*
Changing Collation 
There's only one parameter which is the collation that we want to change to.
If no collation is defined uses the default collation.
*/
------------------------------------------------------------
-- LM_ChangeCollation - Change collation in all tables
------------------------------------------------------------
CREATE PROCEDURE [LM_ChangeCollation]
@new_collation varchar(100)=NULL
 AS

DECLARE 
@table			varchar(50),
@column		        varchar(60),
@type			varchar(20),
@legth			varchar(4),
@nullable		varchar(8),
@sql			varchar(8000),
@msg			varchar(8000),
@servercollation	varchar(120)

select @servercollation = convert(sysname, serverproperty('collation'))

DECLARE C1 CURSOR FOR

select
	'Table'		= b.name,
	'Column'	= a.name,
	'Type'		= type_name(a.xusertype),
	'Length'	= a.length,
	'Nullable'	= case when a.isnullable = 0 then 'NOT NULL' else ' ' end
from syscolumns a, sysobjects b
where a.number = 0 
and a.id =b.id
and b.xtype='U'
and b.name not like 'dt%'
and type_name(a.xusertype) in ('char', 'varchar', 'text', 'nchar', 'nvarchar', 'ntext')
order by b.name,a.colid

OPEN C1
FETCH NEXT FROM C1
INTO 	@table,@column,@type,@legth,@nullable


WHILE @@FETCH_STATUS=0
BEGIN

IF @new_collation is null
set @new_collation=@servercollation

set @sql='ALTER TABLE ' + @table + ' ALTER COLUMN ' + @column + ' '
set @sql=@sql+ @type+'('+@legth+')'+' COLLATE '+@new_collation+' '+@nullable

EXEC (@sql)

FETCH NEXT FROM C1
INTO 	@table,@column,@type,@legth,@nullable

END
CLOSE C1
DEALLOCATE C1
GO

