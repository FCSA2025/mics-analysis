-- =============================================================================
-- 02_create_ft_fe_drop_trigger.sql
-- Creates a DATABASE-scoped DDL trigger that fires on DROP_TABLE for FT and FE
-- tables. For tables matching ft_*_site, ft_*_ante, ft_*_chan, fe_*_site, 
-- fe_*_ante, fe_*_chan it: (1) rolls back the drop, (2) copies data into
-- tsip_archive tables, (3) re-drops the table.
-- =============================================================================

USE [YourDatabase];  -- Change to your dev database
GO

-- Remove existing trigger if re-running
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_ArchiveFtFe_OnDropTable' AND parent_id = 0)
    DROP TRIGGER trg_ArchiveFtFe_OnDropTable ON DATABASE;
GO

CREATE TRIGGER trg_ArchiveFtFe_OnDropTable
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
    DECLARE @PdfName      NVARCHAR(128);
    DECLARE @TableType    CHAR(2);  -- 'FT' or 'FE'
    DECLARE @TableSuffix  VARCHAR(10);  -- 'site', 'ante', or 'chan'

    -- Determine if this is an FT or FE table we should archive
    -- FT tables: ft_*_site, ft_*_ante, ft_*_chan
    -- FE tables: fe_*_site, fe_*_ante, fe_*_chan
    
    IF @ObjectName LIKE 'ft_%_site'
    BEGIN
        SET @TableType = 'FT';
        SET @TableSuffix = 'site';
        SET @PdfName = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- strip 'ft_' and '_site'
    END
    ELSE IF @ObjectName LIKE 'ft_%_ante'
    BEGIN
        SET @TableType = 'FT';
        SET @TableSuffix = 'ante';
        SET @PdfName = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- strip 'ft_' and '_ante'
    END
    ELSE IF @ObjectName LIKE 'ft_%_chan'
    BEGIN
        SET @TableType = 'FT';
        SET @TableSuffix = 'chan';
        SET @PdfName = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- strip 'ft_' and '_chan'
    END
    ELSE IF @ObjectName LIKE 'fe_%_site'
    BEGIN
        SET @TableType = 'FE';
        SET @TableSuffix = 'site';
        SET @PdfName = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- strip 'fe_' and '_site'
    END
    ELSE IF @ObjectName LIKE 'fe_%_ante'
    BEGIN
        SET @TableType = 'FE';
        SET @TableSuffix = 'ante';
        SET @PdfName = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- strip 'fe_' and '_ante'
    END
    ELSE IF @ObjectName LIKE 'fe_%_chan'
    BEGIN
        SET @TableType = 'FE';
        SET @TableSuffix = 'chan';
        SET @PdfName = SUBSTRING(@ObjectName, 4, LEN(@ObjectName) - 4 - 5);  -- strip 'fe_' and '_chan'
    END
    ELSE
        -- Not an FT/FE table we care about
        RETURN;

    -- Rollback the drop so the table and data exist again
    ROLLBACK;

    SET @QualifiedName = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName);

    -- Copy data into archive based on table type and suffix
    IF @TableType = 'FT'
    BEGIN
        IF @TableSuffix = 'site'
        BEGIN
            SET @Sql = N'
                INSERT INTO tsip_archive.ArchiveFT_SITE 
                    (PdfName, call1, call2, name1, name2, oper, oper2, latit, longit, grnd, cmd, ArchivedAt)
                SELECT @PdfName, call1, call2, name1, name2, oper, oper2, latit, longit, grnd, cmd, GETUTCDATE()
                FROM ' + @QualifiedName;
            EXEC sp_executesql @Sql, N'@PdfName NVARCHAR(128)', @PdfName = @PdfName;
        END
        ELSE IF @TableSuffix = 'ante'
        BEGIN
            SET @Sql = N'
                INSERT INTO tsip_archive.ArchiveFT_ANTE 
                    (PdfName, call1, call2, bndcde, anum, acode, aht, azmth, elvtn, gain, dist, offazm, cmd, ArchivedAt)
                SELECT @PdfName, call1, call2, bndcde, anum, acode, aht, azmth, elvtn, gain, dist, offazm, cmd, GETUTCDATE()
                FROM ' + @QualifiedName;
            EXEC sp_executesql @Sql, N'@PdfName NVARCHAR(128)', @PdfName = @PdfName;
        END
        ELSE IF @TableSuffix = 'chan'
        BEGIN
            SET @Sql = N'
                INSERT INTO tsip_archive.ArchiveFT_CHAN 
                    (PdfName, call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, pwrrx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, ArchivedAt)
                SELECT @PdfName, call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, pwrrx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, GETUTCDATE()
                FROM ' + @QualifiedName;
            EXEC sp_executesql @Sql, N'@PdfName NVARCHAR(128)', @PdfName = @PdfName;
        END
    END
    ELSE IF @TableType = 'FE'
    BEGIN
        IF @TableSuffix = 'site'
        BEGIN
            SET @Sql = N'
                INSERT INTO tsip_archive.ArchiveFE_SITE 
                    (PdfName, location, name, oper, latit, longit, grnd, rainzone, radiozone, cmd, ArchivedAt)
                SELECT @PdfName, location, name, oper, latit, longit, grnd, rainzone, radiozone, cmd, GETUTCDATE()
                FROM ' + @QualifiedName;
            EXEC sp_executesql @Sql, N'@PdfName NVARCHAR(128)', @PdfName = @PdfName;
        END
        ELSE IF @TableSuffix = 'ante'
        BEGIN
            SET @Sql = N'
                INSERT INTO tsip_archive.ArchiveFE_ANTE 
                    (PdfName, location, call1, band, acodetx, acoderx, aht, az, el, g_t, satname, satoper, satlongit, cmd, ArchivedAt)
                SELECT @PdfName, location, call1, band, acodetx, acoderx, aht, az, el, g_t, satname, satoper, satlongit, cmd, GETUTCDATE()
                FROM ' + @QualifiedName;
            EXEC sp_executesql @Sql, N'@PdfName NVARCHAR(128)', @PdfName = @PdfName;
        END
        ELSE IF @TableSuffix = 'chan'
        BEGIN
            SET @Sql = N'
                INSERT INTO tsip_archive.ArchiveFE_CHAN 
                    (PdfName, location, call1, band, chid, freqtx, freqrx, pwrtx, pwrrx, eirp, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, ArchivedAt)
                SELECT @PdfName, location, call1, band, chid, freqtx, freqrx, pwrtx, pwrrx, eirp, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd, GETUTCDATE()
                FROM ' + @QualifiedName;
            EXEC sp_executesql @Sql, N'@PdfName NVARCHAR(128)', @PdfName = @PdfName;
        END
    END

    -- Re-drop the table (trigger will fire again with nestlevel=2 and exit)
    SET @SqlDrop = N'DROP TABLE ' + @QualifiedName;
    EXEC sp_executesql @SqlDrop;
END;
GO

PRINT 'DDL trigger trg_ArchiveFtFe_OnDropTable created on DATABASE.';
PRINT '';
PRINT 'This trigger archives data from:';
PRINT '  - ft_*_site, ft_*_ante, ft_*_chan (Terrestrial Station tables)';
PRINT '  - fe_*_site, fe_*_ante, fe_*_chan (Earth Station tables)';
GO
