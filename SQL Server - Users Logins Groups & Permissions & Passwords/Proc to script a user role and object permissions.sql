/*
Proc to script a user role and object permissions

I wanted to be able to prepare a script of User Roles and permissions for objects in a database so I can be prepared for backup and disaster recovery scenarios. 

I also wanted to be able to audit the permissions for each role.

I wrote this stored procedure to do this.  

The usage is:

Use Northwind
go
DECLARE @RC int
DECLARE @RoleName varchar(85)
Select @RoleName = 'exec_proc'
EXEC @RC = dbo.sp_ScriptRole @RoleName
Select @RC 
*/

Use master
go
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_ScriptRole]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_ScriptRole]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


Create Procedure sp_ScriptRole
	(
	 @RoleName varchar(85)
	)
AS

/********1*********2*********3*********4*********5*********6*********8*********9*********0*********1*********2*****
**
**  $Archive$
**  $Revision$
**  $Author$ 
**  $Modtime$
**
*******************************************************************************************************************
**
**  $Log$
**
*******************************************************************************************************************
**
**	Name: sp_ScriptRole
**	Desc: This procedure prepares a script of the role and permissions 
**		of a given role (or user) in the current database.
**	NOTE: This only scripts the permissions in the current database for a given role or user on user objects
**		It does not script extended permissions such as create table, create view, backup database or 
**		system roles
**	
**	Return values: 0 = Successful, error number if failed
**              
*******************************************************************************************************************
**		Change History - All Author comments below this point.
*******************************************************************************************************************
**  Author	Date		Description
**  -------	--------	-------------------------------------------
**  NBJ		10-Oct-2002	Original - SP to script a user role
******************************************************************************************************************/

Declare   	@Err 	int
Set nocount on
Select @Err = 0

If @RoleName is Null
Begin
	Select @RoleName = 'my_default_role'
End
-- This table is to store the type of user action 
-- that is coded in the sysprotects system table  e.g Insert, Update, Select
CREATE TABLE #tblaction (
	[Action] [int] NOT NULL ,
	[Name] [varchar] (85) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
)
-- This table is to store the Grant or Revoke info that is coded in the sysprotects system table
CREATE TABLE #tblprotecttype (
	[protecttype] [int] NULL ,
	[Name] [varchar] (85) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
)
-- These values can be found in SQL Books Online in the definition of the sysprotects table
Insert #tblprotecttype (protecttype, Name) Values (204,'GRANT_W_GRANT')
Insert #tblprotecttype (protecttype, Name) Values (205,'GRANT')
Insert #tblprotecttype (protecttype, Name) Values (206,'REVOKE')
Insert #tblaction (Action, Name) Values (26,'REFERENCES')
Insert #tblaction (Action, Name) Values (178,'CREATE FUNCTION')
Insert #tblaction (Action, Name) Values (193,'SELECT')
Insert #tblaction (Action, Name) Values (195,'INSERT')
Insert #tblaction (Action, Name) Values (196,'DELETE')
Insert #tblaction (Action, Name) Values (197,'UPDATE')
Insert #tblaction (Action, Name) Values (198,'CREATE TABLE')
Insert #tblaction (Action, Name) Values (203,'CREATE DATABASE')
Insert #tblaction (Action, Name) Values (207,'CREATE VIEW')
Insert #tblaction (Action, Name) Values (222,'CREATE PROCEDURE')
Insert #tblaction (Action, Name) Values (224,'EXECUTE')
Insert #tblaction (Action, Name) Values (228,'BACKUP DATABASE')
Insert #tblaction (Action, Name) Values (233,'CREATE DEFAULT')
Insert #tblaction (Action, Name) Values (235,'BACKUP LOG')
Insert #tblaction (Action, Name) Values (236,'CREATE RULE')

-- Get role, objectname and object id into a table for given role
select @RoleName as Role, name AS objectname, id, xtype into #tmpX1 from sysobjects where id in 
	(select id from sysprotects where uid in 
		(select uid from sysusers where name = @RoleName)) 
Select @Err = @@Error
If @Err <> 0
Begin
	Return @Err
End	
-- Get the protection information for each object from sysprotects
select P.id as [ID], tP.Name as [Action], tA.Name as [ProtectType] into #tmpX2 from  #tblprotecttype tP, sysprotects P, #tblaction tA 
where P.action = tA.action AND P.protecttype = tP.protecttype AND  P.uid in 
		(select uid from sysusers where name = @RoleName)  
Select @Err = @@Error
If @Err <> 0
Begin
	Return @Err
End	
-- Script the role itself,  if needed this can be modified to test for existence first.
Select 'Exec sp_addrole ' + @RoleName + char(10) + 'go'
-- Generate the Grant and Revoke statements for each object.
Select rtrim(Action) + ' ' + rtrim(ProtectType) + ' ON ' + rtrim(objectname) + ' TO ' + rtrim(role) + char(10) + 'go' from #tmpX1 Inner Join #tmpX2 ON #tmpX1.id = #tmpX2.id order by objectname
Select @Err = @@Error
If @Err <> 0
Begin
	Return @Err
End	


-- Housekeeping
drop table #tmpX1, #tmpX2, #tblprotecttype, #tblaction
Select @Err = @@Error
If @Err <> 0
Begin
	Return @Err
End	
Return 0



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


