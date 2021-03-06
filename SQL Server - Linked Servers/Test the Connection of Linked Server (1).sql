USE [DIMSCONSOLIDATEDData]
GO
/****** Object: StoredProcedure [dbo].[General_TestLinkedServer] Script Date: 08/07/2007 09:15:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[General_TestLinkedServer] @DistrictID INT
AS 
 BEGIN
 DECLARE @TestResult BIT,
 @Alias VARCHAR(50),
 @ServerName SYSNAME
 SET @Alias = dbo.General_FXN_Alias(@DistrictID, '')
 SET @servername = dbo.General_FXN_ResolveServerName(@Alias) 

BEGIN TRY
 EXEC @TestResult = sys.sp_testlinkedserver @servername 
 RETURN '1'
END TRY
 BEGIN CATCH
--write to windows system log or write to an error table
 INSERT INTO General_Error_Log
 (
 ErrorMessage,
 [DateTime],
 Alias,
 Sproc,
 ErrorCode
 )
 VALUES (
 'An error occured in the connection to '
 + ISNULL(@servername, 'unknown server') + ' at '
 + CONVERT(VARCHAR, GETDATE()) + ' on ' + @@servername
 + '. The error code returned was '
 + ISNULL(CONVERT(VARCHAR, @@Error),
 'the server does not exist in catalogue') + '.',
 GETDATE(),
 ISNULL(@Alias, 'unknown server'),
 'General_TestLinkedServer',
 @@Error
 )
 END CATCH
 RETURN '0'
 END

USE [DIMSCONSOLIDATEDData]
GO
/****** Object: UserDefinedFunction [dbo].[General_FXN_Alias]  Script Date: 08/07/2007 08:44:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[General_FXN_Alias]
(
 @DistrictID int,
 @Table varchar(50) = 'sysobjects'
)
RETURNS varchar(90)
AS
BEGIN
 -- Declare the return variable here
 -- Add the T-SQL statements to compute the return value here

 RETURN (SELECT Alias from General_District where districtID = @districtID) + '.' + @Table
END
and

USE [DIMSCONSOLIDATEDData]
GO
/****** Object: Table [dbo].[General_Error_Log]  Script Date: 08/07/2007 09:21:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[General_Error_Log](
 [ErrorID] [bigint] IDENTITY(1,1) NOT NULL,
 [ErrorMessage] [varchar](255) NULL,
 [DateTime] [datetime] NOT NULL,
 [Alias] [varchar](50) NOT NULL,
 [Sproc] [varchar](50) NOT NULL,
 [ErrorCode] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF