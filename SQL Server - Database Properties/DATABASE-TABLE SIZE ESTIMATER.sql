/*
DATABASE / TABLE SIZE ESTIMATER

The code in this procedure takes standard formula’s given by Microsoft and calculates approximate size of a table as per 
the fields  & indexs on that table. The procdure can be quickly be used in a loop to work for entire database. 

Refer to article http://msdn.microsoft.com/library/default.asp?url=/library/en-us/createdb/cm_8_des_02_92k3.asp 
for the actual document containing the formula’s used.

There are 2 major assumptions made
1. All The VARIABLE LENGTH columns will be completely filled. (you can change it easily)
2. FillFactor for all indexes in tables are same.

Usage:
declare  @objectid int, @num_rows float , @fill_factor  smallint
select @objectid = object_id('authors'), @num_rows = 2000 , @fill_factor = 90 
exec gettablesize ( @objectid ,@num_rows ,@fill_factor  )

Rerurns:
Row Size , Data Size in KB, Clustered Index Size in KB,NonClustered Index Size in KB and total Size in KB

*/

/**********************************************************************************************
Procedure Name   : gettablesize 
Date             : Feb 11 2004 11:31AM
Purpose          : Table Size Estimation 
Tables Referred  : sysobjects,sysindexes, sysindexkeys ,syscolumns 
Input Parameters :
	1. objectid : Id of Table For which size is to be estimated. 
Output Parameters:
   None, A Recordset containing Row Size , Data Size in KB, Clustered Index Size in KB,NonClustered Index Size in KB and total Size in KB

**********************************************************************************************/


create proc gettablesize ( @objectid int, @rows float , @fill_factor  smallint )
as
begin



declare 
        @num_rows                       float, 
	@fixed_data_size		int ,
	@num_cols 			int ,
	@num_variable_cols		int , 
	@has_clust_index		bit ,
	@max_var_size			int ,
	@null_bitmap			int ,
	@variable_data_size		int ,
	@row_size			int ,
	@rows_per_page			int ,
	@free_rows_per_page 		int ,
	@num_pages			int , 

	@num_ckey_cols			int , 
	@fixed_ckey_size		int ,
	@num_variable_ckey_cols		int ,
	@max_var_ckey_size		int , 

	@num_key_cols			int , 
	@fixed_key_size			int ,
	@num_variable_key_cols		int ,
	@max_var_key_size		int , 

	@cindex_null_bitmap		int ,
	@variable_ckey_size		int ,
	@cindex_row_size		int ,
	@cindex_rows_per_page		int , 
	@num_pages_clevel_0		float ,
	@num_cindex_pages		int ,
	@clustered_index_size_in_bytes  int ,
	@index_null_bitmap		int ,
	@variable_key_size		int ,
	@nl_index_row_size		int ,
	@index_row_size			int ,
	@index_rows_per_page		int , 
	@nl_index_rows_per_page		int , 
	@num_pages_level_0		float ,
	@num_index_pages		int ,
	@nc_index_size_in_bytes  	int ,
	@total_nc_index_size_in_bytes  	int ,
	@free_index_rows_per_page	int , 
	@total_nc_index_size_in_kbytes  float ,
	@data_space_used_in_kb  	float ,
	@clustered_index_size_in_kbytes float, 
	@data_space_used_in_byte  	bigint ,
	@indid				tinyint 


        if not  exists ( select 1 from sysobjects where type ='U' and id = @objectid ) 
        begin
           print 'User Table specified by given id does not exits. please use a vaild objectid'
           return 1
        end

        select @num_rows = @rows 
	select @num_cols 	= count(*) ,
	@fixed_data_size	= sum(case when c.xtype in (231, 167, 165, 99) then 0 else c.length end  )  ,
	@num_variable_cols	= sum(case when c.xtype in (231, 167, 165, 99) then 1 else 0 end ) ,
	@max_var_size		= sum(case when c.xtype in (231, 167, 165, 99) then c.length else 0 end  )  ,
	@has_clust_index	= objectproperty ( o.id, 'tablehasclustindex'  ), 
	@num_ckey_cols		= isnull( ( select keycnt from sysindexes i where i.id = o.id and i.indid = 1 ) , 0 ) ,
	@fixed_ckey_size	= case objectproperty ( o.id, 'tablehasclustindex' )when 0 then 0 else ( 
					select isnull(sum(ic.length) , 0) from sysindexkeys ik inner join syscolumns ic 
					on (ic.colid = ik.colid and ic.id = ik.id )
					where ik.id = o.id and ik.indid = 1   
					and ic.xtype not in  (231, 167, 165, 99)
				 ) end , 
	@num_variable_ckey_cols 	= case objectproperty ( o.id, 'tablehasclustindex' )when 0 then 0 else ( 
					select count(* ) from sysindexkeys ik inner join syscolumns ic 
					on (ic.colid = ik.colid and ic.id = ik.id )
					where ik.id = o.id and ik.indid = 1   
					and ic.xtype in  (231, 167, 165, 99) 
				) end,
	@max_var_ckey_size	= case objectproperty ( o.id, 'tablehasclustindex' )when 0 then 0 else ( 
					select isnull(sum(ic.length) , 0) from sysindexkeys ik inner join syscolumns ic 
					on (ic.colid = ik.colid and ic.id = ik.id )
					where ik.id = o.id and ik.indid = 1   
					and ic.xtype in  (231, 167, 165, 99)
				 ) end 
	
	from sysobjects o inner join syscolumns c on ( o.id = c.id )
	where o.id = @objectid 
	group by o.id,o.name 
	
	/* null_bitmap) = 2 + (( num_cols + 7) / 8 ) */
	select @null_bitmap 		= floor(2 + (( @num_cols + 7) / 8 ) )  
	
	/* total size of variable-length columns (variable_data_size) = 2 + (num_variable_cols x 2) + max_var_size
	if there are no variable-length columns, set variable_data_size to 0.
	this formula assumes that all variable-length columns are 100 percent full. */
	select  @variable_data_size 	= case when @num_variable_cols = 0 then 0 else 2 + (@num_variable_cols * 2) +  
@max_var_size end  
	
	/* total row size (row_size) = fixed_data_size + variable_data_size + null_bitmap +4
	the final value of 4 represents the data row header. */
	
	select @row_size		= @fixed_data_size + @variable_data_size + @null_bitmap + 4 
	
	/* number of rows per page (rows_per_page) = ( 8096 ) / (row_size + 2) 
	because rows do not span pages, the number of rows per page should be rounded down to the nearest whole row */
	select @rows_per_page		= ceiling ( 8096 /  ( @row_size + 2 ) ) 
	
	
	/* if a clustered index is to be created on the table, calculate the number of reserved free rows per page, 
	based on the fill factor specified. if no clustered index is to be created, specify fill_factor as 100. 
	number of free rows per page (free_rows_per_page) = 8096 x ((100 - fill_factor) / 100) / (row_size + 2)
	the fill factor used in the calculation is an integer value rather than a percentage.
	because rows do not span pages, the number of rows per page should be rounded down to the nearest whole row. as the  
fill factor grows, more data will be stored on each page and there will be fewer pages.
	*/
	
	select @free_rows_per_page 	= ceiling( 8096 * ( ( 100 - @fill_factor) / 100) / (@row_size + 2) ) 
	/*calculate the number of pages required to store all the rows: 
	number of pages (num_pages) = num_rows / (rows_per_page - free_rows_per_page) */
	
	select @num_pages		=  ceiling ( convert(float, @num_rows / (@rows_per_page - @free_rows_per_page) ) )
	
	/* the amount of space required to store the data in a table (8192 total bytes per page): 
	table_size_in_bytes = 8192 x num_pages */
	
	
	select @data_space_used_in_byte = 8192 * @num_pages 
	select @data_space_used_in_kb  = @data_space_used_in_byte  / 1024    
	
	
	/* space used to store the clustered index */
	
	
	/* if there are fixed-length columns in the clustered index, a portion of the index row is reserved for the null  
bitmap. calculate its size: 
	index null bitmap (cindex_null_bitmap) = 2 + (( num_ckey_cols + 7) / 8 ) */ 
	select @cindex_null_bitmap	= floor(2 + (( @num_ckey_cols + 7) / 8 ) )  
	
	/* total size of variable length columns (variable_ckey_size) = 2 + (num_variable_ckey_cols x 2) + max_var_ckey_size
	if there are no variable-length columns, set variable_ckey_size to 0.
	this formula assumes that all variable-length key columns are 100 percent full. 
	*/
	
	select @variable_ckey_size	= case when @num_variable_ckey_cols = 0 then 0 else  2 + (@num_variable_ckey_cols *  
2) + ( @max_var_ckey_size * @fill_factor / 100  )  end 
	
	/* total index row size (cindex_row_size) = fixed_ckey_size + variable_ckey_size + cindex_null_bitmap + 1 + 8 */ 
	
	select @cindex_row_size		= @fixed_ckey_size + @variable_ckey_size + @cindex_null_bitmap + 1 + 8 
	
	/* the number of index rows per page (8096 free bytes per page): 
	number of index rows per page (cindex_rows_per_page) = ( 8096 ) / (cindex_row_size + 2)
	because index rows do not span pages, the number of index rows per page should be rounded down to the nearest whole  
row.
	*/
	select @cindex_rows_per_page = ceiling( ( 8096.0 ) / @cindex_row_size + 2  )
	
	/*
	calculate the number of pages required to store all the index rows at each level of the index. 
	number of pages (level 0) (num_pages_clevel_0) = (data_space_used / 8192) / cindex_rows_per_page
	number of pages (level 1) (num_pages_clevel_1) = num_pages_clevel_0 / cindex_rows_per_page
	
	repeat the second calculation, dividing the number of pages calculated from the previous level n by  
cindex_rows_per_page until the number of pages for a given level n (num_pages_clevel_n) equals one (index root page). for  
example, to calculate the number of pages required for the second index level:
	number of pages (level 2) (num_pages_clevel_2) = num_pages_clevel_1 / cindex_rows_per_page
	
	for each level, the number of pages estimated should be rounded up to the nearest whole page.
	sum the number of pages required to store each level of the index:
	total number of pages (num_cindex_pages) = num_pages_clevel_0 + num_pages_clevel_1 +
	num_pages_clevel_2 + ... + num_pages_clevel_n   */
	
	
	select @num_pages_clevel_0  = ceiling ( ( @data_space_used_in_byte / 8192.0 ) / @cindex_rows_per_page )
	
	
	select @num_cindex_pages  = @num_pages_clevel_0 
	
	while @num_pages_clevel_0 > 1 
	begin
		-- print @num_pages_clevel_0 
		select @num_pages_clevel_0 = ceiling(@num_pages_clevel_0 /  @cindex_rows_per_page )
		select @num_cindex_pages = @num_cindex_pages + @num_pages_clevel_0 	
	
	end 
	
	/* clustered index size (bytes) = 8192 x num_cindex_pages */
	
	select 	@clustered_index_size_in_bytes  = 8192 * @num_cindex_pages 
	if @has_clust_index = 0 
		select @clustered_index_size_in_bytes   = 0
	select @clustered_index_size_in_kbytes = @clustered_index_size_in_bytes / 1024.0 
	
	declare ind_cursor cursor for 
	select indid , keycnt from sysindexes  i
	where i.indid between 2 and 254  
	and i.name not like '[_]wa[_]sys%' 
	and i.id = @objectid 
	select @total_nc_index_size_in_bytes =  0 
	open ind_cursor 
	
	fetch next from ind_cursor into @indid , @num_key_cols  
	
	while @@fetch_status = 0
	begin
		/* 
		calculate the space used to store each additional nonclustered index
		the following steps can be used to estimate the amount of space required to store each additional  
nonclustered index: 
		
		a nonclustered index definition can include fixed-length and variable-length columns. to estimate the size of  
the nonclustered index, you must calculate the space each of these groups of columns occupies within the index row: 
		number of columns in index key = num_key_cols */
		
		/* sum of bytes in all fixed-length key columns = fixed_key_size */
		select @fixed_key_size	= isnull(sum(ic.length) , 0) 
		from sysindexkeys ik inner join syscolumns ic 
		on (ic.colid = ik.colid and ic.id = ik.id )
		where ik.id = @objectid and ik.indid = @indid 
		and ic.xtype not in  (231, 167, 165, 99)
			 	
		
		/*
		number of variable-length columns in index key = num_variable_key_cols
		maximum size of all variable-length key columns = max_var_key_size */
		
		select  @num_variable_key_cols 	=count(* )  , 
			@max_var_key_size	=  isnull(sum(ic.length) , 0)
		from sysindexkeys ik inner join syscolumns ic 
		on (ic.colid = ik.colid and ic.id = ik.id )
		where ik.id = @objectid and ik.indid = @indid 
		and ic.xtype in  (231, 167, 165, 99) 
		
		
		/* if there are fixed-length columns in the index, a portion of the index row is reserved for the null  
bitmap. calculate its size: 
		index null bitmap (index_null_bitmap) = 2 + (( num_key_cols + 7) / 8 ) 
		only the integer portion of the above expression should be used; discard any remainder.  */
		select @index_null_bitmap	= floor(2 + (( @num_key_cols + 7) / 8 ) )  
		
		
		/* if there are variable-length columns in the index, determine how much space is used to store the columns  
within the index row:  
		total size of variable length columns (variable_key_size) = 2 + (num_variable_key_cols x 2) +  
max_var_key_size
		
		if there are no variable-length columns, set variable_key_size to 0.
		this formula assumes that all variable-length key columns are 100 percent full. if you anticipate that a  
lower percentage of the variable-length key column storage space will be used, you can adjust the result by that percentage  
to yield a more accurate estimate of the overall index size.*/
		
		select @variable_key_size	= case when @num_variable_key_cols = 0 then 0 else  2 +  
(@num_variable_key_cols * 2) + ( @max_var_key_size * @fill_factor / 100  )  end 
	
		if @has_clust_index = 1 
		begin			
			/* non clustered index on a table with clustered index */
			/* calculate the nonleaf index row size: 
			total nonleaf index row size (nl_index_row_size) = fixed_key_size + variable_key_size +  
index_null_bitmap + 1 + 8 */
			
			select @nl_index_row_size 	= @fixed_key_size + @variable_key_size + @index_null_bitmap + 1 + 8 
			/* calculate the number of nonleaf index rows per page: 
			number of nonleaf index rows per page (nl_index_rows_per_page) = 
			( 8096 ) / (nl_index_row_size + 2)
			
			because index rows do not span pages, the number of index rows per page should be rounded down to the  
nearest whole row. */
			select @nl_index_rows_per_page = ceiling( ( 8096.0 ) / @nl_index_row_size + 2  )
		
			/*
			calculate the leaf index row size: 
			total leaf index row size (index_row_size) = cindex_row_size + fixed_key_size + variable_key_size +  
index_null_bitmap + 1
			
			the final value of 1 represents the index row header. cindex_row_size is the total index row size for  
the clustered index key. */
		
			select @index_row_size = @cindex_row_size + @fixed_key_size + @variable_key_size + @index_null_bitmap  
+ 1
			
		
			/*	
			calculate the number of leaf level index rows per page: 
			number of leaf level index rows per page (index_rows_per_page) = ( 8096 ) / (index_row_size + 2)
		
			because index rows do not span pages, the number of index rows per page should be rounded down to the  
nearest whole row. */
		
			select @index_rows_per_page = ceiling(( 8096.0 ) / (@index_row_size + 2) )
		
			
			/* 
			calculate the number of reserved free index rows per page based on the fill factor specified for the  
nonclustered index. 
			number of free index rows per page (free_index_rows_per_page) = 8096 x ((100 - fill_factor) / 100) /  
index_row_size 
			
			the fill factor used in the calculation is an integer value rather than a percentage.
			
			because index rows do not span pages, the number of index rows per page should be rounded down to the  
nearest whole row. */
		
			select @free_index_rows_per_page = ceiling(8096 * ((100 - @fill_factor) / 100) / @index_row_size )
		
			
			/* calculate the number of pages required to store all the index rows at each level of the index: 
			number of pages (level 0) (num_pages_level_0) = num_rows / (index_rows_per_page -  
free_index_rows_per_page) 
			
			number of pages (level 1) (num_pages_level_1) = num_pages_level_0 / nl_index_rows_per_page
			
			repeat the second calculation, dividing the number of pages calculated from the previous level n by  
nl_index_rows_per_page until the number of pages for a given level n (num_pages_level_n) equals one (root page).
			
			for example, to calculate the number of pages required for the second and third index levels:
			
			number of data pages (level 2) (num_pages_level_2) = num_pages_level_1 / nl_index_rows_per_page
			
			number of data pages (level 3) (num_pages_level_3) = num_pages_level_2 / nl_index_rows_per_page
			
			for each level, the number of pages estimated should be rounded up to the nearest whole page.
			
			sum the number of pages required to store each level of the index: 
			total number of pages (num_index_pages) = num_pages_level_0 + num_pages_level_1 +num_pages_level_2 +  
... + num_pages_level_n */
		
		
			select @num_pages_level_0 = ceiling( @num_rows / (@index_rows_per_page - @free_index_rows_per_page) )
			select @num_index_pages  = @num_pages_level_0 
		
			while @num_pages_level_0 > 1 
			begin
				-- print @num_pages_level_0 
				select @num_pages_level_0 = ceiling(@num_pages_level_0 /  @nl_index_rows_per_page )
				select @num_index_pages = @num_index_pages + @num_pages_level_0 	
			
			end 
		end 
		else
		begin
			/* non clustered index on a table without a clustered index */
			/* calculate the index row size: 
			total index row size (index_row_size) = fixed_key_size + variable_key_size + index_null_bitmap + 1 +  
8 */
			select @index_row_size = @fixed_key_size + @variable_key_size + @index_null_bitmap + 1 + 8
	
			/* calculate the number of index rows per page (8096 free bytes per page): 
			number of index rows per page (index_rows_per_page) = ( 8096 ) / (index_row_size + 2) 
			because index rows do not span pages, the number of index rows per page should be rounded down to the  
nearest whole row.*/		
			select @index_rows_per_page = ceiling(( 8096 ) / (@index_row_size + 2))
	
			
	
			/* calculate the number of reserved free index rows per leaf page, based on the fill factor specified  
for the nonclustered index. for more information, see fill factor. 
			number of free index rows per leaf page (free_index_rows_per_page) = 8096 x ((100 - fill_factor) /  
100) / 
			index_row_size
			
			the fill factor used in the calculation is an integer value rather than a percentage.
			
			because index rows do not span pages, the number of index rows per page should be rounded down to the  
nearest whole row. */
			select @free_index_rows_per_page = ceiling( 8096 * (( 100 - @fill_factor) / 100) / @index_row_size )
	
			/* calculate the number of pages required to store all the index rows at each level of the index: 
			number of pages (level 0) (num_pages_level_0) = num_rows / (index_rows_per_page -  
free_index_rows_per_page)
			
			number of pages (level 1) (num_pages_level_1) = num_pages_level_0 / index_rows_per_page
			
			repeat the second calculation, dividing the number of pages calculated from the previous level n by  
index_rows_per_page until the number of pages for a given level n (num_pages_level_n) equals one (root page). for example, to  
calculate the number of pages required for the second index level:
			
			number of pages (level 2) (num_pages_level_2) = num_pages_level_1 / index_rows_per_page
			
			for each level, the number of pages estimated should be rounded up to the nearest whole page.
			
			sum the number of pages required to store each level of the index:
			
			total number of pages (num_index_pages) = num_pages_level_0 + num_pages_level_1 + num_pages_level_2 +  
... + num_pages_level_n */
	
		
		
			select @num_pages_level_0 = ceiling( @num_rows / (@index_rows_per_page - @free_index_rows_per_page) )
			select @num_index_pages  = @num_pages_level_0 
	
			while @num_pages_level_0 > 1 
			begin
				-- print @num_pages_level_0 
				select @num_pages_level_0 = ceiling(@num_pages_level_0 /  @index_rows_per_page )
				select @num_index_pages = @num_index_pages + @num_pages_level_0 	
				
			end 
			
	
		end 
	
		/*calculate the size of the nonclustered index: nonclustered index size (bytes) = 8192 x num_index_pages	 
*/
		select @nc_index_size_in_bytes = 8192 * @num_index_pages
		-- print 	@nc_index_size_in_bytes 
		select @total_nc_index_size_in_bytes = @total_nc_index_size_in_bytes +  @nc_index_size_in_bytes 
	
		fetch next from ind_cursor into @indid , @num_key_cols 
	end
	
	close ind_cursor 
	deallocate  ind_cursor 
	
	
	select @total_nc_index_size_in_kbytes   = @total_nc_index_size_in_bytes  / 1024.0
	
	select 	'row size' 		= @row_size			,
	--	'number of pages' 	= @num_pages			, 
	--	'data size in bytes' 	= @data_space_used_in_byte  	,
		'data size in kb' 	= @data_space_used_in_kb  	, 
	--	'clustered_index_size_in_bytes'   = @clustered_index_size_in_bytes  ,
		'clustered_index_size_in_kbytes'  = @clustered_index_size_in_kbytes , 
	--	'nclustered_index_size_in_bytes'   = @total_nc_index_size_in_bytes  ,
		'nclustered_index_size_in_kbytes'  = @total_nc_index_size_in_kbytes  ,
		'total size'   = @data_space_used_in_kb  + @clustered_index_size_in_kbytes  + @total_nc_index_size_in_kbytes  
	
end 
go





