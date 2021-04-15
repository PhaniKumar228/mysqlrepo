/*
Attach Excel Workbook

After installing below procedure you will be able to easly attach workbook and read data from it.

This example shows how to attach excel file (c:\temp\orders.xls) and display data from named range (Table1):

Exec mysp_AttachWorkbook 'c:\temp\orders.xls', 'MyOrders'

Select * from MyOrders...Table1


*/

CREATE PROCEDURE mysp_AttachWorkbook 
    @Path nvarchar(4000),
    @AttachAs nvarchar(128)
AS

EXEC sp_addlinkedserver 
	@server = @AttachAs
    , 	@srvproduct = 'Microsoft Excel Workbook'
    , 	@provider = 'Microsoft.Jet.OLEDB.4.0'
    , 	@datasrc = @Path
    , 	@provstr = 'Excel 8.0' 

EXEC sp_addlinkedsrvlogin @AttachAs, 'false'

