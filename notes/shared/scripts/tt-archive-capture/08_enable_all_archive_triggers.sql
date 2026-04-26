-- =============================================================================
-- 08_enable_all_archive_triggers.sql
-- Re-enables everything 07_disable_all_archive_triggers.sql turned off.
-- =============================================================================

USE [YourDatabase];  -- same database as 07
GO

SET NOCOUNT ON;

-- (1) All table-level triggers on web.tsip_queue (those that are still disabled)
DECLARE @trig  sysname;
DECLARE @tsql  NVARCHAR(512);
DECLARE @sch   sysname = ISNULL(OBJECT_SCHEMA_NAME(OBJECT_ID(N'web.tsip_queue', N'U')), N'web');
DECLARE @tname sysname = ISNULL(OBJECT_NAME(OBJECT_ID(N'web.tsip_queue', N'U')), N'tsip_queue');

IF OBJECT_ID(N'web.tsip_queue', N'U') IS NULL
    PRINT '--- web.tsip_queue not found; skipping table triggers ---';
ELSE IF NOT EXISTS (
    SELECT 1 FROM sys.triggers t
    WHERE t.parent_id = OBJECT_ID(N'web.tsip_queue', N'U') AND t.is_disabled = 1
)
    PRINT '--- No disabled triggers on web.tsip_queue (nothing to enable) ---';
ELSE
BEGIN
    PRINT '--- Enabling disabled triggers on web.tsip_queue ---';
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.name
    FROM sys.triggers t
    WHERE t.parent_id = OBJECT_ID(N'web.tsip_queue', N'U') AND t.is_disabled = 1;

    OPEN c;
    FETCH NEXT FROM c INTO @trig;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @tsql = N'ENABLE TRIGGER ' + QUOTENAME(@sch) + N'.' + QUOTENAME(@trig) + N' ON ' + QUOTENAME(@sch) + N'.' + QUOTENAME(@tname) + N';';
        PRINT @tsql;
        EXEC sp_executesql @tsql;
        FETCH NEXT FROM c INTO @trig;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveTT_OnDropTable' AND parent_id = 0 AND is_disabled = 1)
BEGIN
    ENABLE TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
    PRINT '--- Enabled: trg_ArchiveTT_OnDropTable ON DATABASE ---';
END
ELSE
    PRINT '--- Skipped (not found or not disabled): trg_ArchiveTT_OnDropTable ---';
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveFtFe_OnDropTable' AND parent_id = 0 AND is_disabled = 1)
BEGIN
    ENABLE TRIGGER trg_ArchiveFtFe_OnDropTable ON DATABASE;
    PRINT '--- Enabled: trg_ArchiveFtFe_OnDropTable ON DATABASE ---';
END
ELSE
    PRINT '--- Skipped (not found or not disabled): trg_ArchiveFtFe_OnDropTable ---';
GO

PRINT 'Done.';
GO
