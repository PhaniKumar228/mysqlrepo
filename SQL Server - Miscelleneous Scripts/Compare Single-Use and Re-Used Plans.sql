/*
Compare Single-Use and Re-Used Plans

Description

Sample script that compares single use plans to re-used plans. This script requires Microsoft SQL Server 2005. 

Script Code


*/

declare @single int, @reused int, @total int

select @single=
	sum(case(usecounts)
		when 1 then 1
		else 0
	end),
	@reused=
	sum(case(usecounts)
		when 1 then 0
		else 1
	end),
	@total=count(usecounts)
from sys.dm_exec_cached_plans

select 
'Single use plans (usecounts=1)'= @single,
'Re-used plans (usecounts>1)'= @reused,
're-use %'=cast(100.0*@reused / @total as dec(5,2)),
'total usecounts'=@total


select 'single use plan size'=sum(cast(size_in_bytes as bigint))
from sys.dm_exec_cached_plans
where usecounts = 1

