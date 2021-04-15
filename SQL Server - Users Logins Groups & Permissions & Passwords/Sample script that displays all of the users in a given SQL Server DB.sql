/*
Sample script that displays all of the users in a given SQL Server DB.

Description

Sample script that displays all of the users in a given SQL Server DB.

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
Set colUsers = objDB.Users
For Each objUser In colUsers
   WScript.Echo "User: "    & objUser.Name
   WScript.Echo "Login: "   & objUser.Login
Next
