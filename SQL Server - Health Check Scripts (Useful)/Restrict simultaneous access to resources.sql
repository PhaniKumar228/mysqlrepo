/*
Restrict simultaneous access to resources

This set of procedures allow you to control simultaneous access to any resource you are using. 
It mimics the behaviour of a Semaphore in programming.

A typical problem where you need this, is when you have a computational intensive procedure you only want to be started a limited number of times.

First, add a record to the Semaphore table, identifying the maximum number of simultaneous 'users' of the resource.
Whenever you need access to that specific resource, you add a call to usp_LockSemaphore to the beginning of your call. 
If the procedure returns 0 (zero), you can continue using the resource.
After the resource is no longer used, call usp_UnlockSemaphore. 

*/
--------------------------------------------------------------------
-- Create the table that holds Semaphore data
--
-- Fields : 
-- SemName          The Name of the semaphore used to identify it
-- MaxInstance      The maximum number of concurrent processes using
--                  this Semaphore
-- CurInstance      The current number of concurrent processes that
--                  are using this Semaphore
-- SemDescription   Free description field
--------------------------------------------------------------------
CREATE TABLE Semaphore
(
SemName	VARCHAR (25) CONSTRAINT PK_Semaphores PRIMARY KEY NOT NULL,
MaxInstance INT NOT NULL,
CurInstance INT NOT NULL CONSTRAINT DF_CurInstance DEFAULT 0,
SemDescription VARCHAR(255) NULL
)

DROP PROCEDURE usp_lockSemaphore
--------------------------------------------------------------------
-- Create the Stored Procedure to take control of the Semaphore
--
-- Parameters :
-- SemName           The name of the Semaphore to take control of
--
-- ReturnValues :
-- 0 (zero)          Access to the protected resource is allowed
-- Negative          Error occurred
-- 1 (one)           Access to the protected resource is not allowed
--------------------------------------------------------------------
CREATE PROCEDURE usp_LockSemaphore
@SemName varchar(25)
AS
DECLARE @iMaxInstance int
DECLARE @iCurInstance int
DECLARE @iReturnValue int
DECLARE @iRowCount    int
-- Start the transaction
BEGIN TRANSACTION
-- Fetch the value
SELECT @iMaxInstance = MaxInstance, @iCurInstance = CurInstance
FROM Semaphore WITH (ROWLOCK)
WHERE SemName = @SemName
SET @iRowCount = @@ROWCOUNT
IF @@ERROR <> 0
BEGIN
   SET @iReturnValue = -1
END
ELSE IF @iRowCount <> 1
BEGIN
   SET @iReturnValue = -2
END
ELSE
    -- Check the value
    IF @iMaxInstance > @iCurInstance 
    BEGIN
    	-- Update the value
	UPDATE Semaphore
        SET CurInstance = @iCurInstance + 1
        WHERE SemName = @SemName
        -- Set return value
        SET @iReturnValue = 0
    END
    ELSE
	SET @iReturnValue = 1
-- End the transaction
COMMIT TRANSACTION
-- Return from the procedure
RETURN @iReturnValue
GO

--------------------------------------------------------------------
-- Create the Stored Procedure to release control over the Semaphore
--
-- Parameters :
-- SemName           The name of the Semaphore to release
--
-- ReturnValues :
-- 0 (zero)          Success 
-- Nonzero           Failure
--------------------------------------------------------------------
CREATE PROCEDURE usp_UnlockSemaphore
@SemName varchar(25)
AS
DECLARE @iReturnValue int
-- Update the value
UPDATE Semaphore SET CurInstance = CASE CurInstance -1 WHEN -1 THEN 0 ELSE CurInstance - 1 END
WHERE SemName = @SemName
IF @@ERROR <> 0
BEGIN
   SET @iReturnValue = -1
END
ELSE
BEGIN
   SET @iReturnValue = 0
END
-- Return from the procedure
RETURN @iReturnValue
GO
