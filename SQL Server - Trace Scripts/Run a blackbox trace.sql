/*
Run a blackbox trace

There is a script for setting up a blackbox trace on SQL 2000 described by Kalen Delaney in "Inside SQL Server 2000". 
Since I can never remember where to look it up I wrote this simple stored procedure to run the blackbox trace when I need it. 
This should be used with caution as it will slow performance. 

To check the status of the trace: SELECT * from ::fn_trace_getinfo() 
-- Usually trace id = 1 To stop the trace: EXEC sp_trace_setstatus , 0 
-- Usually trace id = 1 To remove the trace: EXEC sp_trace_setstatus , 2 
*/

CREATE PROC dbo.sp_blackbox
AS

declare @TraceID int, @tracefile nvarchar(128), @maxfilesize bigint
Select @tracefile = 'BlackBox', @maxfilesize = 2
exec sp_trace_create @TraceID output, 8, @tracefile, @maxfilesize
exec sp_trace_setstatus @traceID, 1
RETURN
