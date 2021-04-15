/*
Displays the total size of a SQL Server database

Description

Sample script that displays the total size of a SQL Server DB.

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
WScript.Echo "Total Size of Data File + Transaction Log of DB " & strDBName & ": " & objDB.Size & "(MB)"