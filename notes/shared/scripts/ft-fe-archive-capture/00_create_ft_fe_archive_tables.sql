-- =============================================================================
-- 00_create_ft_fe_archive_tables.sql
-- Creates archive tables for FT (Terrestrial Station) and FE (Earth Station)
-- PDF source data. These capture the input data used in TSIP runs.
-- 
-- NEW APPROACH: FT/FE source data is captured at TSIP run completion time
-- (when TT_PARM is dropped), not when the FT/FE tables are dropped. This
-- ensures we capture the exact source data used for each run.
-- 
-- Run this after the TT archive tables are created.
-- =============================================================================

USE [YourDatabase];  -- Change to your dev database (e.g. MicsMin, RemicsDev)
GO

-- Schema for archive tables (reuses tsip_archive from TT scripts)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'tsip_archive')
    EXEC('CREATE SCHEMA tsip_archive');
GO

-- =============================================================================
-- FT (Terrestrial Station) Archive Tables
-- Keyed by RunKey to link directly to the TSIP run that used this data
-- =============================================================================

-- Archive table for FT_SITE (one row per site in a PDF)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_SITE;
GO

CREATE TABLE tsip_archive.ArchiveFT_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,       -- TS PDF name (= proname in TT_PARM)
    -- Site identification
    call1        CHAR(9) NULL,                 -- Call sign 1 (primary)
    call2        CHAR(9) NULL,                 -- Call sign 2 (remote)
    name1        CHAR(32) NULL,                -- Site name 1
    name2        CHAR(32) NULL,                -- Site name 2
    oper         CHAR(6) NULL,                 -- Operator code
    oper2        CHAR(6) NULL,                 -- Operator code 2
    -- Location
    latit        INT NULL,                     -- Latitude (scaled integer)
    longit       INT NULL,                     -- Longitude (scaled integer)
    grnd         FLOAT NULL,                   -- Ground elevation (m)
    -- Status
    cmd          CHAR(1) NULL,                 -- Command flag (A=Add, D=Delete, etc.)
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_SITE_RunKey ON tsip_archive.ArchiveFT_SITE (RunKey);
GO

-- Archive table for FT_ANTE (antenna records for a PDF)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveFT_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,
    -- Antenna identification
    call1        CHAR(9) NULL,                 -- Call sign 1
    call2        CHAR(9) NULL,                 -- Call sign 2
    bndcde       CHAR(4) NULL,                 -- Band code
    anum         SMALLINT NULL,                -- Antenna number
    -- Antenna properties
    acode        CHAR(12) NULL,                -- Antenna code (references sd_ante)
    aht          FLOAT NULL,                   -- Antenna height (m)
    azmth        FLOAT NULL,                   -- Azimuth (degrees)
    elvtn        FLOAT NULL,                   -- Elevation (degrees)
    gain         FLOAT NULL,                   -- Antenna gain (dB)
    -- Link properties
    dist         FLOAT NULL,                   -- Distance (km)
    offazm       CHAR(1) NULL,                 -- Off-axis azimuth flag
    -- Status
    cmd          CHAR(1) NULL,                 -- Command flag
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_ANTE_RunKey ON tsip_archive.ArchiveFT_ANTE (RunKey);
GO

-- Archive table for FT_CHAN (channel records for a PDF)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveFT_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,
    -- Channel identification
    call1        CHAR(9) NULL,                 -- Call sign 1
    call2        CHAR(9) NULL,                 -- Call sign 2
    bndcde       CHAR(4) NULL,                 -- Band code
    chid         CHAR(4) NULL,                 -- Channel ID
    -- Frequencies
    freqtx       FLOAT NULL,                   -- Transmit frequency (MHz)
    freqrx       FLOAT NULL,                   -- Receive frequency (MHz)
    -- Power
    pwrtx        FLOAT NULL,                   -- TX power (dBW)
    pwrrx        FLOAT NULL,                   -- RX power (dBm)
    -- Traffic/Equipment
    traftx       CHAR(6) NULL,                 -- TX traffic code
    trafrx       CHAR(6) NULL,                 -- RX traffic code
    eqpttx       CHAR(8) NULL,                 -- TX equipment code
    eqptrx       CHAR(8) NULL,                 -- RX equipment code
    -- Status
    stattx       CHAR(1) NULL,                 -- TX status
    statrx       CHAR(1) NULL,                 -- RX status
    cmd          CHAR(1) NULL,                 -- Command flag
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_CHAN_RunKey ON tsip_archive.ArchiveFT_CHAN (RunKey);
GO

-- =============================================================================
-- FE (Earth Station) Archive Tables
-- Keyed by RunKey to link directly to the TSIP run that used this data
-- =============================================================================

-- Archive table for FE_SITE (one row per earth station location in a PDF)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_SITE;
GO

CREATE TABLE tsip_archive.ArchiveFE_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,       -- ES PDF name (= envname in TT_PARM)
    -- Site identification
    location     CHAR(10) NULL,                -- Earth station location code
    name         CHAR(16) NULL,                -- Earth station name
    oper         CHAR(6) NULL,                 -- Operator code
    -- Location
    latit        INT NULL,                     -- Latitude (scaled integer)
    longit       INT NULL,                     -- Longitude (scaled integer)
    grnd         FLOAT NULL,                   -- Ground elevation (m)
    -- Environment
    rainzone     SMALLINT NULL,                -- Rain zone
    radiozone    CHAR(2) NULL,                 -- Radio zone
    -- Status
    cmd          CHAR(1) NULL,                 -- Command flag
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_SITE_RunKey ON tsip_archive.ArchiveFE_SITE (RunKey);
GO

-- Archive table for FE_ANTE (earth station antenna records)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveFE_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,
    -- Antenna identification
    location     CHAR(10) NULL,                -- Earth station location
    call1        CHAR(9) NULL,                 -- Call sign
    band         CHAR(4) NULL,                 -- Band code
    -- Antenna properties
    acodetx      CHAR(12) NULL,                -- TX antenna code
    acoderx      CHAR(12) NULL,                -- RX antenna code
    aht          FLOAT NULL,                   -- Antenna height (m)
    az           FLOAT NULL,                   -- Azimuth (degrees)
    el           FLOAT NULL,                   -- Elevation (degrees)
    g_t          FLOAT NULL,                   -- G/T ratio (dB/K)
    -- Satellite
    satname      CHAR(16) NULL,                -- Satellite name
    satoper      CHAR(3) NULL,                 -- Satellite operator
    satlongit    INT NULL,                     -- Satellite longitude
    -- Status
    cmd          CHAR(1) NULL,                 -- Command flag
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_ANTE_RunKey ON tsip_archive.ArchiveFE_ANTE (RunKey);
GO

-- Archive table for FE_CHAN (earth station channel records)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveFE_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,       -- Links to ArchiveTT_PARM.RunKey
    PdfName      NVARCHAR(128) NOT NULL,
    -- Channel identification
    location     CHAR(10) NULL,                -- Earth station location
    call1        CHAR(9) NULL,                 -- Call sign
    band         CHAR(4) NULL,                 -- Band code
    chid         CHAR(4) NULL,                 -- Channel ID
    -- Frequencies
    freqtx       FLOAT NULL,                   -- Transmit frequency (MHz)
    freqrx       FLOAT NULL,                   -- Receive frequency (MHz)
    -- Power
    pwrtx        FLOAT NULL,                   -- TX power (dBW)
    pwrrx        FLOAT NULL,                   -- RX power (dBm)
    eirp         FLOAT NULL,                   -- EIRP (dBW)
    -- Traffic/Equipment
    traftx       CHAR(6) NULL,                 -- TX traffic code
    trafrx       CHAR(6) NULL,                 -- RX traffic code
    eqpttx       CHAR(8) NULL,                 -- TX equipment code
    eqptrx       CHAR(8) NULL,                 -- RX equipment code
    -- Status
    stattx       CHAR(1) NULL,                 -- TX status
    statrx       CHAR(1) NULL,                 -- RX status
    cmd          CHAR(1) NULL,                 -- Command flag
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CHAN_RunKey ON tsip_archive.ArchiveFE_CHAN (RunKey);
GO

PRINT 'FT and FE archive tables created in tsip_archive schema.';
PRINT '';
PRINT 'FT (Terrestrial Station) tables:';
PRINT '  - tsip_archive.ArchiveFT_SITE';
PRINT '  - tsip_archive.ArchiveFT_ANTE';
PRINT '  - tsip_archive.ArchiveFT_CHAN';
PRINT '';
PRINT 'FE (Earth Station) tables:';
PRINT '  - tsip_archive.ArchiveFE_SITE';
PRINT '  - tsip_archive.ArchiveFE_ANTE';
PRINT '  - tsip_archive.ArchiveFE_CHAN';
GO
