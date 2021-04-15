/*
DB Details - Tables, Rows, Columns, Primary Keys

This procedure will give you the list of tables in the current database along with total columns in the table, no. of rows and the primary key(s) defined for the table.

MCP, MCAD (.Net), MCSD, MCDBA 

*/

CREATE proc sp_DBDetails  
as        
/*
This procedure will give you the list of tables in the current database along with total columns in the table, no. of rows and the primary key(s) defined for the table.

*/
set nocount on        
declare @id int, @name varchar(255), @cnt int, @sql nvarchar(4000), @temp varchar(900), @pcol varchar(255)  
create table #temptable (TableName varchar(255), TotalColumns int, TotalRows int, PrimaryKeyCols varchar(900))    
declare tempCursor cursor for    
select name, id from sysObjects where type='U' and name not like 'dt%'    
open tempCursor        
fetch next from tempCursor into @name, @id        
while(@@fetch_status=0)        
begin        
 set @cnt=0     
 set @sql='select @cnt = count(*) from [' + @name + ']'    
 EXEC sp_executesql @sql, N'@cnt int out', @cnt out         
   
  set @temp=''  
  declare intemp cursor for    
  select a.Column_Name from INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE a, INFORMATION_SCHEMA.TABLE_CONSTRAINTS b where b.constraint_type='PRIMARY KEY' and a.constraint_name = b.constraint_name and a.table_name=ltrim(rtrim(@name))  
  open intemp  
  fetch next from intemp into @pcol  
  while(@@fetch_status=0)        
  begin        
   set @temp=@temp + ',' + @pcol  
   fetch next from intemp into @pcol  
  end  
  close intemp  
  deallocate intemp  
  
 set @temp='''' + substring(@temp,2,900) + ''''  
  
 set @sql='insert into #temptable (tablename, PrimaryKeyCols, TotalRows, TotalColumns) values (''' + @name + ''',' + @temp + ',' + cast(@cnt as varchar) + ','      
 select @cnt=count(*) from sysColumns where id=@id        
 set @sql=@sql + cast(@cnt as varchar) + ')'         
 EXEC sp_executesql @sql    
fetch next from tempCursor into @name, @id        
end      
close tempCursor    
deallocate tempCursor    
    
select * from #tempTable        
drop table #temptable        
set nocount off  
    
  




