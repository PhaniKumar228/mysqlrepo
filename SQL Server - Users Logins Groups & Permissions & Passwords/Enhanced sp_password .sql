/*
Enhanced sp_password 

For SQL Server in Mixed Authentication mode this stored procedure helps to validate users password. 
Currently this procedure checks for the next requrements: password must have length at least 8 characters 
plus among them at least one digit and at least one of the characters must be in upper case.
*/

/***************************************************************************
	Script to validate user input for password change

	Based on original Microsoft SQl Server stored procedure sp_password
	with modifications.

	For SQL Server in Mixed Authentication mode this stored procedure 
	will help to control modifications of users passwords. 

	Currently procedure checks for next requrements: 
	password must have length at least 8 characters plus among them 
	at least one digit and at least one of the characters must be in upper case.

****************************************************************************/

use master
go

sp_configure 'allow update', 1
go

RECONFIGURE WITH OVERRIDE
go

alter procedure sp_password
    @old sysname = NULL,        -- the old (current) password
    @new sysname,               -- the new password
    @loginame sysname = NULL    -- user to change password on
as
    -- SETUP RUNTIME OPTIONS / DECLARE VARIABLES --
	set nocount on
	declare @self int
    	select @self = CASE WHEN @loginame is null THEN 1 ELSE 0 END

    -- RESOLVE LOGIN NAME
    if @loginame is null
        select @loginame = suser_sname()

    -- CHECK PERMISSIONS (SecurityAdmin per Richard Waymire) --
	IF (not is_srvrolemember('securityadmin') = 1)
        AND not @self = 1
	begin
	   dbcc auditevent (107, @self, 0, @loginame, NULL, NULL, NULL)
	   raiserror(15210,-1,-1)
	   return (1)
	end
	ELSE
	begin
	   dbcc auditevent (107, @self, 1, @loginame, NULL, NULL, NULL)
	end

    -- DISALLOW USER TRANSACTION --
	set implicit_transactions off
	IF (@@trancount > 0)
	begin
		raiserror(15002,-1,-1,'sp_password')
		return (1)
	end

    -- RESOLVE LOGIN NAME (disallows nt names)
    if not exists (select * from master.dbo.syslogins where
                    loginname = @loginame and isntname = 0)
	begin
		raiserror(15007,-1,-1,@loginame)
		return (1)
	end

	-- IF non-SYSADMIN ATTEMPTING CHANGE TO SYSADMIN, REQUIRE PASSWORD (218078) --
	if (@self <> 1 AND is_srvrolemember('sysadmin') = 0 AND exists
			(SELECT * FROM master.dbo.syslogins WHERE loginname = @loginame and isntname = 0
				AND sysadmin = 1) )
		SELECT @self = 1

    -- CHECK OLD PASSWORD IF NEEDED --
    if (@self = 1 or @old is not null)
        if not exists (select * from master.dbo.sysxlogins
                        where srvid IS NULL and
						      name = @loginame and
			                  ( (@old is null and password is null) or
                              (pwdcompare(@old, password, (CASE WHEN xstatus&2048 = 2048 THEN 1 ELSE 0 END)) = 1) )   )
        begin
		    raiserror(15211,-1,-1)
		    return (1)
	    end
	-- =========================================================================================
    -- D.Bobkov - change for VALIDATE USER INPUT ===============================================
    -- as example using: minimum length - 8 char, minimum 1 number and minimum 1 capital letter in it...
    -- Perform comparision of @new
	declare @NumPos int
	declare @CapsPos int
	declare @position int
	declare @CharValue int

	SET @position = 1
	SET @NumPos = 0
	SET @CapsPos = 0

	WHILE @position <= DATALENGTH(@new)
	   BEGIN
		SET @CharValue = ASCII(SUBSTRING(@new, @position, 1))
		IF ( @CharValue > 47 AND @CharValue < 58)
			SET @NumPos = @NumPos + 1
		ELSE IF ( @CharValue > 64 AND @CharValue < 91)
			SET @CapsPos = @CapsPos + 1
	   	SET @position = @position + 1
	   END
	IF DATALENGTH(CAST(@new AS varchar(20))) < 8 
	begin
		raiserror('Password length is less than 8 chars', 16, 1)
		return (1)
	end

	IF @NumPos < 1
	begin
		raiserror('Password must have at least one digit', 16, 1) 
		return (1)
	end
	
	IF @CapsPos < 1 
	begin
		raiserror('Password must have at least one character in upper case', 16, 1)
		return (1)
	end
    -- END OF D.Bobkov change ===================================================================
	-- ==========================================================================================
    -- CHANGE THE PASSWORD --
    update master.dbo.sysxlogins
	set password = convert(varbinary(256), pwdencrypt(@new)), xdate2 = getdate(), xstatus = xstatus & (~2048)
	where name = @loginame and srvid IS NULL

	-- UPDATE PROTECTION TIMESTAMP FOR MASTER DB, TO INDICATE SYSLOGINS CHANGE --
	exec('use master grant all to null')

    -- FINALIZATION: RETURN SUCCESS/FAILURE --
	if @@error <> 0
        return (1)
    raiserror(15478,-1,-1)
	return  (0)	-- sp_password

GO

update sysobjects set
    base_schema_ver = 0,
    status = status | 0xC0000001
    where name = 'sp_password'
go

sp_configure "allow update", 0
go

RECONFIGURE WITH OVERRIDE
go

GRANT EXECUTE ON [dbo].[sp_password] TO [public]
go

