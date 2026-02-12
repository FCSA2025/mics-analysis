-- =============================================================================
-- 03_test_drop_and_verify.sql
-- Drops the sample FT and FE tables. The trigger copies data to tsip_archive
-- before each drop completes. Then we verify all archive tables have the data.
-- =============================================================================

USE [YourDatabase];  -- Same database as 00, 01, 02
GO

PRINT '=== Before drop: archive row counts ===';
SELECT 'ArchiveFT_SITE' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveFT_SITE
UNION ALL
SELECT 'ArchiveFT_ANTE', COUNT(*) FROM tsip_archive.ArchiveFT_ANTE
UNION ALL
SELECT 'ArchiveFT_CHAN', COUNT(*) FROM tsip_archive.ArchiveFT_CHAN
UNION ALL
SELECT 'ArchiveFE_SITE', COUNT(*) FROM tsip_archive.ArchiveFE_SITE
UNION ALL
SELECT 'ArchiveFE_ANTE', COUNT(*) FROM tsip_archive.ArchiveFE_ANTE
UNION ALL
SELECT 'ArchiveFE_CHAN', COUNT(*) FROM tsip_archive.ArchiveFE_CHAN;
GO

-- =============================================================================
-- Drop FT (Terrestrial Station) tables
-- =============================================================================

PRINT '';
PRINT '=== Dropping FT tables ===';
PRINT 'Dropping dbo.ft_test_ts_pdf_site ...';
DROP TABLE dbo.ft_test_ts_pdf_site;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.ft_test_ts_pdf_ante ...';
DROP TABLE dbo.ft_test_ts_pdf_ante;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.ft_test_ts_pdf_chan ...';
DROP TABLE dbo.ft_test_ts_pdf_chan;
PRINT 'Dropped.';
GO

-- =============================================================================
-- Drop FE (Earth Station) tables
-- =============================================================================

PRINT '';
PRINT '=== Dropping FE tables ===';
PRINT 'Dropping dbo.fe_test_es_pdf_site ...';
DROP TABLE dbo.fe_test_es_pdf_site;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.fe_test_es_pdf_ante ...';
DROP TABLE dbo.fe_test_es_pdf_ante;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.fe_test_es_pdf_chan ...';
DROP TABLE dbo.fe_test_es_pdf_chan;
PRINT 'Dropped.';
GO

-- =============================================================================
-- Verify archive contents
-- =============================================================================

PRINT '';
PRINT '=== After drop: FT archive contents ===';
SELECT * FROM tsip_archive.ArchiveFT_SITE WHERE PdfName = 'test_ts_pdf';
SELECT * FROM tsip_archive.ArchiveFT_ANTE WHERE PdfName = 'test_ts_pdf';
SELECT * FROM tsip_archive.ArchiveFT_CHAN WHERE PdfName = 'test_ts_pdf';
GO

PRINT '';
PRINT '=== After drop: FE archive contents ===';
SELECT * FROM tsip_archive.ArchiveFE_SITE WHERE PdfName = 'test_es_pdf';
SELECT * FROM tsip_archive.ArchiveFE_ANTE WHERE PdfName = 'test_es_pdf';
SELECT * FROM tsip_archive.ArchiveFE_CHAN WHERE PdfName = 'test_es_pdf';
GO

PRINT '';
PRINT '=== After drop: archive row counts ===';
SELECT 'ArchiveFT_SITE' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveFT_SITE
UNION ALL
SELECT 'ArchiveFT_ANTE', COUNT(*) FROM tsip_archive.ArchiveFT_ANTE
UNION ALL
SELECT 'ArchiveFT_CHAN', COUNT(*) FROM tsip_archive.ArchiveFT_CHAN
UNION ALL
SELECT 'ArchiveFE_SITE', COUNT(*) FROM tsip_archive.ArchiveFE_SITE
UNION ALL
SELECT 'ArchiveFE_ANTE', COUNT(*) FROM tsip_archive.ArchiveFE_ANTE
UNION ALL
SELECT 'ArchiveFE_CHAN', COUNT(*) FROM tsip_archive.ArchiveFE_CHAN;
GO

-- Verify all tables are really gone
PRINT '';
PRINT '=== Verify tables are dropped ===';
IF OBJECT_ID(N'dbo.ft_test_ts_pdf_site', N'U') IS NULL
    PRINT 'OK: ft_test_ts_pdf_site no longer exists.';
IF OBJECT_ID(N'dbo.ft_test_ts_pdf_ante', N'U') IS NULL
    PRINT 'OK: ft_test_ts_pdf_ante no longer exists.';
IF OBJECT_ID(N'dbo.ft_test_ts_pdf_chan', N'U') IS NULL
    PRINT 'OK: ft_test_ts_pdf_chan no longer exists.';
IF OBJECT_ID(N'dbo.fe_test_es_pdf_site', N'U') IS NULL
    PRINT 'OK: fe_test_es_pdf_site no longer exists.';
IF OBJECT_ID(N'dbo.fe_test_es_pdf_ante', N'U') IS NULL
    PRINT 'OK: fe_test_es_pdf_ante no longer exists.';
IF OBJECT_ID(N'dbo.fe_test_es_pdf_chan', N'U') IS NULL
    PRINT 'OK: fe_test_es_pdf_chan no longer exists.';
GO
