-- ---------------------------------------------------------------------------
--  Purpose: To report information about an instance's start time and uptime.
-- ---------------------------------------------------------------------------

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET QUOTED_IDENTIFIER ON;
GO

CREATE VIEW dbo.ServerStartInfo
AS
    WITH ServerUpTimeInfo AS (
            SELECT  (dm_io_virtual_file_stats.sample_ms / 1000.00 ) / 60.00
                        AS server_up_time_min,
                    ((dm_io_virtual_file_stats.sample_ms / 1000.00 ) / 60.00) / 60.00
                        AS server_up_time_hr,
                    (((dm_io_virtual_file_stats.sample_ms / 1000.00 ) / 60.00) / 60.00) / 24.00
                        AS server_up_time_day
            FROM    sys.dm_io_virtual_file_stats(1,1) AS dm_io_virtual_file_stats )
    SELECT  CAST(server_up_time_min AS decimal(12,2)) AS server_up_time_min,
            CAST(server_up_time_hr AS decimal(12,2)) AS server_up_time_hr,
            CAST(server_up_time_day AS decimal(12,2)) AS server_up_time_day,
            CAST(DATEADD(n,
                  -ROUND(server_up_time_min, -1),
                    DATEADD(hh, -ROUND(server_up_time_hr, -1), DATEADD(d, -ROUND(server_up_time_day, -1), GETUTCDATE()))
                 ) AS smalldatetime)
                        AS approx_server_start_utc_datetime
    FROM    ServerUpTimeInfo;
GO

select * From dbo.ServerStartInfo