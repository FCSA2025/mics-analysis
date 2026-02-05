-- =============================================================================
-- 00_create_schema_and_archive_tables.sql
-- Creates tsip_archive schema and archive tables for TT PARM and SITE (minimal
-- columns for testing the drop-trigger capture). Run this first.
-- =============================================================================

USE [YourDatabase];  -- Change to your dev database (e.g. MicsMin, RemicsDev)
GO

-- Schema for archive tables
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'tsip_archive')
    EXEC('CREATE SCHEMA tsip_archive');
GO

-- Archive table for TT_PARM (one row per run)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_PARM', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_PARM;
GO

CREATE TABLE tsip_archive.ArchiveTT_PARM (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    proname      CHAR(16) NULL,   -- TS (Terrestrial Station) file/PDF name
    envname      CHAR(16) NULL,   -- ES (Earth Station) file/PDF name
    runname      CHAR(5) NULL,
    numcases     INT NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_PARM PRIMARY KEY (ArchiveId)
);
GO

-- Archive table for TT_SITE (many rows per run)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_SITE;
GO

CREATE TABLE tsip_archive.ArchiveTT_SITE (
    RunKey     NVARCHAR(128) NOT NULL,
    SiteRowId  BIGINT IDENTITY(1,1) NOT NULL,
    intcall1   CHAR(9) NULL,
    viccall1   CHAR(9) NULL,
    caseno     INT NULL,
    ArchivedAt DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_SITE PRIMARY KEY (RunKey, SiteRowId)
);
GO

-- Archive table for TT_ANTE (many rows per run)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveTT_ANTE (
    RunKey     NVARCHAR(128) NOT NULL,
    AnteRowId  BIGINT IDENTITY(1,1) NOT NULL,
    intcall1   CHAR(9) NULL,
    viccall1   CHAR(9) NULL,
    caseno     INT NULL,
    intacode   CHAR(12) NULL,
    vicacode   CHAR(12) NULL,
    ArchivedAt DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_ANTE PRIMARY KEY (RunKey, AnteRowId)
);
GO

-- Archive table for TT_CHAN (many rows per run)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveTT_CHAN (
    RunKey     NVARCHAR(128) NOT NULL,
    ChanRowId  BIGINT IDENTITY(1,1) NOT NULL,
    intcall1   CHAR(9) NULL,
    viccall1   CHAR(9) NULL,
    caseno     INT NULL,
    resti      FLOAT NULL,   -- margin (dB)
    freqsep    FLOAT NULL,   -- frequency separation (MHz)
    ArchivedAt DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_CHAN PRIMARY KEY (RunKey, ChanRowId)
);
GO

PRINT 'Schema tsip_archive and archive tables (PARM, SITE, ANTE, CHAN) created.';
GO
