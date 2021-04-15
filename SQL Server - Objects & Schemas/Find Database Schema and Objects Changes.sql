/*

Find Database Schema and Objects Changes 

This procedure will execute, taking two parameters, (the 2 db names, and will then list out the major object and schema changes for you. 
It is pretty sraight forward and suggestions are appreciated. 
It's a good utility for a DBA to track changes after upgrades, etc.. Each portion is easily convertable to a stand alone script. 

*/

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO


CREATE PROCEDURE dbo.DBA_GetDBChanges_sp

 @FromDBName sysname,
 @ToDBName  sysname

AS

/* 	This script will provide DDL differences between two databases*/

DECLARE 
	@SQL nvarchar(4000)


Select '-------************* NEW TABLES **************----------'
SET @SQL = 'Select	Source_Table.Name As New_Table_Name,
		 			Source_Columns.Name As New_Column_Name,
					Source_Type.Name As New_Column_Type,
		 			Source_Columns.Prec As New_Column_Precision,
		 			Source_Columns.Scale As New_Column_Scale,
		 			Source_Comments.Text As Default_Value,
	     			Case When Source_Columns.status & 8 = 8 Then ''Yes'' Else ''No'' END As AllowNulls
    		From 
					' + @ToDBName + '.dbo.SysObjects Source_Table Left Join 
					' + @FromDBName + '.dbo.sysobjects Target_Table ON Source_Table.Name = Target_Table.Name INNER JOIN
					' + @ToDBName + '.dbo.syscolumns Source_Columns ON Source_Table.ID = Source_Columns.ID INNER JOIN
					' + @ToDBName + '.dbo.systypes Source_Type ON Source_Columns.xtype = Source_Type.xusertype LEFT OUTER JOIN 
					' + @ToDBName + '.dbo.syscomments Source_Comments ON Source_Columns.CDefault = Source_Comments.ID
   			Where 
					Source_Table.Type = ''U'' AND 
					Target_Table.ID IS NULL
   			Order by Source_Table.Name'
exec sp_executesql @sql

Select '-------************* NEW COLUMNS **************----------'
SET @SQL = 'Select	Source_Table.Name As Source_TableName,
					Source_Column.Name As Source_ColumnName,
					SysTypes.Name As ColumnType,
					Source_Column.Prec As ColumnPrec,
					Source_Column.Scale As ColumnScale, 
					SysComments.Text As Default_Value,
					Case When Source_Column.status & 8 = 8 Then ''Yes'' Else ''No'' END As AllowNulls
			From 
					' + @ToDBName + '.dbo.SysObjects Source_Table INNER JOIN 
					' + @ToDBName + '.dbo.SysColumns Source_Column ON Source_Table.ID = Source_Column.ID LEFT OUTER JOIN
    				' + @ToDBName + '.dbo.SysComments SysComments ON SysComments.ID = Source_Column.CDefault INNER JOIN
   					' + @FromDBName + '.dbo.SysObjects Target_Table ON Target_Table.Name = Source_Table.Name LEFT OUTER JOIN
    				' + @FromDBName + '.dbo.SysColumns Target_Column ON Target_Column.ID = Target_Table.ID AND Target_Column.Name = Source_Column.Name INNER JOIN
    				' + @ToDBName + '.dbo.Systypes SysTypes ON Systypes.XUserType = Source_Column.XType
   			Where 	Source_Table.Type = ''U'' AND 
					Target_Column.ID IS NULL AND 
					Source_Table.Name not like ''SyMailMerge%''
   			Order by Source_Table.Name, Source_Column.Name'
exec sp_executesql @sql

Select '-------************* NEW STORED PROCEDURES **************----------'

SET @sql = 	'Select Source_Table.NAme as Procedure_Name , Target_table.Name as Still_here, *

	From 
		' + @ToDBName + '.dbo.sysobjects source_table 
			Left Outer Join 
		' + @FromDBName + '.dbo.sysobjects target_table 
				ON Source_Table.Name = Target_table.Name
WHERE 
	Source_Table.type = ''P'' 
AND 
	Target_table.NAme is null'


exec SP_executesql @sql

Select '-------************* New Indexes **************----------'
SET @SQL =	'Select   	
				Source.Table_Name AS Table_Name, 
				Source.Index_Name AS Index_Name, 
				CASE (Source.Index_Status & 2) WHEN 2 THEN ''YES'' ELSE ''NO'' END AS UniqueInd,
				CASE (Source.Index_Status & 2) WHEN 2 THEN CASE (Source.Index_Status & 1) WHEN 1 THEN ''YES'' ELSE ''NO'' END ELSE ''N/A'' END AS IgnoreDupKey,
				INDEX_COL(''' + @ToDBName + '.dbo.''' + ' + Source.Table_Name, Source.Index_ID, Keys.KeyNO) AS Index_Column,
				CASE INDEXKEY_PROPERTY(Source.ID, Source.Index_ID, Keys.KeyNO, ''IsDescending'') WHEN 1 THEN ''YES'' ELSE ''NO'' END AS DescendingSort
			From 		
				(
				SELECT 	so.ID, so.Name AS Table_Name, si.Name AS Index_Name, 
						si.IndID AS Index_ID, si.Status AS Index_Status 
				FROM 	' + @ToDBName + '.dbo.SysObjects so JOIN 
					 	' + @ToDBName + '.dbo.SysIndexes si ON so.ID=si.ID 
				WHERE 	so.xtype=''U'' AND (si.Status & 64) = 0
				) Source LEFT OUTER JOIN
				(
				SELECT 	so.ID, so.Name AS Table_Name, si.Name AS Index_Name, 
					   	si.IndID AS Index_ID, si.Status AS Index_Status 
				FROM 	' + @FromDBName + '.dbo.SysObjects so JOIN 
						' + @FromDBName + '.dbo.SysIndexes si ON so.ID=si.ID 
				WHERE  	so.xtype=''U'' AND (si.Status & 64) = 0
				) Target ON	Source.ID = Target.ID AND 
							Source.Table_Name = Target.Table_Name AND 
							Source.Index_Name = Target.Index_Name INNER JOIN 
				' + @ToDBName + '.dbo.SysIndexKeys Keys ON 	Source.ID = Keys.ID AND 
															Source.Index_ID = Keys.IndID
			WHERE Target.ID IS NULL
   			Order by Source.Table_Name, Source.Index_Name'

exec sp_executesql @sql

Select '-------************* New Triggers **************----------'
SET @SQL =	'Select	Source_Parent.Name AS Table_Name, 
					Source.Name AS Trigger_Name
			From
					' + @ToDBName + '.dbo.SysObjects Source LEFT OUTER JOIN
					' + @FromDBName + '.dbo.SysObjects Target ON Source.Name = Target.Name INNER JOIN
					' + @ToDBName + '.dbo.SysObjects Source_Parent ON Source.Parent_Obj = Source_Parent.ID
			WHERE 	Source.xtype=''TR'' AND Target.ID IS NULL
			ORDER BY Trigger_Name'
exec sp_executesql @sql

Select '-------************* NEW VIEWS **************----------'

SET @sql = 	'Select Source_Table.NAme as View_Name ,  *

	From 
		' + @ToDBName + '.dbo.sysobjects source_table 
			Left Outer Join 
		' + @FromDBName + '.dbo.sysobjects target_table 
				ON Source_Table.Name = Target_table.Name
WHERE 
	Source_Table.type = ''v'' 
AND 
	Target_table.NAme is null'


exec SP_executesql @sql
Select '-------************* DELETED TABLES **************----------'

SET @sql = 	'select Source_Table.NAme as Old_Table_Name ,  *

	From 
		' + @FromDBName + '.dbo.sysobjects source_table 
			Left Outer Join 
		' + @TODBName + '.dbo.sysobjects target_table 
				ON Source_Table.Name = Target_table.NAme
WHERE 
	Source_Table.type = ''U'' 
AND 
	Target_table.NAme is null'


exec SP_executesql @sql
Select '-------************* DELETED INDEXES **************----------'

SET @sql = 'SELECT 	Source.Table_Name AS Table_Name, 
	
			Source.Index_Name AS Index_Name, 
	
			CASE (Source.Index_Status & 2) 
				WHEN 2 
					THEN ''YES'' 
					ELSE ''NO'' 
				END AS UniqueInd,
	
			CASE (Source.Index_Status & 2) 
				WHEN 2 
					THEN CASE (Source.Index_Status & 1) 
						WHEN 1 
							THEN ''YES'' 
							ELSE ''NO'' 
						END 
				ELSE ''N/A'' 
			END AS IgnoreDupKey,
			
			INDEX_COL(''' + @FromDBName + '.dbo.''' + ' + Source.Table_Name,Source.Index_ID, Keys.KeyNO) AS Index_Column,
	
			CASE INDEXKEY_PROPERTY(Source.ID, Source.Index_ID, Keys.KeyNO, ''IsDescending'') 
				WHEN 1 
					THEN ''YES''
					ELSE ''NO'' 
			END AS DescendingSort
	
	
	From 
				(
				SELECT 	so.ID, so.Name AS Table_Name, si.Name AS Index_Name, 
						si.IndID AS Index_ID, si.Status AS Index_Status 
				FROM 	' + @FromDBName + '.dbo.SysObjects so JOIN 
					 	' + @FromDBName + '.dbo.SysIndexes si ON so.ID=si.ID 
				WHERE 	so.xtype=''U'' AND (si.Status & 64) = 0
				) 
					Source LEFT OUTER JOIN
				(
				SELECT 	so.ID, so.Name AS Table_Name, si.Name AS Index_Name, 
					   	si.IndID AS Index_ID, si.Status AS Index_Status 
				FROM 	' + @ToDBName + '.dbo.SysObjects so JOIN 
						' + @ToDBName + '.dbo.SysIndexes si ON so.ID=si.ID 
				WHERE  	so.xtype=''U'' AND (si.Status & 64) = 0
				) 

				Target ON	
							Source.Table_Name = Target.Table_Name AND 
							Source.Index_Name = Target.Index_Name INNER JOIN 
				' + @FromDBName + '.dbo.SysIndexKeys Keys ON 	Source.ID = Keys.ID AND 
				Source.Index_ID = Keys.IndID

			WHERE Target.ID IS NULL
   			Order by Source.Table_Name, Source.Index_Name'



exec SP_executesql @sql


Select '-------************* DELETED TRIGGERS **************----------'

SET @sql = 	'Select Source_Table.NAme as Source_Table_Name , *

	From 
		' + @FromDBName + '.dbo.sysobjects source_table 
			Left Outer Join 
		' + @TODBName + '.dbo.sysobjects target_table 
				ON Source_Table.Name = Target_table.Name
WHERE 
	Source_Table.type = ''TR'' 
AND 
	Target_table.NAme is null'


exec SP_executesql @sql


Select '-------************* DELETED STORED PROCEDURES **************----------'

SET @sql = 	'Select Source_Table.NAme as Procedure_Name , *

	From 
		' + @FromDBName + '.dbo.sysobjects source_table 
			Left Outer Join 
		' + @TODBName + '.dbo.sysobjects target_table 
				ON Source_Table.Name = Target_table.Name
WHERE 
	Source_Table.type = ''P'' 
AND 
	Target_table.NAme is null'


exec SP_executesql @sql


Select '-------************* DELETED COLUMNS **************----------'
SET @SQL = 'Select	Source_Table.Name As Source_TableName, 
					Source_Column.Name As Source_ColumnName, 
					SysTypes.Name As ColumnType, 
					Source_Column.Prec As ColumnPrec, 
					Source_Column.Scale As ColumnScale, 
					SysComments.Text As Default_Value,
					Case When Source_Column.status & 8 = 8 Then ''Yes'' Else ''No'' END As AllowNulls
			From 
					' + @FromDBName + '.dbo.SysObjects Source_Table INNER JOIN
    				' + @FromDBName + '.dbo.SysColumns Source_Column ON Source_Table.ID = Source_Column.ID LEFT OUTER JOIN
    				' + @FromDBName + '.dbo.SysComments SysComments ON SysComments.ID = Source_Column.CDefault INNER JOIN
   					' + @ToDBName + '.dbo.SysObjects Target_Table ON Target_Table.Name = Source_Table.Name LEFT OUTER JOIN
    				' + @ToDBName + '.dbo.SysColumns Target_Column ON Target_Column.ID = Target_Table.ID AND Target_Column.Name = Source_Column.Name INNER JOIN
    				' + @FromDBName + '.dbo.Systypes SysTypes ON Systypes.XUserType = Source_Column.XType
   			Where 	Source_Table.Type = ''U'' AND 
					Target_Column.ID IS NULL AND 
					Source_Table.Name not like ''SyMailMerge%''
   			Order by Source_Table.Name, Source_Column.Name'
exec sp_executesql @sql

Select '-------************* DELETED VIEWS **************----------'

SET @sql = 	'Select Source_Table.NAme as View_Name , *

	From 
		' + @FromDBName + '.dbo.sysobjects source_table 
			Left Outer Join 
		' + @TODBName + '.dbo.sysobjects target_table 
				ON Source_Table.Name = Target_table.Name
WHERE 
	Source_Table.type = ''V'' 
AND 
	Target_table.NAme is null'


exec SP_executesql @sql

Select '-------************* MODIFIED STORED PROCEDURES **************----------'

SET @sql = 'Select Distinct	SourceObjects.ID As ObjectID
		 into ChangedProcs
			  From ' + @FromDBName + '.dbo.sysComments as Source
				Join ' + @FromDBName + '.dbo.sysObjects as SourceObjects
				      on SourceObjects.id = [Source].id
				Join ' + @ToDBName + '.dbo.sysComments as [Target]
				   Join ' + @ToDBName + '.dbo.sysObjects as TargetObjects     
					on [TargetObjects].id = Target.id
					    on [TargetObjects].[Name] = [SourceObjects].[Name]
		   AND [Source].ColID = [Target].colID
		   AND [Source].Number = [Target].Number  
			Where [SourceObjects].[Type] = ''p''
		   And [Source].[text] <> [Target].[text]'
exec SP_executesql @sql	
		
SET @SQL = 		
		'Select source.Name
		  from ' + @FromDBName + '.dbo.SysObjects [Source]
		  Join ChangedProcs C
		    on C.ObjectID = [Source].id'

exec SP_executesql @sql		
		
		Drop table ChangedProcs

Select '-------************* MODIFIED TRIGGERS **************----------'

SET @sql = 'Select 	SourceObjects.ID As ObjectID, sourceObjects.*
		 into ChangedTriggers
			  From ' + @FromDBName + '.dbo.sysComments as Source
				Join ' + @FromDBName + '.dbo.sysObjects as SourceObjects
				      on SourceObjects.id = [Source].id
				Join ' + @ToDBName + '.dbo.sysComments as [Target]
				   Join ' + @ToDBName + '.dbo.sysObjects as TargetObjects     
					on [TargetObjects].id = Target.id
					    on [TargetObjects].[Name] = [SourceObjects].[Name]
		   AND [Source].ColID = [Target].colID
		   AND [Source].Number = [Target].Number  
			Where [SourceObjects].[Type] = ''T''
		   And [Source].[text] <> [Target].[text]'
exec SP_executesql @sql	
		
SET @SQL = 		
		'Select source.Name
		  from ' + @FromDBName + '.dbo.SysObjects [Source]
		  Join ChangedTRiggers T
		    on T.ObjectID = [Source].id'

exec SP_executesql @sql		
		
		Drop table ChangedTriggers

Select '-------************* MODIFIED VIEWS **************----------'

SET @sql = 'Select 	SourceObjects.ID As ObjectID
		 into ChangedViews
			  From ' + @FromDBName + '.dbo.sysComments as Source
				Join ' + @FromDBName + '.dbo.sysObjects as SourceObjects
				      on SourceObjects.id = [Source].id
				Join ' + @ToDBName + '.dbo.sysComments as [Target]
				   Join ' + @ToDBName + '.dbo.sysObjects as TargetObjects     
					on [TargetObjects].id = Target.id
					    on [TargetObjects].[Name] = [SourceObjects].[Name]
		   AND [Source].ColID = [Target].colID
		   AND [Source].Number = [Target].Number  
			Where [SourceObjects].[Type] = ''V''
		   And [Source].[text] <> [Target].[text]'
exec SP_executesql @sql	
		
SET @SQL = 		
		'Select source.Name
		  from ' + @FromDBName + '.dbo.SysObjects [Source]
		  Join ChangedViews V
		    on V.ObjectID = [Source].id'

exec SP_executesql @sql		
		
		Drop table ChangedViews


Select '-------************* COLUMNS MODIFIED **************----------'
SET @SQL = 'Select	left(Source_Table.Name,25) As TableName,
					left(Source_Column.Name,35) As ColumnName,
					left(SysTypes.Name,15) As ColumnType,
					Source_Column.Prec As ColumnPrec,
					Source_Column.Scale As ColumnScale,
					Case When Source_Column.status & 8 = 8 Then ''Yes'' Else ''No'' END As AllowNulls, 
					left(OldTypes.Name,15) As Old_Type, 
					Target_Column.Prec as Old_Prec,
					Target_Column.Scale as Old_Scale,
					Case When Target_Column.status & 8 = 8 Then ''Yes'' Else ''No'' END As Old_AllowNulls
			From 
				' + @ToDBName + '.dbo.SysObjects Source_Table INNER JOIN
	    			' + @ToDBName + '.dbo.SysColumns Source_Column ON Source_Table.ID = Source_Column.ID INNER JOIN 
					' + @FromDBName + '.dbo.SysObjects Target_Table ON Target_Table.Name = Source_Table.Name INNER JOIN
	    			' + @FromDBName + '.dbo.SysColumns Target_Column ON Target_Column.ID = Target_Table.ID AND Target_Column.Name = Source_Column.Name INNER JOIN
	    			' + @ToDBName + '.dbo.SysTypes SysTypes ON Systypes.XUserType = Source_Column.XType INNER JOIN
	    			' + @FromDBName + '.dbo.SysTypes OldTypes ON OldTypes.XUserType = Target_Column.XType
   			Where 	Source_Table.Type = ''U'' AND 
					(Source_Column.Type != Target_Column.Type OR 
						Source_Column.Length != Target_Column.Length OR 
						Source_Column.Prec != Target_Column.Prec OR 
						Source_Column.Scale != Target_Column.Scale
					)
   			Order by Source_Table.Name, Source_Column.Name'
exec sp_executesql @sql

GO



	
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

--Drop procedure dba_getdbchanges_sp

--Exec DBA_GetDBChanges_sp SourceDB, TargetDB
