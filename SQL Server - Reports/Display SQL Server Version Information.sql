/*
Display SQL Server Version Information

Description

Display SQL Server Version Information.

Supported Platforms

SQL Server 2000
 Yes
 

Script Code


*/

strDBServerName = "."

Set objSQLServer = CreateObject("SQLDMO.SQLServer")
objSQLServer.LoginSecure = True
objSQLServer.Connect strDBServerName

WScript.Echo "SQL Major Version: " & objSQLServer.VersionMajor
WScript.Echo "SQL Minor Version: " & objSQLServer.VersionMinor
WScript.Echo "SQL Version String: " & objSQLServer.VersionString
