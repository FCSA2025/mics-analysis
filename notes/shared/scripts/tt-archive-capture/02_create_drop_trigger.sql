-- =============================================================================
-- 02_create_drop_trigger.sql
-- Creates a DATABASE-scoped DDL trigger that fires on DROP_TABLE. For tables
-- matching tt_%_parm, tt_%_site, tt_%_ante, or tt_%_chan (all non-temp TT
-- tables) it: (1) rolls back the drop, (2) copies data into tsip_archive
-- tables, (3) re-drops the table. Uses trigger_nestlevel() so the re-drop
-- does not loop. Run after 00 and 01.
-- =============================================================================

USE [YourDatabase];  -- Change to your dev database
GO

-- Remove existing trigger if re-running (database-level trigger)
-- This version runs in the current database (ON DATABASE)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveTT_OnDropTable' AND parent_id = 0)
    DROP TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
GO

CREATE TRIGGER trg_ArchiveTT_OnDropTable
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only run for the top-level DROP (avoid recursion when we re-drop)
    IF trigger_nestlevel() > 1
        RETURN;

    DECLARE @EventData    XML = EVENTDATA();
    DECLARE @SchemaName   sysname = @EventData.value('(/EVENT_INSTANCE/SchemaName)[1]', 'sysname');
    DECLARE @ObjectName   sysname = @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'sysname');
    DECLARE @Sql          NVARCHAR(MAX);
    DECLARE @SqlDrop      NVARCHAR(256);
    DECLARE @QualifiedName NVARCHAR(256);

    -- Only handle non-temp TT tables (parm, site, ante, chan; exclude _tmp1/_tmp2)
    IF @ObjectName NOT LIKE 'tt_%_parm' AND @ObjectName NOT LIKE 'tt_%_site'
       AND @ObjectName NOT LIKE 'tt_%_ante' AND @ObjectName NOT LIKE 'tt_%_chan'
        RETURN;

    -- Rollback the drop so the table and data exist again
    ROLLBACK;

    -- Parse RunKey: e.g. tt_test_run01_parm -> test_run01 (strip tt_ and suffix _parm/_site/_ante/_chan)
    DECLARE @RunKey NVARCHAR(128);
    IF @ObjectName LIKE 'tt_%_parm'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- 5 = len('_parm')
    ELSE IF @ObjectName LIKE 'tt_%_site'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);   -- 5 = len('_site')
    ELSE IF @ObjectName LIKE 'tt_%_ante'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);   -- 5 = len('_ante')
    ELSE IF @ObjectName LIKE 'tt_%_chan'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);   -- 5 = len('_chan')
    ELSE
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4);

    SET @QualifiedName = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName);

    -- Copy data into archive based on table type
    IF @ObjectName LIKE '%_parm'
    BEGIN
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_PARM (RunKey, proname, envname, runname, numcases, ArchivedAt)
            SELECT @RunKey, proname, envname, runname, numcases, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_site'
    BEGIN
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_SITE (RunKey, intcall1, viccall1, caseno, ArchivedAt)
            SELECT @RunKey, intcall1, viccall1, caseno, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_ante'
    BEGIN
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_ANTE (RunKey, intcall1, viccall1, caseno, intacode, vicacode, ArchivedAt)
            SELECT @RunKey, intcall1, viccall1, caseno, intacode, vicacode, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_chan'
    BEGIN
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_CHAN (RunKey, intcall1, viccall1, caseno, resti, freqsep, ArchivedAt)
            SELECT @RunKey, intcall1, viccall1, caseno, resti, freqsep, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END

    -- Re-drop the table (trigger will fire again with nestlevel=2 and exit)
    SET @SqlDrop = N'DROP TABLE ' + @QualifiedName;
    EXEC sp_executesql @SqlDrop;
END;
GO

PRINT 'DDL trigger trg_ArchiveTT_OnDropTable created on DATABASE.';
GO
