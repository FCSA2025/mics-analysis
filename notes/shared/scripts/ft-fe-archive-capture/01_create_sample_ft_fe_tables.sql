-- =============================================================================
-- 01_create_sample_ft_fe_tables.sql
-- Creates sample FT (Terrestrial Station) and FE (Earth Station) PDF tables
-- with test data for verifying the archive capture trigger.
-- =============================================================================

USE [YourDatabase];  -- Same database as 00
GO

-- =============================================================================
-- Sample FT (Terrestrial Station) Tables - PDF name: "test_ts_pdf"
-- =============================================================================

-- FT_SITE - Sample terrestrial station sites
IF OBJECT_ID(N'dbo.ft_test_ts_pdf_site', N'U') IS NOT NULL
    DROP TABLE dbo.ft_test_ts_pdf_site;
GO

CREATE TABLE dbo.ft_test_ts_pdf_site (
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    name1        CHAR(32) NULL,
    name2        CHAR(32) NULL,
    oper         CHAR(6) NULL,
    oper2        CHAR(6) NULL,
    latit        INT NULL,
    longit       INT NULL,
    grnd         FLOAT NULL,
    cmd          CHAR(1) NULL
);
GO

INSERT INTO dbo.ft_test_ts_pdf_site (call1, call2, name1, name2, oper, latit, longit, grnd, cmd)
VALUES 
    ('KABC123  ', 'KXYZ789  ', 'Denver Main Site        ', 'Denver Remote Site      ', 'OPER01', 394000000, -1049000000, 1609.0, 'A'),
    ('KDEF456  ', 'KGHI012  ', 'Boulder Site            ', 'Boulder Remote          ', 'OPER02', 400150000, -1052200000, 1655.0, 'A'),
    ('KJKL345  ', 'KMNO678  ', 'Colorado Springs        ', 'CS Remote               ', 'OPER01', 388330000, -1047900000, 1839.0, 'A');
GO

-- FT_ANTE - Sample terrestrial station antennas
IF OBJECT_ID(N'dbo.ft_test_ts_pdf_ante', N'U') IS NOT NULL
    DROP TABLE dbo.ft_test_ts_pdf_ante;
GO

CREATE TABLE dbo.ft_test_ts_pdf_ante (
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

INSERT INTO dbo.ft_test_ts_pdf_ante (call1, call2, bndcde, anum, acode, aht, azmth, elvtn, gain, dist, cmd)
VALUES 
    ('KABC123  ', 'KXYZ789  ', '6GH ', 1, 'ANT6G-STD   ', 30.0, 45.5, 0.5, 38.5, 25.3, 'A'),
    ('KABC123  ', 'KXYZ789  ', '6GH ', 2, 'ANT6G-HP    ', 35.0, 45.5, 0.5, 42.0, 25.3, 'A'),
    ('KDEF456  ', 'KGHI012  ', '11G ', 1, 'ANT11G-STD  ', 25.0, 120.0, 1.0, 40.0, 18.7, 'A'),
    ('KJKL345  ', 'KMNO678  ', '6GH ', 1, 'ANT6G-STD   ', 40.0, 270.0, -0.5, 38.5, 32.1, 'A');
GO

-- FT_CHAN - Sample terrestrial station channels
IF OBJECT_ID(N'dbo.ft_test_ts_pdf_chan', N'U') IS NOT NULL
    DROP TABLE dbo.ft_test_ts_pdf_chan;
GO

CREATE TABLE dbo.ft_test_ts_pdf_chan (
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

INSERT INTO dbo.ft_test_ts_pdf_chan (call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd)
VALUES 
    ('KABC123  ', 'KXYZ789  ', '6GH ', '01  ', 6175.24, 6004.50, 30.0, 'T64QAM', 'R64QAM', 'EQ6G-01 ', 'EQ6G-01 ', 'A', 'A', 'A'),
    ('KABC123  ', 'KXYZ789  ', '6GH ', '02  ', 6205.24, 6034.50, 30.0, 'T64QAM', 'R64QAM', 'EQ6G-01 ', 'EQ6G-01 ', 'A', 'A', 'A'),
    ('KDEF456  ', 'KGHI012  ', '11G ', '01  ', 11245.00, 10945.00, 25.0, 'T256Q ', 'R256Q ', 'EQ11G-02', 'EQ11G-02', 'A', 'A', 'A'),
    ('KJKL345  ', 'KMNO678  ', '6GH ', '01  ', 6525.00, 6355.00, 32.0, 'T64QAM', 'R64QAM', 'EQ6G-03 ', 'EQ6G-03 ', 'A', 'A', 'A');
GO

-- =============================================================================
-- Sample FE (Earth Station) Tables - PDF name: "test_es_pdf"
-- =============================================================================

-- FE_SITE - Sample earth station sites
IF OBJECT_ID(N'dbo.fe_test_es_pdf_site', N'U') IS NOT NULL
    DROP TABLE dbo.fe_test_es_pdf_site;
GO

CREATE TABLE dbo.fe_test_es_pdf_site (
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

INSERT INTO dbo.fe_test_es_pdf_site (location, name, oper, latit, longit, grnd, rainzone, radiozone, cmd)
VALUES 
    ('ES-DEN-001', 'Denver ES Hub   ', 'SATOP1', 394500000, -1048500000, 1620.0, 3, 'K ', 'A'),
    ('ES-LAX-001', 'Los Angeles ES  ', 'SATOP2', 340000000, -1183000000, 71.0, 2, 'E ', 'A'),
    ('ES-NYC-001', 'New York ES     ', 'SATOP1', 407500000, -740000000, 10.0, 4, 'K ', 'A');
GO

-- FE_ANTE - Sample earth station antennas
IF OBJECT_ID(N'dbo.fe_test_es_pdf_ante', N'U') IS NOT NULL
    DROP TABLE dbo.fe_test_es_pdf_ante;
GO

CREATE TABLE dbo.fe_test_es_pdf_ante (
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

INSERT INTO dbo.fe_test_es_pdf_ante (location, call1, band, acodetx, acoderx, aht, az, el, g_t, satname, satoper, satlongit, cmd)
VALUES 
    ('ES-DEN-001', 'E12345678', 'C   ', 'ES-ANT-4.5M ', 'ES-ANT-4.5M ', 5.0, 210.5, 35.2, 28.5, 'GALAXY-19       ', 'INL', -970000000, 'A'),
    ('ES-LAX-001', 'E23456789', 'KU  ', 'ES-ANT-3.0M ', 'ES-ANT-3.0M ', 3.0, 180.0, 42.1, 32.0, 'SES-3           ', 'SES', -1030000000, 'A'),
    ('ES-NYC-001', 'E34567890', 'C   ', 'ES-ANT-6.1M ', 'ES-ANT-6.1M ', 8.0, 225.0, 28.5, 35.2, 'GALAXY-19       ', 'INL', -970000000, 'A');
GO

-- FE_CHAN - Sample earth station channels
IF OBJECT_ID(N'dbo.fe_test_es_pdf_chan', N'U') IS NOT NULL
    DROP TABLE dbo.fe_test_es_pdf_chan;
GO

CREATE TABLE dbo.fe_test_es_pdf_chan (
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

INSERT INTO dbo.fe_test_es_pdf_chan (location, call1, band, chid, freqtx, freqrx, pwrtx, eirp, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, cmd)
VALUES 
    ('ES-DEN-001', 'E12345678', 'C   ', '01  ', 6125.00, 3900.00, 15.0, 52.0, 'SCPC  ', 'SCPC  ', 'EQSAT-01', 'EQSAT-01', 'A', 'A', 'A'),
    ('ES-DEN-001', 'E12345678', 'C   ', '02  ', 6145.00, 3920.00, 15.0, 52.0, 'SCPC  ', 'SCPC  ', 'EQSAT-01', 'EQSAT-01', 'A', 'A', 'A'),
    ('ES-LAX-001', 'E23456789', 'KU  ', '01  ', 14250.00, 11950.00, 10.0, 48.0, 'VSAT  ', 'VSAT  ', 'EQSAT-02', 'EQSAT-02', 'A', 'A', 'A'),
    ('ES-NYC-001', 'E34567890', 'C   ', '01  ', 6175.00, 3950.00, 18.0, 58.0, 'TDMA  ', 'TDMA  ', 'EQSAT-03', 'EQSAT-03', 'A', 'A', 'A');
GO

PRINT 'Sample FT and FE tables created with test data.';
PRINT '';
PRINT 'FT (Terrestrial Station) sample tables:';
PRINT '  - dbo.ft_test_ts_pdf_site (3 rows)';
PRINT '  - dbo.ft_test_ts_pdf_ante (4 rows)';
PRINT '  - dbo.ft_test_ts_pdf_chan (4 rows)';
PRINT '';
PRINT 'FE (Earth Station) sample tables:';
PRINT '  - dbo.fe_test_es_pdf_site (3 rows)';
PRINT '  - dbo.fe_test_es_pdf_ante (3 rows)';
PRINT '  - dbo.fe_test_es_pdf_chan (4 rows)';
GO
