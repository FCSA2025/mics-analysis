-- =============================================================================
-- 01_create_sample_tt_tables.sql
-- Creates sample TT-like tables (parm, site, ante, chan) and inserts sample data.
-- Also creates matching FT (TS) and FE (ES) source tables to test the enhanced
-- trigger that captures source data at run completion.
-- Run after 00, before creating the trigger.
-- =============================================================================

USE [YourDatabase];  -- Change to your dev database
GO

-- =============================================================================
-- Drop existing test tables if they exist
-- =============================================================================

-- TT tables
IF OBJECT_ID(N'dbo.tt_test_run01_parm', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_parm;
IF OBJECT_ID(N'dbo.tt_test_run01_site', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_site;
IF OBJECT_ID(N'dbo.tt_test_run01_ante', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_ante;
IF OBJECT_ID(N'dbo.tt_test_run01_chan', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_chan;

-- FT tables (TS source - proname = 'testproj')
-- Full set: TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
IF OBJECT_ID(N'dbo.ft_testproj_titl', N'U') IS NOT NULL
    DROP TABLE dbo.ft_testproj_titl;
IF OBJECT_ID(N'dbo.ft_testproj_shrl', N'U') IS NOT NULL
    DROP TABLE dbo.ft_testproj_shrl;
IF OBJECT_ID(N'dbo.ft_testproj_site', N'U') IS NOT NULL
    DROP TABLE dbo.ft_testproj_site;
IF OBJECT_ID(N'dbo.ft_testproj_ante', N'U') IS NOT NULL
    DROP TABLE dbo.ft_testproj_ante;
IF OBJECT_ID(N'dbo.ft_testproj_chan', N'U') IS NOT NULL
    DROP TABLE dbo.ft_testproj_chan;
IF OBJECT_ID(N'dbo.ft_testproj_chng_call', N'U') IS NOT NULL
    DROP TABLE dbo.ft_testproj_chng_call;

-- FE tables (ES source - envname = 'envproj')
-- Full set: TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
IF OBJECT_ID(N'dbo.fe_envproj_titl', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_titl;
IF OBJECT_ID(N'dbo.fe_envproj_shrl', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_shrl;
IF OBJECT_ID(N'dbo.fe_envproj_site', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_site;
IF OBJECT_ID(N'dbo.fe_envproj_azim', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_azim;
IF OBJECT_ID(N'dbo.fe_envproj_ante', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_ante;
IF OBJECT_ID(N'dbo.fe_envproj_chan', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_chan;
IF OBJECT_ID(N'dbo.fe_envproj_cloc', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_cloc;
IF OBJECT_ID(N'dbo.fe_envproj_ccal', N'U') IS NOT NULL
    DROP TABLE dbo.fe_envproj_ccal;
GO

-- Minimal TT_PARM-like table (proname = TS file, envname = ES file per production TT_PARM)
CREATE TABLE dbo.tt_test_run01_parm (
    proname   CHAR(16) NULL,   -- TS (Terrestrial Station) file/PDF name
    envname   CHAR(16) NULL,   -- ES (Earth Station) file/PDF name
    runname   CHAR(5) NULL,
    numcases  INT NULL
);
GO

-- Minimal TT_SITE-like table
CREATE TABLE dbo.tt_test_run01_site (
    intcall1  CHAR(9) NULL,
    viccall1  CHAR(9) NULL,
    caseno    INT NULL
);
GO

-- Minimal TT_ANTE-like table (subset of columns for testing)
CREATE TABLE dbo.tt_test_run01_ante (
    intcall1  CHAR(9) NULL,
    viccall1  CHAR(9) NULL,
    caseno    INT NULL,
    intacode  CHAR(12) NULL,
    vicacode  CHAR(12) NULL
);
GO

-- Minimal TT_CHAN-like table (subset of columns for testing)
CREATE TABLE dbo.tt_test_run01_chan (
    intcall1  CHAR(9) NULL,
    viccall1  CHAR(9) NULL,
    caseno    INT NULL,
    resti     FLOAT NULL,
    freqsep   FLOAT NULL
);
GO

INSERT INTO dbo.tt_test_run01_parm (proname, envname, runname, numcases)
VALUES ('testproj', 'envproj', 'run01', 42);
GO

INSERT INTO dbo.tt_test_run01_site (intcall1, viccall1, caseno)
VALUES
    ('CALL001', 'VIC001', 1),
    ('CALL002', 'VIC002', 2),
    ('CALL003', 'VIC003', 3);
GO

INSERT INTO dbo.tt_test_run01_ante (intcall1, viccall1, caseno, intacode, vicacode)
VALUES
    ('CALL001', 'VIC001', 1, 'ANT001', 'VANT001'),
    ('CALL002', 'VIC002', 2, 'ANT002', 'VANT002'),
    ('CALL003', 'VIC003', 3, 'ANT003', 'VANT003');
GO

INSERT INTO dbo.tt_test_run01_chan (intcall1, viccall1, caseno, resti, freqsep)
VALUES
    ('CALL001', 'VIC001', 1, 12.5, 0.1),
    ('CALL002', 'VIC002', 2, -2.0, 0.2),
    ('CALL003', 'VIC003', 3, 8.0, 0.15);
GO

-- =============================================================================
-- FT (Terrestrial Station) SOURCE TABLES - proname = 'testproj'
-- These represent the TS PDF data used as input to the TSIP run
-- Full set: TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
-- =============================================================================

-- FT_TITL - Title/metadata
CREATE TABLE dbo.ft_testproj_titl (
    title        CHAR(80) NULL,
    cdate        CHAR(10) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_testproj_titl (title, cdate, mdate, mtime, cmd)
VALUES 
    ('Test Project TS File - Denver/Boulder Microwave Links                      ', '2025-01-15', '2025-06-01', '14:30:00', 'A');
GO

-- FT_SHRL - Shared link approvals
CREATE TABLE dbo.ft_testproj_shrl (
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    bndcde       CHAR(4) NULL,
    shession     CHAR(10) NULL,
    approval     CHAR(1) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_testproj_shrl (call1, call2, bndcde, shession, approval, cmd)
VALUES 
    ('CALL001  ', 'REM001   ', '6GH ', 'SH-2025-01', 'Y', 'A'),
    ('CALL002  ', 'REM002   ', '11G ', 'SH-2025-02', 'P', 'A');
GO

-- FT_SITE - Site catalog (single physical location per row)
-- Note: call2 is NOT in FT_SITE - it's in FT_ANTE and FT_CHAN which define links
CREATE TABLE dbo.ft_testproj_site (
    call1        CHAR(9) NULL,     -- Site's call sign
    name1        CHAR(32) NULL,    -- Site's name
    oper         CHAR(6) NULL,     -- Site's operator
    latit        INT NULL,
    longit       INT NULL,
    grnd         FLOAT NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_testproj_site (call1, name1, oper, latit, longit, grnd, cmd)
VALUES 
    ('CALL001  ', 'Denver Main             ', 'OP01  ', 394000000, -1049000000, 1609.0, 'A'),
    ('CALL002  ', 'Boulder Site            ', 'OP02  ', 400150000, -1052200000, 1655.0, 'A'),
    ('REM001   ', 'Denver Remote           ', 'OP01  ', 394500000, -1048500000, 1620.0, 'A'),
    ('REM002   ', 'Boulder Remote          ', 'OP02  ', 400250000, -1051800000, 1670.0, 'A');
GO

CREATE TABLE dbo.ft_testproj_ante (
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
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_testproj_ante (call1, call2, bndcde, anum, acode, aht, azmth, gain, cmd)
VALUES 
    ('CALL001  ', 'REM001   ', '6GH ', 1, 'ANT6G-STD   ', 30.0, 45.5, 38.5, 'A'),
    ('CALL002  ', 'REM002   ', '11G ', 1, 'ANT11G-STD  ', 25.0, 120.0, 40.0, 'A');
GO

CREATE TABLE dbo.ft_testproj_chan (
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
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_testproj_chan (call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, traftx, trafrx, eqpttx, eqptrx, cmd)
VALUES 
    ('CALL001  ', 'REM001   ', '6GH ', '01  ', 6175.24, 6004.50, 30.0, 'T64QAM', 'R64QAM', 'EQ6G-01 ', 'EQ6G-01 ', 'A'),
    ('CALL002  ', 'REM002   ', '11G ', '01  ', 11245.00, 10945.00, 25.0, 'T256Q ', 'R256Q ', 'EQ11G-02', 'EQ11G-02', 'A');
GO

-- FT_CHNG_CALL - Call sign change history
CREATE TABLE dbo.ft_testproj_chng_call (
    oldcall1     CHAR(9) NULL,
    oldcall2     CHAR(9) NULL,
    newcall1     CHAR(9) NULL,
    newcall2     CHAR(9) NULL,
    chngdate     CHAR(10) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_testproj_chng_call (oldcall1, oldcall2, newcall1, newcall2, chngdate, cmd)
VALUES 
    ('OLDCAL01 ', 'OLDREM01 ', 'CALL001  ', 'REM001   ', '2024-12-01', 'A');
GO

-- =============================================================================
-- FE (Earth Station) SOURCE TABLES - envname = 'envproj'
-- These represent the ES PDF data used as input to the TSIP run
-- Full set: TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
-- =============================================================================

-- FE_TITL - Title/metadata
CREATE TABLE dbo.fe_envproj_titl (
    title        CHAR(80) NULL,
    cdate        CHAR(10) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_titl (title, cdate, mdate, mtime, cmd)
VALUES 
    ('Environment Project ES File - Satellite Earth Stations                     ', '2025-02-01', '2025-05-15', '09:45:00', 'A');
GO

-- FE_SHRL - Shared link approvals
CREATE TABLE dbo.fe_envproj_shrl (
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    shession     CHAR(10) NULL,
    approval     CHAR(1) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_shrl (location, call1, shession, approval, cmd)
VALUES 
    ('ES-DEN-001', 'E12345678', 'SH-2025-ES', 'Y', 'A');
GO

-- FE_SITE - Site information
CREATE TABLE dbo.fe_envproj_site (
    location     CHAR(10) NULL,
    name         CHAR(16) NULL,
    oper         CHAR(6) NULL,
    latit        INT NULL,
    longit       INT NULL,
    grnd         FLOAT NULL,
    rainzone     SMALLINT NULL,
    radiozone    CHAR(2) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_site (location, name, oper, latit, longit, grnd, rainzone, radiozone, cmd)
VALUES 
    ('ES-DEN-001', 'Denver ES Hub   ', 'SATOP1', 394500000, -1048500000, 1620.0, 3, 'K ', 'A'),
    ('ES-LAX-001', 'Los Angeles ES  ', 'SATOP2', 340000000, -1183000000, 71.0, 2, 'E ', 'A');
GO

-- FE_AZIM - Azimuth records
CREATE TABLE dbo.fe_envproj_azim (
    location     CHAR(10) NULL,
    az1          FLOAT NULL,
    az2          FLOAT NULL,
    el1          FLOAT NULL,
    el2          FLOAT NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_azim (location, az1, az2, el1, el2, cmd)
VALUES 
    ('ES-DEN-001', 200.0, 220.0, 30.0, 40.0, 'A'),
    ('ES-LAX-001', 170.0, 190.0, 38.0, 46.0, 'A');
GO

-- FE_ANTE - Antenna information
CREATE TABLE dbo.fe_envproj_ante (
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
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_ante (location, call1, band, acodetx, acoderx, aht, az, el, g_t, satname, satoper, satlongit, cmd)
VALUES 
    ('ES-DEN-001', 'E12345678', 'C   ', 'ES-ANT-4.5M ', 'ES-ANT-4.5M ', 5.0, 210.5, 35.2, 28.5, 'GALAXY-19       ', 'INL', -970000000, 'A'),
    ('ES-LAX-001', 'E23456789', 'KU  ', 'ES-ANT-3.0M ', 'ES-ANT-3.0M ', 3.0, 180.0, 42.1, 32.0, 'SES-3           ', 'SES', -1030000000, 'A');
GO

CREATE TABLE dbo.fe_envproj_chan (
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
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_chan (location, call1, band, chid, freqtx, freqrx, pwrtx, eirp, traftx, trafrx, eqpttx, eqptrx, cmd)
VALUES 
    ('ES-DEN-001', 'E12345678', 'C   ', '01  ', 6125.00, 3900.00, 15.0, 52.0, 'SCPC  ', 'SCPC  ', 'EQSAT-01', 'EQSAT-01', 'A'),
    ('ES-LAX-001', 'E23456789', 'KU  ', '01  ', 14250.00, 11950.00, 10.0, 48.0, 'VSAT  ', 'VSAT  ', 'EQSAT-02', 'EQSAT-02', 'A');
GO

-- FE_CLOC - Location change history
CREATE TABLE dbo.fe_envproj_cloc (
    oldlocation  CHAR(10) NULL,
    newlocation  CHAR(10) NULL,
    chngdate     CHAR(10) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_cloc (oldlocation, newlocation, chngdate, cmd)
VALUES 
    ('ES-OLD-001', 'ES-DEN-001', '2024-06-15', 'A');
GO

-- FE_CCAL - Call sign change history
CREATE TABLE dbo.fe_envproj_ccal (
    location     CHAR(10) NULL,
    oldcall1     CHAR(9) NULL,
    newcall1     CHAR(9) NULL,
    chngdate     CHAR(10) NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.fe_envproj_ccal (location, oldcall1, newcall1, chngdate, cmd)
VALUES 
    ('ES-DEN-001', 'E00000001', 'E12345678', '2024-08-01', 'A');
GO

-- =============================================================================
-- Summary
-- =============================================================================

PRINT 'Sample tables created and populated:';
PRINT '';
PRINT 'TT (TSIP Results):';
PRINT '  - dbo.tt_test_run01_parm (proname=testproj, envname=envproj)';
PRINT '  - dbo.tt_test_run01_site (3 rows)';
PRINT '  - dbo.tt_test_run01_ante (3 rows)';
PRINT '  - dbo.tt_test_run01_chan (3 rows)';
PRINT '';
PRINT 'FT (TS Source - testproj, 6 tables):';
PRINT '  - dbo.ft_testproj_titl (1 row)';
PRINT '  - dbo.ft_testproj_shrl (2 rows)';
PRINT '  - dbo.ft_testproj_site (2 rows)';
PRINT '  - dbo.ft_testproj_ante (2 rows)';
PRINT '  - dbo.ft_testproj_chan (2 rows)';
PRINT '  - dbo.ft_testproj_chng_call (1 row)';
PRINT '';
PRINT 'FE (ES Source - envproj, 8 tables):';
PRINT '  - dbo.fe_envproj_titl (1 row)';
PRINT '  - dbo.fe_envproj_shrl (1 row)';
PRINT '  - dbo.fe_envproj_site (2 rows)';
PRINT '  - dbo.fe_envproj_azim (2 rows)';
PRINT '  - dbo.fe_envproj_ante (2 rows)';
PRINT '  - dbo.fe_envproj_chan (2 rows)';
PRINT '  - dbo.fe_envproj_cloc (1 row)';
PRINT '  - dbo.fe_envproj_ccal (1 row)';
GO

SELECT 'TT_PARM' AS TableType, * FROM dbo.tt_test_run01_parm;
GO
