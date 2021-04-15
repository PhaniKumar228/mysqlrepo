use master
go

CREATE procedure run1hourtrace @folder varchar(200)
as
/*
Creates 1 hour trace + folder based on date and time
*/
set nocount on

declare @date char(8) ; set @date = convert(char(8),getdate(),112)
declare @time char(4) ; set @time = cast(replace(convert(varchar(5),getdate(),108),':','') as char(4))
declare @stop datetime ; set @stop = dateadd(hh,1,getdate())
declare @rc int
declare @TraceID int
declare @file nvarchar(100)
declare @maxfilesize bigint ; set @maxfilesize = 50
declare @cmd varchar(2000)
declare @msg varchar(200)

If right(@folder,1)<>'\' set @folder = @folder + '\'

--create trace folder
set @cmd = 'mkdir ' +@folder+@date+@time
exec @rc = master..xp_cmdshell @cmd,no_output
if (@rc != 0) 
begin
   set @msg = 'Error creating trace folder : ' + cast(@rc as varchar(10))
   raiserror(@msg,10,1)
   return(-1)
end

set @file = @folder+@date+@time+'\trace'

exec @rc = sp_trace_create @TraceID output, 2, @file, @maxfilesize, @stop
if (@rc != 0) 
begin
   set @msg = 'Error creating trace : ' + cast(@rc as varchar(10))
   raiserror(@msg,10,1)
   return(-1)
end

-- change below to customise trace

declare @on bit
set @on = 1
exec sp_trace_setevent @TraceID, 10, 1, @on
exec sp_trace_setevent @TraceID, 10, 3, @on
exec sp_trace_setevent @TraceID, 10, 6, @on
exec sp_trace_setevent @TraceID, 10, 8, @on
exec sp_trace_setevent @TraceID, 10, 9, @on
exec sp_trace_setevent @TraceID, 10, 10, @on
exec sp_trace_setevent @TraceID, 10, 11, @on
exec sp_trace_setevent @TraceID, 10, 12, @on
exec sp_trace_setevent @TraceID, 10, 13, @on
exec sp_trace_setevent @TraceID, 10, 14, @on
exec sp_trace_setevent @TraceID, 10, 15, @on
exec sp_trace_setevent @TraceID, 10, 16, @on
exec sp_trace_setevent @TraceID, 10, 17, @on
exec sp_trace_setevent @TraceID, 10, 18, @on
exec sp_trace_setevent @TraceID, 10, 25, @on
exec sp_trace_setevent @TraceID, 12, 1, @on
exec sp_trace_setevent @TraceID, 12, 3, @on
exec sp_trace_setevent @TraceID, 12, 6, @on
exec sp_trace_setevent @TraceID, 12, 8, @on
exec sp_trace_setevent @TraceID, 12, 9, @on
exec sp_trace_setevent @TraceID, 12, 10, @on
exec sp_trace_setevent @TraceID, 12, 11, @on
exec sp_trace_setevent @TraceID, 12, 12, @on
exec sp_trace_setevent @TraceID, 12, 13, @on
exec sp_trace_setevent @TraceID, 12, 14, @on
exec sp_trace_setevent @TraceID, 12, 15, @on
exec sp_trace_setevent @TraceID, 12, 16, @on
exec sp_trace_setevent @TraceID, 12, 17, @on
exec sp_trace_setevent @TraceID, 12, 18, @on
exec sp_trace_setevent @TraceID, 12, 25, @on
exec sp_trace_setevent @TraceID, 14, 1, @on
exec sp_trace_setevent @TraceID, 14, 3, @on
exec sp_trace_setevent @TraceID, 14, 6, @on
exec sp_trace_setevent @TraceID, 14, 8, @on
exec sp_trace_setevent @TraceID, 14, 9, @on
exec sp_trace_setevent @TraceID, 14, 10, @on
exec sp_trace_setevent @TraceID, 14, 11, @on
exec sp_trace_setevent @TraceID, 14, 12, @on
exec sp_trace_setevent @TraceID, 14, 13, @on
exec sp_trace_setevent @TraceID, 14, 14, @on
exec sp_trace_setevent @TraceID, 14, 15, @on
exec sp_trace_setevent @TraceID, 14, 16, @on
exec sp_trace_setevent @TraceID, 14, 17, @on
exec sp_trace_setevent @TraceID, 14, 18, @on
exec sp_trace_setevent @TraceID, 14, 25, @on
exec sp_trace_setevent @TraceID, 15, 1, @on
exec sp_trace_setevent @TraceID, 15, 3, @on
exec sp_trace_setevent @TraceID, 15, 6, @on
exec sp_trace_setevent @TraceID, 15, 8, @on
exec sp_trace_setevent @TraceID, 15, 9, @on
exec sp_trace_setevent @TraceID, 15, 10, @on
exec sp_trace_setevent @TraceID, 15, 11, @on
exec sp_trace_setevent @TraceID, 15, 12, @on
exec sp_trace_setevent @TraceID, 15, 13, @on
exec sp_trace_setevent @TraceID, 15, 14, @on
exec sp_trace_setevent @TraceID, 15, 15, @on
exec sp_trace_setevent @TraceID, 15, 16, @on
exec sp_trace_setevent @TraceID, 15, 17, @on
exec sp_trace_setevent @TraceID, 15, 18, @on
exec sp_trace_setevent @TraceID, 15, 25, @on
exec sp_trace_setevent @TraceID, 16, 1, @on
exec sp_trace_setevent @TraceID, 16, 3, @on
exec sp_trace_setevent @TraceID, 16, 6, @on
exec sp_trace_setevent @TraceID, 16, 8, @on
exec sp_trace_setevent @TraceID, 16, 9, @on
exec sp_trace_setevent @TraceID, 16, 10, @on
exec sp_trace_setevent @TraceID, 16, 11, @on
exec sp_trace_setevent @TraceID, 16, 12, @on
exec sp_trace_setevent @TraceID, 16, 13, @on
exec sp_trace_setevent @TraceID, 16, 14, @on
exec sp_trace_setevent @TraceID, 16, 15, @on
exec sp_trace_setevent @TraceID, 16, 16, @on
exec sp_trace_setevent @TraceID, 16, 17, @on
exec sp_trace_setevent @TraceID, 16, 18, @on
exec sp_trace_setevent @TraceID, 16, 25, @on
exec sp_trace_setevent @TraceID, 17, 1, @on
exec sp_trace_setevent @TraceID, 17, 3, @on
exec sp_trace_setevent @TraceID, 17, 6, @on
exec sp_trace_setevent @TraceID, 17, 8, @on
exec sp_trace_setevent @TraceID, 17, 9, @on
exec sp_trace_setevent @TraceID, 17, 10, @on
exec sp_trace_setevent @TraceID, 17, 11, @on
exec sp_trace_setevent @TraceID, 17, 12, @on
exec sp_trace_setevent @TraceID, 17, 13, @on
exec sp_trace_setevent @TraceID, 17, 14, @on
exec sp_trace_setevent @TraceID, 17, 15, @on
exec sp_trace_setevent @TraceID, 17, 16, @on
exec sp_trace_setevent @TraceID, 17, 17, @on
exec sp_trace_setevent @TraceID, 17, 18, @on
exec sp_trace_setevent @TraceID, 17, 25, @on
exec sp_trace_setevent @TraceID, 21, 1, @on
exec sp_trace_setevent @TraceID, 21, 3, @on
exec sp_trace_setevent @TraceID, 21, 6, @on
exec sp_trace_setevent @TraceID, 21, 8, @on
exec sp_trace_setevent @TraceID, 21, 9, @on
exec sp_trace_setevent @TraceID, 21, 10, @on
exec sp_trace_setevent @TraceID, 21, 11, @on
exec sp_trace_setevent @TraceID, 21, 12, @on
exec sp_trace_setevent @TraceID, 21, 13, @on
exec sp_trace_setevent @TraceID, 21, 14, @on
exec sp_trace_setevent @TraceID, 21, 15, @on
exec sp_trace_setevent @TraceID, 21, 16, @on
exec sp_trace_setevent @TraceID, 21, 17, @on
exec sp_trace_setevent @TraceID, 21, 18, @on
exec sp_trace_setevent @TraceID, 21, 25, @on
exec sp_trace_setevent @TraceID, 22, 1, @on
exec sp_trace_setevent @TraceID, 22, 3, @on
exec sp_trace_setevent @TraceID, 22, 6, @on
exec sp_trace_setevent @TraceID, 22, 8, @on
exec sp_trace_setevent @TraceID, 22, 9, @on
exec sp_trace_setevent @TraceID, 22, 10, @on
exec sp_trace_setevent @TraceID, 22, 11, @on
exec sp_trace_setevent @TraceID, 22, 12, @on
exec sp_trace_setevent @TraceID, 22, 13, @on
exec sp_trace_setevent @TraceID, 22, 14, @on
exec sp_trace_setevent @TraceID, 22, 15, @on
exec sp_trace_setevent @TraceID, 22, 16, @on
exec sp_trace_setevent @TraceID, 22, 17, @on
exec sp_trace_setevent @TraceID, 22, 18, @on
exec sp_trace_setevent @TraceID, 22, 25, @on
exec sp_trace_setevent @TraceID, 33, 1, @on
exec sp_trace_setevent @TraceID, 33, 3, @on
exec sp_trace_setevent @TraceID, 33, 6, @on
exec sp_trace_setevent @TraceID, 33, 8, @on
exec sp_trace_setevent @TraceID, 33, 9, @on
exec sp_trace_setevent @TraceID, 33, 10, @on
exec sp_trace_setevent @TraceID, 33, 11, @on
exec sp_trace_setevent @TraceID, 33, 12, @on
exec sp_trace_setevent @TraceID, 33, 13, @on
exec sp_trace_setevent @TraceID, 33, 14, @on
exec sp_trace_setevent @TraceID, 33, 15, @on
exec sp_trace_setevent @TraceID, 33, 16, @on
exec sp_trace_setevent @TraceID, 33, 17, @on
exec sp_trace_setevent @TraceID, 33, 18, @on
exec sp_trace_setevent @TraceID, 33, 25, @on
exec sp_trace_setevent @TraceID, 55, 1, @on
exec sp_trace_setevent @TraceID, 55, 3, @on
exec sp_trace_setevent @TraceID, 55, 6, @on
exec sp_trace_setevent @TraceID, 55, 8, @on
exec sp_trace_setevent @TraceID, 55, 9, @on
exec sp_trace_setevent @TraceID, 55, 10, @on
exec sp_trace_setevent @TraceID, 55, 11, @on
exec sp_trace_setevent @TraceID, 55, 12, @on
exec sp_trace_setevent @TraceID, 55, 13, @on
exec sp_trace_setevent @TraceID, 55, 14, @on
exec sp_trace_setevent @TraceID, 55, 15, @on
exec sp_trace_setevent @TraceID, 55, 16, @on
exec sp_trace_setevent @TraceID, 55, 17, @on
exec sp_trace_setevent @TraceID, 55, 18, @on
exec sp_trace_setevent @TraceID, 55, 25, @on
exec sp_trace_setevent @TraceID, 61, 1, @on
exec sp_trace_setevent @TraceID, 61, 3, @on
exec sp_trace_setevent @TraceID, 61, 6, @on
exec sp_trace_setevent @TraceID, 61, 8, @on
exec sp_trace_setevent @TraceID, 61, 9, @on
exec sp_trace_setevent @TraceID, 61, 10, @on
exec sp_trace_setevent @TraceID, 61, 11, @on
exec sp_trace_setevent @TraceID, 61, 12, @on
exec sp_trace_setevent @TraceID, 61, 13, @on
exec sp_trace_setevent @TraceID, 61, 14, @on
exec sp_trace_setevent @TraceID, 61, 15, @on
exec sp_trace_setevent @TraceID, 61, 16, @on
exec sp_trace_setevent @TraceID, 61, 17, @on
exec sp_trace_setevent @TraceID, 61, 18, @on
exec sp_trace_setevent @TraceID, 61, 25, @on
exec sp_trace_setevent @TraceID, 67, 1, @on
exec sp_trace_setevent @TraceID, 67, 3, @on
exec sp_trace_setevent @TraceID, 67, 6, @on
exec sp_trace_setevent @TraceID, 67, 8, @on
exec sp_trace_setevent @TraceID, 67, 9, @on
exec sp_trace_setevent @TraceID, 67, 10, @on
exec sp_trace_setevent @TraceID, 67, 11, @on
exec sp_trace_setevent @TraceID, 67, 12, @on
exec sp_trace_setevent @TraceID, 67, 13, @on
exec sp_trace_setevent @TraceID, 67, 14, @on
exec sp_trace_setevent @TraceID, 67, 15, @on
exec sp_trace_setevent @TraceID, 67, 16, @on
exec sp_trace_setevent @TraceID, 67, 17, @on
exec sp_trace_setevent @TraceID, 67, 18, @on
exec sp_trace_setevent @TraceID, 67, 25, @on
exec sp_trace_setevent @TraceID, 69, 1, @on
exec sp_trace_setevent @TraceID, 69, 3, @on
exec sp_trace_setevent @TraceID, 69, 6, @on
exec sp_trace_setevent @TraceID, 69, 8, @on
exec sp_trace_setevent @TraceID, 69, 9, @on
exec sp_trace_setevent @TraceID, 69, 10, @on
exec sp_trace_setevent @TraceID, 69, 11, @on
exec sp_trace_setevent @TraceID, 69, 12, @on
exec sp_trace_setevent @TraceID, 69, 13, @on
exec sp_trace_setevent @TraceID, 69, 14, @on
exec sp_trace_setevent @TraceID, 69, 15, @on
exec sp_trace_setevent @TraceID, 69, 16, @on
exec sp_trace_setevent @TraceID, 69, 17, @on
exec sp_trace_setevent @TraceID, 69, 18, @on
exec sp_trace_setevent @TraceID, 69, 25, @on
exec sp_trace_setevent @TraceID, 79, 1, @on
exec sp_trace_setevent @TraceID, 79, 3, @on
exec sp_trace_setevent @TraceID, 79, 6, @on
exec sp_trace_setevent @TraceID, 79, 8, @on
exec sp_trace_setevent @TraceID, 79, 9, @on
exec sp_trace_setevent @TraceID, 79, 10, @on
exec sp_trace_setevent @TraceID, 79, 11, @on
exec sp_trace_setevent @TraceID, 79, 12, @on
exec sp_trace_setevent @TraceID, 79, 13, @on
exec sp_trace_setevent @TraceID, 79, 14, @on
exec sp_trace_setevent @TraceID, 79, 15, @on
exec sp_trace_setevent @TraceID, 79, 16, @on
exec sp_trace_setevent @TraceID, 79, 17, @on
exec sp_trace_setevent @TraceID, 79, 18, @on
exec sp_trace_setevent @TraceID, 79, 25, @on
exec sp_trace_setevent @TraceID, 80, 1, @on
exec sp_trace_setevent @TraceID, 80, 3, @on
exec sp_trace_setevent @TraceID, 80, 6, @on
exec sp_trace_setevent @TraceID, 80, 8, @on
exec sp_trace_setevent @TraceID, 80, 9, @on
exec sp_trace_setevent @TraceID, 80, 10, @on
exec sp_trace_setevent @TraceID, 80, 11, @on
exec sp_trace_setevent @TraceID, 80, 12, @on
exec sp_trace_setevent @TraceID, 80, 13, @on
exec sp_trace_setevent @TraceID, 80, 14, @on
exec sp_trace_setevent @TraceID, 80, 15, @on
exec sp_trace_setevent @TraceID, 80, 16, @on
exec sp_trace_setevent @TraceID, 80, 17, @on
exec sp_trace_setevent @TraceID, 80, 18, @on
exec sp_trace_setevent @TraceID, 80, 25, @on

declare @intfilter int
declare @bigintfilter bigint

-- change below to modify filters

exec sp_trace_setfilter @TraceID, 10, 0, 7, N'SQL Profiler'
exec sp_trace_setfilter @TraceID, 10, 0, 7, N'SQLAgent%'
exec sp_trace_setfilter @TraceID, 10, 0, 7, N'Lumigent%'
exec sp_trace_setfilter @TraceID, 10, 0, 7, N'OSQL%'
set @intfilter = 100
exec sp_trace_setfilter @TraceID, 22, 0, 4, @intfilter

exec sp_trace_setstatus @TraceID, 1 -- start trace

return
go
