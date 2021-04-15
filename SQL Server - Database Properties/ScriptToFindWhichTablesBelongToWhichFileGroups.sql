--1. Given a File Group Name, how to find all the tables 
--   that belong the file group


CREATE PROC usp_FilegroupObjects @FGName sysname
AS

SELECT s.groupname AS FileGroupName, object_name(id) AS ObjectName
			FROM SYSFILEGROUPS s, SYSINDEXES i
			WHERE  i.indid < 2
				AND i.groupid = s.groupid
				AND s.groupname = @FGname 
ORDER BY object_name(id)

/******* --Sample output from my database

FileGroupName       ObjectName
-------------       ----------
FileGroup1	    authors
FileGroup1	    discounts
FileGroup1	    employee
FileGroup1	    jobs
FileGroup1	    pub_info
FileGroup1	    publishers

*******/

--2. To find all the tables that belong to each file group


CREATE PROC usp_AllFilegroupsObjects
AS

SELECT s.groupname AS GroupName, object_name(id) AS ObjectName
			FROM SYSFILEGROUPS s, SYSINDEXES i
			WHERE  i.indid < 2
				AND i.groupid = s.groupid
				AND s.groupname IN ( 'Filegroup1', 'Filegroup2', 'PRIMARY') --You need to mention your File Groups here in the 'IN Clause'
ORDER BY s.groupname

/******* --Sample output from my database

FileGroupName       ObjectName
-------------       ----------
FileGroup1	    discounts
FileGroup1	    employee
FileGroup1	    authors
FileGroup1	    pub_info
FileGroup1	    publishers
FileGroup1	    jobs
FileGroup2	    stores
FileGroup2	    titles
FileGroup2	    roysched
FileGroup2	    sales
FileGroup2	    titleauthor
PRIMARY	sysobjects
PRIMARY	sysindexes
PRIMARY	syscolumns
PRIMARY	systypes
PRIMARY	syscomments
PRIMARY	sysfiles1
PRIMARY	syspermissions
PRIMARY	sysusers
PRIMARY	sysproperties
PRIMARY	sysdepends
PRIMARY	sysreferences
PRIMARY	sysfulltextcatalogs
PRIMARY	sysfulltextnotify
PRIMARY	sysfilegroups
PRIMARY	dtproperties

*******/
