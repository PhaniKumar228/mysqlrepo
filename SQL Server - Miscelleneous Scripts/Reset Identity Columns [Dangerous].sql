/******************************************************************************/
/*  RESET_IDENTITY_COLUMNS.SQL                                           */
/*                                                                            */
/*  Reset's the identity seed value to 1 greater than than the max value      */
/*  currently in that column, for all tables in XXXX schema.                  */
/*                                                                            */
/*  HISTORY                                                                   */
/*  DATE     INITIALS   COMMENTS                                              */
/*  070416   KVA        Initial Creation.                                     */
/*                                                                            */
/******************************************************************************/

use [tempdb]
go

BEGIN
	DECLARE         @lv_table_name	varchar(35),
			@lv_column_name varchar(35),
			@lv_count		int,
			@lv_count_str	varchar(15),
		        @lv_sql_stmt	varchar(400)

	DECLARE cur_tables CURSOR FOR
	select o.name, c.name
	from sys.columns c, sys.objects o, sys.schemas s
	where c.object_id = o.object_id
	  and o.schema_id = s.schema_id
	  and c.is_identity = 1
	  and o.type_desc = 'USER_TABLE'
	  and s.name = 'XXXX'
	order by o.name

	BEGIN

		create table ##temp_count (rec_id int, mycount int)
		insert into ##temp_count values (1,0)

		OPEN cur_tables
		FETCH NEXT FROM cur_tables INTO @lv_table_name, @lv_column_name
		WHILE @@FETCH_STATUS = 0
		BEGIN

			select @lv_sql_stmt = 'update ##temp_count set mycount = (select max('+ @lv_column_name +') from prod.' + @lv_table_name + ') where rec_id=1'
			execute (@lv_sql_stmt)

			select @lv_count = (mycount+1) from ##temp_count where rec_id = 1
			select @lv_count_str = STR(@lv_count)

			select @lv_sql_stmt = 'DBCC CHECKIDENT ( ''prod.' + @lv_table_name + ''', RESEED, ' + @lv_count_str + ')'
			execute (@lv_sql_stmt)
			
			FETCH NEXT FROM cur_tables INTO @lv_table_name, @lv_column_name
		END

		drop table ##temp_count

		CLOSE cur_tables
		DEALLOCATE cur_tables

	END
END