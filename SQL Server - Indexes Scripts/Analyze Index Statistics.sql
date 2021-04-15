/*
Analyze Index Statistics

Description

Sample stored procedure that analyzes index statistics, including accesses, overhead, locks, blocks, and waits. 
The order of execution is as follows: 
(1) Truncate indexstats with the script Create / Truncate an Indexstats Table; 
(2) Take initial index snapshot using the script Retrieve Index Statistics; 
(3) Run workload; 
(4) Take final index snapshot using the script Retrieve Index Statistics; and, 
(5) Use this script to perform the final analysis. See script comments for additional information. 
This stored procedure, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code

*/
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[get_indexstats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[get_indexstats]
GO
create proc dbo.get_indexstats 
	(@dbid smallint=-1
	,@top varchar(100)=NULL
	,@columns varchar(500)=NULL
	,@order varchar(100)='lock waits'
	,@threshold varchar(500)=NULL)
as

-- @dbid limits analysis to a database
-- @top allows you to specify TOP n
-- @columns is used to specify what columns from 
--			sys.dm_db_index_operational_stats will be included in the report
--			For example, @columns='scans,lookups,waits' will include columns
--			containing these keywords
-- @order used to order results
-- @threshold used to add a threshold, 
--			example: @threshold='[block %] > 5' only include if blocking is over 5%
--
------  definition of some computed columns returned
-- [blk %] = percentage of locks that cause blocks e.g. blk% = 100 * lock waits / locks
-- [index usage] = range_scan_count + singleton_lookup_count + leaf_insert_count
-- [nonleaf index overhead]=nonleaf_insert_count + nonleaf_delete_count + nonleaf_update_count
-- [avg row lock wait ms]=row_lock_wait_in_ms/row_lock_wait_count
-- [avg page lock wait ms]=page_lock_wait_in_ms/page_lock_wait_count
-- [avg page latch wait ms]=page_latch_wait_in_ms/page_latch_wait_count
-- [avg pageio latch wait ms]=page_io_latch_wait_in_ms/page_io_latch_wait_count
---------------------------------------------------------------------------------------------------
--- Case 1 - only one snapshot of sys.dm_db_operational_index_stats was stored in 
---			indexstats.  This is an error - return errormsg to user
--- Case 2 - beginning snapshot taken, however some objects were not referenced
---			at the time of the beginning snapshot.  Thus, they will not be in the initial
---			snapshot of sys.dm_db_operational_index_stats, use 0 for starting values.
---			Print INFO msg for informational purposes.
--- Case 3 - beginning and ending snapshots, beginning values for all objects and indexes
---			this should be the normal case, especially if SQL Server is up a long time
---------------------------------------------------------------------------------------------------
set nocount on
declare @orderby varchar(100), @where_dbid_is varchar(100), @temp varchar(500), @threshold_temptab varchar(500)
declare @cmd varchar(max),@col_stmt varchar(500),@addcol varchar(500)
declare @begintime datetime, @endtime datetime, @duration datetime, @mincount int, @maxcount int

select @begintime = min(now), @endtime = max(now) from indexstats

if @begintime = @endtime
	begin
		print 'Error: indexstats contains only 1 snapshot of sys.dm_db_index_operational_stats'
		print 'Order of execution is as follows: '
		print '	(1) truncate indexstats with init_indexstats'
		print '	(2) take initial index snapshot using insert_indexstats'
		print '	(3) Run workload'
		print '	(4) take final index snapshot using insert_indexstats'
		print '	(5) analyze with get_indexstats'
		return -99
	end

select @mincount = count(*) from indexstats where now = @begintime
select @maxcount = count(*) from indexstats where now = @endtime

if @mincount < @maxcount
	begin
		print 'InfoMsg1: sys.dm_db_index_operational_stats only contains entries for objects referenced since last SQL re-cycle'
		print 'InfoMsg2: Any newly referenced objects and indexes captured in the ending snapshot will use 0 as a beginning value'
	end

select @top = case 
		when @top is NULL then ''
		else lower(@top)
	end,
		@where_dbid_is = case (@dbid)
		when -1 then ''
		else ' and i1.database_id = ' + cast(@dbid as varchar(10))
	end,
--- thresholding requires a temp table
		@threshold_temptab = case 
		when @threshold is NULL then ''
		else ' select * from #t where ' + @threshold
	end
--- thresholding requires temp table, add 'into #t' to select statement 
select @temp = case (@threshold_temptab)
		when '' then ''
		else ' into #t '
	end
select @orderby=case(@order)
when 'leaf inserts' then 'order by [' + @order + ']'
when 'leaf deletes' then 'order by [' + @order + ']'
when 'leaf updates' then 'order by [' + @order + ']'
when 'nonleaf inserts' then 'order by [' + @order + ']'
when 'nonleaf deletes' then 'order by [' + @order + ']'
when 'nonleaf updates' then 'order by [' + @order + ']'
when 'nonleaf index overhead' then 'order by [' + @order + ']' 
when 'leaf allocations' then 'order by [' + @order + ']'
when 'nonleaf allocations' then 'order by [' + @order + ']'
when 'allocations' then 'order by [' + @order + ']'
when 'leaf page merges' then 'order by [' + @order + ']'
when 'nonleaf page merges' then 'order by [' + @order + ']'
when 'range scans' then 'order by [' + @order + ']'
when 'singleton lookups' then 'order by [' + @order + ']'
when 'index usage' then 'order by [' + @order + ']'
when 'row locks' then 'order by [' + @order + ']'
when 'row lock waits' then 'order by [' + @order + ']'
when 'block %' then 'order by [' + @order + ']' 
when 'row lock wait ms' then 'order by [' + @order + ']'
when 'avg row lock wait ms' then 'order by [' + @order + ']'
when 'page locks' then 'order by [' + @order + ']'
when 'page lock waits' then 'order by [' + @order + ']'
when 'page lock wait ms' then 'order by [' + @order + ']'
when 'avg page lock wait ms' then 'order by [' + @order + ']'
when 'index lock promotion attempts' then 'order by [' + @order + ']'
when 'index lock promotions' then 'order by [' + @order + ']'
when 'page latch waits' then 'order by [' + @order + ']'
when 'page latch wait ms' then 'order by [' + @order + ']'
when 'pageio latch waits' then 'order by [' + @order + ']'
when 'pageio latch wait ms' then 'order by [' + @order + ']'
else ''
end

if @orderby <> '' select @orderby = @orderby + ' desc'
select 'start time'=@begintime,'end time'=@endtime,'duration (hh:mm:ss:ms)'=convert(varchar(50),@endtime-@begintime,14)
		,'Report'=case (@dbid) 
			when -1 then 'all databases'
			else db_name(@dbid)
		end
		+case 
		    when @top = '' then ''
			when @top is NULL then ''
			when @top = 'none' then ''
			else ', ' + @top
		end
	+case 
		    when @columns = '' then ''
			when @columns is NULL then ''
			when @columns = 'none' then ''
			else ', include only columns containing ' + @columns
		end
		+case(@orderby)
			when '' then ''
			when NULL then ''
			when 'none' then ''
			else ', ' + @orderby
		end
		+case
			when @threshold = '' then ''
			when @threshold is NULL then ''
			when @threshold = 'none' then ''
			else ', threshold on ' + @threshold
		end

select @cmd = ' select i2.database_id, i2.object_id, i2.index_id, i2.partition_number '
select @cmd = @cmd +' , begintime=case min(i1.now) when max(i2.now) then NULL else min(i1.now) end '
select @cmd = @cmd +' 	, endtime=max(i2.now) '
select @cmd = @cmd +' into #i '
select @cmd = @cmd +' from indexstats i2 '
select @cmd = @cmd +' full outer join '
select @cmd = @cmd +' 	indexstats i1 '
select @cmd = @cmd +' on i1.database_id = i2.database_id '
select @cmd = @cmd +' and i1.object_id = i2.object_id '
select @cmd = @cmd +' and i1.index_id = i2.index_id '
select @cmd = @cmd +' and i1.partition_number = i2.partition_number '
select @cmd = @cmd +' where i1.now >= ''' +  convert(varchar(100),@begintime, 109) + ''''
select @cmd = @cmd +' and i2.now = ''' + convert(varchar(100),@endtime, 109) + ''''
select @cmd = @cmd + ' ' + @where_dbid_is + ' '
select @cmd = @cmd + ' group by i2.database_id, i2.object_id, i2.index_id, i2.partition_number '
select @cmd = @cmd + ' select ' + @top + ' i.database_id, db_name=db_name(i.database_id), object=isnull(object_name(i.object_id),i.object_id), indid=i.index_id, part_no=i.partition_number '
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[leaf inserts]=i2.leaf_insert_count - isnull(i1.leaf_insert_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[leaf deletes]=i2.leaf_delete_count - isnull(i1.leaf_delete_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[leaf updates]=i2.leaf_update_count - isnull(i1.leaf_update_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[nonleaf inserts]=i2.nonleaf_insert_count - isnull(i1.nonleaf_insert_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[nonleaf deletes]=i2.nonleaf_delete_count - isnull(i1.nonleaf_delete_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[nonleaf updates]=i2.nonleaf_update_count - isnull(i1.nonleaf_update_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[nonleaf index overhead]=(i2.nonleaf_insert_count - isnull(i1.nonleaf_insert_count,0)) + (i2.nonleaf_delete_count - isnull(i1.nonleaf_delete_count,0)) + (i2.nonleaf_update_count - isnull(i1.nonleaf_update_count,0))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[leaf allocations]=i2.leaf_allocation_count - isnull(i1.leaf_allocation_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[nonleaf allocations]=i2.nonleaf_allocation_count - isnull(i1.nonleaf_allocation_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[allocations]=(i2.leaf_allocation_count - isnull(i1.leaf_allocation_count,0)) + (i2.nonleaf_allocation_count - isnull(i1.nonleaf_allocation_count,0))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[leaf page merges]=i2.leaf_page_merge_count - isnull(i1.leaf_page_merge_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[nonleaf page merges]=i2.nonleaf_page_merge_count - isnull(i1.nonleaf_page_merge_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[range scans]=i2.range_scan_count - isnull(i1.range_scan_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[singleton lookups]=i2.singleton_lookup_count - isnull(i1.singleton_lookup_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[index usage]=(i2.range_scan_count - isnull(i1.range_scan_count,0)) + (i2.singleton_lookup_count - isnull(i1.singleton_lookup_count,0)) + (i2.leaf_insert_count - isnull(i1.leaf_insert_count,0))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[row locks]=i2.row_lock_count - isnull(i1.row_lock_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[row lock waits]=i2.row_lock_wait_count - isnull(i1.row_lock_wait_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[block %]=cast (100.0 * (i2.row_lock_wait_count - isnull(i1.row_lock_wait_count,0)) / (1 + i2.row_lock_count - isnull(i1.row_lock_count,0)) as numeric(5,2))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[row lock wait ms]=i2.row_lock_wait_in_ms - isnull(i1.row_lock_wait_in_ms,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[avg row lock wait ms]=cast ((1.0*(i2.row_lock_wait_in_ms - isnull(i1.row_lock_wait_in_ms,0)))/(1 + i2.row_lock_wait_count - isnull(i1.row_lock_wait_count,0)) as numeric(20,1))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[page locks]=i2.page_lock_count - isnull(i1.page_lock_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[page lock waits]=i2.page_lock_wait_count - isnull(i1.page_lock_wait_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[page lock wait ms]=i2.page_lock_wait_in_ms - isnull(i1.page_lock_wait_in_ms,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[avg page lock wait ms]=cast ((1.0*(i2.page_lock_wait_in_ms - isnull(i1.page_lock_wait_in_ms,0)))/(1 + i2.page_lock_wait_count - isnull(i1.page_lock_wait_count,0)) as numeric(20,1))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[index lock promotion attempts]=i2.index_lock_promotion_attempt_count - isnull(i1.index_lock_promotion_attempt_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[index lock promotions]=i2.index_lock_promotion_count - isnull(i1.index_lock_promotion_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[page latch waits]=i2.page_latch_wait_count - isnull(i1.page_latch_wait_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[page latch wait ms]=i2.page_latch_wait_in_ms - isnull(i1.page_latch_wait_in_ms,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[avg page latch wait ms]=cast ((1.0*(i2.page_latch_wait_in_ms - isnull(i1.page_latch_wait_in_ms,0)))/(1 + i2.page_latch_wait_count - isnull(i1.page_latch_wait_count,0)) as numeric(20,1))'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[pageio latch waits]=i2.page_io_latch_wait_count - isnull(i1.page_latch_wait_count,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[pageio latch wait ms]=i2.page_io_latch_wait_in_ms - isnull(i1.page_latch_wait_in_ms,0)'
select @cmd = @cmd +@addcol
exec dbo.add_column @add_stmt=@addcol out,@cols_containing=@columns,@col_stmt=' ,[avg pageio latch wait ms]=cast ((1.0*(i2.page_io_latch_wait_in_ms - isnull(i1.page_io_latch_wait_in_ms,0)))/(1 + i2.page_io_latch_wait_count - isnull(i1.page_io_latch_wait_count,0)) as numeric(20,1))'
select @cmd = @cmd +@addcol
select @cmd = @cmd + @temp
select @cmd = @cmd + ' from #i i '
select @cmd = @cmd + ' left join indexstats i1 on i.begintime = i1.now and i.database_id = i1.database_id and i.object_id = i1.object_id and i.index_id = i1.index_id and i.partition_number = i1.partition_number '
select @cmd = @cmd + ' left join indexstats i2 on i.endtime = i2.now and i.database_id = i2.database_id and i.object_id = i2.object_id and i.index_id = i2.index_id and i.partition_number = i2.partition_number '
select @cmd = @cmd + ' ' + @orderby + ' '
select @cmd = @cmd + @threshold_temptab
--select @cmd
exec ( @cmd )
go
--- get all index column stats for dbid=7, order by singleton lookups desc
exec get_indexstats @dbid=7
				,@order='singleton lookups'
--- get the top 5 indexes for all databases, order by index usage desc
exec get_indexstats @dbid=-1,@top='top 5',@columns='index,usage',@order='index usage'
--- get the top 5 (all columns) index lock promotions where a lock promotion was attempted
exec get_indexstats @dbid=7,@top='top 5'
				,@order='index lock promotions',@threshold='[index lock promotion attempts] > 0'
--- get all index stats for top 10 nonleaf index overhead (cost of index)
exec get_indexstats @dbid=-1,@top='top 10',@order='nonleaf index overhead',@columns='leaf'
/*
--- get top 5 singleton lookups with avg row lock waits>2ms, return columns containing wait, scan, singleton
exec get_indexstats @dbid=5,@top='top 5',@columns='wait,scan,singleton'
				,@order='singleton lookups',@threshold='[avg row lock wait ms] > 2'
--- get all indexstats for dbid=5, order by index usage desc, threshold on block%, include columns containing usage,block,lock,wait
exec get_indexstats @dbid=-1,@columns='usage,block,lock,wait',
				@order='index usage',@threshold='[block %] > .005'
--- get indexstats for all dbid, include columns containing usage,wait
exec get_indexstats @dbid=-1,@columns='usage,wait',@order='row lock waits'
--- get top10, all index stats, order by row lock waits where block% > .01%
exec get_indexstats @dbid=-1,@top='top 10 ',@order='row lock waits',
				@threshold='[block %] > .01'
--- get top 10 for all databases, columns containing 'avg, wait', order by wait ms, where row lock waits > 1
exec get_indexstats @dbid=-1,@top='top 10 ',@columns='wait,row',
				@order='row lock wait ms', @threshold='[row lock waits] > 1'
--- get top 5 index stats, order by avg row lock waits desc
exec get_indexstats @dbid=-1,@top='top 5',@order='avg row lock wait ms'
--- get top 5 index stats, order by avg page latch lock waits desc
exec get_indexstats @dbid=-1,@top='top 5',@order='avg page latch wait ms'
--- get top 5 percent index stats, order by avg pageio latch waits desc where there were pageio latch waits
exec get_indexstats @dbid=-1,@top='top 3 percent',@order='avg pageio latch wait ms',
				@threshold='[pageio latch waits] > 0'
exec get_indexstats @dbid=-1,@top='top 10 percent',@order='page latch waits'
--- get all index stats for top 10 in db=5, ordered by block%
exec get_indexstats @dbid=5,@top='top 10',@order='block %'
--- get all index stats for top 10 in db=5, ordered by block% where block% > .1
exec get_indexstats @dbid=-1,@top='top 10',@order='block %',@threshold='[block %] > 0.1'
exec get_indexstats @dbid=-1,@top='top 5',@order='allocations',@columns='allocation'
*/
exec get_indexstats @dbid=-1,@top='top 10 ',@order='row lock waits'

				,@order='singleton lookups'rds

