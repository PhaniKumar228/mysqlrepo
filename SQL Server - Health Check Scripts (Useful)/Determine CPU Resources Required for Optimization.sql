/*
Determine CPU Resources Required for Optimization

Description

Sample script that determines CPU resources required for optimization. Optimizations represent the total query plans created. Elapsed time reflects CPU time, because optimization is CPU-intensive. The Trivial plan is the number of 'trivial' plans; tables indicate average number of tables per query; and Inserts/Updates/Deletes report the number of inserts, updates, and deletes. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

Select * from sys.dm_exec_query_optimizer_info
where counter in ('optimizations','elapsed time','trivial plan','tables','insert stmt','update stmt','delete stmt')
