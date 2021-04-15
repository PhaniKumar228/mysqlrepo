--drop TABLE [dbo].[Table_Audit]
--drop PROCEDURE [dbo].[USPU_Generate_Audit_Trigger]
--Create a table called Table_Audit
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Table_Audit](
	[RID] [int] IDENTITY(1,1) NOT NULL,
	[TableName] [varchar](100) NOT NULL,
	[Action] [char](1) NOT NULL,
	[txtXML] [xml] NOT NULL,
	[DateAction] [datetime] NOT NULL CONSTRAINT [DF_Table_Audit_DateAction]  DEFAULT (getdate()),
 CONSTRAINT [PK_Table_Audit] PRIMARY KEY CLUSTERED 
(
	[RID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF

--Create Stored procedure to generate Audit Triggers

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Stored Procedure to generate Audit triggers
-- =============================================
CREATE PROCEDURE [dbo].[USPU_Generate_Audit_Trigger]
	@tblName varchar(100) =''									--Table name to add triggers to 
AS
BEGIN

Set NOCOUNT ON

Declare @s0 varchar(4000)				--to drop triggers if exists  
Declare @s1 varchar(4000)				--Create Insert Trigger
Declare @s2 varchar(4000)				--Update Trigger
Declare @s3 varchar(4000)				--Delete Trigger
Declare @s varchar(4000)


Select @s0 ='
IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[tri_@tblName_INSERT]''))
DROP TRIGGER [dbo].[tri_TestData_INSERT]
IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[tri_@tblName_UPDATE]''))
DROP TRIGGER [dbo].[tri_TestData_UPDATE]
IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[tri_@tblName_DELETE]''))
DROP TRIGGER [dbo].[tri_TestData_DELETE]
'

Select @s1 = '
Create TRIGGER [dbo].[tri_@tblName_INSERT] ON [dbo].[@tblName] 
For INSERT 
AS
    
	Declare @x as XML
    Select @x = (Select * from Inserted FOR XML AUTO, BINARY BASE64 , ELEMENTS, Root(''ROOT''))
      
	Insert Table_Audit(TableName,txtXML,Action) Select ''@tblName'',@x,''I''
'

Select @s2 = '
Create TRIGGER [dbo].[tri_@tblName_UPDATE] ON [dbo].[@tblName] 
For Update 
AS
    
	Declare @x as XML
    Select @x = (Select * from Inserted FOR XML AUTO, BINARY BASE64 , ELEMENTS, Root(''ROOT''))
	Insert Table_Audit(TableName,txtXML,Action) Select ''@tblName'',@x,''U''

'

Select @s3 = '
Create TRIGGER [dbo].[tri_@tblName_DELETE] ON [dbo].[@tblName] 
For DELETE 
AS
	Declare @x as XML
	Select @x = (Select * from Deleted FOR XML AUTO, BINARY BASE64 , ELEMENTS, Root(''ROOT''))
	Insert Table_Audit(TableName,txtXML,Action) Select ''@tblName'',@x,''D''

'

	Select @s= Replace(@s0,'@tblName',@tblName)
	Execute (@s)
	Select @s= Replace(@s1,'@tblName',@tblName)
	Execute (@s)
	Select @s= Replace(@s2,'@tblName',@tblName)
	Execute (@s)
    Select @s = Replace(@s3,'@tblName',@tblName) 
	Execute (@s)
    Return 0


END
