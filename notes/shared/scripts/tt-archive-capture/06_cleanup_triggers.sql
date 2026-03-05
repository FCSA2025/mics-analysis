-- =============================================================================
-- 06_cleanup_triggers.sql
-- Removes all triggers and optionally the helper function.
-- Run when you no longer need the archive capture behavior.
-- =============================================================================

USE [YourDatabase];
GO

-- =============================================================================
-- Remove DDL trigger (TT archiving)
-- =============================================================================
PRINT '=== Removing DDL trigger for TT archiving ===';
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveTT_OnDropTable' AND parent_id = 0)
BEGIN
    DROP TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
    PRINT 'Dropped: trg_ArchiveTT_OnDropTable (DATABASE DDL trigger)';
END
ELSE
    PRINT 'Not found: trg_ArchiveTT_OnDropTable (may already be dropped)';
GO

-- =============================================================================
-- Remove INSERT trigger on tsip_queue (FT/FE archiving)
-- =============================================================================
PRINT '';
PRINT '=== Removing INSERT trigger for FT/FE archiving ===';
IF OBJECT_ID(N'web.trg_ArchiveFTFE_OnQueueInsert', N'TR') IS NOT NULL
BEGIN
    DROP TRIGGER web.trg_ArchiveFTFE_OnQueueInsert;
    PRINT 'Dropped: web.trg_ArchiveFTFE_OnQueueInsert (INSERT trigger)';
END
ELSE
    PRINT 'Not found: web.trg_ArchiveFTFE_OnQueueInsert (may already be dropped)';
GO

-- =============================================================================
-- Remove helper function (optional)
-- =============================================================================
PRINT '';
PRINT '=== Removing helper function ===';
IF OBJECT_ID(N'tsip_archive.fn_GetSchemaFromMicsID', N'FN') IS NOT NULL
BEGIN
    DROP FUNCTION tsip_archive.fn_GetSchemaFromMicsID;
    PRINT 'Dropped: tsip_archive.fn_GetSchemaFromMicsID';
END
ELSE
    PRINT 'Not found: tsip_archive.fn_GetSchemaFromMicsID';
GO

PRINT '';
PRINT '=== Cleanup complete ===';
PRINT '';
PRINT 'NOTE: Archive tables and data are preserved in tsip_archive schema.';
PRINT 'To remove the archive schema and all data, run:';
PRINT '';
PRINT '  DROP TABLE tsip_archive.ArchiveTT_PARM;';
PRINT '  DROP TABLE tsip_archive.ArchiveTT_SITE;';
PRINT '  DROP TABLE tsip_archive.ArchiveTT_ANTE;';
PRINT '  DROP TABLE tsip_archive.ArchiveTT_CHAN;';
PRINT '  DROP TABLE tsip_archive.ArchiveFT_TITL;';
PRINT '  DROP TABLE tsip_archive.ArchiveFT_SHRL;';
PRINT '  DROP TABLE tsip_archive.ArchiveFT_SITE;';
PRINT '  DROP TABLE tsip_archive.ArchiveFT_ANTE;';
PRINT '  DROP TABLE tsip_archive.ArchiveFT_CHAN;';
PRINT '  DROP TABLE tsip_archive.ArchiveFT_CHNG_CALL;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_TITL;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_SHRL;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_SITE;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_AZIM;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_ANTE;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_CHAN;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_CLOC;';
PRINT '  DROP TABLE tsip_archive.ArchiveFE_CCAL;';
PRINT '  DROP SCHEMA tsip_archive;';
GO
