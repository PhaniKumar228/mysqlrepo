/*************************************************************************************************
** File: "20090217 - testing script.sql"
** Desc: This is a more generalized script to run performance testing on the sequence 
** comparison code. It can be modified to test any other spds. This script requires
** the existence of two tables, Seq1 and Seq2, which should have the following structure:
** 
** CREATE TABLE Seq1 (
**   CodeLineTxt varchar(max), /* stores the original line of code */
**   CodeLineNum int not null identity(1,1), /* stores the line number */
**   MatchLineNum int /* stores the matching line of code from spd #2 */
** )
** 
** Return values: report & results
** 
** Called by: 
** 
** Parameters:
** Input
** ----------
** none
**
** Output
** -----------
** none
**
** Date: 02/16/2008
*/

SET NOCOUNT ON

DECLARE @RunsPerInputSize int         ; SET @RunsPerInputSize = 1      /* #runs of @InputSize to execute */
DECLARE @InputSizeIncrement int       ; SET @InputSizeIncrement = 50   /* @InputSize to increment btwn outer runs */
DECLARE @TotalNumberIncrements int    ; SET @TotalNumberIncrements = 1 /* #increments to execute */

DECLARE @StartTime datetime           ; SET @StartTime = GETDATE()
DECLARE @StopTime datetime            ; SET @StopTime = GETDATE()
DECLARE @Seq1 varchar(max)            ; SET @Seq1 = 'Test Sequence "'
DECLARE @Seq2 varchar(max)            ; SET @Seq2 = 'Test Sequence "'
DECLARE @TestValue varchar(2)         ; SET @TestValue = ''             /* holder to load values into seq tables */
DECLARE @InputSize int                ; SET @InputSize = 0              /* input size for the current run */
DECLARE @InputValueIdx int            ; SET @InputValueIdx = 1          /* counter */
DECLARE @RunIdx int                   ; SET @RunIdx = 1                 /* counter */
DECLARE @IncrIdx int                  ; SET @IncrIdx = 1                /* counter */
DECLARE @Seq1Size int
DECLARE @Seq2Size int
DECLARE @Seq1Sizea int
DECLARE @Seq2Sizea int
DECLARE @PcntMatch decimal(9, 2)

CREATE TABLE #PerformanceResults (
  InputSize int,
  RunStart datetime,
  RunDone datetime,
  PcntMatch decimal(9, 2)
)

/* the straight-forward approach to testing would be to start at the smallest
input size, run through as many runs as we need for that, move on to the next
input size, test that, until we test the max input size. We don't do that here.
The problem with that approach is that if there's an external process running
during the testing of an input size, the results for that size might be false.
The approach here is to test the min size once, then the next largest size, 
until the max size is tested, then start all over and repeat until we've tested
each inputsize as many as "@RunsPerInputSize" times. */

SET @RunIdx = 1
/* outer loop to increment the number of runs per input size */
WHILE @RunIdx <= @RunsPerInputSize
BEGIN
  SET @IncrIdx = 1
  /* inner loop to increment each input size */
  WHILE @IncrIdx <= @TotalNumberIncrements
  BEGIN
    PRINT 'Testing size ' + LTRIM(STR(@IncrIdx)) + '/' + LTRIM(STR(@TotalNumberIncrements))
     + ', for run ' + LTRIM(STR(@RunIdx)) + '/' + LTRIM(STR(@RunsPerInputSize))
 
    SET @InputSize = @IncrIdx * @InputSizeIncrement
 
 
    /* insert rows into test table 1 */
    TRUNCATE TABLE Seq1
    SET @InputValueIdx = 1
    WHILE @InputValueIdx <= @InputSize
    BEGIN
      SET @TestValue = CHAR(FLOOR(RAND() * 10) + 65) + CHAR(FLOOR(RAND() * 10) + 65)
      INSERT INTO Seq1 (CodeLineTxt) VALUES (@TestValue)
      SET @Seq1 = @Seq1 + @TestValue
      SET @InputValueIdx = @InputValueIdx + 1
    END
    UPDATE Seq1 SET MatchLineNum = 0
    SET @Seq1 = @Seq1 + '"'


    /* insert rows into test table 2 */
    TRUNCATE TABLE Seq2
    SET @InputValueIdx = 1
    WHILE @InputValueIdx <= @InputSize
    BEGIN
      SET @TestValue = CHAR(FLOOR(RAND() * 10) + 65) + CHAR(FLOOR(RAND() * 10) + 65)
      INSERT INTO Seq2 (CodeLineTxt) VALUES (@TestValue)
      SET @Seq2 = @Seq2 + @TestValue
      SET @InputValueIdx = @InputValueIdx + 1
    END
    UPDATE Seq2 SET MatchLineNum = 0
    SET @Seq2 = @Seq2 + '"'


    /* wrap the executing code around timers to test */
    SET @StartTime = GETDATE()
  
    EXEC spd_SequenceCompare

    SET @StopTime = GETDATE()


    /* record results */
    SELECT @Seq1Size = COUNT(*) FROM Seq1
    SELECT @Seq2Size = COUNT(*) FROM Seq2
  
    SELECT @Seq1Sizea = COUNT(*) FROM Seq1 T1 WHERE MatchLineNum <> 0
    SELECT @Seq2Sizea = COUNT(*) FROM Seq2 T1 WHERE MatchLineNum <> 0
  
    SET @PcntMatch = 100.0 * (@Seq1Sizea / (1.0 * @Seq1Size) + @Seq2Sizea / (1.0 * @Seq2Size)) / 2

    INSERT INTO #PerformanceResults (InputSize, RunStart, RunDone, PcntMatch)
    VALUES (@InputSize, @StartTime, @StopTime, @PcntMatch)
 
    SET @IncrIdx = @IncrIdx + 1
  END

  SET @RunIdx = @RunIdx + 1
END

SELECT 
  InputSize, 
  NumberOfRuns = COUNT(*),
  AverageRunTime = AVG(CONVERT(decimal(9, 2), CONVERT(varchar(max), DATEDIFF(ss, RunStart, RunDone))
   + '.' + CONVERT(varchar(max), DATEDIFF(ms, RunStart, RunDone)))),
  AveragePercentMatch = AVG(PcntMatch)
FROM #PerformanceResults
GROUP BY InputSize


DROP TABLE #PerformanceResults

SET NOCOUNT OFF
