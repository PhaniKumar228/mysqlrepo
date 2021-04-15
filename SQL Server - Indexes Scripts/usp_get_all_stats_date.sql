/*
usp_get_all_stats_date

This script gathers stats_date and index information for all of the current database. 
Please feel free to modify it as it is made up of components that are available on this site here- http://www.sqlservercentral.com/scripts/contributions/97.asp
and a BOL entry for stats_date.
I needed this information and thought I would share it. 

*/

-- This procedure will query to find out the stats_date for all indexes in the current database. 
-- I needed it, and thought I would share it. It uses the simple loop on this site
--  http://www.sqlservercentral.com/scripts/contributions/97.asp and the BOL entry for "stats_date"
-- Scott Skeen

create procedure dbo.usp_all_stats_date
as

declare @objName VARCHAR(50)
declare @temp table
			(tablename varchar(100)
			,indexname varchar (100)
			,[rowcount] varchar (100)
			,indexid varchar(100)
			,statisticsdate varchar(100))  

SET	@objName = ''

WHILE	@objName IS NOT NULL
	BEGIN
		
SELECT @objName = MIN( Name )
		FROM	SysObjects
		WHERE	Type='U' AND
			Name > @objName

		IF	@objName IS NOT NULL
			BEGIN
			insert into @temp

SELECT 	@objname
	,'Index Name' = i.name
	,i.rowcnt
	,i.indid	
	,'Statistics Date' = STATS_DATE(i.id, i.indid)
	

FROM 	sysobjects o
	,sysindexes i
WHERE 
	o.name =@objname 
	AND o.id = i.id
	
 
			END
	END

select * from @temp order by tablename 





