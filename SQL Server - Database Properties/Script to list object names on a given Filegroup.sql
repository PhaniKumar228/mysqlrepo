
/*
Script to list object names on a given Filegroup

This script is useful when want find out the list of the object on a given filegroup. 
*/

Create procedure List_ObjNames_FileGroup
@FG_Name Varchar(25)
AS
SELECT DISTINCT un.name, ung.groupname 
FROM sysobjects un INNER JOIN sysindexes si ON un.id=si.id 
INNER JOIN sysfilegroups ung ON si.groupid=ung.groupid 
WHERE ung.groupname= @FG_Name
