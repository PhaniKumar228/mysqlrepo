/*
Auto Fix Orphaned Users
Add this procedure to the master database, it can then be executed from any DB to fix orphaned users 
(very useful when moving back to development). 
Using sp_msforeachdb with the proc allows you to resolve orphaned users in all databases in a 
single command: SP_MSFOREACHDB "USE ?; EXEC SP_AUTOFIX_USERS;" 
*/

CREATE PROCEDURE SP_AUTOFIX_USERS
AS
/* USAGE FOR FIX USER SIDS FOR ALL DATABASES
	SP_MSFOREACHDB "USE ?; EXEC SP_AUTOFIX_USERS;"
*/ 
-- Declare the variables to store the values returned by FETCH.
set nocount on
declare @login sysname

PRINT DB_NAME()
PRINT '--------'
DECLARE user_update_cursor CURSOR FOR
SELECT distinct name from sysusers where  issqluser = 1 and name not in ('dbo', 'guest') order by name


OPEN user_update_cursor
-- Perform the first fetch and store the values in variables.
-- Note: The variables are in the same order as the columns
-- in the SELECT statement. 

FETCH NEXT FROM user_update_cursor
INTO  @login

-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
WHILE @@FETCH_STATUS = 0
BEGIN
print @login
	exec sp_change_users_login 'update_one', @login, @login
   -- This is executed as long as the previous fetch succeeds.
   FETCH NEXT FROM user_update_cursor
   INTO  @login
END

CLOSE user_update_cursor
DEALLOCATE user_update_cursor

