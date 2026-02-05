-- =============================================================================
-- 01_create_sample_tt_tables.sql
-- Creates sample TT-like tables (parm, site, ante, chan) and inserts sample data.
-- Run after 00, before creating the trigger.
-- =============================================================================

USE [YourDatabase];  -- Change to your dev database
GO

-- Drop if they exist from a previous test run (trigger may not exist yet)
IF OBJECT_ID(N'dbo.tt_test_run01_parm', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_parm;
IF OBJECT_ID(N'dbo.tt_test_run01_site', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_site;
IF OBJECT_ID(N'dbo.tt_test_run01_ante', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_ante;
IF OBJECT_ID(N'dbo.tt_test_run01_chan', N'U') IS NOT NULL
    DROP TABLE dbo.tt_test_run01_chan;
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

PRINT 'Sample TT tables (parm, site, ante, chan) created and populated.';
SELECT * FROM dbo.tt_test_run01_parm;
SELECT * FROM dbo.tt_test_run01_site;
SELECT * FROM dbo.tt_test_run01_ante;
SELECT * FROM dbo.tt_test_run01_chan;
GO
