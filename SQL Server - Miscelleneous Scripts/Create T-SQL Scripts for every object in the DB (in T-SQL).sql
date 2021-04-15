/*
Create T-SQL Scripts for every object in the DB (in T-SQL)

This script will create scripts for every database object. This makes it easy to check them in to VSS.

Usage : DMOScriptDatabase 'Databasename','Directoryname'

*/

CREATE procedure dbo.dmoScriptDatabase 
        @pDatabaseName varchar(255), 
        @workingFolder varchar(255), 
        @pInstanceName varchar(30) = null  
as 

-- common 
declare @dmoServer int, 
        @path varchar(255), 
        @cmd varchar(1200), 
        @returnstatus int, 
        @dmoMethod varchar(255), 
        @dmoProperty varchar(255), 
        @dmoCollection varchar(255), 
        @scriptFile varchar(255), 
        @hr int, 
        @hrhex char(10), 
        @OleErrorSource varchar(255), 
        @OleErrorDescription varchar(1000), 
        @scriptType int, 
        @databaseScriptType int, 
        @procedureName sysname, 
        @Processflowerror varchar(255), 
        @pTempFolder varchar(255), 
-- defaults 
        @defaultCount int, 
        @curDefaultNbr int, 
        @defaultName varchar(255), 
-- full text catalog 
        @catalogCount int, 
        @curCatalogNbr int, 
        @catalogName varchar(255), 
-- roles 
        @roleCount int, 
        @curRoleNbr int, 
        @roleName varchar(255), 
        @isFixedRole bit, 
-- rules 
        @ruleCount int, 
        @curRuleNbr int, 
        @ruleName varchar(255), 
-- stored procedures 
        @storedProcedureCount int, 
        @curStoredProcedureNbr int, 
        @storedProcedureName varchar(255), 
        @isSystemStoredProcedure bit, 
        @procedureScriptType int, 
-- user data types 
        @dataTypeCount int, 
        @curDataTypeNbr int, 
        @dataTypeName varchar(255), 
-- user functions 
        @functionCount int, 
        @curFunctionNbr int, 
        @functionName varchar(255), 
-- users 
        @userCount int, 
        @curUserNbr int, 
        @userName varchar(255), 
        @loginName varchar(255), 
        @loginScriptType int, 
        @userScriptType int, 
-- views 
        @viewCount int, 
        @curViewNbr int, 
        @viewName varchar(255), 
        @isSystemView bit, 
        @viewScriptType int 

-- Directory Structure Temp Directory 
Declare @prefix varchar(1000) 
Declare @prefix_fil  varchar (1000) 
Declare @prefix_tab varchar (1000) 
Declare @prefix_cns varchar (1000) 
Declare @prefix_viw varchar (1000) 
Declare @prefix_trg varchar (1000) 
Declare @prefix_rul varchar (1000) 
Declare @prefix_ind varchar (1000) 
Declare @prefix_prc varchar (1000) 
Declare @prefix_udf varchar (1000) 
Declare @prefix_def varchar (1000) 
Declare @prefix_ftc varchar (1000) 
Declare @prefix_rol varchar (1000) 
Declare @prefix_udt varchar (1000) 
Declare @prefix_usr varchar (1000) 
-- Memory Table For logging 
Declare @ActivityLog table 
( id int identity, 
  activity varchar(1000)) 

-- Ok here we begin with the stuff 

set nocount on 
set @Processflowerror = '' 
set @prefix = @workingFolder + '\DB-Framework\' 
set @prefix_fil  = @prefix + '01. Filegroups\' 
set @prefix_tab = @prefix + '02. Tables (only columns)\' 
set @prefix_cns = @prefix + '03. PK + FKs + Constraints\' 
set @prefix_viw = @prefix + '04. Views\' 
set @prefix_trg = @prefix + '06. Triggers\' 
set @prefix_rul = @prefix + '07. Rules\' 
set @prefix_ind = @prefix + '08. Indexes\' 
set @prefix_prc = @prefix + '09. Stored Procedures\' 
set @prefix_udf = @prefix + '10. User Defined Functions\' 
set @prefix_def = @prefix + '11. Defaults\' 
set @prefix_FTC = @prefix + '12. Full Text Catalogs\' 
set @prefix_rol = @prefix + '13. Roles\' 
set @prefix_UDT = @prefix + '14. User Defined Datatypes\' 
set @prefix_USR = @prefix + '15. Database users\' 
-- init 
set @procedureName = db_name() + '.' 
                        + user_name(objectproperty(@@procid,'OwnerId')) 
                        + '.' + object_name(@@procid) 

-- file system project working folder must exist 
set @cmd = 'dir ' + '"'+@workingFolder+'"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                set @cmd = 'MD ' + @workingFolder 
                exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
                if @returnstatus <> 0 
                        begin 
                                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                                set @Processflowerror = 'Could not create working Directory :' + @CMD 
                                goto ErrorHandler 
                        end 
                else 
                        begin 
                           insert @ActivityLog (activity) values ('Working directory sucessfully created') 
                        end 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Target directory sucessfully located') 
        end 

-- The Target Direcory does Exist now kill all the files in it 

set @cmd = 'RMDIR ' + '"'+@workingFolder + '\"' + ' /q /s' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not delete Target Directory :' + @CMD 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Target directory sucessfully deleted') 
        end 

-- Create the Dir structure 

set @cmd = 'MD ' + '"' + @prefix_fil + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create filegoups Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Filegroup directory sucessfully created') 
        end 

set @cmd = 'MD ' +'"' +  @prefix_tab + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Table Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Table directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_cns + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Constraints Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Constraints directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_viw + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Views Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('View directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_trg + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Trigger Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Trigger directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_rul + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Rules Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Rules directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_ind + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Index Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Index directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_prc + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Stored Procedure Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Stored Procedure directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_udf + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create User defined functions Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('User defined functions Procedure directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_def + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Defaults Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Defaults directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_ftc + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Full Text Catalog Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Full Text Catalog  directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_rol + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create Roles Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('Roles Catalog  directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_udt + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create User defined Datatypes Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('User defined Datatypes directory sucessfully created') 
        end 

set @cmd = 'MD ' + '"' + @prefix_usr + '"' 
exec @returnstatus = master.dbo.xp_cmdshell @CMD, no_output 
if @returnstatus <> 0 
        begin 
                raiserror (59007,16,1,@procedureName, @pTempFolder,@@servername) 
                set @Processflowerror = 'Could not create User Directory :' + @CMD 
                goto ErrorHandler 
        end 
else 
        begin 
           insert @ActivityLog (activity) values ('User directory sucessfully created') 
        end 

set @path = @workingFolder 



-- new file, script drop object and create object 
set @scriptType         = 1             -- drop 
                        + 4             -- primary object 
                        + 64            -- to file only 
                        + 4096          -- if not exists 
                        + 262144        -- owner qualify 

-- database script type - non destructive 
set @databaseScriptType         = 4             -- primary object 
                                + 64            -- to file only 
                                + 4096          -- if not exists 

-- new file, script create object only 
set @loginScriptType           =  4             -- primary object 
                                + 64            -- to file only 
                                + 4096          -- if not exists 

-- new file, script create object only 
set @userScriptType             = 1             -- drop 
                                + 4             -- primary object 
                                + 64            -- to file only 
                                + 256           -- append (login script will create)     
                                + 4096          -- if not exists 

-- script drop object, create object, and permissions 
set @procedureScriptType        = 1             -- drop 
                                + 2             -- object permissions 
                                + 4             -- primary object 
                                + 32            -- database permissions 
                                + 64            -- to file only 
                                + 4096          -- if not exists 
                                + 262144        -- owner qualify 

-- script drop object, create object, and permissions 
set @viewScriptType             = 1             -- drop 
                                + 2             -- object permissions 
                                + 4             -- primary object 
                                + 32            -- database permissions 
                                + 64            -- to file only 
                                + 4096          -- if not exists 
                                + 262144        -- owner qualify 



-- open an in-process COM/DMO connection to this server 
exec @hr = master.dbo.sp_OACreate       'SQLDMO.SQLServer', 
                                        @dmoServer OUT 
if @hr <> 0 
        goto ErrorHandler 

-- set the security context to integrated 
exec @hr = master.dbo.sp_OASetProperty  @dmoServer, 
                                        'loginSecure', 
                                        1 -- NT Authentication 
if @hr <> 0 
        goto ErrorHandler 

-- connect to the specified server 
exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                        'Connect', 
                                        NULL, 
                                        @@servername 
if @hr <> 0 
        goto ErrorHandler 

-- script each object to a separate file 
-- database 
select @dmoMethod       = 'Databases("' + @pDatabaseName + '").Script' 
select @scriptFile      = @prefix_fil +@pdatabasename+'.Db' 
exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                        @dmoMethod, 
                                        NULL, 
                                        @databaseScriptType, 
                                        @scriptFile 
if @hr <> 0 goto ErrorHandler 
insert @ActivityLog (activity) values ('Database Successfully scripted') 
-- defaults 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Defaults.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@defaultCount OUT 
if @hr <> 0     goto ErrorHandler 
set @curDefaultNbr = 1 
while @curDefaultNbr <= @defaultCount 
        begin 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Defaults.Item('  + cast(@curDefaultNbr as varchar(10))+ ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@defaultName OUT 
                if @hr <> 0 goto ErrorHandler 
                select @dmoMethod       = 'Databases("' + @pDatabaseName + '").Defaults("' + @defaultName + '").Script' 
                select @scriptFile      = @prefix_def + @defaultName + '.def' 
                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                        @dmoMethod, 
                                                        NULL, 
                                                        @scriptType, 
                                                        @scriptFile 
                if @hr <> 0 goto ErrorHandler 
                select @curDefaultNbr = @curDefaultNbr + 1 
      end 
insert @ActivityLog (activity) values ('Defaults Successfully scripted') 
-- full text catalogs 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").FullTextCatalogs.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                        @dmoProperty, 
                                        @catalogCount OUT 
if @hr <> 0     goto ErrorHandler 
set @curCatalogNbr = 1 
while @curCatalogNbr <= @catalogCount 
        begin 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").FullTextCatalogs.Item('  + cast(@curCatalogNbr as varchar(10))+ ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                                        @dmoProperty, 
                                                        @catalogName OUT 
                if @hr <> 0 goto ErrorHandler 
                select @dmoMethod       = 'Databases("' + @pDatabaseName + '").FullTextCatalogs("' + @catalogName + '").Script'

                select @scriptFile      = @prefix_def   + @catalogName  + '.cat' 
                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                        @dmoMethod, 
                                                        NULL, 
                                                        @scriptType, 
                                                        @scriptFile 
                if @hr <> 0                     goto ErrorHandler 
                select @curCatalogNbr = @curCatalogNbr + 1 
      end 
insert @ActivityLog (activity) values ('FullTextCatalogs Successfully scripted') 
-- roles 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").DatabaseRoles.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                        @dmoProperty, 
                                        @roleCount OUT 
if @hr <> 0 goto ErrorHandler 
set @curRoleNbr = 1 
while @curRoleNbr <= @RoleCount 
        begin 
                -- fixed roles cannot be removed so don't try to script 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").DatabaseRoles.Item(' + cast(@curRoleNbr as varchar(10))  + ').IsFixedRole'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                                        @dmoProperty, 
                                                        @isFixedRole OUT 
                if @hr <> 0 goto ErrorHandler 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").DatabaseRoles.Item(' + cast(@curRoleNbr as varchar(10))  + ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                                        @dmoProperty, 
                                                        @roleName OUT 
                if @hr <> 0 goto ErrorHandler 
                if @isFixedRole = 0 and @roleName <> 'Public' 
                        begin 
                                select @dmoMethod       = 'Databases("' + @pDatabaseName + '").DatabaseRoles("' + @roleName+ '").Script'

                                select @scriptFile      = @prefix_rol + @roleName + '.rol' 
                                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                                        @dmoMethod, 
                                                                        NULL, 
                                                                        @scriptType, 
                                                                        @scriptFile 
                                if @hr <> 0 goto ErrorHandler 
                        end 
                select @curRoleNbr = @curRoleNbr + 1 
      end 
insert @ActivityLog (activity) values ('Roles Successfully scripted') 
-- rules 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Rules.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@ruleCount OUT 
if @hr <> 0 goto ErrorHandler 
set @curRuleNbr = 1 
while @curRuleNbr <= @RuleCount 
        begin 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Rules.Item(' + cast(@curRuleNbr as varchar(10))  + ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                                        @dmoProperty, 
                                                        @ruleName OUT 
                if @hr <> 0 goto ErrorHandler 
                select @dmoMethod       = 'Databases("' + @pDatabaseName + '").Rules("' + @ruleName + '").Script' 
                select @scriptFile      = @prefix_rul+@ruleName + '.rul' 
                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                        @dmoMethod, 
                                                        NULL, 
                                                        @scriptType, 
                                                        @scriptFile 
                if @hr <> 0 goto ErrorHandler 
                select @curRuleNbr = @curRuleNbr + 1 
      end 
insert @ActivityLog (activity) values ('Rules Successfully scripted') 
-- stored procedures 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").StoredProcedures.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@storedProcedureCount OUT 
if @hr <> 0 goto ErrorHandler 
set @curStoredProcedureNbr = 1 
while @curStoredProcedureNbr <= @StoredProcedureCount 
        begin 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").StoredProcedures.Item(' + cast(@curStoredProcedureNbr as varchar(5)) + ').SystemObject'        

                exec @hr = master..sp_OAGetProperty     @dmoServer, 
                                                        @dmoProperty, 
                                                        @isSystemStoredProcedure OUT 
                if @hr <> 0 goto ErrorHandler 
                if @isSystemStoredProcedure = 0 
                        begin 
                                -- get the name 
                                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").StoredProcedures.Item('  + cast(@curStoredProcedureNbr as varchar(10))+ ').Name'

                                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@storedProcedureName OUT

                                if @hr <> 0 goto ErrorHandler 
                                select @dmoMethod       = 'Databases("' 
                                                        + @pDatabaseName 
                                                        + '").StoredProcedures("' 
                                                        + @StoredProcedureName 
                                                        + '").Script' 

                                select @scriptFile      = @prefix_prc+ @StoredProcedureName + '.prc' 
                                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                                        @dmoMethod, 
                                                                        NULL, 
                                                                        @ProcedureScriptType, 
                                                                        @scriptFile 
                                if @hr <> 0 goto ErrorHandler 
                        end 
                select @curStoredProcedureNbr = @curStoredProcedureNbr + 1 
      end 
insert @ActivityLog (activity) values ('Stored procedures Successfully scripted') 
-- user data types 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").UserDefinedDataTypes.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@dataTypeCount OUT 
if @hr <> 0 goto ErrorHandler 
set @curDataTypeNbr = 1 
while @curDataTypeNbr <= @dataTypeCount 
        begin 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").UserDefinedDataTypes.Item(' + cast(@curDataTypeNbr as varchar(10))+ ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@dataTypeName OUT 
                if @hr <> 0 goto ErrorHandler 
                select @dmoMethod       = 'Databases("' 
                                        + @pDatabaseName 
                                        + '").UserDefinedDataTypes("' 
                                        + @dataTypeName 
                                        + '").Script' 
                select @scriptFile      = @prefix_udt + @dataTypeName   + '.udt' 
                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                        @dmoMethod, 
                                                        NULL, 
                                                        @scriptType, 
                                                        @scriptFile 
                if @hr <> 0 goto ErrorHandler 
                select @curDataTypeNbr = @curDataTypeNbr + 1 
      end 
insert @ActivityLog (activity) values ('User defined datatypes Successfully scripted') 
-- user functions (sql2000 or greater) 
select @dmoProperty     = 'Databases("' 
                        + @pDatabaseName 
                        + '").UserDefinedFunctions.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer, 
                                        @dmoProperty, 
                                        @functionCount OUT 
if @hr <> 0 
        goto ErrorHandler 
set @curFunctionNbr = 1 
while @curFunctionNbr <= @functionCount 
        begin 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").UserDefinedFunctions.Item(' + cast(@curFunctionNbr as varchar(10))+ ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@functionName OUT 
                if @hr <> 0 goto ErrorHandler 
                select @dmoMethod       = 'Databases("' 
                                        + @pDatabaseName 
                                        + '").UserDefinedFunctions("' 
                                        + @functionName 
                                        + '").Script' 
                select @scriptFile      = @prefix_udf+ @functionName + '.udf' 
                exec @hr = master.dbo.sp_OAMethod       @dmoServer,@dmoMethod,NULL,@scriptType,@scriptFile 
                if @hr <> 0 goto ErrorHandler 
                select @curFunctionNbr = @curFunctionNbr + 1 
      end 
insert @ActivityLog (activity) values ('User defined functions Successfully scripted') 
-- users 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Users.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@userCount OUT 
if @hr <> 0 goto ErrorHandler 
set @curUserNbr = 1 
while @curUserNbr <= @userCount 
        begin 
                -- get the name 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Users.Item(' + cast(@curUserNbr as varchar(10))  + ').Name'

                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@userName OUT 
                if @hr <> 0 goto ErrorHandler 
                if @userName <> 'guest' 
                        begin 
                                -- get the login name 
                                select @dmoProperty     = 'Databases("'+ @pDatabaseName + '").Users.Item(' + cast(@curUserNbr as varchar(10))+ ').Login'

                                exec @hr = master.dbo.sp_OAGetProperty @dmoServer, @dmoProperty, @loginName OUT 
                                        if @hr <> 0 goto ErrorHandler 
                                -- start the file with the login script but do not drop existing 
                                if @loginName is not null 
                                        begin 
                                                select @scriptFile      = @prefix_usr + replace(@userName ,'\','~') + '.usr'

                                                select @dmoMethod       = 'Logins("' 
                                                                        + @loginName 
                                                                        + '").Script' 
                                                        exec @hr = master.dbo.sp_OAMethod       
                                                                                @dmoServer, 
                                                                                @dmoMethod, 
                                                                                NULL, 
                                                                                @loginScriptType, 
                                                                                @scriptFile 
                                                if @hr <> 0 goto ErrorHandler 
                                        end 
                                -- append the user script 
                                select @dmoMethod       = 'Databases("' 
                                                        + @pDatabaseName 
                                                        + '").Users("' 
                                                        + @userName 
                                                        + '").Script' 
                                select @scriptFile      = @prefix_usr+ replace(@userName ,'\','~')+ '.usr' 
                                exec @hr = master.dbo.sp_OAMethod @dmoServer,@dmoMethod,NULL,@userScriptType,@scriptFile

                                if @hr <> 0 goto ErrorHandler 
                        end 
                select @curUserNbr = @curUserNbr + 1 
        end 
insert @ActivityLog (activity) values ('Users Successfully scripted') 
-- views 
select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Views.Count' 
exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@viewCount OUT 
if @hr <> 0 goto ErrorHandler 
set @curViEwNbr = 1 
while @curViewNbr <= @viewCount 
        begin 
                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Views.Item(' + cast(@curViewNbr as varchar(5)) + ').SystemObject'        

                exec @hr = master..sp_OAGetProperty     @dmoServer,@dmoProperty,@isSystemView OUT 
                if @hr <> 0 goto ErrorHandler 
                if @isSystemView = 0 
                        begin 
                                -- get the name 
                                select @dmoProperty     = 'Databases("' + @pDatabaseName + '").Views.Item(' + cast(@curViewNbr as varchar(10))  + ').Name'

                                exec @hr = master.dbo.sp_OAGetProperty  @dmoServer,@dmoProperty,@viewName OUT 
                                if @hr <> 0 goto ErrorHandler 
                                select @dmoMethod       = 'Databases("' 
                                                        + @pDatabaseName 
                                                        + '").Views("' 
                                                        + @viewName 
                                                        + '").Script' 
                                select @scriptFile      = @prefix_viw + @viewName + '.viw' 
                                exec @hr = master.dbo.sp_OAMethod       @dmoServer, 
                                                                        @dmoMethod, 
                                                                        NULL, 
                                                                        @viewScriptType, 
                                                                        @scriptFile 
                                if @hr <> 0 goto ErrorHandler 
                        end 
                select @curViewNbr = @curViewNbr + 1 
end 
insert @ActivityLog (activity) values ('Views Successfully scripted') 

-- close and cleanup the COM/DMO database connection 
exec @hr = master.dbo.sp_OAMethod @dmoServer,'DisConnect' 
if @hr <> 0 
        goto ErrorHandler 
exec @hr = master.dbo.sp_OADestroy @dmoServer 
if @hr <> 0 
        goto ErrorHandler 
-- audit completion 
select * from @Activitylog 
return 

ErrorHandler: 
insert @ActivityLog (activity) values ('Command Was :'+@Processflowerror) 
if (@hr is not null) 
        begin   
                exec master.dbo.sp_OAGetErrorInfo       @dmoServer, 
                                                        @OleErrorSource OUT, 
                                                        @OleErrorDescription OUT 
                
                insert @ActivityLog (activity) 
                select @procedureName + ' ' + @pDatabaseName 
                        + ' ended with error: ' + cast(@hr as varchar(20)) + ' 
                        OLE ERROR: ' 
                --+ isnull(Admin.dbo.binToHex (@hr),'not defined') no function in 7 so skip conversion of error number 
                + cast(@hr as varchar(20)) + ' 
                        Source: ' + isnull(@OleErrorSource,'unknown') + ' 
                        Description: ' + isnull(@OleErrorDescription,'unknown') 

                -- still need to cleanup 
                exec master.dbo.sp_OAMethod @dmoServer,'DisConnect' 
                exec master.dbo.sp_OADestroy @dmoServer 

                raiserror (59001,16,1,@procedureName) 
        end 
else 
        if @cmd is not null 
                begin 
                        insert @ActivityLog (activity) 
                        select @procedureName + ' ' + @pDatabaseName 
                                + ' ' + isNull(@pTempFolder,'') 
                                + ' failed with returnstatus ' 
                                + cast(@returnstatus as varchar(10)) + ' at: ' + @cmd 
                        raiserror(59001,16,1,@procedureName) 
                end 
        else 
                raiserror (59000,16,1,@procedureName) 
select * from @activitylog 
return -1 

GO




