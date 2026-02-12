-- =============================================================================
-- 04_cleanup_trigger.sql
-- (Optional) Drops the FT/FE archive trigger.
-- =============================================================================

USE [YourDatabase];  -- Same database
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveFtFe_OnDropTable' AND parent_id = 0)
BEGIN
    DROP TRIGGER trg_ArchiveFtFe_OnDropTable ON DATABASE;
    PRINT 'Trigger trg_ArchiveFtFe_OnDropTable dropped.';
END
ELSE
    PRINT 'Trigger trg_ArchiveFtFe_OnDropTable does not exist.';
GO
