/*
Generate excel-html file

Generate an html-excel file with any table. Does not need Excel to generate , because does not use Excel automation 

*/

--Parameters :
--@vlogin : Is a user name.  This parameter is used to create a sub-folder
--   with the user name on the mail folder of the application.
--@vnombre_excel : Is the final name of the file (It must be passed without
--xls extension)
--@vdir_app : Is the folder on which the subfolder (@vlogin) will be created.
--@ctable : Is the name of the table to be converted in excel file.
--@vsession_id : Is a value that will be used to create the temporary tables,
--   and will be part of the excel name.

--Script
CREATE PROCEDURE pa_excel_simple
@vlogin varchar(200),
@vnombre_excel varchar(200),
@vdir_app varchar(2000),
@ctable varchar(200), 
@vsession_id varchar(10)

AS
SET NOCOUNT ON
set dateformat ymd

declare @param_debug varchar(5000)

declare @vfile_excel varchar(500)    --Nombre del archivo html
declare @temp_table varchar(200)   --Nombre de la tabla temporal
DECLARE @sql nvarchar(4000)
declare @sql_insert varchar(7000)
DECLARE @max int    --Nro. de Columnas
declare @recno int      --Puntero de cada fila
declare @max_filas int   --Numero de filas
declare @verror int

declare @i int   
declare @column int     --Subindice para recorrer las columnas de la tabla
declare @vcolumn_name varchar(200)    --Nombre de cada columna de la tabla
declare @vdata_type varchar(200)      --Tipo de cada columna de la tabla
declare @vchar_max_len int     --Longitud de cada columna de la tabla
declare @vnumeric_precision int    --Precision Decimal
declare @vnumeric_scale int        --Posiciones Decimales
declare @vstring_table varchar(5000)
declare @vstring_html varchar(5000)
declare @vcontenido_columna varchar(500)    --Contenido de las columnas que me interesan
declare @vcontenido_foraneo varchar(500)
declare @vrows_inserted int   --Numero de filas insertadas

set @vfile_excel = rtrim(@vdir_app)+'\' + rtrim(@vlogin) + '\' +rtrim(@vnombre_excel)+rtrim(@vsession_id) + '.xls'
set @temp_table = '##'+rtrim(@ctable)+rtrim(@vsession_id)

-- A continuacion, obtiene el NUMERO de columnas de la tabla
set @sql = N'SELECT @MAX = max(ordinal_position) FROM information_schema.columns WITH (NOLOCK) where table_name = '''+@ctable+''''
EXEC sp_executesql @sql, N'@max int OUTPUT', @max OUTPUT
if @@error <> 0
   return -21

-- A continuacion, arma el string para  crear la tabla temporal, que sera una fiel copia de la
-- tabla fuente
set @vstring_table = 'recno int identity primary key, '
set @sql_insert = ''
set @i = 1

while (@i <= @max)
   begin
      set @sql = 'select @vcolumn_name = lower(column_name), @vdata_type = lower(data_type), @vchar_max_len = character_maximum_length, @vnumeric_precision = numeric_precision, @vnumeric_scale = numeric_scale from information_schema.columns WITH (NOLOCK) where table_name = '''+@ctable+''' and ordinal_position = ' + convert(varchar(5), @i)
      EXEC sp_executesql @sql, N'@vcolumn_name varchar(200) OUTPUT, @vdata_type varchar(200) OUTPUT, @vchar_max_len int OUTPUT, @vnumeric_precision int output, @vnumeric_scale int output', @vcolumn_name OUTPUT, @vdata_type output, @vchar_max_len OUTPUT, @vnumeric_precision output, @vnumeric_scale output
      if @@error <> 0
         return -22

      set @vstring_table = @vstring_table + rtrim(@vcolumn_name) + ' ' + rtrim(@vdata_type)
      set @sql_insert = @sql_insert + rtrim(@vcolumn_name)
      if @vdata_type = 'char' or @vdata_type = 'varchar'
         begin
            set @vstring_table = @vstring_table + '('+convert(varchar(100), @vchar_max_len)+')'
         end

      if @vdata_type = 'decimal' 
         begin
            set @vstring_table = @vstring_table + '(' + convert(varchar(100), @vnumeric_precision) + ',' + convert(varchar(100), @vnumeric_scale) + ' )'
         end         
         
      if @i < @max
         begin
            set @vstring_table = @vstring_table + ','
   set @sql_insert = @sql_insert + ','
         end

      set @i = @i + 1
   end

-- lo que hace A continuacion, es para saber si la tabla temporal YA ha sido creada en tempdb
set @max = 0
set @sql = N'SELECT @MAX = max(ordinal_position) FROM tempdb.information_schema.columns WITH (NOLOCK) where table_name = '''+@temp_table + ''''
EXEC sp_executesql @sql, N'@max int OUTPUT', @max OUTPUT

if @max <> 0
begin

   -- Borra las 2 tablas temporales de la base de datos tempdb
   -- Si NO existen, almacena 0 (ZERO) en una variable, y... todo bien todo bien ... NO pasa nada !!!

   set @sql = 'drop table '+@temp_table
   exec(@sql)
   if @@error <> 0
      set @verror = 0
end

-- lo que hace A continuacion, es para saber si la tabla temporal YA ha sido creada en tempdb
set @max = 0
set @sql = N'SELECT @MAX = max(ordinal_position) FROM tempdb.information_schema.columns WITH (NOLOCK) where table_name = '''+@temp_table + '2'''
EXEC sp_executesql @sql, N'@max int OUTPUT', @max OUTPUT

if @max <> 0
begin

   -- Borra las 2 tablas temporales de la base de datos tempdb
   -- Si NO existen, almacena 0 (ZERO) en una variable, y... todo bien todo bien ... NO pasa nada !!!
   
   set @sql = 'drop table '+rtrim(@temp_table)+'2'
   exec(@sql)
   if @@error <> 0
      set @verror = 0
end

--Crea la tabla Temporal primaria
set @sql = 'create table '+@temp_table+' ('+@vstring_table+')'

exec(@sql)

-- Verifica si hubo error al crear la tabla temporal
if @@error <> 0
   return -10

-- A continuacion, inserta los registros desde la tabla fuente, a la tabla Temporal
set @sql = 'insert into '+@temp_table + ' (' + rtrim(@sql_insert) + ')' + ' select ' + @sql_insert + ' from ' + @ctable + ' WITH (NOLOCK)'
exec(@sql)

if @@error <> 0
   return -11

-- Ya se tiene el cursor armado.  (Tabla temporal global UNICA por Usuario)
-- A continuacion, se debe recorrer de arriba a abajo, y de izquierda a derecha pasando
-- por cada una de sus columnas, para ir generando el contenido del archivo html
--

-- A continuacion, crea la tabla temporal que contendra el campo texto, y que servira
-- de fuente final al archivo html

set @sql = 'create table '+rtrim(@temp_table)+'2 (recno int, string_html VARCHAR(7000))'
-- set @sql = 'create table '+rtrim(@temp_table)+'2 (string_html varchar(7000))'
exec(@sql)
-- Verifica si hubo error al crear la tabla temporal de texto
if @@error <> 0
   return -13
   
set @sql = 'create clustered index recno_'+rtrim(@temp_table)+'2 on '+rtrim(@temp_table)+'2 (recno)'
exec(@sql)
-- Verifica si hubo error al crear el indice de la tabla temporal de texto
if @@error <> 0
   return -13

-- A continuacion, obtiene el NUMERO de columnas de la tabla temporal
set @sql = N'SELECT @MAX = max(ordinal_position) FROM tempdb.information_schema.columns WITH (NOLOCK) where table_name = '''+@temp_table + ''''
EXEC sp_executesql @sql, N'@max int OUTPUT', @max OUTPUT
if @@error <> 0
   return -14

-- A continuacion, obtiene el numero de filas de la tabla temporal
set @sql = N'SELECT @MAX_FILAS = max(recno) FROM ' + @temp_table + ' WITH (NOLOCK)'
EXEC sp_executesql @sql, N'@max_filas int OUTPUT', @max_filas OUTPUT
if @@error <> 0
   return -15

set @vstring_html = ''

set @vstring_html = @vstring_html + '<table width="100%" border="0" >'+CHAR(13)

-- Fila de encabezado del archivo excel
set @vstring_html = @vstring_html + '<tr>'+CHAR(13)
set @vstring_html = @vstring_html + '<td colspan = "2">'+CHAR(13)
set @vstring_html = @vstring_html + '<div style="text-align: justify; color = #000000; " >'+CHAR(13)
set @vstring_html = @vstring_html + '<b> MONEXT - ' + @vnombre_excel + ' </b>'+CHAR(13)
set @vstring_html = @vstring_html + '</div>'+CHAR(13)
set @vstring_html = @vstring_html + '</td>'+CHAR(13)
set @vstring_html = @vstring_html + '</tr>'+CHAR(13)

set @vstring_html = @vstring_html + '</table>'+CHAR(13)

set @vstring_html = @vstring_html + '<table width="100%" border="1" bordercolor="#000000">'+CHAR(13)

set @vstring_html = @vstring_html + '<tr>'+CHAR(13)

set @vrows_inserted = 1

set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) +''', ''' + @vstring_html + ''')'
exec(@sql)
if @@error <> 0
   return -16

set @vrows_inserted = @vrows_inserted + 1

set @vstring_html = ''

   -- A continuacion, recorre el registro de izquierda a derecha para generar los nombres de columnas

   set @column = 2    --Inicia en la columna 2, porque la 1 es IDENTITY
   while (@column <= @max)
      begin
         set @sql = 'select @vcolumn_name = lower(column_name), @vdata_type = lower(data_type), @vchar_max_len = character_maximum_length  from tempdb.information_schema.columns WITH (NOLOCK) where table_name = '''+@temp_table+''' and ordinal_position = ' + convert(varchar(5), @column) 
         EXEC sp_executesql @sql, N'@vcolumn_name varchar(200) OUTPUT, @vdata_type varchar(200) OUTPUT, @vchar_max_len int OUTPUT', @vcolumn_name OUTPUT, @vdata_type output, @vchar_max_len OUTPUT
         if @@error <> 0
            return -17

         set @vstring_html = @vstring_html + '<th>'+CHAR(13)
         set @vstring_html = @vstring_html + '<b>'+LOWER(@vcolumn_name)+'</b>'+CHAR(13)
         set @vstring_html = @vstring_html + '</th>'+CHAR(13)
         
         set @column = @column + 1
      end    --   del while (@column <= @max)

      set @vstring_html = @vstring_html + '</tr>'+CHAR(13)

      set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) +''', '''+@vstring_html + ''')'
      exec(@sql)
      if @@error <> 0
         return -18
	  
	  set @vrows_inserted = @vrows_inserted + 1

      set @vstring_html = ''

-- A continuacion, recorre el cursor de arriba a abajo
set @recno = 1
while (@recno <= @max_filas)
   begin

   -- Inicio de Linea
   set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) +''', ''<tr>'')'
   exec(@sql)
   if @@error <> 0
      return -23
   
   set @vrows_inserted = @vrows_inserted + 1

   -- A continuacion, recorre el registro de izquierda a derecha
   set @column = 2   --Inicia en la columna 2, porque la 1 es IDENTITY
   while (@column <= @max)
      begin
         set @sql = 'select @vcolumn_name = lower(column_name), @vdata_type = lower(data_type), @vchar_max_len = character_maximum_length  from tempdb.information_schema.columns WITH (NOLOCK) where table_name = '''+@temp_table+''' and ordinal_position = ' + convert(varchar(5), @column)
         EXEC sp_executesql @sql, N'@vcolumn_name varchar(200) OUTPUT, @vdata_type varchar(200) OUTPUT, @vchar_max_len int OUTPUT', @vcolumn_name OUTPUT, @vdata_type output, @vchar_max_len OUTPUT
         if @@error <> 0
            return -19

         -- Inicio de Columna
		
         set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) +''', ''<td '
         --Aun NO cierra la etiqueta <td>
         
         set @vcolumn_name = lower(@vcolumn_name)
		
		set @sql = @sql + '>'' )'
         exec(@sql)
         if @@error <> 0
            return -24
		
         set @vrows_inserted = @vrows_inserted + 1

         -- Contenido de la Columna
         set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) select ''' + convert(varchar(10), @vrows_inserted) + ''', '
		
         if @vdata_type = 'float' or @vdata_type = 'int' or @vdata_type = 'money' or @vdata_type = 'real' or @vdata_type = 'numeric' or @vdata_type = 'decimal'
		begin
            set @sql = @sql + 'convert(varchar(40), convert(money, ' + @vcolumn_name + ') ,1) from '+rtrim(@temp_table) + ' WITH (NOLOCK) where recno = '+convert(varchar(10),@recno)
         end
		else
         begin
		    if @vdata_type = 'char' or @vdata_type = 'varchar'
			   begin
                  --set @sql = @sql + '''' + '''' + '''' + '''' + '+' + @vcolumn_name +' from '+rtrim(@temp_table) + ' WITH (NOLOCK) where recno = '+convert(varchar(10),@recno)
                  set @sql = @sql + @vcolumn_name +' from '+rtrim(@temp_table) + ' WITH (NOLOCK) where recno = '+convert(varchar(10),@recno)                  
		end
			   
		    else
			   begin
		          set @sql = @sql + @vcolumn_name +' from '+rtrim(@temp_table) + ' WITH (NOLOCK) where recno = '+convert(varchar(10),@recno)  
               end			
         end
		
      --set @param_debug = @sql
         --exec pa_debug @param_debug
			
         exec(@sql)
         if @@error <> 0
            return -25
		
		set @vrows_inserted = @vrows_inserted + 1

         -- Fin de Columna
         set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) + ''', ''</td>'')'
         exec(@sql)
         if @@error <> 0
            return -26		
		set @vrows_inserted = @vrows_inserted + 1

   -- A continuacion, pongo el contenido de la columna en una variable para poder usarla como
   -- llave foranea para buscar campos en otras tablas

set @sql = 'select @vcontenido_columna = ' + @vcolumn_name + ' from '+rtrim(@temp_table) + ' WITH (NOLOCK) where recno = '+convert(varchar(10),@recno)  
         EXEC sp_executesql @sql, N'@vcontenido_columna varchar(200) OUTPUT ', @vcontenido_columna OUTPUT
         if @@error <> 0
           return -20

         if @vcolumn_name = 'region'
         begin
            set @vcontenido_foraneo = ''
            set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values ('''  + convert(varchar(10), @vrows_inserted) + ''', ''<td>'')'
            exec(@sql)
   if @@error <> 0
               return -30
			
			set @vrows_inserted = @vrows_inserted + 1
			
            select @vcontenido_foraneo = nombre from da_region WITH (NOLOCK) where codigo = rtrim(@vcontenido_columna) 
		
            set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values ('''  + convert(varchar(10), @vrows_inserted) + ''', ''' + @vcontenido_foraneo + ''')'
            exec(@sql)
            if @@error <> 0
               return -30
			
			set @vrows_inserted = @vrows_inserted + 1
			
          set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values ('''  + convert(varchar(10), @vrows_inserted) + ''', ''</td>'')'
            exec(@sql)
            if @@error <> 0
               return -30
			
			set @vrows_inserted = @vrows_inserted + 1
			
         end
        
         set @column = @column + 1
      end    --   del while (@column <= @max)

      -- Fin de linea
      set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) + ''', ''</tr>'')'
      exec(@sql)
      if @@error <> 0
         return -27
	  
	  set @vrows_inserted = @vrows_inserted + 1

      set @recno = @recno + 1

   end    -- del while (@recno <= @max_filas)   

   -- Fin de Tabla
   set @sql = 'insert into '+rtrim(@temp_table)+'2 (recno, string_html) values (''' + convert(varchar(10), @vrows_inserted) + ''', ''</table>'')'
   exec(@sql)
   if @@error <> 0
      return -28
   
   set @vrows_inserted = @vrows_inserted + 1

-- A continuacion, crea el folder con el nombre del usuario, en la carpeta archivos
set @sql = 'exec master..xp_cmdshell "mkdir ' + rtrim(@vdir_app)+'\' + rtrim(@vlogin)+'"'
exec(@sql)
if @@error <> 0
   return -29

set @sql = 'bcp "select string_html from ' + rtrim(@temp_table) + '2 WITH (NOLOCK) order by recno" queryout "' + rtrim(@vfile_excel) + '" -c -T -C ANSI'
exec master..xp_cmdshell @sql

-- Verifica si hubo error al generar el archivo html (Excel)
if @@error <> 0
   return -12

-- Borra las 2 tablas temporales de la base de datos tempdb
set @sql = 'drop table '+@temp_table
exec(@sql)

set @sql = 'drop table '+rtrim(@temp_table)+'2'
exec(@sql)

