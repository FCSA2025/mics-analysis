-- =============================================================================
-- 05_test_and_verify.sql
-- Tests the complete archive solution:
--   1. Simulates a queue INSERT to archive FT/FE source data
--   2. Drops TT tables to test DDL trigger TT archiving
--   3. Verifies all archived data
--
-- Prerequisites:
--   - Run 00_create_schema_and_archive_tables.sql
--   - Run 01_create_sample_tt_tables.sql  
--   - Run 02_create_drop_trigger.sql (DDL trigger for TT)
--   - Run 03_create_schema_lookup_function.sql
--   - Run 04_create_queue_insert_trigger.sql (INSERT trigger for FT/FE)
-- =============================================================================

USE [YourDatabase];  -- Same database as other scripts
GO

-- =============================================================================
-- PART 1: Test FT/FE archiving via queue INSERT trigger
-- =============================================================================
PRINT '==============================================================================';
PRINT 'PART 1: Testing FT/FE archiving via tsip_queue INSERT';
PRINT '==============================================================================';
PRINT '';

PRINT '=== Before test: archive row counts ===';
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

-- Insert a test job into tsip_queue to trigger FT/FE archiving
-- NOTE: For this test, we need a tp_*_parm table. 
-- The sample test data uses schema 'dbo' and argfile 'test_run01'
-- So we need: dbo.tp_test_run01_parm with proname and envname

-- First, create the tp_parm table that the trigger will look for
PRINT '';
PRINT '=== Creating test tp_parm table (dbo.tp_test_run01_parm) ===';
IF OBJECT_ID(N'dbo.tp_test_run01_parm', N'U') IS NOT NULL
    DROP TABLE dbo.tp_test_run01_parm;

CREATE TABLE dbo.tp_test_run01_parm (
    proname CHAR(16),
    envname CHAR(16)
);
INSERT INTO dbo.tp_test_run01_parm (proname, envname) 
VALUES ('testproj', 'envproj');
PRINT 'Created tp_test_run01_parm with proname=testproj, envname=envproj';
GO

-- Insert into tsip_queue to trigger FT/FE archiving
-- This simulates a real TSIP job being queued
PRINT '';
PRINT '=== Inserting test job into web.tsip_queue ===';

-- Get next TQ_Job number
DECLARE @NextJob INT;
SELECT @NextJob = ISNULL(MAX(TQ_Job), 0) + 1 FROM web.tsip_queue;

INSERT INTO web.tsip_queue (TQ_Job, TQ_Status, TQ_ArgFile, TQ_MicsID, TQ_TimeIn)
VALUES (@NextJob, 'P', 'test_run01', 'dbo1', GETDATE());

PRINT 'Inserted TQ_Job = ' + CAST(@NextJob AS VARCHAR(10));
PRINT 'TQ_ArgFile = test_run01';
PRINT 'TQ_MicsID = dbo1 (maps to schema dbo)';
PRINT '';
PRINT 'The INSERT trigger should have archived FT/FE source data.';
GO

-- Verify FT/FE archives
PRINT '';
PRINT '=== FT Archive Contents (from queue trigger) ===';
SELECT 'FT_TITL' AS TblType, TQ_Job, PdfName, ArchivedAt FROM tsip_archive.ArchiveFT_TITL ORDER BY ArchiveId DESC;
SELECT 'FT_SITE' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveFT_SITE WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
SELECT 'FT_CHAN' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveFT_CHAN WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
GO

PRINT '';
PRINT '=== FE Archive Contents (from queue trigger) ===';
SELECT 'FE_TITL' AS TblType, TQ_Job, PdfName, ArchivedAt FROM tsip_archive.ArchiveFE_TITL ORDER BY ArchiveId DESC;
SELECT 'FE_SITE' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveFE_SITE WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
SELECT 'FE_CHAN' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveFE_CHAN WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
GO

-- =============================================================================
-- PART 2: Test TT archiving via DDL DROP trigger
-- =============================================================================
PRINT '';
PRINT '==============================================================================';
PRINT 'PART 2: Testing TT archiving via DROP TABLE DDL trigger';
PRINT '==============================================================================';
PRINT '';

PRINT '=== Dropping TT tables (triggers TT archiving) ===';
PRINT '';
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

-- =============================================================================
-- PART 3: Verify all archives
-- =============================================================================
PRINT '';
PRINT '==============================================================================';
PRINT 'PART 3: Verification';
PRINT '==============================================================================';
PRINT '';

PRINT '=== TT Archive Contents (RunKey = test_run01) ===';
SELECT * FROM tsip_archive.ArchiveTT_PARM WHERE RunKey = 'test_run01';
SELECT 'TT_SITE' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveTT_SITE WHERE RunKey = 'test_run01';
SELECT 'TT_ANTE' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveTT_ANTE WHERE RunKey = 'test_run01';
SELECT 'TT_CHAN' AS TblType, COUNT(*) AS RowCount FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = 'test_run01';
GO

PRINT '';
PRINT '=== After test: archive row counts ===';
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
-- Verify TT tables are gone, FT/FE source tables still exist
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
PRINT '=== Verify FT/FE source tables STILL EXIST (not dropped) ===';
IF OBJECT_ID(N'dbo.ft_testproj_site', N'U') IS NOT NULL
    PRINT 'OK: ft_testproj_site still exists.';
IF OBJECT_ID(N'dbo.fe_envproj_site', N'U') IS NOT NULL
    PRINT 'OK: fe_envproj_site still exists.';
GO

PRINT '';
PRINT '==============================================================================';
PRINT 'TEST COMPLETE';
PRINT '';
PRINT 'Expected Results:';
PRINT '  - FT/FE archives: Populated when job was INSERTed into tsip_queue';
PRINT '  - TT archives: Populated when TT tables were DROPped';
PRINT '  - TT tables: Gone (dropped)';
PRINT '  - FT/FE source tables: Still exist (only archived, not dropped)';
PRINT '==============================================================================';
GO
