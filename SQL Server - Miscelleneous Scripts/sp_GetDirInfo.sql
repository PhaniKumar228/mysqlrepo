/*

sp_GetDirInfo

Returns information about the files in the specified directory and/or subdirectories (if requested) and the total bytes for those files. Directory names are excluded so that the total bytes can be computed using the compute clause but you can specify that they be included at the expense of no total bytes. 
This sp uses the bcp utility and tries to figure out the correct path when SQL 7.0 and SQL 2000 are both installed, 
however, you can include a bcp path parameter for non-standard installations. 
Microsoft changed the output format results of "dir /a /X /-C /TC " from Windows 2000 to Windows 2003.
This updates the code to reflect the changes so the code will work on either platform.

*/

if exists (select * 
             from dbo.sysobjects 
             where id = object_id(N'[dbo].[sp_GetDirInfo]') 
             and OBJECTPROPERTY(id, N'IsProcedure') = 1)
   drop procedure [dbo].[sp_GetDirInfo]
Go

Create procedure sp_GetDirInfo 
       @vcPrimaryPath   varchar(255) = null,
       @tiIncludeSubDir tinyint      = 0,
       @vcBcpPath       varchar(255) = null,
       @cDateType       char(1)      = 'C',
       @tiIncludeDir    tinyint      = 0
As       

/*******************************************************************/
--Name        : sp_GetDirInfo
--Server      : Generic 
--Description : Captures directory information into a table. Specify
--              a particular directory (and/or its subdirectories)
--              or gather all drive file information.
--
--Parameters  : @vcPrimaryPath - Path of specified directory. Can be 
--                 a mapped drive that the SQL Server startup account  
--                 has to access. If null then all local drives are
--                 included except the C drive. Use 1 to include C.
--              @vcBcpPath - Path to bcp.exe for the current SQL 
--                 version.
--              @tiIncludeSubDir - Set to 1 to include subdirectories. 
--              @cDateType - Specifies whether to get the creation 
--                 date, last access date or the last written to date:
--                 C - creation date, A - last access date, W - last
--                 written date.
--              @tiIncludeDir - when 1 then includes directories in the
--                 listing
--
--Note        : Microsoft changed the output format of 'dir' with  
--              certain switches which requires a change in the bcp 
--              format file based on the Windows version.
-- 

/*******************************************************************/

Set nocount on

-- Declare variables.
Declare @vcCmd       varchar(255),
        @vcBcpFile   varchar(255),
        @vcPath      varchar(255),
        @vcFilePath  varchar(255),
        @dtDate      datetime,
        @iPos        int, 
        @vcValue     varchar(16),
        @cVersion    char(3),
        @cWVersion   char(3),
        @vcCollation varchar(28),
        @rtn         int
      
Select @dtDate = getdate()

-- Create a table in msdb to hold directory info.
If exists(select * from msdb.dbo.sysobjects where name = 'filelist' and uid = 1)
    Drop table msdb.dbo.filelist

-- What Windows version - 2k or 2003
If (PatIndex('%Windows NT 5.2%',@@version)) > 0 -- Win 2003
   Begin
      Exec ('Use msdb Create table dbo.filelist( ' +
            'date varchar(10) null, ' +
            'time varchar(14) null, ' +
            'info varchar(15) null, ' +
            'msdosname varchar(13) null, ' +
            'filename varchar(54) null, ' +
            'path varchar(255) null, ' +
            'prcsd tinyint null)')
   End
Else
   Begin
      Exec ('Use msdb Create table dbo.filelist( ' +
            'date varchar(10) null, ' +
            'time varchar(14) null, ' +
            'info varchar(15) null, ' +
            'msdosname varchar(16) null, ' +
            'filename varchar(50) null, ' +
            'path varchar(255) null, ' +
            'prcsd tinyint null)')
   End

       
-- If a temp table exists with the following name drop it.
If (Select object_id('tempdb.dbo.##fmtfile')) > 0
   Exec ('Drop table ##fmtfile')

-- Create a temp table to load format file string information. Make
-- it a global temp table so we can bcp the data into a format file.
Create table ##fmtfile(id int identity(1,1) not null, string varchar(96) null)

-- If a temp table exists with the following name drop it.
If (Select object_id('tempdb.dbo.#fileexists')) > 0
   Exec ('Drop table #fileexists')

-- Create a temp table to work with xp_fileexist.
Create table #fileexists(
       FileExists tinyint null,
       FileIsDirectory  tinyint null,
       ParentDirectoryExists  tinyint null)

-- If a temp table exists with the following name drop it.
If (Select object_id('tempdb.dbo.#fixeddrives')) > 0
   Exec ('Drop table #fixeddrives')

-- Create a temp table to work with xp_fileexist.
Create table #fixeddrives(
       Drive char(1) null,
       FreeSpace  varchar(15) null)

-- If a temp table exists with the following name drop it.
If (Select object_id('tempdb.dbo.#DefaultBcpPath')) > 0
   Exec ('Drop table #DefaultBcpPath')

-- Create a temp table to work with xp_fileexist.
Create table #DefaultBcpPath(Value varchar(255) null)

-- Check to see if we have enough space on drive C
Insert into #fixeddrives exec master.dbo.xp_fixeddrives
If (select convert(numeric(8), FreeSpace) from #fixeddrives where drive = 'C') < 1
   Begin
      Print 'There is not enough space on drive C to create temporary directory files.'
      Print 'Please delete some files to make room before running this procedure again.'
      Return
   End

-- Check if we want to include the C drive with all other local drives
If @vcPrimaryPath = '1' -- means to include the C drive
   Set @vcPrimaryPath = null
Else 
   Delete from #fixeddrives where drive = 'C'

-- Check SQL version
If (PatIndex('%7.00 - %',@@version) > 0) -- SQL 7.0
   Begin
      -- Set version specific variables
      Set @cVersion = '6.0'
      Set @vcCollation = ''

      -- if @vcBcpPath is null then set a default bcp file path (must be short name).
      If @vcBcpPath is null
         -- Set the SQL 7.0 bcp.exe path
         Select @vcBcpPath = 'c:\mssql7\binn\'
   End
Else -- assume SQL 2000
   Begin
      -- Set version specific variables
      Set @cVersion = '8.0'
      Set @vcCollation = 'SQL_Latin1_General_CP1_CI_AS'

      -- if @vcBcpPath is null then set a default bcp file path (must be short name).
      If @vcBcpPath is null
         Begin
             -- Get the short path for 'Program Files'
            Insert into #DefaultBcpPath
            Exec @rtn = master.dbo.xp_cmdshell 'dir /X /AD c:\"Program file?"'
            If @rtn <> 0 print 'Cannot get "Program file" short name.'
            Select @iPos = charindex('~', value) from #DefaultBcpPath where value like '%Program files'
            Select @vcBcpPath = 'c:\' + substring(value,@iPos-6, 8)  
              from #DefaultBcpPath 
             where value like '%Program files'
            Truncate table #DefaultBcpPath
            -- Get the short path for 'Microsoft SQL Server'
            Insert into #DefaultBcpPath
            Exec @rtn = master.dbo.xp_cmdshell 'dir /X /AD c:\"Program files"\"Microsoft SQL Serve?"'
            If @rtn <> 0 print 'Cannot get "Microsoft SQL Server" short name.'
            Select @iPos = charindex('~', value) from #DefaultBcpPath where value like '%Microsoft SQL Server'
            Select @vcBcpPath = @vcBcpPath + '\' + substring(value,@iPos-6, 8) + '\80\tools\binn\' 
              from #DefaultBcpPath 
             where value like '%Microsoft SQL Server'
         End
   End

-- Check for bcp file.
Select @vcBcpFile = @vcBcpPath + 'bcp.exe'
Insert into #fileexists exec master.dbo.xp_fileexist @vcBcpFile

If (select ParentDirectoryExists from #fileexists) = 0
   Begin
      Select @vcCmd = 'The bcp.exe file path, ' + @vcBcpPath + 'bcp.exe, is not valid.'
      Print @vcCmd
      Return
   End
Else
   Begin
      If (select FileExists from #fileexists) = 0
         Begin
            Select @vcCmd = 'The bcp.exe file cannot be found at ' + @vcBcpPath + '.'
            Print @vcCmd
            Return
         End
      Else
         Begin
            -- See if the path contains spaces
            If (charindex(' ', @vcBcpPath) > 0)
               Begin
                  Print 'The bcp path is valid but it contains spaces.'
                  Print 'This may cause some problems running bcp.'
                  Print 'Please replace the bcp path with the msdos or short path name.'
                  Return      
               End
         End
   End

-- Set variable path. 
Select @vcPath = @vcPrimaryPath

-- Check the directory path variable.
If @vcPrimaryPath is null
   Begin

      -- The variable was null so get all fixed drives.
      Insert into msdb.dbo.filelist
      Select null, null, '<DIR>', 'Root','Root', Drive + ':\', null
        from #fixeddrives
   End
Else
   Begin
      -- We have a specific path.
      Truncate table #fileexists

      -- Remove double quotes for use with xp_fileexists.
      Select @vcPath = Replace(@vcPrimaryPath, '"', '')
      
      -- Insure we have a trailing '\'.
      If right(@vcPrimaryPath,1) <> '\'
         Begin
            Select @vcPrimaryPath = @vcPrimaryPath + '\'
            Select @vcPath = @vcPath + '\'
         End
            
      -- The variable is not null so check for a valid path.
      Insert into #fileexists exec master.dbo.xp_fileexist @vcPrimaryPath
      If ((select ParentDirectoryExists from #fileexists) = 0) or
         ((select ParentDirectoryExists from #fileexists) = 1 and
          (select FileIsDirectory from #fileexists) = 0)
         Begin
            Select @vcCmd = 'The specified path does not exist.'
            Print @vcCmd
            Return
         End
      Else
         Begin
            -- See if the path contains spaces
            If (charindex(' ', @vcPath) > 0 and charindex('"',@vcPrimaryPath) = 0)
               Begin
                  Print 'The specified path is valid but it contains spaces.'
                  Print 'This may cause some problems running bcp.'
                  Print 'Please use double quotes around folder names that contain spaces.'
                  Return
               End
            Else
               Begin
                  Insert into msdb.dbo.filelist
                  Values (null, null, '<DIR>', '<N/A>', '<Specified>', @vcPrimaryPath, null)
               End
         End
   End

-- Build a format file for directory info.
-- What Windows version - 2k or 2003
If (PatIndex('%Windows NT 5.2%',@@version)) > 0 -- Win 2003
   Begin
      Insert into ##fmtfile(string) values(@cVersion)
      Insert into ##fmtfile(string) values('7')
      Insert into ##fmtfile(string) values('1       SQLCHAR       0       10       ""        1       date      ' + @vcCollation)
      Insert into ##fmtfile(string) values('2       SQLCHAR       0       14       ""        2       time      ' + @vcCollation)
      Insert into ##fmtfile(string) values('3       SQLCHAR       0       15       ""        3       info      ' + @vcCollation)
      Insert into ##fmtfile(string) values('4       SQLCHAR       0       13       ""        4       msdosname ' + @vcCollation)
      Insert into ##fmtfile(string) values('5       SQLCHAR       0       54       "\r\n"    5       filename  ' + @vcCollation)
      Insert into ##fmtfile(string) values('6       SQLCHAR       0       0        ""        0       path      ' + @vcCollation)
      Insert into ##fmtfile(string) values('7       SQLCHAR       0       0        ""        0       prcsd     ' + @vcCollation)
   End
Else 
   Begin
      Insert into ##fmtfile(string) values(@cVersion)
      Insert into ##fmtfile(string) values('7')
      Insert into ##fmtfile(string) values('1       SQLCHAR       0       10       ""        1       date      ' + @vcCollation)
      Insert into ##fmtfile(string) values('2       SQLCHAR       0       14       ""        2       time      ' + @vcCollation)
      Insert into ##fmtfile(string) values('3       SQLCHAR       0       15       ""        3       info      ' + @vcCollation)
      Insert into ##fmtfile(string) values('4       SQLCHAR       0       16       ""        4       msdosname ' + @vcCollation)
      Insert into ##fmtfile(string) values('5       SQLCHAR       0       50       "\r\n"    5       filename  ' + @vcCollation)
      Insert into ##fmtfile(string) values('6       SQLCHAR       0       0        ""        0       path      ' + @vcCollation)
      Insert into ##fmtfile(string) values('7       SQLCHAR       0       0        ""        0       prcsd     ' + @vcCollation)
   End

-- select * from ##fmtfile order by id -- for testing

-- Bcp out the format file
Select @vcCmd = @vcBcpFile + ' "select string from ##fmtfile order by id" queryout c:\dir.fmt /c /S' + @@servername + ' /T' -- SQL 2K
-- Select @vcCmd  -- for test
Exec @rtn = master.dbo.xp_cmdshell @vcCmd, no_output
If @rtn <> 0 print 'Failed to bcp out the fmt file.'

-- exec xp_cmdshell 'type c:\dir.fmt'  -- for test            
      
-- Get inital directory
Select @vcPath = min(path) 
  from msdb.dbo.filelist 
 where info = '<DIR>' 
   and prcsd is null
   and charindex(' ', filename) = 0


-- Loop through all directories and subdirectories
While @vcPath is not null
   Begin
      -- create a text file containing directory info
      Select @vcCmd = 'dir /a /X /-C /T' + @cDateType + ' ' + @vcPath + 
                      '>c:\dir.txt'  -- location of temp file

      --Select @vcCmd  -- for test
      Exec @rtn = master.dbo.xp_cmdshell @vcCmd, no_output
      If @rtn <> 0 print 'Failed to create the dir file for path ' + @vcPath
   
      -- use findstr to create a headerless file with fixed length records
      Select @vcCmd = 'findstr /i /r /c:"/../" c:\dir.txt>c:\fdir.txt' 
      --Select @vcCmd  -- for test
      Exec @rtn = master.dbo.xp_cmdshell @vcCmd, no_output
      If @rtn <> 0 print 'Findstr failed.'
--exec xp_cmdshell 'type c:\fdir.txt'  -- for test            
      -- bcp the directory data info msdb.dbo.filelist
      Select @vcCmd = @vcBcpFile + ' msdb.dbo.filelist in ' + 
                      'c:\fdir.txt /fc:\dir.fmt /S' + @@servername + ' /T '
      --Select @vcCmd  -- for test
      Exec @rtn = master.dbo.xp_cmdshell @vcCmd, no_output
      If @rtn <> 0 print 'Loading dir info failed.'
--select * from msdb.dbo.filelist -- for test     
      -- delete records whose filename matches any created files
      Delete 
        from msdb.dbo.filelist 
       where filename = 'dir.txt' 
          or filename = 'fdir.txt' 
          or filename = 'dir.fmt'
          or filename = '.'
          or filename = '..'
      
      -- Update the processed path
      Update msdb.dbo.filelist 
         set prcsd = 1 
       where path = @vcPath
      
      -- Update the path 
      Update msdb.dbo.filelist 
         set path = @vcPath + 
                    case when charindex(' ', filename) > 0 and info = '<DIR>' 
                         then '"' + filename + '"' 
                         else filename 
                    end +
                    case when info = '<DIR>' then '\' else '' end
       Where path is null
      
      skipit:      
      -- Stop if subdirectory info was not specified 
      -- and there are no more root directories.
      If @tiIncludeSubDir = 0 or @tiIncludeSubDir is null
         Begin
            Select @vcPath = min(path) 
              from msdb.dbo.filelist 
             where info = '<DIR>' 
               and filename = 'root'
               and prcsd is null
         End
      Else
         Begin
            -- Else get next directory path if any
            Select @vcPath = min(path) 
              from msdb.dbo.filelist 
             where info = '<DIR>' 
               and prcsd is null
               and filename <> 'System Volume Information'
         End
   End

-- Remove temp files.
Select @vcCmd = 'del c:\dir.txt'
Exec master.dbo.xp_cmdshell @vcCmd, no_output
Select @vcCmd = 'del c:\fdir.txt'
Exec master.dbo.xp_cmdshell @vcCmd, no_output
Select @vcCmd = 'del c:\dir.fmt'
Exec master.dbo.xp_cmdshell @vcCmd, no_output

-- select * from msdb.dbo.filelist --for test

-- Remove directories.
If @tiIncludeDir = 0
   Delete from msdb.dbo.filelist where info = '<DIR>'

Set nocount off

-- If no file data display a message else return the data.
If (select count(*) from msdb.dbo.filelist) = 0
   Begin
      Print 'There are no files in the specified directories.'
   End
Else
   Begin
      If @tiIncludeDir = 0
         Begin
            Select date,
                   time,
                   convert(numeric(15),info)[file size (bytes)],
                   filename,
                   path  
              from msdb.dbo.filelist
             order by path, filename
           compute sum(convert(numeric(15),info))
         End
      Else
         Begin
            Select date,
                   time,
                   info,
                   filename,
                   path  
              from msdb.dbo.filelist
             order by path, filename
         End

      Set nocount on
      Select str(datediff(ss, @dtDate, getdate())/60.0,8,3) + ' minutes' [Run Time]
   End

Go

Grant Execute on dbo.sp_GetDirInfo to public
Go
