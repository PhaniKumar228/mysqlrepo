create procedure sp_displaylogin @loginname varchar(1000)
as
set nocount on
-- this procedure takes a sql login name and returns information about the login.
-- anyone who knows Sybase will recognise the name and layout. use :- 
-- exec sp_displaylogin 'loginname' to get login information returned.

-- this procedure has been tested on SQL Server 2005 sp2
-- any problems email pgr_consulting @ yahoo.com

declare @principal_id int, @user_name varchar(1000), @default_database_name varchar(1000), 
        @default_language_name varchar(1000) ,  @is_disabled int, 
        @is_policy_checked bit, @is_expiration_checked bit, @msg varchar(1000), @number_of_roles int,
        @counter int, @role_name varchar(100)

select @principal_id=principal_id , @user_name=name, @default_database_name =default_database_name , 
       @default_language_name=default_language_name,  @is_disabled=is_disabled, 
       @is_policy_checked=is_policy_checked, @is_expiration_checked=is_expiration_checked
from sys.sql_logins
where name = @loginname

select @msg='Id: ' + cast(@principal_id as varchar(100))
print @msg
select @msg='Loginname: ' + @user_name
print @msg
select @msg='Default Database: ' + @default_database_name
print @msg
select @msg='Default Language: ' + @default_language_name
print @msg

create table #roles (role_id int identity (1,1), role_name varchar(1000))

insert into #roles
select sp2.name 
from
sys.server_role_members srm, sys.server_principals sp1, sys.server_principals sp2
where 
srm.member_principal_id = sp1.principal_id
and srm.role_principal_id = sp2.principal_id
and sp1.principal_id = @principal_id
select @msg = 'Configured Authorization:'
print @msg
select @number_of_roles = count(*) from #roles
select @counter=1
while @counter <= @number_of_roles
begin
    select @role_name = role_name from #roles  where role_id = @counter
    select @msg = '        ' + @role_name + ' (default OFF)'
    print @msg
    select @counter=@counter+1
end

select @msg='Enabled: ' + cast((case @is_disabled when 0 then 'Yes' else 'No' END) as varchar(100))
print @msg
select @msg='Is Policy Checked: ' + cast((case @is_policy_checked when 0 then 'No' else 'Yes' END) as varchar(100))
print @msg
select @msg='Is Expiration Checked: ' + cast((case @is_expiration_checked when 0 then 'No' else 'Yes' END) as varchar(100))
print @msg

drop table #roles
go