/*
    
Trigger Generator for data audit

This Procedure generates 3 triggers (for Insert, Update & delete). 
The purpose of these triggers is to keep a SIMPLE audit trail. 
Create the table and the procedure in the database to which you want to have the auditing facility. 
To include a table for auditing run the procedure with Table Name as the parameter.  
 
*/

/*
p_GenerateTrigger

The SP creates Insert, Update and Delete triggers on a table for auditing.
This procedure should be created with the table in the current database

Parameter:
  @TableName : Name of the table Where the triggers to be created.
 			If it is in another schema it should be written in <Schema>.<Table> format and should be
               entered with sigle quotes.
  @Verbose   : verbose mode default =0 (In verbose mode the triggers are not created. But they are printed.

Assumptions  : The table has a primary key
Known Issues :	Multiple rows could be modified in single Update statement provided that the Primary key  
			is not updated. In case of Primary key updation Only one row should be updated at a time.
			If more than one row is updated with a single Update statement and if the Primary key is
			modified The Logtable keeps Cartesian Product.
Solution     : Include an identity field and make it primary.

*/

if exists (select * from sysobjects where id = object_id(N'p_GenerateTrigger'))
DROP Procedure p_GenerateTrigger
GO

if exists (select * from sysobjects where id = object_id(N'LogTable'))
drop table LogTable
GO
CREATE TABLE LogTable (
	LOG_ID bigint IDENTITY (1, 1) NOT NULL ,
	LOG_Table varchar (80) NOT NULL ,
	LOG_Condition varchar (2000) NULL ,
	LOG_ConditionD varchar (2000) NULL ,
	LOG_Action char (1) NOT NULL ,
	LOG_Date datetime NOT NULL Default (GetDate()),
	LOG_User varchar(50) NOT NULL Default(CURRENT_USER),
	LOG_Application Varchar(100) NOT NULL Default(APP_NAME())
)
GO


CREATE Procedure p_GenerateTrigger
@TableName sysname, @Verbose bit=0   
AS    
DECLARE @Body_G nvarchar(1000), @Body_I nvarchar(4000), @Body_U nvarchar(4000),  @Body_D nvarchar(4000)    
DECLARE @PreCond nvarchar(200), @EquCond nVarchar(1000), @InEquCond nvarchar(1000)  
DECLARE @Cond_U nvarchar(1000), @Cond_D nvarchar(1000), @Keys nvarchar(900)  
DECLARE @Table sysname, @Schema sysname    
DECLARE @Column sysname, @DataType Sysname, @IsIdentity bit    
SELECT @Table =PARSENAME(@TableName,1), @Schema=ISNULL(PARSENAME(@TableName, 2), CURRENT_USER), @IsIdentity=0    
    
SELECT @Body_G='    
IF EXISTS (SELECT * FROM SysObjects WHERE Type = ''TR'' AND id = Object_id('''+@Schema+'.iTR_Audit_'    
+@Table    
+'''))     
Drop Trigger '+@Schema+'.iTR_Audit_'+@Table+'
    
IF EXISTS (SELECT * FROM SysObjects WHERE Type = ''TR'' AND id = Object_id('''+@Schema+'.uTR_Audit_'    
+@Table    
+'''))     
Drop Trigger '+@Schema+'.uTR_Audit_'+@Table+'
    
IF EXISTS (SELECT * FROM SysObjects WHERE Type = ''TR'' AND id = Object_id('''+@Schema+'.dTR_Audit_'    
+@Table    
+'''))     
Drop Trigger '+@Schema+'.dTR_Audit_'+@Table+'
   ' 
  
Select @Body_I ='', @Body_U ='', @Body_D ='',    
	  @EquCOnd ='', @InEquCond ='', @PreCond='',   
	  @Cond_U='', @Cond_D ='', @Keys =''    
    
select @Body_I ='Create Trigger iTR_Audit_'+@Table +' ON '+ @TableName +'    
For Insert     
As     
', @Body_U='Create Trigger uTR_Audit_'+@Table +' ON '+@TableName+ '    
For Update     
As    
', @Body_d='Create Trigger dTR_Audit_'+@Table+' ON '+@TableName+'    
For Delete    
As    
'    

Select @Keys= @Keys +', ['+ COL_Name(Object_ID(@TableName), k.COLID)+']' 
from sysIndexKeys k, sysindexes I
Where i.id=object_ID(@TableName)  and 
     i.id = k.id and i.indid=k.indid and 
     i.status & 0x800 =0x800
order by keyno
--Select @keys
IF LEN(@Keys)>1
	select @Keys = SUBSTRING(@Keys, 3, LEN(@Keys)-2) 
ELSE
  	BEGIN
	PRINT 'No Primary Keys are available to handle the operation'
	RETURN
	END

IF CharIndex(', [', @Keys, 2)=0 --there is only one field now check whether it is identity
BEGIN
IF Exists(Select * from syscolumns where name =Substring(@Keys,2, LEn(@Keys)-2) and autoval is not null)
   Set @IsIdentity=1
END
 
 
Declare FieldList Cursor FOR    
Select COLUMN_NAME, DATA_TYPE from Information_Schema.Columns Where TABLE_Name =@Table and TABLE_SCHEMA=@Schema and Data_Type <> 'TimeStamp'    
Open FieldList    
FETCH NEXT FROM FieldList INTO @Column, @DataType    
WHILE @@FETCH_STATUS=0    
BEGIN    
    
	IF CHARINDEX(''+@Column+'', @Keys)>0     
		SELECT @Cond_U =@Cond_U+ '+'' AND ' +@Column +' = ''+'+    
		CASE     
		WHEN @DataType in ('Smalldatetime', 'DateTime') THEN     '
		  ''''''''+ Convert(Varchar(30), I.'+ @Column +', 113)+''''''''    
		  '    
		WHEN @DataType in ('bigint','bit','BINARY', 'varbinary', 'int', 'smallint', 'tinyint', 'real', 'decimal', 'float', 'money', 'numeric') THEN     
		'  Convert(Varchar(35), I.'+ @Column +')    
		   '    
		ELSE     
		'  ''''''''+I.'+ @Column + '+''''''''    
		   '    
		END,
			@EquCond = @EquCond+ ' AND I.'+ @Column +' = D.'+@Column,
			@InEquCond = @InEquCond+ ' AND I.'+ @Column +' <> D.'+@Column,
			@PreCond = @preCond+' AND Update('+ @Column+')',
			 @Cond_d =@Cond_d+ '+'' AND ' +@Column +' = ''+'+    
		CASE     
		WHEN @DataType in ('Smalldatetime', 'DateTime') THEN     '
		  ''''''''+ Convert(Varchar(30), D.'+ @Column +', 113)+''''''''    
		  '    
		WHEN @DataType in ('bigint','bit','BINARY', 'varbinary', 'int', 'smallint', 'tinyint', 'real', 'decimal', 'float', 'money', 'numeric') THEN     
		'  Convert(Varchar(35), D.'+ @Column +')    
		   '    
		ELSE     
		'  ''''''''+D.'+ @Column + '+''''''''    
		   '    
		END
	FETCH NEXT FROM FieldList INTO @Column, @DataType    
	    
END    
CLOSE FieldList    
    
deallocate FieldList    
IF LEN(@Cond_D)>7
	SELECT @Cond_D  = ''''+SUBSTRING(@Cond_D,   8, LEN(@Cond_D )-7)
IF LEN(@Cond_U)>7
	SELECT @Cond_U  = ''''+SUBSTRING(@Cond_U,   8, LEN(@Cond_U )-7)
IF LEN(@PreCond)>5
	SELECT @PreCond= 'IF '+ SUBSTRING(@PreCond, 6, LEN(@PreCond)-5)
IF LEN(@EquCond)>5
	SELECT @EquCond= ' WHERE '+ SUBSTRING(@EquCond, 6, LEN(@EquCond)-5)
IF LEN(@InEquCond)>5
	SELECT @InEquCond= 'WHERE '+ SUBSTRING(@InEquCond, 6, LEN(@InEquCond)-5)

  
select @Body_I = @Body_I + 'IF EXISTS (Select * from Inserted)      
Insert into LogTable (LOG_Table, LOG_Condition, LOG_Action)  
Select '''+@Table+''', '+@Cond_U+',''I'' from Inserted I  
'    
IF @IsIdentity=0
SELECT @Body_U =@Body_U + 'IF EXISTS (Select * from Inserted)      
'+@PreCond +'
Insert into LogTable (LOG_Table, LOG_Condition, LOG_ConditionD, LOG_Action)  
Select '''+@Table+''', '+@Cond_U+','+@Cond_D+',''U'' from Inserted I, Deleted D   
'+@InEquCond+'
ELSE    
Insert into LogTable (LOG_Table, LOG_Condition, LOG_ConditionD, LOG_Action)  
Select '''+@Table+''', '+@Cond_U+','+@Cond_D+',''U'' from Inserted I, Deleted D   
'+@EquCond
Else
SELECT @Body_U =@Body_U + 'Insert into LogTable (LOG_Table, LOG_Condition, LOG_ConditionD, LOG_Action)  
Select '''+@Table+''', '+@Cond_U+','+@Cond_D+',''U'' from Inserted I, Deleted D   
'+@EquCond

Select @Body_D = @Body_D+'IF EXISTS (Select * from Deleted)      
Insert into LogTable (LOG_Table, LOG_ConditionD, LOG_Action)  
Select '''+@Table+''', '+@Cond_D+',''D'' from Deleted D  
'    
If @Verbose=1
BEGIN
Print @Body_G+'
GO'
Print @Body_I+'
GO'
Print @Body_U+'
GO'
Print @Body_D+'
GO'
END 
ELSE
BEGIN
Execute sp_ExecuteSQL @Body_G
Execute sp_ExecuteSQL @Body_I    
Execute sp_ExecuteSQL @Body_U    
Execute sp_ExecuteSQL @Body_D    
END
GO




