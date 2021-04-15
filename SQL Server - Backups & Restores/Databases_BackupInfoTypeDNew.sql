USE [KnowledgeWarehouse]
GO
/****** Object:  StoredProcedure [dbo].[usp_t_Failed_Jobs_Get]    Script Date: 03/16/2009 08:06:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create Procedure [dbo].[usp_Get_Backup_Details] As
/*Written by Nick Fairway on 16 Mar 2009 */

Select 	
	ServerName,
	CaptureDate,
	DatabaseName,
	DataFileName,
	BackupFileName,
	BackupStartDate,
	BackupFinishDate,
	RestoreFinishDate,
	DateDiff(s,IsNull(BackupStartDate,'01/01/1900'),IsNull(BackupFinishDate,'01/01/1900')) As BackupDuration,
	BackupSize,
	MediaSetId
From
	DBREFS.dbo.t_backup_details 
Order By ServerName,DatabaseName,BackupStartDate
