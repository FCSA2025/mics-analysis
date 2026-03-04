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

-- Required SET options for trigger compatibility across SQL Server instances
-- These settings are captured at trigger creation time
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

    -- Parse RunKey: e.g. tt_test_run01_parm -> test_run01 (strip tt_ prefix and _parm/_site/_ante/_chan suffix)
    -- SUBSTRING position 4 skips 3 chars ('tt_'), so subtract 3 for prefix, 5 for suffix
    DECLARE @RunKey NVARCHAR(128);
    IF @ObjectName LIKE 'tt_%_parm'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);  -- 3 = len('tt_'), 5 = len('_parm')
    ELSE IF @ObjectName LIKE 'tt_%_site'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);  -- 3 = len('tt_'), 5 = len('_site')
    ELSE IF @ObjectName LIKE 'tt_%_ante'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);  -- 3 = len('tt_'), 5 = len('_ante')
    ELSE IF @ObjectName LIKE 'tt_%_chan'
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3 - 5);  -- 3 = len('tt_'), 5 = len('_chan')
    ELSE
        SET @RunKey = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 3);

    SET @QualifiedName = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName);

    -- Copy data into archive based on table type
    IF @ObjectName LIKE '%_parm'
    BEGIN
        -- Archive the TT_PARM data (27 columns verified from micsprod)
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_PARM 
                (RunKey, protype, envtype, proname, envname, tsorbout, spherecalc, fsep, coordist,
                 analopt, margin, numchan, chancodes, tempant, tempctx, tempplan, tempequip,
                 country, selsites, numcodes, codes, runname, reports, numcases, numtecases,
                 parmparm, mdate, mtime, ArchivedAt)
            SELECT @RunKey, protype, envtype, proname, envname, tsorbout, spherecalc, fsep, coordist,
                   analopt, margin, numchan, chancodes, tempant, tempctx, tempplan, tempequip,
                   country, selsites, numcodes, codes, runname, reports, numcases, numtecases,
                   parmparm, mdate, mtime, GETUTCDATE()
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
            -- Actual columns: validated, namef, source, descr, mdate, mtime
            IF OBJECT_ID(@FtTitlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_TITL 
                        (RunKey, PdfName, validated, namef, source, descr, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, validated, namef, source, descr, mdate, mtime, GETUTCDATE()
                    FROM ' + @FtTitlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_SHRL if it exists
            -- Actual columns: userid, mdate, mtime
            IF OBJECT_ID(@FtShrlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_SHRL 
                        (RunKey, PdfName, userid, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, userid, mdate, mtime, GETUTCDATE()
                    FROM ' + @FtShrlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_SITE if it exists
            -- Actual columns (29): cmd, recstat, call1(PK), name, prov, oper, latit, longit, grnd,
            --                      stats, sdate, loc, icaccount, reg, spoint, nots, oprtyp, snumb,
            --                      notwr, bandwd1-8, mdate, mtime
            IF OBJECT_ID(@FtSiteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_SITE 
                        (RunKey, PdfName, cmd, recstat, call1, name, prov, oper, latit, longit, grnd,
                         stats, sdate, loc, icaccount, reg, spoint, nots, oprtyp, snumb, notwr,
                         bandwd1, bandwd2, bandwd3, bandwd4, bandwd5, bandwd6, bandwd7, bandwd8,
                         mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, call1, name, prov, oper, latit, longit, grnd,
                           stats, sdate, loc, icaccount, reg, spoint, nots, oprtyp, snumb, notwr,
                           bandwd1, bandwd2, bandwd3, bandwd4, bandwd5, bandwd6, bandwd7, bandwd8,
                           mdate, mtime, GETUTCDATE()
                    FROM ' + @FtSiteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_ANTE if it exists
            -- Verified from micsprod (37 columns)
            IF OBJECT_ID(@FtAnteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_ANTE 
                        (RunKey, PdfName, cmd, recstat, call1, call2, bndcde, anum, ause, acode,
                         aht, azmth, elvtn, dist, offazm, tazmth, telvtn, tgain,
                         txfdlnth, txfdlnlh, txfdlntv, txfdlnlv, rxfdlnth, rxfdlnlh, rxfdlntv, rxfdlnlv,
                         txpadpam, rxpadlna, txcompl, rxcompl, obsloss, kvalue, atwrno, nota, apoint,
                         sdate, mdate, mtime, licence, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, call1, call2, bndcde, anum, ause, acode,
                           aht, azmth, elvtn, dist, offazm, tazmth, telvtn, tgain,
                           txfdlnth, txfdlnlh, txfdlntv, txfdlnlv, rxfdlnth, rxfdlnlh, rxfdlntv, rxfdlnlv,
                           txpadpam, rxpadlna, txcompl, rxcompl, obsloss, kvalue, atwrno, nota, apoint,
                           sdate, mdate, mtime, licence, GETUTCDATE()
                    FROM ' + @FtAnteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_CHAN if it exists
            -- Verified from micsprod (52 columns)
            IF OBJECT_ID(@FtChanTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_CHAN 
                        (RunKey, PdfName, cmd, recstat, call1, call2, bndcde, splan, hl, vh, chid,
                         freqtx, poltx, antnumbtx1, antnumbtx2, eqpttx, eqptutx, pwrtx, atpccde,
                         afsltx1, afsltx2, traftx, srvctx, stattx,
                         freqrx, polrx, antnumbrx1, antnumbrx2, antnumbrx3, eqptrx, eqpturx,
                         afslrx1, afslrx2, afslrx3, pwrrx1, pwrrx2, pwrrx3, trafrx, esint, tsint,
                         srvcrx, statrx, routnumb, stnnumb, hopnumb, sdate,
                         notetx, noterx, notegnl, cpoint, feetx, feerx, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, call1, call2, bndcde, splan, hl, vh, chid,
                           freqtx, poltx, antnumbtx1, antnumbtx2, eqpttx, eqptutx, pwrtx, atpccde,
                           afsltx1, afsltx2, traftx, srvctx, stattx,
                           freqrx, polrx, antnumbrx1, antnumbrx2, antnumbrx3, eqptrx, eqpturx,
                           afslrx1, afslrx2, afslrx3, pwrrx1, pwrrx2, pwrrx3, trafrx, esint, tsint,
                           srvcrx, statrx, routnumb, stnnumb, hopnumb, sdate,
                           notetx, noterx, notegnl, cpoint, feetx, feerx, mdate, mtime, GETUTCDATE()
                    FROM ' + @FtChanTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @proname;
            END

            -- Archive FT_CHNG_CALL if it exists
            -- Actual columns (3): newcall1(PK), oldcall1(PK), name
            IF OBJECT_ID(@FtChngCallTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFT_CHNG_CALL 
                        (RunKey, PdfName, newcall1, oldcall1, name, ArchivedAt)
                    SELECT @RunKey, @PdfName, newcall1, oldcall1, name, GETUTCDATE()
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

            -- Archive FE_TITL if it exists (6 columns - same as FT_TITL)
            IF OBJECT_ID(@FeTitlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_TITL 
                        (RunKey, PdfName, validated, namef, source, descr, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, validated, namef, source, descr, mdate, mtime, GETUTCDATE()
                    FROM ' + @FeTitlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_SHRL if it exists (3 columns - same as FT_SHRL)
            IF OBJECT_ID(@FeShrlTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_SHRL 
                        (RunKey, PdfName, userid, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, userid, mdate, mtime, GETUTCDATE()
                    FROM ' + @FeShrlTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_SITE if it exists (18 columns)
            IF OBJECT_ID(@FeSiteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_SITE 
                        (RunKey, PdfName, cmd, recstat, location, name, prov, oper, latit, longit, grnd,
                         radio, rain, sdate, stats, nots, oprtyp, reg, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, location, name, prov, oper, latit, longit, grnd,
                           radio, rain, sdate, stats, nots, oprtyp, reg, mdate, mtime, GETUTCDATE()
                    FROM ' + @FeSiteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_AZIM if it exists (11 columns)
            IF OBJECT_ID(@FeAzimTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_AZIM 
                        (RunKey, PdfName, cmd, recstat, deleteall, location, call1, azim, elev, dist, loss, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, deleteall, location, call1, azim, elev, dist, loss, mdate, mtime, GETUTCDATE()
                    FROM ' + @FeAzimTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_ANTE if it exists (35 columns)
            IF OBJECT_ID(@FeAnteTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_ANTE 
                        (RunKey, PdfName, cmd, recstat, location, call1, txband, rxband, acodetx, acoderx,
                         g_t, lnat, aht, afslt, afslr, txhgmax, rxhgmax, satlongit, satlong, satlongs,
                         az, el, sarc1, sarc2, rxpre, txpre, rxtro, txtro, licence, satname,
                         stata, nota, op2, antref, orbit, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, location, call1, txband, rxband, acodetx, acoderx,
                           g_t, lnat, aht, afslt, afslr, txhgmax, rxhgmax, satlongit, satlong, satlongs,
                           az, el, sarc1, sarc2, rxpre, txpre, rxtro, txtro, licence, satname,
                           stata, nota, op2, antref, orbit, mdate, mtime, GETUTCDATE()
                    FROM ' + @FeAnteTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_CHAN if it exists (29 columns)
            IF OBJECT_ID(@FeChanTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_CHAN 
                        (RunKey, PdfName, cmd, recstat, location, call1, chid, freqtx, poltx, maxtxpower,
                         pwrtx, p4khz, eqpttx, traftx, stattx, feetx, freqrx, polrx, pwrrx, eqptrx,
                         trafrx, statrx, i20, it01, ip01, feerx, notc, srvctx, srvcrx, mdate, mtime, ArchivedAt)
                    SELECT @RunKey, @PdfName, cmd, recstat, location, call1, chid, freqtx, poltx, maxtxpower,
                           pwrtx, p4khz, eqpttx, traftx, stattx, feetx, freqrx, polrx, pwrrx, eqptrx,
                           trafrx, statrx, i20, it01, ip01, feerx, notc, srvctx, srvcrx, mdate, mtime, GETUTCDATE()
                    FROM ' + @FeChanTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_CLOC if it exists (3 columns)
            IF OBJECT_ID(@FeClocTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_CLOC 
                        (RunKey, PdfName, newlocation, oldlocation, name, ArchivedAt)
                    SELECT @RunKey, @PdfName, newlocation, oldlocation, name, GETUTCDATE()
                    FROM ' + @FeClocTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END

            -- Archive FE_CCAL if it exists (2 columns)
            IF OBJECT_ID(@FeCcalTable, N'U') IS NOT NULL
            BEGIN
                SET @Sql = N'
                    INSERT INTO tsip_archive.ArchiveFE_CCAL 
                        (RunKey, PdfName, newcallsign, oldcallsign, ArchivedAt)
                    SELECT @RunKey, @PdfName, newcallsign, oldcallsign, GETUTCDATE()
                    FROM ' + @FeCcalTable;
                EXEC sp_executesql @Sql, 
                    N'@RunKey NVARCHAR(128), @PdfName NVARCHAR(128)', 
                    @RunKey = @RunKey, @PdfName = @envname;
            END
        END
    END
    ELSE IF @ObjectName LIKE '%_site'
    BEGIN
        -- Archive TT_SITE (31 columns verified from micsprod)
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_SITE 
                (RunKey, interferer, intcall1, intcall2, viccall1, viccall2, caseno, subcases,
                 intname1, intname2, vicname1, vicname2, intoper, intoper2, vicoper, vicoper2,
                 intlatit, intlongit, intgrnd, viclatit, viclongit, vicgrnd, report,
                 int1int2dist, vic1vic2dist, int1vic1dist, distadv, intoffax, vicoffax,
                 intvicaz, vicintaz, processed, ArchivedAt)
            SELECT @RunKey, interferer, intcall1, intcall2, viccall1, viccall2, caseno, subcases,
                   intname1, intname2, vicname1, vicname2, intoper, intoper2, vicoper, vicoper2,
                   intlatit, intlongit, intgrnd, viclatit, viclongit, vicgrnd, report,
                   int1int2dist, vic1vic2dist, int1vic1dist, distadv, intoffax, vicoffax,
                   intvicaz, vicintaz, processed, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_ante'
    BEGIN
        -- Archive TT_ANTE (47 columns verified from micsprod)
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_ANTE 
                (RunKey, interferer, intcall1, intcall2, intbndcde, intanum, viccall1, viccall2,
                 vicbndcde, caseno, vicanum, intacode, vicacode, report, subcaseno,
                 adiscctxh, adiscctxv, adisccrxh, adisccrxv, adiscxtxh, adiscxtxv, adiscxrxh, adiscxrxv,
                 processed, intause, vicause, intoffaxa, vicoffaxa, intgain, vicgain,
                 intaxref, intamodel, vicaxref, vicamodel, intaoffax, inthopaz, intantaz, intoffantax,
                 vicaoffax, vichopaz, vicantaz, vicoffantax, intaht, vicaht, intvicel, vicintel,
                 intelev, vicelev, ArchivedAt)
            SELECT @RunKey, interferer, intcall1, intcall2, intbndcde, intanum, viccall1, viccall2,
                   vicbndcde, caseno, vicanum, intacode, vicacode, report, subcaseno,
                   adiscctxh, adiscctxv, adisccrxh, adisccrxv, adiscxtxh, adiscxtxv, adiscxrxh, adiscxrxv,
                   processed, intause, vicause, intoffaxa, vicoffaxa, intgain, vicgain,
                   intaxref, intamodel, vicaxref, vicamodel, intaoffax, inthopaz, intantaz, intoffantax,
                   vicaoffax, vichopaz, vicantaz, vicoffantax, intaht, vicaht, intvicel, vicintel,
                   intelev, vicelev, GETUTCDATE()
            FROM ' + @QualifiedName;
        EXEC sp_executesql @Sql, N'@RunKey NVARCHAR(128)', @RunKey = @RunKey;
    END
    ELSE IF @ObjectName LIKE '%_chan'
    BEGIN
        -- Archive TT_CHAN (60 columns verified from micsprod)
        SET @Sql = N'
            INSERT INTO tsip_archive.ArchiveTT_CHAN 
                (RunKey, interferer, intcall1, intcall2, intbndcde, intanum, intchid,
                 viccall1, viccall2, vicbndcde, vicanum, caseno, vicchid,
                 intpolar, vicpolar, intstattx, vicstatrx, inttraftx, victrafrx, inteqpttx, viceqptrx,
                 intfreqtx, vicfreqrx, vicpwrrx, intpwrtx, intafsltx, vicafslrx, rxant, txant,
                 ctxinttraftx, ctxvictrafrx, ctxeqpt, calctype, report, totantdisc, freqsep,
                 reqdcalc, patloss, calcico, calcixp, resti, eirpadv, tiltdisc,
                 pathloss80, calcico80, calcixp80, reqd80, resti80,
                 pathloss99, calcico99, calcixp99, reqd99, resti99,
                 ohresult, rqco, processed, ctxinteqpt, inteqtype, viceqtype, intbwchans, vicbwchans,
                 ArchivedAt)
            SELECT @RunKey, interferer, intcall1, intcall2, intbndcde, intanum, intchid,
                   viccall1, viccall2, vicbndcde, vicanum, caseno, vicchid,
                   intpolar, vicpolar, intstattx, vicstatrx, inttraftx, victrafrx, inteqpttx, viceqptrx,
                   intfreqtx, vicfreqrx, vicpwrrx, intpwrtx, intafsltx, vicafslrx, rxant, txant,
                   ctxinttraftx, ctxvictrafrx, ctxeqpt, calctype, report, totantdisc, freqsep,
                   reqdcalc, patloss, calcico, calcixp, resti, eirpadv, tiltdisc,
                   pathloss80, calcico80, calcixp80, reqd80, resti80,
                   pathloss99, calcico99, calcixp99, reqd99, resti99,
                   ohresult, rqco, processed, ctxinteqpt, inteqtype, viceqtype, intbwchans, vicbwchans,
                   GETUTCDATE()
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
