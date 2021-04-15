/*
List Network Share Directories Quickly

Need a quick way to list shared folders?  Do it in one call.  Great for ASP page popups and user drop-down lists.

Let's say that you want to display a list of projects, just call usp_GET_ProjectFolder and VIOLA! 

Only works with 2k; however, can be ported to ss7 if the udf is ported to a proc (using the ouput parameter).
Have fun, code cleanly. 

*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

CREATE  FUNCTION udf_DM_ROOT_DIR() RETURNS VARCHAR(255)
AS
   BEGIN
   /***
    *   Date:         2/2/02
    *   Project:      Directory Listing
    *   Location:     Any user database
    *   Permissions:  PUBLIC EXECUTE
    *   
    *   Description:  Returns the 
    *   
    *   TODO:  Put your share name here, make sure
    *          the folder has a PROJECT folder under
    *          it.  The share name below is considered
    *          the root directory.
    *          So make sure  \\myServer\MyShare\Project
    *          exists.  (of course myServer\MyShare
    *          are ficticious, so replace to match your
    *          setup!! ;-)
    ***/
      RETURN '\\myServer\MyShare\'
   END
GO
GRANT EXECUTE ON udf_DM_ROOT_DIR TO PUBLIC
GO
CREATE  PROC usp_SubDirs (@path VARCHAR(255))
AS
BEGIN
   /***
    *   Date:         2/2/02
    *   Author:       <mailto:mikemcw@4segway.biz>
    *   Project:      Directory Listing
    *   Location:     Any user database
    *   Permissions:  PUBLIC EXECUTE
    *   
    *   Description:  Returns a list of folders
    *                 Supports any directory name.
    *                 (It's a general DIR function
    ***/

   SET NOCOUNT ON

   DECLARE @strSQL      VARCHAR(1024)
   DECLARE @PathPrefix  VARCHAR(5)
   DECLARE @nDirNamePos TINYINT

   CREATE TABLE #Dirs (DirName VARCHAR(255))
   CREATE INDEX #idx#Dirs ON #Dirs  (DirName)

   SET @strSQL      = 'DIR ' + @path
   SET @PathPrefix  = '.'
   SET @nDirNamePos = 40

   --Get all the files and directories at the drive/path specified
   INSERT INTO #Dirs EXEC master..xp_cmdshell @strSQL

   DELETE FROM #Dirs WHERE  DirName IS NULL
   DELETE FROM #Dirs WHERE DirName NOT LIKE '% <DIR> %'

   DELETE FROM #Dirs WHERE CHARINDEX(RTRIM(@PathPrefix),  SUBSTRING(Dirname, @nDirNamePos, 255)) = 1
   
   UPDATE #Dirs SET Dirname = SUBSTRING(Dirname, @nDirNamePos, 255)
   SELECT Dirname FROM #Dirs

   DROP TABLE #Dirs
END
GO
GRANT EXECUTE ON usp_SubDirs TO PUBLIC
GO
CREATE  PROC usp_GET_ProjectFolder
AS
BEGIN
   /***
    *   Date:         2/2/02
    *   Author:       <mailto:mikemcw@4segway.biz>
    *   Project:      Directory Listing
    *   Location:     Any user database
    *   Permissions:  PUBLIC EXECUTE
    *   
    *   Description:  Returns the folders found
    *                 [project] directory
    *   
    *   
    ***/

   DECLARE @vDir VARCHAR(255)
   SET @vDir = dbo.udf_DM_ROOT_DIR() + 'PROJECT\*. '
   EXECUTE usp_SubDirs @vDir
END
GO
GRANT EXECUTE ON usp_REQDIR_Project TO PULIC
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

