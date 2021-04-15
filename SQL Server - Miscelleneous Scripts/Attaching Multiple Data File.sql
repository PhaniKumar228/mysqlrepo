/*
Attaching Multiple Data File

This Stored Procedure can attach multiple data File that have *.mdf or *.ldf Extention ..

Example :
you have multiple data file on your "c:\SQL_data directory" .. 
just type this on your query analyzer
.. of course you have to be a member of sysadmin fixed server role 

exec attach_db "c:\SQL_data"

*/

create proc attach_db
@fileAddress varchar(1000)
as
begin
set nocount on
DECLARE 	@cmd 		sysname, 
					@var 			sysname,
					@value		varchar(100),
					@file1 		varchar(100),
					@file2			varchar(100),
					@count		numeric,
					@name		varchar(100),
					@file 			varchar(1000),
					@loop 		numeric,
					@inserted	varchar(100),
					@x2			varchar(100)

SET @var = 'dir ' + @fileAddress + '*.mdf /b'
SET @cmd = @var + ' > c:\dir_out.txt'
EXEC master..xp_cmdshell @cmd, NO_OUTPUT


if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[temp_Text]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[temp_Text]

create table temp_Text
(	Files varchar(4000))

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[temp_File]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[temp_File]

create table temp_File
(	Files varchar(100))

BULK INSERT temp_Text
   FROM 'c:\dir_out.txt'
   WITH 
      (
         ROWTERMINATOR = ''
      )



select  @file=files from temp_Text
if @@rowcount=0
	begin
		print 	'Error!!:'
		print	'Cannot Found Data File!!'
		return 0
	end
else
	begin
		set @loop=1
		while @loop>0
		begin
			set @loop	=	charindex('.MDF',upper(@file),0)
			set @inserted=left(@file,@loop)
			if len(@file)>3
				begin
					set @file=right(@file,len(@file)-@loop-3)
				end
		
			if len(@file)=0
				begin
					break
				end
			else
				begin
					if len(@inserted) = 0
						begin
							break					
						end
					else
						begin
							insert into temp_File
								values (replace(@inserted,'.',''))
						end
				end
		
		end
		
		declare cur_text cursor for
		select  files from temp_File
		
		open cur_text
		fetch next from cur_text into 
		@value
		
		set @count	=	1
		while @@fetch_status=0
		begin
			
			if @count<>1
				begin
					set @file1		=	@fileAddress + right(replace(@value,' ',''),len(@value)-2) + '.MDF'
					if charindex('_Data',@value,1)<>0
						begin
							set @name	=	right(replace(@value,'_Data',''),len(@value)-7) 
							set @file2		= @fileAddress + right(replace(@value,'_Data','_Log'),len(@value)-3) + '.LDF'
						end
					else
						begin
							set @name	=	right(replace(@value,'_Data',''),len(@value)-2) 
							set @file2		=	@fileAddress + right(replace(@value,'_Data','_Log'),len(@value)-2) + '.LDF'
						end
				end
			else
				begin
					set @name	=	replace(@value,'_Data','')
					set @file1		=	@fileAddress + right(replace(@value,' ',''),len(@value)) + '.MDF'
					set @file2		=	@fileAddress + right(replace(@value,'_Data','_Log'),len(@value)) + '.LDF'
				end
			
			if len(@value)-2<>0
			begin
					if exists(select name from sysdatabases where name=@name)
						begin
							print	'Attaching Database : ' + @name + ', Failed!!'
							print 	'Error: Database ' + @name + ' exist!! '	
							print	'--------------------------------------------'
						end
					else
						begin
							exec sp_attach_db @dbname = @name,
							 	@filename1 = @file1,
								@filename2 = @file2
							if @@error=0
								print	'Attaching Database : ' + @name + ', Success !!'
						end
			end
		
			set @count=@count+1
		fetch next from cur_text into 
		@value
		end
		
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[temp_Text]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[temp_Text]
		
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[temp_File]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[temp_File]
		
		--EXEC @x2= [master].[dbo].[xp_cmdshell] 'Del c:\dir_out.txt', NO_OUTPUT
		
		close cur_text
		deallocate cur_text
	end
end
