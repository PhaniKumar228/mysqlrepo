CREATE  FUNCTION dbo.udf_ElapsedTime(@StartDateTime DATETIME, @EndDateTime DATETIME)
  RETURNS VARCHAR(15) AS
BEGIN
  DECLARE @HOURS VARCHAR(12)
      SET @HOURS=CONVERT(VARCHAR(12)
                  ,CONVERT(MONEY
                    ,DATEDIFF(HH,0,@EndDateTime-@StartDateTime)
                   )
                ,1)  --Puts commas in conv. from Money to Varchar
      SET @HOURS=LEFT(@HOURS,LEN(@HOURS)-3) --Drop .00 of hours
   RETURN RIGHT(SPACE(15)
            +@HOURS+RIGHT(
                     CONVERT(VARCHAR(8)
                      ,@EndDateTime-@StartDateTime
                    ,108) -- HH:MM:SS time format
                  ,6) --Grab just right 6 or :MM:SS
         ,15) --Grab just right 15 to right justify result
END

SELECT dbo.udf_ElapsedTime('2008-01-01',getdate())
