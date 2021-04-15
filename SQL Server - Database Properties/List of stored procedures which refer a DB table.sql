/*
	  Get the list Stored Procedures which uses a DB table  
	  It used from syscomments, sysobjects table to gather information
	  It may not be accurate if the DB is not refreshed
	  
*/
SELECT DISTINCT
	 	 c.id,o.id, name 
FROM 	 syscomments c inner join sysobjects o  on c.id = o.id 
WHERE	 TEXT like '%backup%'  -- Product : Table Name
		 AND o.xtype='P'
ORDER BY o.name

