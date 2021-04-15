drop PROCEDURE hx_DatabaseProperties
go

CREATE PROCEDURE hx_DatabaseProperties AS

CREATE TABLE #temp_op (
	
	[Database_Options] [varchar] (5000) NULL 
)

set nocount on

/* 	Robert Vallee 02/21/2000
	rvallee@hybridx.com
	input:	None
	output:	Table format
	Desc: Displays database properties.  Was this the best way of doing it? Probably not, but it works.
	Warnings: None
*/


insert into #temp_op(Database_Options)
select 'Automatic update statistics: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAutoUpdateStatistics') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Automatic create statistics: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAutoCreateStatistics') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database follows SQL-92 rules for allowing null values: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAnsiNullDefault') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'All comparisons to a null evaluate to unknown: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAnsiNullsEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Error or warning messages are issued when standard error conditions occur: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAnsiWarningsEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database shuts down cleanly and frees resources after the last user exits: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAutoClose') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database files are candidates for automatic periodic shrinking: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAutoShrink') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Auto update statistics database option is enabled: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAutoUpdateStatistics') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database allows nonlogged operations: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsBulkCopy') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Cursors that are open when a transaction is committed are closed: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsCloseCursorsOnCommitEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is in DBO-only access mode: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsDboOnly') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database was detached by a detach operation: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsDetached') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Emergency mode is enabled to allow suspect database to be usable: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsEmergencyMode') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is full-text enabled: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsFulltextEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is going through the loading process: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsInLoad') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is recovering: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsInRecovery') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is online as read-only, with restore log allowed: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsInStandBy') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Cursor declarations default to LOCAL: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsLocalCursorsDefault') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database failed to recover: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsAutoUpdateStatistics') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Null concatenation operand yields NULL: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsBulkCopy') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is offline: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsCloseCursorsOnCommitEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Double quotation marks can be used on identifiers: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsQuotedIdentifiersEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is in a read-only access mode: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsReadOnly') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Recursive firing of triggers is enabled: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsRecursiveTriggersEnabled') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database encountered a problem at startup: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsShutDown') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is in single-user access mode: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsSingleUser') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database is suspect: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsSuspect') = 1 THEN 'ON' ELSE 'OFF' END)
insert into #temp_op(Database_Options)
select 'Database truncates its log on checkpoints: ' + (CASE WHEN DatabaseProperty(db_name(), 'IsTruncLog') = 1 THEN 'ON' ELSE 'OFF' END)

set nocount on
select * from #temp_op order by Database_Options

drop table #temp_op

SET QUOTED_IDENTIFIER  OFF    SET ANSI_NULLS  ON 

GO
