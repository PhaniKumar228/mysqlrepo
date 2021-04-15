/*
SP to determine database file growth at intervals

I wrote this SP to be run from a job every night.
Change the myDB reference to be a database on your system for DBA use.

I just set up a job to run:
Exec sp_CatchFileChanges

Then I run in another step:

Select * from mydb.dbo.tbl_sysaltfiles_3

and output to a log file.

Alternatively you could insert into another table with a time stamp.

This gives me advanced warning if the database physical files are growing rapidly. 

*/

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_CatchFileChanges]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_CatchFileChanges]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


Create Proc sp_CatchFileChanges
AS
/********1*********2*********3*********4*********5*********6*********8*********9*********0*********1*********2*****
**
**	$Header: $
**
*******************************************************************************************************************
**  $Revision: $
**  $Author: $ 
**  $History: $
**
*******************************************************************************************************************
**
**	Name: sp_CatchFileChanges		
**	Desc: Stored procedure sp_CatchFileChanges when run will keep a copy of master.dbo.sysaltfiles for comparison later.
**              Check the table tbl_sysfiles_3 for the differences between this run and last.
**		Over time the changes will tell you the rate files in each database are growing.
**	Usage: 
**		EXEC sp_CatchFileChanges 
**
**	Return values:	
**      	0 - Completed OK
*******************************************************************************************************************
*/

if NOT exists (select * from [myDB].dbo.sysobjects where id = object_id(N'[dbo].[tbl_sysaltfiles_1]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
Begin
	CREATE TABLE [myDB].[dbo].[tbl_sysaltfiles_1] (
		[fileid] [smallint] NOT NULL ,
		[groupid] [smallint] NOT NULL ,
		[size] [int] NOT NULL ,
		[maxsize] [int] NOT NULL ,
		[growth] [int] NOT NULL ,
		[status] [int] NOT NULL ,
		[perf] [int] NOT NULL ,
		[dbid] [smallint] NOT NULL ,
		[name] [nchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[filename] [nchar] (260) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[createlsn] [binary] (10) NULL ,
		[droplsn] [binary] (10) NULL 
	)
END
if NOT exists (select * from [myDB].dbo.sysobjects where id = object_id(N'[dbo].[tbl_sysaltfiles_2]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
Begin
	CREATE TABLE [myDB].[dbo].[tbl_sysaltfiles_2] (
		[fileid] [smallint] NOT NULL ,
		[groupid] [smallint] NOT NULL ,
		[size] [int] NOT NULL ,
		[maxsize] [int] NOT NULL ,
		[growth] [int] NOT NULL ,
		[status] [int] NOT NULL ,
		[perf] [int] NOT NULL ,
		[dbid] [smallint] NOT NULL ,
		[name] [nchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[filename] [nchar] (260) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[createlsn] [binary] (10) NULL ,
		[droplsn] [binary] (10) NULL 
	)
END
if NOT exists (select * from [myDB].dbo.sysobjects where id = object_id(N'[dbo].[tbl_sysaltfiles_3]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
Begin
	CREATE TABLE [myDB].[dbo].[tbl_sysaltfiles_3] (
		[fileid] [smallint] NOT NULL ,
		[groupid] [smallint] NOT NULL ,
		[size] [int] NOT NULL ,
		[maxsize] [int] NOT NULL ,
		[growth] [int] NOT NULL ,
		[status] [int] NOT NULL ,
		[perf] [int] NOT NULL ,
		[dbid] [smallint] NOT NULL ,
		[name] [nchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[filename] [nchar] (260) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[createlsn] [binary] (10) NULL ,
		[droplsn] [binary] (10) NULL 
	)
END

Truncate Table [myDB].[dbo].[tbl_sysaltfiles_2]

INSERT INTO [myDB].[dbo].[tbl_sysaltfiles_2]([fileid], [groupid], [size], [maxsize], [growth], [status], [perf], [dbid], [name], [filename], [createlsn], [droplsn])
Select [fileid], [groupid], [size], [maxsize], [growth], [status], [perf], [dbid], [name], [filename], [createlsn], [droplsn] From myDB.dbo.tbl_sysaltfiles_1

Truncate Table [myDB].[dbo].[tbl_sysaltfiles_1]

INSERT INTO [myDB].[dbo].[tbl_sysaltfiles_1]([fileid], [groupid], [size], [maxsize], [growth], [status], [perf], [dbid], [name], [filename], [createlsn], [droplsn])
Select [fileid], [groupid], [size], [maxsize], [growth], [status], [perf], [dbid], [name], [filename], [createlsn], [droplsn] From master.dbo.sysaltfiles

Truncate Table [myDB].[dbo].[tbl_sysaltfiles_3]

INSERT INTO [myDB].[dbo].[tbl_sysaltfiles_3]([fileid], [groupid], [size], [maxsize], [growth], [status], [perf], [dbid], [name], [filename], [createlsn], [droplsn])
Select 
  X1.[fileid]
, X1.[groupid]
, X1.[size]
, X1.[maxsize]
, X1.[growth]
, X1.[status]
, X1.[perf]
, X1.[dbid]
, X1.[name]
, X1.[filename]
, X1.[createlsn]
, X1.[droplsn] 
From myDB.dbo.tbl_sysaltfiles_1 X1 Inner Join myDB.dbo.tbl_sysaltfiles_2 X2
On X1.filename = X2.Filename
Where 
   X1.[size]    <> X2.[size]
OR X1.[maxsize] <> X2.[maxsize]
OR X1.[growth]  <> X2.[growth]



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[sp_CatchFileChanges]  TO [public]
GO


