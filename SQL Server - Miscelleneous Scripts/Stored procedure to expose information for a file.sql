SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_FileInfo]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_FileInfo]
GO

CREATE PROCEDURE dbo.sp_FileInfo
	(  @FileName 	 	nvarchar(2048) = NULL
	 , @FileExists 	 	nvarchar(1)  = NULL OUTPUT 
	 , @IsDir	 		nvarchar(1)  = NULL OUTPUT
	 , @ParentDirExists 	nvarchar(1)  = NULL OUTPUT
	 , @AltName 		nvarchar(20) = NULL OUTPUT
	 , @FileSize 		nvarchar(11) = NULL OUTPUT
	 , @CrDate 			nvarchar(8)  = NULL OUTPUT
	 , @CrTime 			nvarchar(6)  = NULL OUTPUT
	 , @LastWriteDate	nvarchar(8)  = NULL OUTPUT
	 , @LastWriteTime	nvarchar(6)  = NULL OUTPUT
	 , @LastAccessDate	nvarchar(8)  = NULL OUTPUT
	 , @LastAccessTime	nvarchar(6)  = NULL OUTPUT
	 , @Attributes		nvarchar(11) = NULL OUTPUT )

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
**	Name: sp_FileInfo
**	Desc: This procedure checks for information for given file or directory
**		It returns the values as separate parameters.
**	NOTE: Attributes can be transalated as follows:
**	
**	Attribute 		File		Folder
**	Read Only R		1		17		i.e. add 16 to make reference to folder
**	Hidden	H		2		18
**	RH			3		19
**	Archive	A		32		48
**	AR			33		49
**	AH			34		50
**	ARH			35		51
**	none			128		38
**	Compressed C		2048		2064		Note:  all attribute values are additive
**	
**	
**	Return values: 0 = Successful, error number if failed
**              
*******************************************************************************************************************
**		Change History - All Author comments below this point.
*******************************************************************************************************************
**  Author	Date		Description
**  -------	--------	-------------------------------------------
**  NBJ		30-Jan-2002	Original - SP to get results of xp_fileexist and xp_getfiledetails
******************************************************************************************************************/

Declare   @Err int
Select @Err = 0

If @FileName is Null
Begin
	Return 1
End

Set nocount on

Create table #tmp1
(
 FileExists nvarchar(1)
,IsDir nvarchar(1)
,ParentDirExists nvarchar(1)
)
Create table #tmp2
(
 AltName nvarchar(20)
,FileSize nvarchar(11)
,CrDate nvarchar(8)
,CrTime nvarchar(6)
,LastWriteDate nvarchar(8)
,LastWriteTime nvarchar(6)
,LastAccessDate nvarchar(8)
,LastAccessTime nvarchar(6)
,Attributes nvarchar(11)
)
Select @Err = @@Error
If @Err <> 0 
Begin
	Return @Err
End
Insert into #tmp1
Exec Master.dbo.xp_fileexist @FileName
Select @Err = @@Error
If @Err <> 0 
Begin
	Return @Err
End
Insert Into #tmp2
Exec Master.dbo.xp_getfiledetails @FileName
Select @Err = @@Error
If @Err <> 0 
Begin
	Return @Err
End
Select 
 @FileExists 	  = FileExists
,@IsDir 	  = IsDir
,@ParentDirExists = ParentDirExists
From #tmp1 Where FileExists In ('0','1')
Select @Err = @@Error
If @Err <> 0 
Begin
	Return @Err
End
Select 
  @FileSize 		=  FileSize
, @CrDate 		=  CrDate
, @CrTime 		=  CrTime
, @LastWriteDate	=  LastWriteDate
, @LastWriteTime	=  LastWriteTime
, @LastAccessDate	=  LastAccessDate
, @LastAccessTime	=  LastAccessTime
, @Attributes		=  Attributes 
, @AltName 		=  AltName
From #tmp2 Where cast(Attributes as int) > 0 -- used to pick up row with values

Select @Err = @@Error
If @Err <> 0 
Begin
	Return @Err
End
--  Use this to check values
/*
Select	   @FileExists 	 	
	 , @IsDir	 	
	 , @ParentDirExists 	
	 , @AltName 		
	 , @FileSize 		
	 , @CrDate 		
	 , @CrTime 		
	 , @LastWriteDate	
	 , @LastWriteTime	
	 , @LastAccessDate	
	 , @LastAccessTime	
	 , @Attributes
*/
drop table #tmp1
drop table #tmp2

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

