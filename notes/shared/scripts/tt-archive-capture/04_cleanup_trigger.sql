-- =============================================================================
-- 04_cleanup_trigger.sql
-- Removes the DDL trigger. Run when you no longer need the capture behavior.
-- =============================================================================

USE [YourDatabase];
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveTT_OnDropTable' AND parent_id = 0)
BEGIN
    DROP TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
    PRINT 'Trigger trg_ArchiveTT_OnDropTable dropped.';
END
ELSE
    PRINT 'Trigger not found (may already be dropped).';
GO
