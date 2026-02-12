-- =============================================================================
-- 00_create_schema_and_archive_tables.sql
-- Creates tsip_archive schema and archive tables for:
--   - TT (TSIP results): PARM, SITE, ANTE, CHAN
--   - FT (TS source data): TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
--   - FE (ES source data): TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
-- 
-- All FT/FE tables are captured at run completion (when TT_PARM is dropped).
-- Run this first before creating the trigger.
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

-- =============================================================================
-- FT (Terrestrial Station) Source Archive Tables
-- Captured at run completion (when TT_PARM is dropped), linked by RunKey
-- Full set: TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
-- =============================================================================

-- Archive table for FT_TITL (Title/metadata)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_TITL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_TITL;
GO

CREATE TABLE tsip_archive.ArchiveFT_TITL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    title        CHAR(80) NULL,
    cdate        CHAR(10) NULL,                -- Creation date
    mdate        CHAR(10) NULL,                -- Modification date
    mtime        CHAR(8) NULL,                 -- Modification time
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_TITL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_TITL_RunKey ON tsip_archive.ArchiveFT_TITL (RunKey);
GO

-- Archive table for FT_SHRL (Shared link approvals)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_SHRL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_SHRL;
GO

CREATE TABLE tsip_archive.ArchiveFT_SHRL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    bndcde       CHAR(4) NULL,
    shession     CHAR(10) NULL,                -- Sharing session
    approval     CHAR(1) NULL,                 -- Approval flag
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_SHRL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_SHRL_RunKey ON tsip_archive.ArchiveFT_SHRL (RunKey);
GO

-- Archive table for FT_SITE
IF OBJECT_ID(N'tsip_archive.ArchiveFT_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_SITE;
GO

CREATE TABLE tsip_archive.ArchiveFT_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,       -- TS PDF name (= proname)
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    name1        CHAR(32) NULL,
    name2        CHAR(32) NULL,
    oper         CHAR(6) NULL,
    oper2        CHAR(6) NULL,
    latit        INT NULL,
    longit       INT NULL,
    grnd         FLOAT NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_SITE_RunKey ON tsip_archive.ArchiveFT_SITE (RunKey);
GO

-- Archive table for FT_ANTE
IF OBJECT_ID(N'tsip_archive.ArchiveFT_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveFT_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    bndcde       CHAR(4) NULL,
    anum         SMALLINT NULL,
    acode        CHAR(12) NULL,
    aht          FLOAT NULL,
    azmth        FLOAT NULL,
    elvtn        FLOAT NULL,
    gain         FLOAT NULL,
    dist         FLOAT NULL,
    offazm       CHAR(1) NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_ANTE_RunKey ON tsip_archive.ArchiveFT_ANTE (RunKey);
GO

-- Archive table for FT_CHAN
IF OBJECT_ID(N'tsip_archive.ArchiveFT_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveFT_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    bndcde       CHAR(4) NULL,
    chid         CHAR(4) NULL,
    freqtx       FLOAT NULL,
    freqrx       FLOAT NULL,
    pwrtx        FLOAT NULL,
    pwrrx        FLOAT NULL,
    traftx       CHAR(6) NULL,
    trafrx       CHAR(6) NULL,
    eqpttx       CHAR(8) NULL,
    eqptrx       CHAR(8) NULL,
    stattx       CHAR(1) NULL,
    statrx       CHAR(1) NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_CHAN_RunKey ON tsip_archive.ArchiveFT_CHAN (RunKey);
GO

-- Archive table for FT_CHNG_CALL (Call sign change history)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_CHNG_CALL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_CHNG_CALL;
GO

CREATE TABLE tsip_archive.ArchiveFT_CHNG_CALL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    oldcall1     CHAR(9) NULL,                 -- Old call sign 1
    oldcall2     CHAR(9) NULL,                 -- Old call sign 2
    newcall1     CHAR(9) NULL,                 -- New call sign 1
    newcall2     CHAR(9) NULL,                 -- New call sign 2
    chngdate     CHAR(10) NULL,                -- Change date
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_CHNG_CALL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_CHNG_CALL_RunKey ON tsip_archive.ArchiveFT_CHNG_CALL (RunKey);
GO

-- =============================================================================
-- FE (Earth Station) Source Archive Tables
-- Captured at run completion (when TT_PARM is dropped), linked by RunKey
-- Full set: TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
-- =============================================================================

-- Archive table for FE_TITL (Title/metadata)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_TITL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_TITL;
GO

CREATE TABLE tsip_archive.ArchiveFE_TITL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    title        CHAR(80) NULL,
    cdate        CHAR(10) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_TITL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_TITL_RunKey ON tsip_archive.ArchiveFE_TITL (RunKey);
GO

-- Archive table for FE_SHRL (Shared link approvals)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_SHRL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_SHRL;
GO

CREATE TABLE tsip_archive.ArchiveFE_SHRL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    shession     CHAR(10) NULL,
    approval     CHAR(1) NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_SHRL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_SHRL_RunKey ON tsip_archive.ArchiveFE_SHRL (RunKey);
GO

-- Archive table for FE_SITE
IF OBJECT_ID(N'tsip_archive.ArchiveFE_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_SITE;
GO

CREATE TABLE tsip_archive.ArchiveFE_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,       -- ES PDF name (= envname)
    location     CHAR(10) NULL,
    name         CHAR(16) NULL,
    oper         CHAR(6) NULL,
    latit        INT NULL,
    longit       INT NULL,
    grnd         FLOAT NULL,
    rainzone     SMALLINT NULL,
    radiozone    CHAR(2) NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_SITE_RunKey ON tsip_archive.ArchiveFE_SITE (RunKey);
GO

-- Archive table for FE_AZIM (Azimuth records)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_AZIM', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_AZIM;
GO

CREATE TABLE tsip_archive.ArchiveFE_AZIM (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    location     CHAR(10) NULL,
    az1          FLOAT NULL,                   -- Azimuth 1
    az2          FLOAT NULL,                   -- Azimuth 2
    el1          FLOAT NULL,                   -- Elevation 1
    el2          FLOAT NULL,                   -- Elevation 2
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_AZIM PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_AZIM_RunKey ON tsip_archive.ArchiveFE_AZIM (RunKey);
GO

-- Archive table for FE_ANTE
IF OBJECT_ID(N'tsip_archive.ArchiveFE_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveFE_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    band         CHAR(4) NULL,
    acodetx      CHAR(12) NULL,
    acoderx      CHAR(12) NULL,
    aht          FLOAT NULL,
    az           FLOAT NULL,
    el           FLOAT NULL,
    g_t          FLOAT NULL,
    satname      CHAR(16) NULL,
    satoper      CHAR(3) NULL,
    satlongit    INT NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_ANTE_RunKey ON tsip_archive.ArchiveFE_ANTE (RunKey);
GO

-- Archive table for FE_CHAN
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveFE_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    band         CHAR(4) NULL,
    chid         CHAR(4) NULL,
    freqtx       FLOAT NULL,
    freqrx       FLOAT NULL,
    pwrtx        FLOAT NULL,
    pwrrx        FLOAT NULL,
    eirp         FLOAT NULL,
    traftx       CHAR(6) NULL,
    trafrx       CHAR(6) NULL,
    eqpttx       CHAR(8) NULL,
    eqptrx       CHAR(8) NULL,
    stattx       CHAR(1) NULL,
    statrx       CHAR(1) NULL,
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CHAN_RunKey ON tsip_archive.ArchiveFE_CHAN (RunKey);
GO

-- Archive table for FE_CLOC (Location change history)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CLOC', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CLOC;
GO

CREATE TABLE tsip_archive.ArchiveFE_CLOC (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    oldlocation  CHAR(10) NULL,                -- Old location
    newlocation  CHAR(10) NULL,                -- New location
    chngdate     CHAR(10) NULL,                -- Change date
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CLOC PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CLOC_RunKey ON tsip_archive.ArchiveFE_CLOC (RunKey);
GO

-- Archive table for FE_CCAL (Call sign change history)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CCAL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CCAL;
GO

CREATE TABLE tsip_archive.ArchiveFE_CCAL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    location     CHAR(10) NULL,
    oldcall1     CHAR(9) NULL,                 -- Old call sign
    newcall1     CHAR(9) NULL,                 -- New call sign
    chngdate     CHAR(10) NULL,                -- Change date
    cmd          CHAR(1) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CCAL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CCAL_RunKey ON tsip_archive.ArchiveFE_CCAL (RunKey);
GO

PRINT 'Schema tsip_archive created with all archive tables:';
PRINT '';
PRINT 'TT (TSIP Results):';
PRINT '  - ArchiveTT_PARM, ArchiveTT_SITE, ArchiveTT_ANTE, ArchiveTT_CHAN';
PRINT '';
PRINT 'FT (TS Source - 6 tables captured at run completion):';
PRINT '  - ArchiveFT_TITL, ArchiveFT_SHRL, ArchiveFT_SITE, ArchiveFT_ANTE, ArchiveFT_CHAN, ArchiveFT_CHNG_CALL';
PRINT '';
PRINT 'FE (ES Source - 8 tables captured at run completion):';
PRINT '  - ArchiveFE_TITL, ArchiveFE_SHRL, ArchiveFE_SITE, ArchiveFE_AZIM, ArchiveFE_ANTE, ArchiveFE_CHAN, ArchiveFE_CLOC, ArchiveFE_CCAL';
GO
