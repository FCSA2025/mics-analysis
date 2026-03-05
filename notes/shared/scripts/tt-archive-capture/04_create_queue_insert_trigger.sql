-- =============================================================================
-- 04_create_queue_insert_trigger.sql
-- Creates an INSERT trigger on web.tsip_queue that archives FT/FE source data
-- when a new TSIP job is queued.
--
-- Flow:
--   1. New row inserted into web.tsip_queue with TQ_ArgFile and TQ_MicsID
--   2. Trigger maps TQ_MicsID to database schema (e.g., 'rctl6' -> 'rctl')
--   3. Trigger queries <schema>.tp_<TQ_ArgFile>_parm for proname and envname
--   4. If proname exists, archives 6 FT tables (ft_<proname>_*)
--   5. If envname exists, archives 8 FE tables (fe_<envname>_*)
--
-- Requires: fn_GetSchemaFromMicsID function (03_create_schema_lookup_function.sql)
-- =============================================================================

USE [YourDatabase];  -- Change to your database
GO

-- Remove existing trigger if it exists
IF OBJECT_ID(N'web.trg_ArchiveFTFE_OnQueueInsert', N'TR') IS NOT NULL
    DROP TRIGGER web.trg_ArchiveFTFE_OnQueueInsert;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE TRIGGER web.trg_ArchiveFTFE_OnQueueInsert
ON web.tsip_queue
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TQ_Job       INT;
    DECLARE @TQ_ArgFile   VARCHAR(255);
    DECLARE @TQ_MicsID    CHAR(32);
    DECLARE @SchemaName   NVARCHAR(128);
    DECLARE @ParmTable    NVARCHAR(256);
    DECLARE @Proname      CHAR(16);
    DECLARE @Envname      CHAR(16);
    DECLARE @Sql          NVARCHAR(MAX);
    DECLARE @ArchivedAt   DATETIME2(0) = GETUTCDATE();

    -- Process each inserted row (typically just one)
    DECLARE queue_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TQ_Job, TQ_ArgFile, TQ_MicsID
        FROM INSERTED;

    OPEN queue_cursor;
    FETCH NEXT FROM queue_cursor INTO @TQ_Job, @TQ_ArgFile, @TQ_MicsID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Skip if no ArgFile
        IF @TQ_ArgFile IS NULL OR RTRIM(@TQ_ArgFile) = ''
        BEGIN
            FETCH NEXT FROM queue_cursor INTO @TQ_Job, @TQ_ArgFile, @TQ_MicsID;
            CONTINUE;
        END

        -- Map MicsID to schema using our helper function
        SET @SchemaName = tsip_archive.fn_GetSchemaFromMicsID(@TQ_MicsID);
        
        -- Skip if we couldn't determine the schema
        IF @SchemaName IS NULL
        BEGIN
            FETCH NEXT FROM queue_cursor INTO @TQ_Job, @TQ_ArgFile, @TQ_MicsID;
            CONTINUE;
        END

        -- Build the parameter table name: <schema>.tp_<argfile>_parm
        SET @ParmTable = QUOTENAME(@SchemaName) + N'.tp_' + RTRIM(@TQ_ArgFile) + N'_parm';

        -- Check if the tp_parm table exists and get proname/envname
        SET @Sql = N'
            IF OBJECT_ID(@ParmTable, N''U'') IS NOT NULL
            BEGIN
                SELECT TOP 1 @PronameOut = proname, @EnvnameOut = envname
                FROM ' + @ParmTable + N';
            END';

        BEGIN TRY
            EXEC sp_executesql @Sql, 
                N'@ParmTable NVARCHAR(256), @PronameOut CHAR(16) OUTPUT, @EnvnameOut CHAR(16) OUTPUT',
                @ParmTable = @ParmTable, @PronameOut = @Proname OUTPUT, @EnvnameOut = @Envname OUTPUT;
        END TRY
        BEGIN CATCH
            -- tp_parm table doesn't exist or error reading - skip to next
            SET @Proname = NULL;
            SET @Envname = NULL;
        END CATCH

        -- Archive FT tables if proname is populated
        IF @Proname IS NOT NULL AND RTRIM(@Proname) <> ''
        BEGIN
            DECLARE @FT_TITL NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.ft_' + RTRIM(@Proname) + N'_titl';
            DECLARE @FT_SHRL NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.ft_' + RTRIM(@Proname) + N'_shrl';
            DECLARE @FT_SITE NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.ft_' + RTRIM(@Proname) + N'_site';
            DECLARE @FT_ANTE NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.ft_' + RTRIM(@Proname) + N'_ante';
            DECLARE @FT_CHAN NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.ft_' + RTRIM(@Proname) + N'_chan';
            DECLARE @FT_CHNG NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.ft_' + RTRIM(@Proname) + N'_chng_call';

            -- Archive FT_TITL (6 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FT_TITL + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFT_TITL (TQ_Job, PdfName, validated, namef, source, descr, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Proname, validated, namef, source, descr, mdate, mtime, @ArchivedAt FROM ' + @FT_TITL;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Proname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Proname = @Proname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FT_SHRL (3 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FT_SHRL + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFT_SHRL (TQ_Job, PdfName, userid, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Proname, userid, mdate, mtime, @ArchivedAt FROM ' + @FT_SHRL;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Proname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Proname = @Proname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FT_SITE (29 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FT_SITE + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFT_SITE (TQ_Job, PdfName, cmd, recstat, call1, name, prov, oper, latit, longit, grnd, stats, sdate, loc, icaccount, reg, spoint, nots, oprtyp, snumb, notwr, bandwd1, bandwd2, bandwd3, bandwd4, bandwd5, bandwd6, bandwd7, bandwd8, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Proname, cmd, recstat, call1, name, prov, oper, latit, longit, grnd, stats, sdate, loc, icaccount, reg, spoint, nots, oprtyp, snumb, notwr, bandwd1, bandwd2, bandwd3, bandwd4, bandwd5, bandwd6, bandwd7, bandwd8, mdate, mtime, @ArchivedAt FROM ' + @FT_SITE;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Proname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Proname = @Proname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FT_ANTE (37 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FT_ANTE + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFT_ANTE (TQ_Job, PdfName, cmd, recstat, call1, call2, bndcde, anum, ause, acode, aht, azmth, elvtn, dist, offazm, tazmth, telvtn, tgain, txfdlnth, txfdlnlh, txfdlntv, txfdlnlv, rxfdlnth, rxfdlnlh, rxfdlntv, rxfdlnlv, txpadpam, rxpadlna, txcompl, rxcompl, obsloss, kvalue, atwrno, nota, apoint, sdate, mdate, mtime, licence, ArchivedAt) SELECT @TQ_Job, @Proname, cmd, recstat, call1, call2, bndcde, anum, ause, acode, aht, azmth, elvtn, dist, offazm, tazmth, telvtn, tgain, txfdlnth, txfdlnlh, txfdlntv, txfdlnlv, rxfdlnth, rxfdlnlh, rxfdlntv, rxfdlnlv, txpadpam, rxpadlna, txcompl, rxcompl, obsloss, kvalue, atwrno, nota, apoint, sdate, mdate, mtime, licence, @ArchivedAt FROM ' + @FT_ANTE;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Proname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Proname = @Proname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FT_CHAN (52 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FT_CHAN + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFT_CHAN (TQ_Job, PdfName, cmd, recstat, call1, call2, bndcde, splan, hl, vh, chid, freqtx, poltx, antnumbtx1, antnumbtx2, eqpttx, eqptutx, pwrtx, atpccde, afsltx1, afsltx2, traftx, srvctx, stattx, freqrx, polrx, antnumbrx1, antnumbrx2, antnumbrx3, eqptrx, eqpturx, afslrx1, afslrx2, afslrx3, pwrrx1, pwrrx2, pwrrx3, trafrx, esint, tsint, srvcrx, statrx, routnumb, stnnumb, hopnumb, sdate, notetx, noterx, notegnl, cpoint, feetx, feerx, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Proname, cmd, recstat, call1, call2, bndcde, splan, hl, vh, chid, freqtx, poltx, antnumbtx1, antnumbtx2, eqpttx, eqptutx, pwrtx, atpccde, afsltx1, afsltx2, traftx, srvctx, stattx, freqrx, polrx, antnumbrx1, antnumbrx2, antnumbrx3, eqptrx, eqpturx, afslrx1, afslrx2, afslrx3, pwrrx1, pwrrx2, pwrrx3, trafrx, esint, tsint, srvcrx, statrx, routnumb, stnnumb, hopnumb, sdate, notetx, noterx, notegnl, cpoint, feetx, feerx, mdate, mtime, @ArchivedAt FROM ' + @FT_CHAN;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Proname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Proname = @Proname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FT_CHNG_CALL (3 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FT_CHNG + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFT_CHNG_CALL (TQ_Job, PdfName, newcall1, oldcall1, name, ArchivedAt) SELECT @TQ_Job, @Proname, newcall1, oldcall1, name, @ArchivedAt FROM ' + @FT_CHNG;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Proname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Proname = @Proname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH
        END

        -- Archive FE tables if envname is populated
        IF @Envname IS NOT NULL AND RTRIM(@Envname) <> ''
        BEGIN
            DECLARE @FE_TITL NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_titl';
            DECLARE @FE_SHRL NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_shrl';
            DECLARE @FE_SITE NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_site';
            DECLARE @FE_AZIM NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_azim';
            DECLARE @FE_ANTE NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_ante';
            DECLARE @FE_CHAN NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_chan';
            DECLARE @FE_CLOC NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_cloc';
            DECLARE @FE_CCAL NVARCHAR(256) = QUOTENAME(@SchemaName) + N'.fe_' + RTRIM(@Envname) + N'_ccal';

            -- Archive FE_TITL (6 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_TITL + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_TITL (TQ_Job, PdfName, validated, namef, source, descr, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Envname, validated, namef, source, descr, mdate, mtime, @ArchivedAt FROM ' + @FE_TITL;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_SHRL (3 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_SHRL + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_SHRL (TQ_Job, PdfName, userid, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Envname, userid, mdate, mtime, @ArchivedAt FROM ' + @FE_SHRL;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_SITE (18 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_SITE + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_SITE (TQ_Job, PdfName, cmd, recstat, location, name, prov, oper, latit, longit, grnd, radio, rain, sdate, stats, nots, oprtyp, reg, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Envname, cmd, recstat, location, name, prov, oper, latit, longit, grnd, radio, rain, sdate, stats, nots, oprtyp, reg, mdate, mtime, @ArchivedAt FROM ' + @FE_SITE;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_AZIM (11 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_AZIM + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_AZIM (TQ_Job, PdfName, cmd, recstat, deleteall, location, call1, azim, elev, dist, loss, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Envname, cmd, recstat, deleteall, location, call1, azim, elev, dist, loss, mdate, mtime, @ArchivedAt FROM ' + @FE_AZIM;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_ANTE (35 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_ANTE + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_ANTE (TQ_Job, PdfName, cmd, recstat, location, call1, txband, rxband, acodetx, acoderx, g_t, lnat, aht, afslt, afslr, txhgmax, rxhgmax, satlongit, satlong, satlongs, az, el, sarc1, sarc2, rxpre, txpre, rxtro, txtro, licence, satname, stata, nota, op2, antref, orbit, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Envname, cmd, recstat, location, call1, txband, rxband, acodetx, acoderx, g_t, lnat, aht, afslt, afslr, txhgmax, rxhgmax, satlongit, satlong, satlongs, az, el, sarc1, sarc2, rxpre, txpre, rxtro, txtro, licence, satname, stata, nota, op2, antref, orbit, mdate, mtime, @ArchivedAt FROM ' + @FE_ANTE;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_CHAN (29 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_CHAN + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_CHAN (TQ_Job, PdfName, cmd, recstat, location, call1, chid, freqtx, poltx, maxtxpower, pwrtx, p4khz, eqpttx, traftx, stattx, feetx, freqrx, polrx, pwrrx, eqptrx, trafrx, statrx, i20, it01, ip01, feerx, notc, srvctx, srvcrx, mdate, mtime, ArchivedAt) SELECT @TQ_Job, @Envname, cmd, recstat, location, call1, chid, freqtx, poltx, maxtxpower, pwrtx, p4khz, eqpttx, traftx, stattx, feetx, freqrx, polrx, pwrrx, eqptrx, trafrx, statrx, i20, it01, ip01, feerx, notc, srvctx, srvcrx, mdate, mtime, @ArchivedAt FROM ' + @FE_CHAN;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_CLOC (3 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_CLOC + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_CLOC (TQ_Job, PdfName, newlocation, oldlocation, name, ArchivedAt) SELECT @TQ_Job, @Envname, newlocation, oldlocation, name, @ArchivedAt FROM ' + @FE_CLOC;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH

            -- Archive FE_CCAL (2 columns)
            BEGIN TRY
                SET @Sql = N'IF OBJECT_ID(''' + @FE_CCAL + N''', N''U'') IS NOT NULL INSERT INTO tsip_archive.ArchiveFE_CCAL (TQ_Job, PdfName, newcallsign, oldcallsign, ArchivedAt) SELECT @TQ_Job, @Envname, newcallsign, oldcallsign, @ArchivedAt FROM ' + @FE_CCAL;
                EXEC sp_executesql @Sql, N'@TQ_Job INT, @Envname CHAR(16), @ArchivedAt DATETIME2(0)', @TQ_Job = @TQ_Job, @Envname = @Envname, @ArchivedAt = @ArchivedAt;
            END TRY BEGIN CATCH END CATCH
        END

        FETCH NEXT FROM queue_cursor INTO @TQ_Job, @TQ_ArgFile, @TQ_MicsID;
    END

    CLOSE queue_cursor;
    DEALLOCATE queue_cursor;
END;
GO

PRINT 'INSERT trigger trg_ArchiveFTFE_OnQueueInsert created on web.tsip_queue.';
PRINT '';
PRINT 'This trigger archives FT/FE source data when a TSIP job is queued:';
PRINT '';
PRINT 'FT Tables (6) - archived if proname is populated in tp_*_parm:';
PRINT '  ft_<proname>_titl, ft_<proname>_shrl, ft_<proname>_site,';
PRINT '  ft_<proname>_ante, ft_<proname>_chan, ft_<proname>_chng_call';
PRINT '';
PRINT 'FE Tables (8) - archived if envname is populated in tp_*_parm:';
PRINT '  fe_<envname>_titl, fe_<envname>_shrl, fe_<envname>_site, fe_<envname>_azim,';
PRINT '  fe_<envname>_ante, fe_<envname>_chan, fe_<envname>_cloc, fe_<envname>_ccal';
GO
