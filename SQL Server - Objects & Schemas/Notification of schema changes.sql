/*
    
Notification of schema changes

This procedure reports on table schema changes, any new or deleted tables since the previous run of the stored procedure.

It only reports on tables owned by 'dbo' 
 
*/

create procedure usp_dba_schema_ver_cntrl as
BEGIN 
	
 	set nocount on

 	declare @cmd varchar(8000)
	declare @tbl_name sysname
 	declare @current_ver int
 	declare @stored_ver int
 	declare @current_crdate datetime
 	declare @stored_crdate datetime
	declare @cnt int
 	declare @msg varchar(600)
 	declare @status smallint

	declare	@subject 	varchar(255)
	declare @message	varchar(255)
	declare @query  	varchar(800)
	
 	set @status = 0  -- successful status

	if not exists (select name from sysobjects where name = 'dba_SchemaVerCntrl' and xtype = 'U')
		create table dba_SchemaVerCntrl
		(TableName sysname not null,
 		CreateDate datetime not null, 
 		SchemaVersion int not null)

 	
	select @cnt = count(*) from dba_SchemaVerCntrl
	
	
	IF @cnt = 0
	BEGIN
		select @msg = 'Have to initialize dba_SchemaVerCntrl table'
		print @msg
		
		insert into dba_SchemaVerCntrl
		select name, Crdate, schema_ver 
		from sysobjects
		where xtype = 'U'
		and uid = 1
	END
	ELSE
	BEGIN
		create table ##dba_schema(
		tbl_name sysname not null,
		status char not null,
		description varchar(50) null)

		declare tbl_cursor cursor for
   		select name, Crdate, schema_ver 
   		from sysobjects where xtype = 'U'
		and uid = 1
  	
 		open tbl_cursor
  		fetch next from tbl_cursor into @tbl_name, @current_crdate, @current_ver
  		WHILE @@fetch_status = 0
  		BEGIN
   			-- compare the current schema version against the stored schema version
   			select @stored_ver = SchemaVersion, @stored_crdate = CreateDate 
   			from dba_SchemaVerCntrl
   			where TableName = @tbl_name

			IF @@ROWCOUNT = 0 -- no record found, a new table
   			BEGIN
    				select @msg = ' created on ' + convert(varchar(20), @current_crdate)
    				--print @msg
				insert into dba_SchemaVerCntrl
				values (@tbl_name, @current_crdate, @current_ver)
				IF @@ERROR <> 0
     				BEGIN
      					print 'Error inserting into dba_SchemaVerCntrl'
      					set @status = 1
     				END
				insert into ##dba_schema
				values (@tbl_name, 'N', @msg) 
				IF @@ERROR <> 0
     				BEGIN
      					print 'Error inserting into ##dba_schema'
      					set @status = 1
     				END
    
    			END
   			ELSE
			BEGIN  
   				IF @current_crdate <> @stored_crdate or
					@current_ver <> @stored_ver -- values are different
    				BEGIN
     					-- update stored size value
     					update dba_SchemaVerCntrl
     					set CreateDate = @current_crdate,
					SchemaVersion = @current_ver
     					where TableName = @tbl_name
     					IF @@ERROR <> 0
     					BEGIN
      						print 'Error updating dba_SchemaVerCntrl'
      						set @status = 1
     					END
					insert into ##dba_schema
					values(@tbl_name, 'U', null)
					IF @@ERROR <> 0
     					BEGIN
      						print 'Error inserting into ##dba_schema'
      						set @status = 1
     					END
    				END  -- table schema has been changed
    				
   			END  -- matching record found
   
   			fetch next from tbl_cursor into @tbl_name, @current_crdate, @current_ver
  		END  -- end loop
  		close tbl_cursor
  		deallocate tbl_cursor

		-- get a list of deleted objects
		insert into ##dba_schema
		select tablename, 'D', null from dba_SchemaVerCntrl
		where not exists (select * from sysobjects
			where xtype = 'U'
			and uid = 1
			and dba_SchemaVerCntrl.tablename = sysobjects.name)
	
		delete dba_SchemaVerCntrl
		where not exists (select * from sysobjects
			where xtype = 'U'
			and uid = 1
			and dba_SchemaVerCntrl.tablename = sysobjects.name)

		select RTRIM(tbl_name) as 'Table Name',
		case status
		when 'U' then 'Table schema has been changed'
		when 'N' then 'New table ' + RTRIM(description)
		else 'Table has been deleted'
		end as 'Schema Control Status'
		from ##dba_schema
		order by status desc, tbl_name

		IF @@rowcount <> 0  -- send mail
		BEGIN
			SELECT @subject = @@SERVERNAME + ' Database ' + DB_Name() +  ': Schema Control Report for ' + convert( varchar(20), GETDATE()) + char(34)
			SELECT @message = @@SERVERNAME + ' Database ' + DB_Name() + ': Please find attached the Schema Control Report '

			select @query = 'select RTRIM(tbl_name) as ''Table Name'',
			case status
			when ''U'' then ''Table schema has been changed''
			when ''N'' then ''New table '' + RTRIM(description)
			else ''Table has been deleted''
			end as ''Schema Control Status''
			from ##dba_schema
			order by status desc, tbl_name'

			EXEC @status = master..xp_sendmail 
     				@recipients = '<recipients>'
    				,@message = @message
    				,@subject = @subject
    				,@query   = @query
    				,@attach_results = 'false'
    				,@no_header = 'false'
    				,@echo_error = 'true'
    				,@width = 300

		END  -- end send mail
		drop table ##dba_schema
  
	END  -- @cnt <> 0
 	
	
	IF @status <> 0
  		return 1
 
 	return 0
END


GO

