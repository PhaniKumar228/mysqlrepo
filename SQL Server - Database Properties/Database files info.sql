/*
Database files info

This script returns the main properties for all data files and log files in the current database including logical and physical file names, size, used space, and file growth parameter. 
*/

use dbname
go

select fileid, sf.groupid, grp=left([groupname],20), lname=left([name],20), size_mb=[size]/128 
,used_mb=FILEPROPERTY([name], 'SpaceUsed')/128
,file_growth=case when (sf.status&0x100000) > 0 then str(growth)+' %'
			else str(growth/128)+' mb' end
,max_mb=case when [maxsize]<0 then 'Unrestricted'
			else str([maxsize]/128) end
,phname=left(filename,70)
from sysfiles sf left outer join sysfilegroups sfg on sf.groupid=sfg.groupid
order by 1

