/*
Display the free space for a SQL Server database.

Description

Display the free space for a SQL Server database.

Supported Platforms

SQL Server 2000
 Yes
 

Script Code


*/

strDBServerName = "."
strDBName = "ScriptingGuysTestDB"

Set objSQLServer = CreateObject("SQLDMO.SQLServer")
objSQLServer.LoginSecure = True
objSQLServer.Connect strDBServerName

Set objDB = objSQLServer.Databases(strDBName)
WScript.Echo "Space Left (Data File + Transaction Log) for DB " &_
 strDBName & ": " & objDB.SpaceAvailableInMB & "(MB)"

