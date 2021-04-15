If exists(select * from dbo.sysobjects where id = object_id(N'Verifyerrorlog') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure Verifyerrorlog
go
Create proc Verifyerrorlog
as
begin
set nocount on
set quoted_identifier off
/* Procedure to scan past one hour errorlog for the keyword "Error"
--Vidhya Sagar--kvs1983@gmail.com
--This procedure is for Sqlserver 2000
*/
--TABLE TO COPY ALL DESCRIPTION FROM CURRENT ERRORLOG FILE 
declare @curdate varchar(25)
set @curdate = datepart(hh,getdate())
CREATE TABLE #fullerrlog(Description varchar(500) Not null,contin bit)
insert #fullerrlog
exec master..xp_readerrorlog
set rowcount 7
delete #fullerrlog
set rowcount 0
delete #fullerrlog where substring(description,12,2)<>@curdate-1
delete #fullerrlog where description not like ('%error%') 
select * from #fullerrlog
drop TABLE #fullerrlog
end
--========================================================================

If exists(select * from dbo.sysobjects where id = object_id(N'Verifyerrorlog') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure Verifyerrorlog
GO
Create proc Verifyerrorlog
as
begin
/* Procedure to scan past one hour errorlog for the keyword "Error"
--Vidhya Sagar--kvs1983@gmail.com
--This procedure is for Sqlserver 2005
*/
set nocount on
set quoted_identifier off
declare @curtime varchar(25)
set @curtime=datepart(hh,getdate())
create table #fullerrlog(logdate datetime,proinfo varchar(25), descrip varchar(1000))
insert #fullerrlog
exec master..xp_readerrorlog
set rowcount 11
delete #fullerrlog
set rowcount 0
delete #fullerrlog where datepart(hh,logdate) <> @curtime-1
delete #fullerrlog where descrip not like ('%error%')
select Logdate as 'DATE', descrip as 'Description' from #fullerrlog
drop table #fullerrlog
end
--======================================================================