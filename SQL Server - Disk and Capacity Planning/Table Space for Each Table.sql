/*
Table Space for Each Table

This uses sp_MStablespace from an article on this site and a cursor to run against all tables in the context of the db it is called in. One catch is it does not like table names with spaces. 

*/

CREATE PROCEDURE sp_dba_gettablespace

AS 

BEGIN 

DECLARE gettable INSENSITIVE CURSOR FOR 

     Select name from sysobjects
	where type = 'U'

FOR READ ONLY 

      OPEN gettable 

DECLARE @TBName varchar(50), @MSG varchar(255),  @sqlstr varchar(254) 

    FETCH NEXT FROM gettable INTO @TBName 

    WHILE (@@FETCH_STATUS = 0) 

BEGIN

        
	Print @TBName+' is the table schema below..'
	Print '' 

 
Set nocount off 

SELECT @sqlstr= 'sp_MStablespace '+ @TBName

EXECUTE (@sqlstr) 

   PRINT '' 

FETCH NEXT FROM gettable   INTO @TBName 

END  

CLOSE gettable 

DEALLOCATE gettable 

END




