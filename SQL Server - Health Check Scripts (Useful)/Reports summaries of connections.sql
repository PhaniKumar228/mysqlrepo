SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.Util_ConnectionSummary') IS NOT NULL DROP PROCEDURE Util_ConnectionSummary
GO

/**
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
Util_ConnectionSummary

Reports summaries of connections, running requests, open transactions, open cursors, and blocking at 3 different levels of aggregation detail, ranking trouble groups first.
Most useful for finding SPIDs thare being hoggy right now - activity monitor gives session-scoped resource consumption, this aggregates active request scoped resource consumption.
Also useful for quickly finding blocking offenders and finding programs that are not closing cursors or transactions.
Returns 3 result sets:
	Server-wide Total / Summary (No Group By)
	Connections and requests grouped by LoginName, HostName, Programname
	Connections and requests grouped by SessionID
Orders by ActiveReqCount DESC, OpenTranCount DESC, BlockingRequestCount DESC, BlockedReqCount DESC, ConnectionCount DESC, {group by column(s)}

Required Input Parameters
	none

Optional Input Parameters
	none

 Usage:
 	EXECUTE Util_ConnectionSummary

Copyright:
	Licensed under the L-GPL - a weak copyleft license - you are permitted to use this as a component of a proprietary database and call this from proprietary software.
	Copyleft lets you do anything you want except plagarize, conceal the source, or prohibit copying & re-distribution of this script/proc.

	This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    see <http://www.fsf.org/licensing/licenses/lgpl.html> for the license text.

*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
**/

CREATE PROCEDURE dbo.Util_ConnectionSummary AS

--All connections
SELECT
	SUM(ConnectionCount) AS ConnectionCount,
	SUM(CONVERT(bigint, ISNULL(dm_tran_session_transactions.TransactionCount,0))) AS OpenTranCount,
	SUM(CONVERT(bigint, ISNULL(dm_exec_cursors.OpenCursorCount,0))) AS OpenCursorCount,
	SUM(CONVERT(bigint, ISNULL(dm_exec_cursors.ClosedCursorCount,0))) AS ClosedCursorCount,
	ISNULL(SUM(dm_exec_blockrequests.BlockingRequestCount),0) AS BlockingRequestCount,
	SUM(dm_exec_requests.ActiveReqCount) AS ActiveReqCount,
	SUM(dm_exec_requests.open_resultset_count) AS OpenResultSetCount,
	SUM(dm_exec_requests.open_transaction_count) AS ActiveReqOpenTranCount,
	SUM(dm_exec_requests.BlockedReqCount) AS BlockedReqCount,
	SUM(dm_exec_requests.wait_time) AS WaitTime,
	SUM(dm_exec_requests.cpu_time) AS CPUTime,
	SUM(dm_exec_requests.total_elapsed_time) AS ElapsedTime,
	SUM(dm_exec_requests.reads) AS Reads,
	SUM(dm_exec_requests.writes) AS Writes,
	SUM(dm_exec_requests.logical_reads) AS LogicalReads,
	SUM(dm_exec_requests.row_count) AS [RowCount],
	SUM(dm_exec_requests.granted_query_memory) AS GrantedQueryMemoryKB
FROM
	sys.dm_exec_sessions
	LEFT OUTER JOIN (
		SELECT session_id, COUNT(*) AS ConnectionCount FROM sys.dm_exec_connections GROUP BY session_id
	) AS dm_exec_connections ON sys.dm_exec_sessions.session_id=dm_exec_connections.session_id
	LEFT OUTER JOIN (
		SELECT session_id, COUNT(*) AS TransactionCount FROM sys.dm_tran_session_transactions GROUP BY session_id
	) AS dm_tran_session_transactions ON sys.dm_exec_sessions.session_id=dm_tran_session_transactions.session_id
	LEFT OUTER JOIN (
		SELECT blocking_session_id, COUNT(*) AS BlockingRequestCount FROM sys.dm_exec_requests GROUP BY blocking_session_id
	) AS dm_exec_blockrequests ON sys.dm_exec_sessions.session_id=dm_exec_blockrequests.blocking_session_id
	LEFT OUTER JOIN (
		SELECT session_id, SUM(CASE WHEN is_open=1 THEN 1 ELSE 0 END) AS OpenCursorCount, SUM(CASE WHEN is_open=0 THEN 1 ELSE 0 END) AS ClosedCursorCount
		FROM sys.dm_exec_cursors (0)
		GROUP BY session_id
	) AS dm_exec_cursors ON sys.dm_exec_sessions.session_id=dm_exec_cursors.session_id
	LEFT OUTER JOIN (
		SELECT
			session_id,
			SUM(CONVERT(bigint, open_transaction_count)) AS open_transaction_count,
			SUM(CONVERT(bigint, open_resultset_count)) AS open_resultset_count,
			SUM(CASE WHEN total_elapsed_time IS NULL THEN 0 ELSE 1 END) AS ActiveReqCount,
			SUM(CASE WHEN blocking_session_id <> 0 THEN 1 ELSE 0 END) AS BlockedReqCount,
			SUM(CONVERT(bigint, wait_time)) AS wait_time,
			SUM(CONVERT(bigint, cpu_time)) AS cpu_time,
			SUM(CONVERT(bigint, total_elapsed_time)) AS total_elapsed_time,
			SUM(CONVERT(bigint, reads)) AS Reads,
			SUM(CONVERT(bigint, writes)) AS Writes,
			SUM(CONVERT(bigint, logical_reads)) AS logical_reads,
			SUM(CONVERT(bigint, row_count)) AS row_count,
			SUM(CONVERT(bigint, granted_query_memory*8)) AS granted_query_memory
		FROM sys.dm_exec_requests
		GROUP BY session_id
	) AS dm_exec_requests ON sys.dm_exec_sessions.session_id=dm_exec_requests.session_id
WHERE sys.dm_exec_sessions.is_user_process=1

--Connections by LoginName, Hostname, and ProgramName
SELECT
	sys.dm_exec_sessions.login_name, sys.dm_exec_sessions.host_name, sys.dm_exec_sessions.program_name,
	SUM(ConnectionCount) AS ConnectionCount,
	SUM(CONVERT(bigint, ISNULL(dm_tran_session_transactions.TransactionCount,0))) AS OpenTranCount,
	SUM(CONVERT(bigint, ISNULL(dm_exec_cursors.OpenCursorCount,0))) AS OpenCursorCount,
	SUM(CONVERT(bigint, ISNULL(dm_exec_cursors.ClosedCursorCount,0))) AS ClosedCursorCount,
	ISNULL(SUM(dm_exec_blockrequests.BlockingRequestCount),0) AS BlockingRequestCount,
	SUM(dm_exec_requests.ActiveReqCount) AS ActiveReqCount,
	SUM(dm_exec_requests.open_resultset_count) AS OpenResultSetCount,
	SUM(dm_exec_requests.open_transaction_count) AS ActiveReqOpenTranCount,
	SUM(dm_exec_requests.BlockedReqCount) AS BlockedReqCount,
	SUM(dm_exec_requests.wait_time) AS WaitTime,
	SUM(dm_exec_requests.cpu_time) AS CPUTime,
	SUM(dm_exec_requests.total_elapsed_time) AS ElapsedTime,
	SUM(dm_exec_requests.reads) AS Reads,
	SUM(dm_exec_requests.writes) AS Writes,
	SUM(dm_exec_requests.logical_reads) AS LogicalReads,
	SUM(dm_exec_requests.row_count) AS [RowCount],
	SUM(dm_exec_requests.granted_query_memory) AS GrantedQueryMemoryKB
FROM
	sys.dm_exec_sessions
	LEFT OUTER JOIN (
		SELECT session_id, COUNT(*) AS ConnectionCount FROM sys.dm_exec_connections GROUP BY session_id
	) AS dm_exec_connections ON sys.dm_exec_sessions.session_id=dm_exec_connections.session_id
	LEFT OUTER JOIN (
		SELECT session_id, COUNT(*) AS TransactionCount FROM sys.dm_tran_session_transactions GROUP BY session_id
	) AS dm_tran_session_transactions ON sys.dm_exec_sessions.session_id=dm_tran_session_transactions.session_id
	LEFT OUTER JOIN (
		SELECT blocking_session_id, COUNT(*) AS BlockingRequestCount FROM sys.dm_exec_requests GROUP BY blocking_session_id
	) AS dm_exec_blockrequests ON sys.dm_exec_sessions.session_id=dm_exec_blockrequests.blocking_session_id
	LEFT OUTER JOIN (
		SELECT session_id, SUM(CASE WHEN is_open=1 THEN 1 ELSE 0 END) AS OpenCursorCount, SUM(CASE WHEN is_open=0 THEN 1 ELSE 0 END) AS ClosedCursorCount
		FROM sys.dm_exec_cursors (0)
		GROUP BY session_id
	) AS dm_exec_cursors ON sys.dm_exec_sessions.session_id=dm_exec_cursors.session_id
	LEFT OUTER JOIN (
		SELECT
			session_id,
			SUM(CONVERT(bigint, open_transaction_count)) AS open_transaction_count,
			SUM(CONVERT(bigint, open_resultset_count)) AS open_resultset_count,
			SUM(CASE WHEN total_elapsed_time IS NULL THEN 0 ELSE 1 END) AS ActiveReqCount,
			SUM(CASE WHEN blocking_session_id <> 0 THEN 1 ELSE 0 END) AS BlockedReqCount,
			SUM(CONVERT(bigint, wait_time)) AS wait_time,
			SUM(CONVERT(bigint, cpu_time)) AS cpu_time,
			SUM(CONVERT(bigint, total_elapsed_time)) AS total_elapsed_time,
			SUM(CONVERT(bigint, reads)) AS Reads,
			SUM(CONVERT(bigint, writes)) AS Writes,
			SUM(CONVERT(bigint, logical_reads)) AS logical_reads,
			SUM(CONVERT(bigint, row_count)) AS row_count,
			SUM(CONVERT(bigint, granted_query_memory*8)) AS granted_query_memory
		FROM sys.dm_exec_requests
		GROUP BY session_id
	) AS dm_exec_requests ON sys.dm_exec_sessions.session_id=dm_exec_requests.session_id
WHERE sys.dm_exec_sessions.is_user_process=1
GROUP BY sys.dm_exec_sessions.login_name, sys.dm_exec_sessions.host_name, sys.dm_exec_sessions.program_name
ORDER BY
	ActiveReqCount DESC, OpenTranCount DESC, BlockingRequestCount DESC, BlockedReqCount DESC, ConnectionCount DESC,
	sys.dm_exec_sessions.login_name, sys.dm_exec_sessions.host_name, sys.dm_exec_sessions.program_name

--Connections by session_id
SELECT
	sys.dm_exec_sessions.session_id,
	MAX(sys.dm_exec_sessions.login_name) AS login_name, MAX(sys.dm_exec_sessions.host_name) AS host_name,
	MAX(sys.dm_exec_sessions.program_name) AS program_name, MAX(sys.dm_exec_sessions.client_interface_name) AS client_interface_name,
	MAX(sys.dm_exec_sessions.status) AS status,
	SUM(ConnectionCount) AS ConnectionCount,
	SUM(CONVERT(bigint, ISNULL(dm_tran_session_transactions.TransactionCount,0))) AS OpenTranCount,
	SUM(CONVERT(bigint, ISNULL(dm_exec_cursors.OpenCursorCount,0))) AS OpenCursorCount,
	SUM(CONVERT(bigint, ISNULL(dm_exec_cursors.ClosedCursorCount,0))) AS ClosedCursorCount,
	ISNULL(SUM(dm_exec_blockrequests.BlockingRequestCount),0) AS BlockingRequestCount,
	SUM(dm_exec_requests.ActiveReqCount) AS ActiveReqCount,
	SUM(dm_exec_requests.open_resultset_count) AS OpenResultSetCount,
	SUM(dm_exec_requests.open_transaction_count) AS ActiveReqOpenTranCount,
	SUM(dm_exec_requests.BlockedReqCount) AS BlockedReqCount,
	SUM(dm_exec_requests.wait_time) AS WaitTime,
	SUM(dm_exec_requests.cpu_time) AS CPUTime,
	SUM(dm_exec_requests.total_elapsed_time) AS ElapsedTime,
	SUM(dm_exec_requests.reads) AS Reads,
	SUM(dm_exec_requests.writes) AS Writes,
	SUM(dm_exec_requests.logical_reads) AS LogicalReads,
	SUM(dm_exec_requests.row_count) AS [RowCount],
	SUM(dm_exec_requests.granted_query_memory) AS GrantedQueryMemoryKB
FROM
	sys.dm_exec_sessions
	LEFT OUTER JOIN (
		SELECT session_id, COUNT(*) AS ConnectionCount FROM sys.dm_exec_connections GROUP BY session_id
	) AS dm_exec_connections ON sys.dm_exec_sessions.session_id=dm_exec_connections.session_id
	LEFT OUTER JOIN (
		SELECT session_id, COUNT(*) AS TransactionCount FROM sys.dm_tran_session_transactions GROUP BY session_id
	) AS dm_tran_session_transactions ON sys.dm_exec_sessions.session_id=dm_tran_session_transactions.session_id
	LEFT OUTER JOIN (
		SELECT blocking_session_id, COUNT(*) AS BlockingRequestCount FROM sys.dm_exec_requests GROUP BY blocking_session_id
	) AS dm_exec_blockrequests ON sys.dm_exec_sessions.session_id=dm_exec_blockrequests.blocking_session_id
	LEFT OUTER JOIN (
		SELECT session_id, SUM(CASE WHEN is_open=1 THEN 1 ELSE 0 END) AS OpenCursorCount, SUM(CASE WHEN is_open=0 THEN 1 ELSE 0 END) AS ClosedCursorCount
		FROM sys.dm_exec_cursors (0)
		GROUP BY session_id
	) AS dm_exec_cursors ON sys.dm_exec_sessions.session_id=dm_exec_cursors.session_id
	LEFT OUTER JOIN (
		SELECT
			session_id,
			SUM(CONVERT(bigint, open_transaction_count)) AS open_transaction_count,
			SUM(CONVERT(bigint, open_resultset_count)) AS open_resultset_count,
			SUM(CASE WHEN total_elapsed_time IS NULL THEN 0 ELSE 1 END) AS ActiveReqCount,
			SUM(CASE WHEN blocking_session_id <> 0 THEN 1 ELSE 0 END) AS BlockedReqCount,
			SUM(CONVERT(bigint, wait_time)) AS wait_time,
			SUM(CONVERT(bigint, cpu_time)) AS cpu_time,
			SUM(CONVERT(bigint, total_elapsed_time)) AS total_elapsed_time,
			SUM(CONVERT(bigint, reads)) AS Reads,
			SUM(CONVERT(bigint, writes)) AS Writes,
			SUM(CONVERT(bigint, logical_reads)) AS logical_reads,
			SUM(CONVERT(bigint, row_count)) AS row_count,
			SUM(CONVERT(bigint, granted_query_memory*8)) AS granted_query_memory
		FROM sys.dm_exec_requests
		GROUP BY session_id
	) AS dm_exec_requests ON sys.dm_exec_sessions.session_id=dm_exec_requests.session_id
WHERE sys.dm_exec_sessions.is_user_process=1
GROUP BY sys.dm_exec_sessions.session_id
ORDER BY
	ActiveReqCount DESC, OpenTranCount DESC, BlockingRequestCount DESC, BlockedReqCount DESC, ConnectionCount DESC,
	login_name, program_name, host_name, session_id
GO

--*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=

