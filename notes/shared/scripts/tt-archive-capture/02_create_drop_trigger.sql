-- =============================================================================
-- 02_create_drop_trigger.sql
-- Creates a DATABASE-scoped DDL trigger that fires on DROP_TABLE. For tables
-- matching tt_%_parm, tt_%_site, tt_%_ante, or tt_%_chan (all non-temp TT
-- tables) it: (1) rolls back the drop, (2) copies data into tsip_archive
-- tables, (3) re-drops the table. Uses trigger_nestlevel() so the re-drop
-- does not loop. Run after 00 and 01.
--
-- ENHANCED: When TT_PARM is dropped, also captures FT (TS) and FE (ES) source
-- data at that moment, linked to the run via RunKey. This ensures source data
-- is captured at run completion, not when the PDF tables are deleted later.
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
        -- Archive the TT_PARM data
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_PARM (RunKey, proname, envname, runname, numcases, ArchivedAt)
            SELECT @RunKey, proname, envname, runname, numcases, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;

        -- =====================================================================
        -- ALSO CAPTURE FT/FE SOURCE DATA AT RUN COMPLETION
        -- Read proname (TS PDF) and envname (ES PDF) from the TT_PARM table,
        -- then archive corresponding FT_* and FE_* tables if they exist.
        -- =====================================================================
        DECLARE @proname CHAR(16);
        DECLARE @envname CHAR(16);
        
        -- FT table name variables (TS PDF source)
        DECLARE @FtTitlTable NVARCHAR(256);
        DECLARE @FtShrlTable NVARCHAR(256);
        DECLARE @FtSiteTable NVARCHAR(256);
        DECLARE @FtAnteTable NVARCHAR(256);
        DECLARE @FtChanTable NVARCHAR(256);
        DECLARE @FtChngCallTable NVARCHAR(256);
        
        -- FE table name variables (ES PDF source)
        DECLARE @FeTitlTable NVARCHAR(256);
        DECLARE @FeShrlTable NVARCHAR(256);
        DECLARE @FeSiteTable NVARCHAR(256);
        DECLARE @FeAzimTable NVARCHAR(256);
        DECLARE @FeAnteTable NVARCHAR(256);
        DECLARE @FeChanTable NVARCHAR(256);
        DECLARE @FeClocTable NVARCHAR(256);
        DECLARE @FeCcalTable NVARCHAR(256);

        -- Get proname and envname from the TT_PARM table
        SET @Sql = N'SELECT @p = proname, @e = envname FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, 
            N'@p CHAR(16) OUTPUT, @e CHAR(16) OUTPUT', 
            @p = @proname OUTPUT, 
            @e = @envname OUTPUT;

        -- Trim once, use everywhere
        SET @proname = RTRIM(@proname);
        SET @envname = RTRIM(@envname);

        -- Build FT table names from proname (TS PDF)
        -- Full set: TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
        IF @proname IS NOT NULL AND @proname <> ''
        BEGIN
            SET @FtTitlTable = QUOTENAME(@SchemaName) + N'.ft_' + @proname + N'_titl';
            SET @FtShrlTable = QUOTENAME(@SchemaName) + N'.ft_' + @proname + N'_shrl';
            SET @FtSiteTable = QUOTENAME(@SchemaName) + N'.ft_' + @proname + N'_site';
            SET @FtAnteTable = QUOTENAME(@SchemaName) + N'.ft_' + @proname + N'_ante';
            SET @FtChanTable = QUOTENAME(@SchemaName) + N'.ft_' + @proname + N'_chan';
            SET @FtChngCallTable = QUOTENAME(@SchemaName) + N'.ft_' + @proname + N'_chng_call';

            -- Archive FT_TITL if it exists
            IF OBJECT_ID(@FtTitlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_TITL 
                        (RunKey, PdfName, title, cdate, mdate, mtime, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, title, cdate, mdate, mtime, cmd, GETUTCDATE()
                    FROM ' + @FtTitlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_SHRL if it exists
            IF OBJECT_ID(@FtShrlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_SHRL 
                        (RunKey, PdfName, call1, call2, bndcde, shession, approval, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, call1, call2, bndcde, shession, approval, cmd, GETUTCDATE()
                    FROM ' + @FtShrlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_SITE if it exists
            IF OBJECT_ID(@FtSiteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_SITE 
                        (RunKey, PdfName, call1, call2, name1, name2, oper, oper2, latit, longit, grnd, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, call1, call2, name1, name2, oper, oper2, latit, longit, grnd, cmd, GETUTCDATE()
                    FROM ' + @FtSiteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_ANTE if it exists
            IF OBJECT_ID(@FtAnteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_ANTE 
                        (RunKey, PdfName, call1, call2, bndcde, anum, acode, aht, azmth, elvtn, gain, dist, offazm, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, call1, call2, bndcde, anum, acode, aht, azmth, elvtn, gain, dist, offazm, cmd, GETUTCDATE()
                    FROM ' + @FtAnteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_CHAN if it exists
            IF OBJECT_ID(@FtChanTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_CHAN 
                        (RunKey, PdfName, call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, pwrrx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, pwrrx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, GETUTCDATE()
                    FROM ' + @FtChanTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_CHNG_CALL if it exists
            IF OBJECT_ID(@FtChngCallTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_CHNG_CALL 
                        (RunKey, PdfName, oldcall1, oldcall2, newcall1, newcall2, chngdate, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, oldcall1, oldcall2, newcall1, newcall2, chngdate, cmd, GETUTCDATE()
                    FROM ' + @FtChngCallTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END
        END

        -- Build FE table names from envname (ES PDF)
        -- Full set: TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
        IF @envname IS NOT NULL AND @envname <> ''
        BEGIN
            SET @FeTitlTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_titl';
            SET @FeShrlTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_shrl';
            SET @FeSiteTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_site';
            SET @FeAzimTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_azim';
            SET @FeAnteTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_ante';
            SET @FeChanTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_chan';
            SET @FeClocTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_cloc';
            SET @FeCcalTable = QUOTENAME(@SchemaName) + N'.fe_' + @envname + N'_ccal';

            -- Archive FE_TITL if it exists
            IF OBJECT_ID(@FeTitlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_TITL 
                        (RunKey, PdfName, title, cdate, mdate, mtime, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, title, cdate, mdate, mtime, cmd, GETUTCDATE()
                    FROM ' + @FeTitlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_SHRL if it exists
            IF OBJECT_ID(@FeShrlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_SHRL 
                        (RunKey, PdfName, location, call1, shession, approval, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, location, call1, shession, approval, cmd, GETUTCDATE()
                    FROM ' + @FeShrlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_SITE if it exists
            IF OBJECT_ID(@FeSiteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_SITE 
                        (RunKey, PdfName, location, name, oper, latit, longit, grnd, rainzone, radiozone, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, location, name, oper, latit, longit, grnd, rainzone, radiozone, cmd, GETUTCDATE()
                    FROM ' + @FeSiteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_AZIM if it exists
            IF OBJECT_ID(@FeAzimTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_AZIM 
                        (RunKey, PdfName, location, az1, az2, el1, el2, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, location, az1, az2, el1, el2, cmd, GETUTCDATE()
                    FROM ' + @FeAzimTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_ANTE if it exists
            IF OBJECT_ID(@FeAnteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_ANTE 
                        (RunKey, PdfName, location, call1, band, acodetx, acoderx, aht, az, el, g_t, satname, satoper, satlongit, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, location, call1, band, acodetx, acoderx, aht, az, el, g_t, satname, satoper, satlongit, cmd, GETUTCDATE()
                    FROM ' + @FeAnteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_CHAN if it exists
            IF OBJECT_ID(@FeChanTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_CHAN 
                        (RunKey, PdfName, location, call1, band, chid, freqtx, freqrx, pwrtx, pwrrx, eirp, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, location, call1, band, chid, freqtx, freqrx, pwrtx, pwrrx, eirp, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, GETUTCDATE()
                    FROM ' + @FeChanTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_CLOC if it exists
            IF OBJECT_ID(@FeClocTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_CLOC 
                        (RunKey, PdfName, oldlocation, newlocation, chngdate, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, oldlocation, newlocation, chngdate, cmd, GETUTCDATE()
                    FROM ' + @FeClocTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_CCAL if it exists
            IF OBJECT_ID(@FeCcalTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_CCAL 
                        (RunKey, PdfName, location, oldcall1, newcall1, chngdate, cmd, ArchivedAt)
                    SELECT @RunKey, @PdfName, location, oldcall1, newcall1, chngdate, cmd, GETUTCDATE()
                    FROM ' + @FeCcalTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END
        END
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
PRINT '';
PRINT 'This trigger archives:';
PRINT '  - TT tables (tt_%_parm, tt_%_site, tt_%_ante, tt_%_chan)';
PRINT '  - FT source data when TT_PARM is dropped (6 tables: TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL)';
PRINT '  - FE source data when TT_PARM is dropped (8 tables: TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL)';
GO
