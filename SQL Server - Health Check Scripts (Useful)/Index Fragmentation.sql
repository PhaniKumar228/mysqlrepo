/*
Index Fragmentation

To print commands ALTER INDEX ... REORGANIZE or REBUILD for the indices of database TestDB with avg_fragmentation_in_percent greater than 10 (%) is sufficient run:

EXEC USP_ExecReorgRebuildIndex 'TestDB', 0, -1, 10
To run the defragmenter, use instead:

EXEC USP_ExecReorgRebuildIndex 'TestDB', -1, 0, 10

*/

IF OBJECT_ID('USP_ExecReorgRebuildIndex', 'P') IS NOT NULL
 DROP PROCEDURE dbo.USP_ExecReorgRebuildIndex
GO

CREATE PROCEDURE dbo.USP_ExecReorgRebuildIndex
(@DataBaseName AS VARCHAR(128), 
 @Exec AS INT, 
 @Print AS INT,
 @Threshold AS INT)
AS BEGIN

 /*
   Parameters:

     @DataBaseName = Database Name

     @Exec: Performs REORGANIZE or REBUILD index
            (with @Exec = -1 Run the commands, 
             with @Exec <> -1 Does not run the commands)

     @Print: Print command or not 
             (with @Print = -1 Print the commands, 
              with @Print <> -1 Does not print the commands)
     
     @Threshold: Threshold of DM_DB_Index_Physical_Stats 
 */

 DECLARE @index_id AS INT,
         @index_name SYSNAME,
         @action_to_do AS VARCHAR(1024), 
         @avg_fragmentation_in_percent FLOAT,
         @table_name AS VARCHAR(512)

 DECLARE CUR CURSOR FOR
 
 SELECT 

   a.index_id, 
   b.name index_name, 
   a.avg_fragmentation_in_percent,

   CASE WHEN (a.avg_fragmentation_in_percent <= 30) 
        THEN 'ALTER INDEX '+LTRIM(RTRIM(b.name))+' ON '+LTRIM(RTRIM(s.name))+'.'+LTRIM(RTRIM(c.name))+' REORGANIZE'
        ELSE 'ALTER INDEX '+LTRIM(RTRIM(b.name))+' ON '+LTRIM(RTRIM(s.name))+'.'+LTRIM(RTRIM(c.name))+' REBUILD'
   END AS action_to_do,

   LTRIM(RTRIM(s.name))+'.'+LTRIM(RTRIM(c.name)) AS table_name

 FROM
 
   sys.dm_db_index_physical_stats (DB_ID(@DataBaseName), NULL, NULL, NULL, NULL) AS a

 JOIN

   sys.indexes AS b ON a.object_id = b.object_id AND a.index_id = b.index_id
 
 JOIN
 
   sys.objects AS c ON c.object_id = a.object_id
 
 JOIN
 
   sys.schemas AS s ON s.schema_id = c.schema_id
 
 WHERE (b.name IS NOT NULL)
   AND (a.avg_fragmentation_in_percent > @Threshold)
 
 ORDER BY a.avg_fragmentation_in_percent DESC

 OPEN CUR

 FETCH NEXT FROM CUR INTO @index_id, @index_name, @avg_fragmentation_in_percent, @action_to_do, @table_name

 WHILE (@@FETCH_STATUS = 0)
 BEGIN
   IF (@Exec = -1) 
   BEGIN
     EXEC(@action_to_do)
     EXEC('UPDATE STATISTICS ' + @table_name + ' ' + @index_name)
   END

   IF (@Print = -1)
   BEGIN
     PRINT @action_to_do
     PRINT 'UPDATE STATISTICS ' + @table_name + ' ' + @index_name
     PRINT '@'
   END

   FETCH NEXT FROM CUR INTO @index_id, @index_name, @avg_fragmentation_in_percent, @action_to_do, @table_name
 END

 CLOSE CUR

 DEALLOCATE CUR
END



