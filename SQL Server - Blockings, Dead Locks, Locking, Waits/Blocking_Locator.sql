USE MASTER
DECLARE @spid INT
SELECT @spid=spid from master..sysprocesses WITH(NOLOCK)
WHERE blocked = 0
AND spid in (select blocked from master..sysprocesses WITH(NOLOCK) WHERE blocked>0)

-- =================================
-- Find Blocked Bad Processes
-- =================================
SELECT TOP 30 spid, blocked, convert(varchar(10),db_name(dbid)) as DBName, 
    cpu, 
    datediff(second,login_time, getdate()) as Secs,
    convert(float, cpu / datediff(second,login_time, getdate())) as PScore,
    convert(varchar(16), hostname) as Host,
    convert(varchar(50), program_name) as Program,
    convert(varchar(20), loginame) as Login
FROM master..sysprocesses WITH(NOLOCK)
WHERE datediff(second,login_time, getdate()) > 0 and spid > 50 and spid=@spid
ORDER BY pscore desc
-- ========================
-- Find Blocked Resource Hogs
-- ========================
SELECT convert(varchar(50), program_name) as Program,
    count(*) as CliCount,
    sum(cpu) as CPUSum, 
    sum(datediff(second, login_time, getdate())) as SecSum,
    convert(float, sum(cpu)) / convert(float, sum(datediff(second, login_time, getdate()))) as Score,
    convert(float, sum(cpu)) / convert(float, sum(datediff(second, login_time, getdate()))) / count(*) as ProgramBadnessFactor
FROM master..sysprocesses WITH(NOLOCK)
WHERE spid > 50  and spid=@spid
GROUP BY convert(varchar(50), program_name)
ORDER BY 5 DESC

-- ===============================
-- Find All Blocked Processes
-- ===============================
select * from sysprocesses p WITH (NOLOCK) 
where  EXISTS (SELECT * FROM master..syslockinfo l WITH(NOLOCK) WHERE req_spid = p.spid AND rsc_type <> 2)