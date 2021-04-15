SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE function ObSize(@s VARCHAR(255) ) 
returns int
as
BEGIN
declare @i int
set @i=(SELECT SUM(DATALENGTH(dbo.syscomments.text)) AS Expr1
FROM dbo.syscomments INNER JOIN
                      dbo.sysobjects ON dbo.syscomments.id = dbo.sysobjects.id
WHERE     (dbo.sysobjects.name =@s)
)
return @i
END
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE PROCEDURE sp_ObSize  (@s VARCHAR(255), @size int OUT ) 
AS
declare @i int
set @i=(
SELECT     SUM(DATALENGTH(dbo.syscomments.text)) AS Expr1
FROM         dbo.syscomments INNER JOIN
                      dbo.sysobjects ON dbo.syscomments.id = dbo.sysobjects.id
WHERE     (dbo.sysobjects.name =@s)
)
set @size= @i
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
