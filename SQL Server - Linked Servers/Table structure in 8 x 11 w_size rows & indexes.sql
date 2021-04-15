/*
Table structure in 8 x 11 w/size, rows & indexes

Using the sp_help to get a table structure is very cumbersome.  
First, in order to print it you have to use
"Results in Text" not "Results in Grid".  
Second, the results are very wide screen-wise and very hard to read or print.  
Third, you do not get the size or number rows with the same request.
This script does it all for you.   
Its very handy.  Its long, but just create the SP and use it.

*/

create proc sp_tablestru
	@tblname varchar(50)
as

if @tblname is null begin
   raiserror(15250,-1,-1)
   return(1)
end

-- validate @tblname
declare @id int,@dbname sysname,@type char(2),@rows char(11),@pages bigint,@size char(20)
if @tblname is not null begin

	select @dbname = parsename(@tblname, 3)

	if @dbname is not null and @dbname <> db_name()
	   begin
		raiserror(15250,-1,-1)
		return (1)
	   end

	if @dbname is null
	   select @dbname = db_name()

	/*
	**  Try to find the object.
	*/
	select @id = null
	select @id = id, @type = xtype
		from sysobjects
			where id = object_id(@tblname)

	/*
	**  Does the object exist?
	*/
	if @id is null
	   begin
		raiserror(15009,-1,-1,@tblname,@dbname)
		return (1)
	   end
end

-- rows
select @rows=convert(char(11),rows)
from sysindexes
where indid<2 and id=@id


-- size
select @pages = sum(dpages)
from sysindexes
where indid < 2
  and id = @id

select @pages = @pages + isnull(sum(used), 0)
from sysindexes
where indid = 255
  and id = @id

select @size=ltrim(str((@pages * b.low)/1024.,15,0))+''+'KB'
from master.dbo.spt_values b
where number=1 and type ='E'
print '---------------------------------------------------------------------------------------------'
print '------ Object: '+@tblname
print '============================================================================================='
print 'Rows                Size'
print '----------------    ------------------------'
print space(16-len(rtrim(@rows)))+rtrim(@rows)+space(28-len(rtrim(@size)))+rtrim(@size)
print '============================================================================================='


declare @sqltext varchar(8000)
select @sqltext='
declare tblstru_crsr cursor for
select a.name,a.xusertype,a.length,a.xprec,a.xscale,a.isnullable from syscolumns a,sysobjects b
where b.name like '''+@tblname+''' and b.id=a.id order by colid'
exec (@sqltext)

declare @name varchar(50),@xusertype smallint,@length smallint,@xprec tinyint,@xscale tinyint,@isnullable int
open tblstru_crsr
fetch tblstru_crsr into @name,@xusertype,@length,@xprec,@xscale,@isnullable
set nocount on

print 'Column Name                                       Type             Length Scale Null'
print '------------------------------------------------- ---------------- ------ ----- ----'


while @@fetch_status= 0 begin
	
	if @xusertype=34 
	   print @name+space(50-len(@name))+'Image               '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=35
	   print @name+space(50-len(@name))+'Text                '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=36 
	   print @name+space(50-len(@name))+'UniqueIdentifier    '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=48 
	   print @name+space(50-len(@name))+'Tinyint             '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=52
	   print @name+space(50-len(@name))+'Smallint            '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=56
	   print @name+space(50-len(@name))+'Int                 '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=58
	   print @name+space(50-len(@name))+'SmallDateTime       '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=59
	   print @name+space(50-len(@name))+'Real                '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=60
	   print @name+space(50-len(@name))+'Money               '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=61
	   print @name+space(50-len(@name))+'DateTime            '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=62
	   print @name+space(50-len(@name))+'Float               '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=98 
	   print @name+space(50-len(@name))+'SQL_variant         '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end 	
	if @xusertype=99 
	   print @name+space(50-len(@name))+'nText               '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=104 
	   print @name+space(50-len(@name))+'Bit                 '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=106
	   print @name+space(50-len(@name))+'Decimal             '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=108
	   print @name+space(50-len(@name))+'Numeric             '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=122
	   print @name+space(50-len(@name))+'SmallMoney          '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=127
	   print @name+space(50-len(@name))+'Bigint              '+space(2-len(@xprec))+ltrim(str(@xprec))+'     '+ltrim(str(@xscale))+'   '+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=165 
	   print @name+space(50-len(@name))+'Varbinary           '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=167 
	   print @name+space(50-len(@name))+'Varchar             '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=173 
	   print @name+space(50-len(@name))+'Binary              '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=175 
	   print @name+space(50-len(@name))+'Char                '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=189
	   print @name+space(50-len(@name))+'TimeStamp           '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=231
	   print @name+space(50-len(@name))+'nVarchar            '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=239
	   print @name+space(50-len(@name))+'nChar               '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end
	if @xusertype=256
	   print @name+space(50-len(@name))+'Sysname             '+ltrim(str(@length))+space(11-len(@length))+case when @isnullable=1 then 'YES' else 'NO ' end

	       
	fetch tblstru_crsr into @name,@xusertype,@length,@xprec,@xscale,@isnullable
end
close tblstru_crsr
deallocate tblstru_crsr
print '============================================================================================='



print 'Index information:'
print ''
-- indexes
	declare	@indid smallint,	-- the index id of an index
		@groupid smallint,  -- the filegroup id of an index
		@indname sysname,
		@groupname sysname,
		@status int,
		@keys nvarchar(2126)	--Length (16*max_identifierLength)+(15*2)+(16*3)
		
	declare ms_crs_ind cursor local static for
		select indid, groupid, name, status
		from sysindexes
		where id = @id and indid > 0 and indid < 255 and (status & 64)=0 
		order by indid
	open ms_crs_ind

	fetch ms_crs_ind into @indid, @groupid, @indname, @status

	-- IF NO INDEX, QUIT
	if @@fetch_status < 0
	begin
		deallocate ms_crs_ind
           	
		print '   *** '+rtrim(@tblname)+' does not contain any indexes ***'  
		print '============================================================================================='   
		return (0)
	end

	--     1234567890123456789012345   1234567890123456789012345   123456789012345678901234567890
	print 'Index name               '+'Index type               '+'Index key                     '
	print '------------------------ '+'------------------------ '+'------------------------------'
	-- Now check out each index, figure out its type and keys 
	while @@fetch_status >= 0
	begin
		-- First we'll figure out what the keys are.
		declare @i int, @thiskey nvarchar(131) -- 128+3

		select @keys = index_col(@tblname, @indid, 1), @i = 2
		if (indexkey_property(@id, @indid, 1, 'isdescending') = 1)
			select @keys = @keys  + '(-)'

		select @thiskey = index_col(@tblname, @indid, @i)
		if ((@thiskey is not null) and (indexkey_property(@id, @indid, @i, 'isdescending') = 1))
			select @thiskey = @thiskey + '(-)'

		while (@thiskey is not null )
		begin
			select @keys = @keys + ', ' + @thiskey, @i = @i + 1
			select @thiskey = index_col(@tblname, @indid, @i)
			if ((@thiskey is not null) and (indexkey_property(@id, @indid, @i, 'isdescending') = 1))
				select @thiskey = @thiskey + '(-)'
		end

		select @groupname = groupname from sysfilegroups where groupid = @groupid
		
		print rtrim(@indname)+space(25-len(rtrim(@indname)))+
		case when (@status & 16)<>0 then 'clustered' else 'nonclustered' end+' '+rtrim(@groupname)+
		case when (@status & 16)<>0 then '        ' else '     ' end+rtrim(@keys)
		
		-- Next index
		fetch ms_crs_ind into @indid, @groupid, @indname, @status
	end
	deallocate ms_crs_ind
	print ''
	print '============================================================================================='   




return
