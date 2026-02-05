-- =============================================================================
-- 03_test_drop_and_verify.sql
-- Drops the sample TT tables (parm, site, ante, chan). The trigger copies
-- data to tsip_archive before each drop completes. Then we verify all
-- archive tables have the data.
-- =============================================================================

USE [YourDatabase];  -- Same database as 00, 01, 02
GO

PRINT 'Before drop: archive row counts';
SELECT 'ArchiveTT_PARM' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_PARM
UNION ALL
SELECT 'ArchiveTT_SITE', COUNT(*) FROM tsip_archive.ArchiveTT_SITE
UNION ALL
SELECT 'ArchiveTT_ANTE', COUNT(*) FROM tsip_archive.ArchiveTT_ANTE
UNION ALL
SELECT 'ArchiveTT_CHAN', COUNT(*) FROM tsip_archive.ArchiveTT_CHAN;
GO

PRINT 'Dropping dbo.tt_test_run01_parm ...';
DROP TABLE dbo.tt_test_run01_parm;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.tt_test_run01_site ...';
DROP TABLE dbo.tt_test_run01_site;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.tt_test_run01_ante ...';
DROP TABLE dbo.tt_test_run01_ante;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.tt_test_run01_chan ...';
DROP TABLE dbo.tt_test_run01_chan;
PRINT 'Dropped.';
GO

PRINT 'After drop: archive contents';
SELECT * FROM tsip_archive.ArchiveTT_PARM;
SELECT * FROM tsip_archive.ArchiveTT_SITE;
SELECT * FROM tsip_archive.ArchiveTT_ANTE;
SELECT * FROM tsip_archive.ArchiveTT_CHAN;
GO

PRINT 'After drop: archive row counts';
SELECT 'ArchiveTT_PARM' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_PARM
UNION ALL
SELECT 'ArchiveTT_SITE', COUNT(*) FROM tsip_archive.ArchiveTT_SITE
UNION ALL
SELECT 'ArchiveTT_ANTE', COUNT(*) FROM tsip_archive.ArchiveTT_ANTE
UNION ALL
SELECT 'ArchiveTT_CHAN', COUNT(*) FROM tsip_archive.ArchiveTT_CHAN;
GO

-- Verify all four tables are really gone
IF OBJECT_ID(N'dbo.tt_test_run01_parm', N'U') IS NULL
    PRINT 'OK: tt_test_run01_parm no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_site', N'U') IS NULL
    PRINT 'OK: tt_test_run01_site no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_ante', N'U') IS NULL
    PRINT 'OK: tt_test_run01_ante no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_chan', N'U') IS NULL
    PRINT 'OK: tt_test_run01_chan no longer exists.';
GO
