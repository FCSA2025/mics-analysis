-- =============================================================================
-- 02_create_drop_trigger.sql
-- Creates a DATABASE-scoped DDL trigger that fires on DROP_TABLE. For tables
-- matching tt_%_parm, tt_%_site, tt_%_ante, or tt_%_chan (all non-temp TT
-- tables) it: (1) rolls back the drop, (2) copies data into tsip_archive
-- tables, (3) re-drops the table. Uses trigger_nestlevel() so the re-drop
-- does not loop.
--
-- NOTE: This trigger ONLY handles TT (TSIP result) tables.
-- FT/FE source data is archived separately via INSERT trigger on tsip_queue.
-- =============================================================================

USE [YourDatabase];  -- Change to your database
GO

-- Remove existing trigger if re-running (database-level trigger)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveTT_OnDropTable' AND parent_id = 0)
    DROP TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
GO

-- Required SET options for trigger compatibility across SQL Server instances
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
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

    DECLARE @EventData     XML = EVENTDATA();
    DECLARE @SchemaName    sysname = @EventData.value('(/EVENT_INSTANCE/SchemaName)[1]', 'sysname');
    DECLARE @ObjectName    sysname = @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'sysname');
    DECLARE @Sql           NVARCHAR(MAX);
    DECLARE @SqlDrop       NVARCHAR(256);
    DECLARE @QualifiedName NVARCHAR(256);
    DECLARE @RunKey        NVARCHAR(128);

    -- Only handle non-temp TT tables (parm, site, ante, chan)
    IF @ObjectName NOT LIKE 'tt_%_parm' AND @ObjectName NOT LIKE 'tt_%_site'
       AND @ObjectName NOT LIKE 'tt_%_ante' AND @ObjectName NOT LIKE 'tt_%_chan'
        RETURN;

    -- Rollback the drop so the table and data exist again
    ROLLBACK;

    -- Parse RunKey: e.g. tt_test_run01_parm -> test_run01
    IF @ObjectName LIKE 'tt_%_parm'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);
    ELSE IF @ObjectName LIKE 'tt_%_site'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);
    ELSE IF @ObjectName LIKE 'tt_%_ante'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);
    ELSE IF @ObjectName LIKE 'tt_%_chan'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);
    ELSE
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3);

    SET @QualifiedName = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName);

    -- Archive based on table type
    IF @ObjectName LIKE '%_parm'
    BEGIN
        -- Archive TT_PARM (27 columns)
        SET @Sql = N'INSERT INTO tsip_archive.ArchiveTT_PARM (RunKey, protype, envtype, proname, envname, tsorbout, spherecalc, fsep, coordist, analopt, margin, numchan, chancodes, tempant, tempctx, tempplan, tempequip, country, selsites, numcodes, codes, runname, reports, numcases, numtecases, parmparm, mdate, mtime, ArchivedAt) SELECT @RunKey, protype, envtype, proname, envname, tsorbout, spherecalc, fsep, coordist, analopt, margin, numchan, chancodes, tempant, tempctx, tempplan, tempequip, country, selsites, numcodes, codes, runname, reports, numcases, numtecases, parmparm, mdate, mtime, GETUTCDATE() FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_site'
    BEGIN
        -- Archive TT_SITE (31 columns)
        SET @Sql = N'INSERT INTO tsip_archive.ArchiveTT_SITE (RunKey, interferer, intcall1, intcall2, viccall1, viccall2, caseno, subcases, intname1, intname2, vicname1, vicname2, intoper, intoper2, vicoper, vicoper2, intlatit, intlongit, intgrnd, viclatit, viclongit, vicgrnd, report, int1int2dist, vic1vic2dist, int1vic1dist, distadv, intoffax, vicoffax, intvicaz, vicintaz, processed, ArchivedAt) SELECT @RunKey, interferer, intcall1, intcall2, viccall1, viccall2, caseno, subcases, intname1, intname2, vicname1, vicname2, intoper, intoper2, vicoper, vicoper2, intlatit, intlongit, intgrnd, viclatit, viclongit, vicgrnd, report, int1int2dist, vic1vic2dist, int1vic1dist, distadv, intoffax, vicoffax, intvicaz, vicintaz, processed, GETUTCDATE() FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_ante'
    BEGIN
        -- Archive TT_ANTE (47 columns)
        SET @Sql = N'INSERT INTO tsip_archive.ArchiveTT_ANTE (RunKey, interferer, intcall1, intcall2, intbndcde, intanum, viccall1, viccall2, vicbndcde, caseno, vicanum, intacode, vicacode, report, subcaseno, adiscctxh, adiscctxv, adisccrxh, adisccrxv, adiscxtxh, adiscxtxv, adiscxrxh, adiscxrxv, processed, intause, vicause, intoffaxa, vicoffaxa, intgain, vicgain, intaxref, intamodel, vicaxref, vicamodel, intaoffax, inthopaz, intantaz, intoffantax, vicaoffax, vichopaz, vicantaz, vicoffantax, intaht, vicaht, intvicel, vicintel, intelev, vicelev, ArchivedAt) SELECT @RunKey, interferer, intcall1, intcall2, intbndcde, intanum, viccall1, viccall2, vicbndcde, caseno, vicanum, intacode, vicacode, report, subcaseno, adiscctxh, adiscctxv, adisccrxh, adisccrxv, adiscxtxh, adiscxtxv, adiscxrxh, adiscxrxv, processed, intause, vicause, intoffaxa, vicoffaxa, intgain, vicgain, intaxref, intamodel, vicaxref, vicamodel, intaoffax, inthopaz, intantaz, intoffantax, vicaoffax, vichopaz, vicantaz, vicoffantax, intaht, vicaht, intvicel, vicintel, intelev, vicelev, GETUTCDATE() FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_chan'
    BEGIN
        -- Archive TT_CHAN (60 columns)
        SET @Sql = N'INSERT INTO tsip_archive.ArchiveTT_CHAN (RunKey, interferer, intcall1, intcall2, intbndcde, intanum, intchid, viccall1, viccall2, vicbndcde, vicanum, caseno, vicchid, intpolar, vicpolar, intstattx, vicstatrx, inttraftx, victrafrx, inteqpttx, viceqptrx, intfreqtx, vicfreqrx, vicpwrrx, intpwrtx, intafsltx, vicafslrx, rxant, txant, ctxinttraftx, ctxvictrafrx, ctxeqpt, calctype, report, totantdisc, freqsep, reqdcalc, patloss, calcico, calcixp, resti, eirpadv, tiltdisc, pathloss80, calcico80, calcixp80, reqd80, resti80, pathloss99, calcico99, calcixp99, reqd99, resti99, ohresult, rqco, processed, ctxinteqpt, inteqtype, viceqtype, intbwchans, vicbwchans, ArchivedAt) SELECT @RunKey, interferer, intcall1, intcall2, intbndcde, intanum, intchid, viccall1, viccall2, vicbndcde, vicanum, caseno, vicchid, intpolar, vicpolar, intstattx, vicstatrx, inttraftx, victrafrx, inteqpttx, viceqptrx, intfreqtx, vicfreqrx, vicpwrrx, intpwrtx, intafsltx, vicafslrx, rxant, txant, ctxinttraftx, ctxvictrafrx, ctxeqpt, calctype, report, totantdisc, freqsep, reqdcalc, patloss, calcico, calcixp, resti, eirpadv, tiltdisc, pathloss80, calcico80, calcixp80, reqd80, resti80, pathloss99, calcico99, calcixp99, reqd99, resti99, ohresult, rqco, processed, ctxinteqpt, inteqtype, viceqtype, intbwchans, vicbwchans, GETUTCDATE() FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END

    -- Re-drop the table (trigger will fire again with nestlevel=2 and exit)
    SET @SqlDrop = N'DROP TABLE ' + @QualifiedName;
    EXEC sp_executesql @SqlDrop;
END;
GO

PRINT 'DDL trigger trg_ArchiveTT_OnDropTable created on DATABASE.';
PRINT '';
PRINT 'This trigger archives TT tables only:';
PRINT '  - tt_%_parm -> tsip_archive.ArchiveTT_PARM';
PRINT '  - tt_%_site -> tsip_archive.ArchiveTT_SITE';
PRINT '  - tt_%_ante -> tsip_archive.ArchiveTT_ANTE';
PRINT '  - tt_%_chan -> tsip_archive.ArchiveTT_CHAN';
PRINT '';
PRINT 'FT/FE source data is archived separately via INSERT trigger on web.tsip_queue.';
GO
