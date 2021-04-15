DROP PROCEDURE hx_ShowFixedDriveSpace
go
/* 	input:	None
	output:	Table format
	Desc:	Very simple, how much space is free on the hard drives of the SQL Server you are connected to.
	Warnings: None.
*/

CREATE PROCEDURE hx_ShowFixedDriveSpace AS

set nocount on
exec master..xp_fixeddrives
