-- =============================================================================
-- 03_test_drop_and_verify.sql
-- Drops the sample TT tables (parm, site, ante, chan). The trigger copies
-- data to tsip_archive before each drop completes.
--
-- ENHANCED: When TT_PARM is dropped, the trigger also captures all FT and FE
-- source data (at run completion time). The FT/FE tables are NOT dropped -
-- they're just snapshotted into the archive linked to this run.
--
-- FT tables captured (6): TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
-- FE tables captured (8): TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
-- =============================================================================

USE [YourDatabase];  -- Same database as 00, 01, 02
GO

PRINT '=== Before drop: archive row counts ===';
SELECT 'ArchiveTT_PARM' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_PARM
UNION ALL SELECT 'ArchiveTT_SITE', COUNT(*) FROM tsip_archive.ArchiveTT_SITE
UNION ALL SELECT 'ArchiveTT_ANTE', COUNT(*) FROM tsip_archive.ArchiveTT_ANTE
UNION ALL SELECT 'ArchiveTT_CHAN', COUNT(*) FROM tsip_archive.ArchiveTT_CHAN
-- FT tables (6)
UNION ALL SELECT 'ArchiveFT_TITL', COUNT(*) FROM tsip_archive.ArchiveFT_TITL
UNION ALL SELECT 'ArchiveFT_SHRL', COUNT(*) FROM tsip_archive.ArchiveFT_SHRL
UNION ALL SELECT 'ArchiveFT_SITE', COUNT(*) FROM tsip_archive.ArchiveFT_SITE
UNION ALL SELECT 'ArchiveFT_ANTE', COUNT(*) FROM tsip_archive.ArchiveFT_ANTE
UNION ALL SELECT 'ArchiveFT_CHAN', COUNT(*) FROM tsip_archive.ArchiveFT_CHAN
UNION ALL SELECT 'ArchiveFT_CHNG_CALL', COUNT(*) FROM tsip_archive.ArchiveFT_CHNG_CALL
-- FE tables (8)
UNION ALL SELECT 'ArchiveFE_TITL', COUNT(*) FROM tsip_archive.ArchiveFE_TITL
UNION ALL SELECT 'ArchiveFE_SHRL', COUNT(*) FROM tsip_archive.ArchiveFE_SHRL
UNION ALL SELECT 'ArchiveFE_SITE', COUNT(*) FROM tsip_archive.ArchiveFE_SITE
UNION ALL SELECT 'ArchiveFE_AZIM', COUNT(*) FROM tsip_archive.ArchiveFE_AZIM
UNION ALL SELECT 'ArchiveFE_ANTE', COUNT(*) FROM tsip_archive.ArchiveFE_ANTE
UNION ALL SELECT 'ArchiveFE_CHAN', COUNT(*) FROM tsip_archive.ArchiveFE_CHAN
UNION ALL SELECT 'ArchiveFE_CLOC', COUNT(*) FROM tsip_archive.ArchiveFE_CLOC
UNION ALL SELECT 'ArchiveFE_CCAL', COUNT(*) FROM tsip_archive.ArchiveFE_CCAL;
GO

-- =============================================================================
-- DROP TT_PARM FIRST - This triggers FT/FE source capture!
-- =============================================================================
PRINT '';
PRINT '=== Dropping dbo.tt_test_run01_parm (triggers FT/FE capture) ===';
DROP TABLE dbo.tt_test_run01_parm;
PRINT 'Dropped. All FT (6 tables) and FE (8 tables) source data should now be archived.';
GO

PRINT '';
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

-- =============================================================================
-- Verify TT archives
-- =============================================================================
PRINT '';
PRINT '=== TT Archive Contents (RunKey = test_run01) ===';
SELECT * FROM tsip_archive.ArchiveTT_PARM WHERE RunKey = 'test_run01';
SELECT * FROM tsip_archive.ArchiveTT_SITE WHERE RunKey = 'test_run01';
SELECT * FROM tsip_archive.ArchiveTT_ANTE WHERE RunKey = 'test_run01';
SELECT * FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = 'test_run01';
GO

-- =============================================================================
-- Verify FT archives (6 tables captured at run completion)
-- =============================================================================
PRINT '';
PRINT '=== FT (TS Source) Archive Contents - 6 tables (RunKey = test_run01) ===';
SELECT 'FT_TITL' AS TblType, * FROM tsip_archive.ArchiveFT_TITL WHERE RunKey = 'test_run01';
SELECT 'FT_SHRL' AS TblType, * FROM tsip_archive.ArchiveFT_SHRL WHERE RunKey = 'test_run01';
SELECT 'FT_SITE' AS TblType, * FROM tsip_archive.ArchiveFT_SITE WHERE RunKey = 'test_run01';
SELECT 'FT_ANTE' AS TblType, * FROM tsip_archive.ArchiveFT_ANTE WHERE RunKey = 'test_run01';
SELECT 'FT_CHAN' AS TblType, * FROM tsip_archive.ArchiveFT_CHAN WHERE RunKey = 'test_run01';
SELECT 'FT_CHNG_CALL' AS TblType, * FROM tsip_archive.ArchiveFT_CHNG_CALL WHERE RunKey = 'test_run01';
GO

-- =============================================================================
-- Verify FE archives (8 tables captured at run completion)
-- =============================================================================
PRINT '';
PRINT '=== FE (ES Source) Archive Contents - 8 tables (RunKey = test_run01) ===';
SELECT 'FE_TITL' AS TblType, * FROM tsip_archive.ArchiveFE_TITL WHERE RunKey = 'test_run01';
SELECT 'FE_SHRL' AS TblType, * FROM tsip_archive.ArchiveFE_SHRL WHERE RunKey = 'test_run01';
SELECT 'FE_SITE' AS TblType, * FROM tsip_archive.ArchiveFE_SITE WHERE RunKey = 'test_run01';
SELECT 'FE_AZIM' AS TblType, * FROM tsip_archive.ArchiveFE_AZIM WHERE RunKey = 'test_run01';
SELECT 'FE_ANTE' AS TblType, * FROM tsip_archive.ArchiveFE_ANTE WHERE RunKey = 'test_run01';
SELECT 'FE_CHAN' AS TblType, * FROM tsip_archive.ArchiveFE_CHAN WHERE RunKey = 'test_run01';
SELECT 'FE_CLOC' AS TblType, * FROM tsip_archive.ArchiveFE_CLOC WHERE RunKey = 'test_run01';
SELECT 'FE_CCAL' AS TblType, * FROM tsip_archive.ArchiveFE_CCAL WHERE RunKey = 'test_run01';
GO

-- =============================================================================
-- After drop: archive row counts
-- =============================================================================
PRINT '';
PRINT '=== After drop: archive row counts ===';
SELECT 'ArchiveTT_PARM' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_PARM
UNION ALL SELECT 'ArchiveTT_SITE', COUNT(*) FROM tsip_archive.ArchiveTT_SITE
UNION ALL SELECT 'ArchiveTT_ANTE', COUNT(*) FROM tsip_archive.ArchiveTT_ANTE
UNION ALL SELECT 'ArchiveTT_CHAN', COUNT(*) FROM tsip_archive.ArchiveTT_CHAN
-- FT tables (6)
UNION ALL SELECT 'ArchiveFT_TITL', COUNT(*) FROM tsip_archive.ArchiveFT_TITL
UNION ALL SELECT 'ArchiveFT_SHRL', COUNT(*) FROM tsip_archive.ArchiveFT_SHRL
UNION ALL SELECT 'ArchiveFT_SITE', COUNT(*) FROM tsip_archive.ArchiveFT_SITE
UNION ALL SELECT 'ArchiveFT_ANTE', COUNT(*) FROM tsip_archive.ArchiveFT_ANTE
UNION ALL SELECT 'ArchiveFT_CHAN', COUNT(*) FROM tsip_archive.ArchiveFT_CHAN
UNION ALL SELECT 'ArchiveFT_CHNG_CALL', COUNT(*) FROM tsip_archive.ArchiveFT_CHNG_CALL
-- FE tables (8)
UNION ALL SELECT 'ArchiveFE_TITL', COUNT(*) FROM tsip_archive.ArchiveFE_TITL
UNION ALL SELECT 'ArchiveFE_SHRL', COUNT(*) FROM tsip_archive.ArchiveFE_SHRL
UNION ALL SELECT 'ArchiveFE_SITE', COUNT(*) FROM tsip_archive.ArchiveFE_SITE
UNION ALL SELECT 'ArchiveFE_AZIM', COUNT(*) FROM tsip_archive.ArchiveFE_AZIM
UNION ALL SELECT 'ArchiveFE_ANTE', COUNT(*) FROM tsip_archive.ArchiveFE_ANTE
UNION ALL SELECT 'ArchiveFE_CHAN', COUNT(*) FROM tsip_archive.ArchiveFE_CHAN
UNION ALL SELECT 'ArchiveFE_CLOC', COUNT(*) FROM tsip_archive.ArchiveFE_CLOC
UNION ALL SELECT 'ArchiveFE_CCAL', COUNT(*) FROM tsip_archive.ArchiveFE_CCAL;
GO

-- =============================================================================
-- Verify TT tables are gone, but FT/FE source tables still exist
-- =============================================================================
PRINT '';
PRINT '=== Verify TT tables are dropped ===';
IF OBJECT_ID(N'dbo.tt_test_run01_parm', N'U') IS NULL
    PRINT 'OK: tt_test_run01_parm no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_site', N'U') IS NULL
    PRINT 'OK: tt_test_run01_site no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_ante', N'U') IS NULL
    PRINT 'OK: tt_test_run01_ante no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_chan', N'U') IS NULL
    PRINT 'OK: tt_test_run01_chan no longer exists.';

PRINT '';
PRINT '=== Verify FT source tables STILL EXIST (not dropped, just archived) ===';
IF OBJECT_ID(N'dbo.ft_testproj_titl', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_titl still exists.';
IF OBJECT_ID(N'dbo.ft_testproj_shrl', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_shrl still exists.';
IF OBJECT_ID(N'dbo.ft_testproj_site', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_site still exists.';
IF OBJECT_ID(N'dbo.ft_testproj_ante', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_ante still exists.';
IF OBJECT_ID(N'dbo.ft_testproj_chan', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_chan still exists.';
IF OBJECT_ID(N'dbo.ft_testproj_chng_call', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_chng_call still exists.';

PRINT '';
PRINT '=== Verify FE source tables STILL EXIST (not dropped, just archived) ===';
IF OBJECT_ID(N'dbo.fe_envproj_titl', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_titl still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_shrl', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_shrl still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_site', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_site still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_azim', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_azim still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_ante', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_ante still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_chan', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_chan still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_cloc', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_cloc still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_ccal', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_ccal still exists.';
GO

-- =============================================================================
-- Show complete run summary with all linked data
-- =============================================================================
PRINT '';
PRINT '=== Complete Run Summary ===';
SELECT 
    p.RunKey,
    p.ArchivedAt,
    RTRIM(p.proname) AS TS_PdfName,
    RTRIM(p.envname) AS ES_PdfName,
    p.numcases AS TotalCases,
    -- TT counts
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_SITE WHERE RunKey = p.RunKey) AS TT_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = p.RunKey) AS TT_Channels,
    -- FT counts (6 tables)
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_TITL WHERE RunKey = p.RunKey) AS FT_Titl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SHRL WHERE RunKey = p.RunKey) AS FT_Shrl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SITE WHERE RunKey = p.RunKey) AS FT_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_ANTE WHERE RunKey = p.RunKey) AS FT_Ante,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_CHAN WHERE RunKey = p.RunKey) AS FT_Chan,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_CHNG_CALL WHERE RunKey = p.RunKey) AS FT_ChngCall,
    -- FE counts (8 tables)
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_TITL WHERE RunKey = p.RunKey) AS FE_Titl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SHRL WHERE RunKey = p.RunKey) AS FE_Shrl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SITE WHERE RunKey = p.RunKey) AS FE_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_AZIM WHERE RunKey = p.RunKey) AS FE_Azim,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_ANTE WHERE RunKey = p.RunKey) AS FE_Ante,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CHAN WHERE RunKey = p.RunKey) AS FE_Chan,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CLOC WHERE RunKey = p.RunKey) AS FE_Cloc,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CCAL WHERE RunKey = p.RunKey) AS FE_Ccal
FROM tsip_archive.ArchiveTT_PARM p
WHERE p.RunKey = 'test_run01';
GO
