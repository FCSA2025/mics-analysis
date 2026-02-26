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
-- UPDATED: Column structures verified against micsprod (Feb 2026)
-- =============================================================================

-- FT_TITL - Title/metadata (6 columns)
CREATE TABLE dbo.ft_testproj_titl (
    validated    CHAR(1) NULL,
    namef        CHAR(16) NULL,
    source       CHAR(6) NULL,
    descr        CHAR(40) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.ft_testproj_titl (validated, namef, source, descr, mdate, mtime)
VALUES 
    ('Y', 'testproj        ', 'ISED  ', 'Test Project - Denver/Boulder Links     ', '2025-06-01', '14:30:00');
GO

-- FT_SHRL - Shared link approvals (3 columns)
CREATE TABLE dbo.ft_testproj_shrl (
    userid       CHAR(8) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.ft_testproj_shrl (userid, mdate, mtime)
VALUES 
    ('TESTUSER', '2025-06-01', '14:30:00');
GO

-- FT_SITE - Site catalog (29 columns)
CREATE TABLE dbo.ft_testproj_site (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    call1        CHAR(9) NOT NULL,
    name         CHAR(32) NULL,
    prov         CHAR(2) NULL,
    oper         CHAR(6) NULL,
    latit        INT NULL,
    longit       INT NULL,
    grnd         FLOAT NULL,
    stats        CHAR(2) NULL,
    sdate        CHAR(10) NULL,
    loc          CHAR(40) NULL,
    icaccount    CHAR(10) NULL,
    reg          CHAR(1) NULL,
    spoint       CHAR(4) NULL,
    nots         CHAR(60) NULL,
    oprtyp       CHAR(1) NULL,
    snumb        CHAR(8) NULL,
    notwr        CHAR(40) NULL,
    bandwd1      CHAR(6) NULL,
    bandwd2      CHAR(6) NULL,
    bandwd3      CHAR(6) NULL,
    bandwd4      CHAR(6) NULL,
    bandwd5      CHAR(6) NULL,
    bandwd6      CHAR(6) NULL,
    bandwd7      CHAR(6) NULL,
    bandwd8      CHAR(6) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    CONSTRAINT PK_ft_testproj_site PRIMARY KEY (call1)
);
GO

INSERT INTO dbo.ft_testproj_site (cmd, recstat, call1, name, prov, oper, latit, longit, grnd, stats, mdate, mtime)
VALUES 
    ('A', 'A', 'CALL001  ', 'Denver Main                     ', 'CO', 'OP01  ', 394000000, -1049000000, 1609.0, 'OP', '2025-06-01', '14:30:00'),
    ('A', 'A', 'CALL002  ', 'Boulder Site                    ', 'CO', 'OP02  ', 400150000, -1052200000, 1655.0, 'OP', '2025-06-01', '14:30:00'),
    ('A', 'A', 'REM001   ', 'Denver Remote                   ', 'CO', 'OP01  ', 394500000, -1048500000, 1620.0, 'OP', '2025-06-01', '14:30:00'),
    ('A', 'A', 'REM002   ', 'Boulder Remote                  ', 'CO', 'OP02  ', 400250000, -1051800000, 1670.0, 'OP', '2025-06-01', '14:30:00');
GO

-- FT_ANTE - Antenna (37 columns)
CREATE TABLE dbo.ft_testproj_ante (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    call1        CHAR(9) NOT NULL,
    call2        CHAR(9) NOT NULL,
    bndcde       CHAR(4) NOT NULL,
    anum         SMALLINT NOT NULL,
    ause         CHAR(3) NULL,
    acode        CHAR(12) NULL,
    aht          REAL NULL,
    azmth        REAL NULL,
    elvtn        REAL NULL,
    dist         REAL NULL,
    offazm       CHAR(1) NULL,
    tazmth       REAL NULL,
    telvtn       REAL NULL,
    tgain        REAL NULL,
    txfdlnth     CHAR(2) NULL,
    txfdlnlh     REAL NULL,
    txfdlntv     CHAR(2) NULL,
    txfdlnlv     REAL NULL,
    rxfdlnth     CHAR(2) NULL,
    rxfdlnlh     REAL NULL,
    rxfdlntv     CHAR(2) NULL,
    rxfdlnlv     REAL NULL,
    txpadpam     REAL NULL,
    rxpadlna     REAL NULL,
    txcompl      REAL NULL,
    rxcompl      REAL NULL,
    obsloss      REAL NULL,
    kvalue       REAL NULL,
    atwrno       TINYINT NULL,
    nota         CHAR(4) NULL,
    apoint       CHAR(4) NULL,
    sdate        CHAR(10) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    licence      CHAR(13) NULL,
    CONSTRAINT PK_ft_testproj_ante PRIMARY KEY (call1, call2, bndcde, anum)
);
GO

INSERT INTO dbo.ft_testproj_ante (cmd, recstat, call1, call2, bndcde, anum, acode, aht, azmth, tgain, mdate, mtime)
VALUES 
    ('A', 'A', 'CALL001  ', 'REM001   ', '6GH ', 1, 'ANT6G-STD   ', 30.0, 45.5, 38.5, '2025-06-01', '14:30:00'),
    ('A', 'A', 'CALL002  ', 'REM002   ', '11G ', 1, 'ANT11G-STD  ', 25.0, 120.0, 40.0, '2025-06-01', '14:30:00');
GO

-- FT_CHAN - Channel (52 columns)
CREATE TABLE dbo.ft_testproj_chan (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    call1        CHAR(9) NOT NULL,
    call2        CHAR(9) NOT NULL,
    bndcde       CHAR(4) NOT NULL,
    splan        CHAR(4) NULL,
    hl           TINYINT NULL,
    vh           TINYINT NULL,
    chid         CHAR(4) NOT NULL,
    freqtx       FLOAT NULL,
    poltx        CHAR(1) NULL,
    antnumbtx1   TINYINT NULL,
    antnumbtx2   TINYINT NULL,
    eqpttx       CHAR(8) NULL,
    eqptutx      CHAR(1) NULL,
    pwrtx        REAL NULL,
    atpccde      REAL NULL,
    afsltx1      REAL NULL,
    afsltx2      REAL NULL,
    traftx       CHAR(6) NULL,
    srvctx       CHAR(6) NULL,
    stattx       CHAR(1) NULL,
    freqrx       FLOAT NULL,
    polrx        CHAR(1) NULL,
    antnumbrx1   TINYINT NULL,
    antnumbrx2   TINYINT NULL,
    antnumbrx3   TINYINT NULL,
    eqptrx       CHAR(8) NULL,
    eqpturx      CHAR(1) NULL,
    afslrx1      REAL NULL,
    afslrx2      REAL NULL,
    afslrx3      REAL NULL,
    pwrrx1       REAL NULL,
    pwrrx2       REAL NULL,
    pwrrx3       REAL NULL,
    trafrx       CHAR(6) NULL,
    esint        REAL NULL,
    tsint        REAL NULL,
    srvcrx       CHAR(6) NULL,
    statrx       CHAR(1) NULL,
    routnumb     CHAR(8) NULL,
    stnnumb      TINYINT NULL,
    hopnumb      TINYINT NULL,
    sdate        CHAR(10) NULL,
    notetx       CHAR(4) NULL,
    noterx       CHAR(4) NULL,
    notegnl      CHAR(4) NULL,
    cpoint       CHAR(4) NULL,
    feetx        CHAR(2) NULL,
    feerx        CHAR(2) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    CONSTRAINT PK_ft_testproj_chan PRIMARY KEY (call1, call2, bndcde, chid)
);
GO

INSERT INTO dbo.ft_testproj_chan (cmd, recstat, call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, mdate, mtime)
VALUES 
    ('A', 'A', 'CALL001  ', 'REM001   ', '6GH ', '01  ', 6175.24, 6004.50, 30.0, 'T64QAM', 'R64QAM', 'EQ6G-01 ', 'EQ6G-01 ', 'O', 'O', '2025-06-01', '14:30:00'),
    ('A', 'A', 'CALL002  ', 'REM002   ', '11G ', '01  ', 11245.00, 10945.00, 25.0, 'T256Q ', 'R256Q ', 'EQ11G-02', 'EQ11G-02', 'O', 'O', '2025-06-01', '14:30:00');
GO

-- FT_CHNG_CALL - Call sign change history (3 columns)
CREATE TABLE dbo.ft_testproj_chng_call (
    newcall1     CHAR(9) NOT NULL,
    oldcall1     CHAR(9) NOT NULL,
    name         CHAR(32) NULL,
    CONSTRAINT PK_ft_testproj_chng_call PRIMARY KEY (newcall1, oldcall1)
);
GO

INSERT INTO dbo.ft_testproj_chng_call (newcall1, oldcall1, name)
VALUES 
    ('CALL001  ', 'OLDCAL01 ', 'Denver Main Call Sign Change    ');
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
