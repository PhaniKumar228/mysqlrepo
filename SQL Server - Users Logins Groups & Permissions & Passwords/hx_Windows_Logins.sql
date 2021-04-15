drop procedure hx_Windows_Logins
go
/* 	input:	None
	output:	Table format
	Desc:	Display only windows logins for SQL Server.
	Warnings: None.
*/
CREATE procedure hx_Windows_Logins as

set nocount on
create table #tempNT (
[account name] varchar(55),
type varchar(25),
privilege varchar (25),
[mapped login name] varchar (66),
[permission path] varchar(66)
)

insert into #tempNT([account name],type,privilege,[mapped login name],[permission path])
EXEC master..xp_logininfo 'BUILTIN\Administrators',@option = 'members' 

select [account name],type,privilege,[mapped login name] from #tempNT

Drop table #tempNT
