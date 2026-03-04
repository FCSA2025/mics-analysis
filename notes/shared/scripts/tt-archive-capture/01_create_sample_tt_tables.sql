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

-- TT_PARM table (27 columns - verified from micsprod)
CREATE TABLE dbo.tt_test_run01_parm (
    protype      CHAR(1) NULL,
    envtype      CHAR(8) NULL,
    proname      CHAR(16) NULL,      -- TS (Terrestrial Station) file/PDF name
    envname      CHAR(16) NULL,      -- ES (Earth Station) file/PDF name
    tsorbout     CHAR(1) NULL,
    spherecalc   CHAR(1) NULL,
    fsep         FLOAT NULL,
    coordist     FLOAT NULL,
    analopt      CHAR(4) NULL,
    margin       FLOAT NULL,
    numchan      SMALLINT NULL,
    chancodes    CHAR(19) NULL,
    tempant      CHAR(15) NULL,
    tempctx      CHAR(15) NULL,
    tempplan     CHAR(15) NULL,
    tempequip    CHAR(15) NULL,
    country      CHAR(3) NULL,
    selsites     CHAR(15) NULL,
    numcodes     SMALLINT NULL,
    codes        CHAR(164) NULL,
    runname      CHAR(5) NULL,
    reports      INT NULL,
    numcases     INT NULL,
    numtecases   INT NULL,
    parmparm     CHAR(50) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

-- TT_SITE table (31 columns - verified from micsprod)
CREATE TABLE dbo.tt_test_run01_site (
    interferer   CHAR(1) NULL,
    intcall1     CHAR(9) NULL,
    intcall2     CHAR(9) NULL,
    viccall1     CHAR(9) NULL,
    viccall2     CHAR(9) NULL,
    caseno       INT NULL,
    subcases     INT NULL,
    intname1     CHAR(32) NULL,
    intname2     CHAR(32) NULL,
    vicname1     CHAR(32) NULL,
    vicname2     CHAR(32) NULL,
    intoper      CHAR(6) NULL,
    intoper2     CHAR(6) NULL,
    vicoper      CHAR(6) NULL,
    vicoper2     CHAR(6) NULL,
    intlatit     INT NULL,
    intlongit    INT NULL,
    intgrnd      FLOAT NULL,
    viclatit     INT NULL,
    viclongit    INT NULL,
    vicgrnd      FLOAT NULL,
    report       SMALLINT NULL,
    int1int2dist FLOAT NULL,
    vic1vic2dist FLOAT NULL,
    int1vic1dist FLOAT NULL,
    distadv      FLOAT NULL,
    intoffax     FLOAT NULL,
    vicoffax     FLOAT NULL,
    intvicaz     FLOAT NULL,
    vicintaz     FLOAT NULL,
    processed    INT NULL
);
GO

-- TT_ANTE table (47 columns - verified from micsprod)
CREATE TABLE dbo.tt_test_run01_ante (
    interferer   CHAR(1) NULL,
    intcall1     CHAR(9) NULL,
    intcall2     CHAR(9) NULL,
    intbndcde    CHAR(4) NULL,
    intanum      SMALLINT NULL,
    viccall1     CHAR(9) NULL,
    viccall2     CHAR(9) NULL,
    vicbndcde    CHAR(4) NULL,
    caseno       INT NULL,
    vicanum      SMALLINT NULL,
    intacode     CHAR(12) NULL,
    vicacode     CHAR(12) NULL,
    report       SMALLINT NULL,
    subcaseno    INT NULL,
    adiscctxh    FLOAT NULL,
    adiscctxv    FLOAT NULL,
    adisccrxh    FLOAT NULL,
    adisccrxv    FLOAT NULL,
    adiscxtxh    FLOAT NULL,
    adiscxtxv    FLOAT NULL,
    adiscxrxh    FLOAT NULL,
    adiscxrxv    FLOAT NULL,
    processed    INT NULL,
    intause      CHAR(4) NULL,
    vicause      CHAR(4) NULL,
    intoffaxa    FLOAT NULL,
    vicoffaxa    FLOAT NULL,
    intgain      FLOAT NULL,
    vicgain      FLOAT NULL,
    intaxref     CHAR(12) NULL,
    intamodel    CHAR(16) NULL,
    vicaxref     CHAR(12) NULL,
    vicamodel    CHAR(16) NULL,
    intaoffax    CHAR(1) NULL,
    inthopaz     FLOAT NULL,
    intantaz     FLOAT NULL,
    intoffantax  FLOAT NULL,
    vicaoffax    CHAR(1) NULL,
    vichopaz     FLOAT NULL,
    vicantaz     FLOAT NULL,
    vicoffantax  FLOAT NULL,
    intaht       FLOAT NULL,
    vicaht       FLOAT NULL,
    intvicel     FLOAT NULL,
    vicintel     FLOAT NULL,
    intelev      FLOAT NULL,
    vicelev      FLOAT NULL
);
GO

-- TT_CHAN table (60 columns - verified from micsprod)
CREATE TABLE dbo.tt_test_run01_chan (
    interferer   CHAR(1) NULL,
    intcall1     CHAR(9) NULL,
    intcall2     CHAR(9) NULL,
    intbndcde    CHAR(4) NULL,
    intanum      SMALLINT NULL,
    intchid      CHAR(4) NULL,
    viccall1     CHAR(9) NULL,
    viccall2     CHAR(9) NULL,
    vicbndcde    CHAR(4) NULL,
    vicanum      SMALLINT NULL,
    caseno       INT NULL,
    vicchid      CHAR(4) NULL,
    intpolar     CHAR(1) NULL,
    vicpolar     CHAR(1) NULL,
    intstattx    CHAR(1) NULL,
    vicstatrx    CHAR(1) NULL,
    inttraftx    CHAR(6) NULL,
    victrafrx    CHAR(6) NULL,
    inteqpttx    CHAR(8) NULL,
    viceqptrx    CHAR(8) NULL,
    intfreqtx    FLOAT NULL,
    vicfreqrx    FLOAT NULL,
    vicpwrrx     FLOAT NULL,
    intpwrtx     FLOAT NULL,
    intafsltx    FLOAT NULL,
    vicafslrx    FLOAT NULL,
    rxant        SMALLINT NULL,
    txant        SMALLINT NULL,
    ctxinttraftx CHAR(6) NULL,
    ctxvictrafrx CHAR(6) NULL,
    ctxeqpt      CHAR(8) NULL,
    calctype     CHAR(3) NULL,
    report       SMALLINT NULL,
    totantdisc   FLOAT NULL,
    freqsep      FLOAT NULL,
    reqdcalc     FLOAT NULL,
    patloss      FLOAT NULL,
    calcico      FLOAT NULL,
    calcixp      FLOAT NULL,
    resti        FLOAT NULL,
    eirpadv      FLOAT NULL,
    tiltdisc     FLOAT NULL,
    pathloss80   FLOAT NULL,
    calcico80    FLOAT NULL,
    calcixp80    FLOAT NULL,
    reqd80       FLOAT NULL,
    resti80      FLOAT NULL,
    pathloss99   FLOAT NULL,
    calcico99    FLOAT NULL,
    calcixp99    FLOAT NULL,
    reqd99       FLOAT NULL,
    resti99      FLOAT NULL,
    ohresult     SMALLINT NULL,
    rqco         FLOAT NULL,
    processed    INT NULL,
    ctxinteqpt   CHAR(8) NULL,
    inteqtype    CHAR(1) NULL,
    viceqtype    CHAR(1) NULL,
    intbwchans   FLOAT NULL,
    vicbwchans   FLOAT NULL
);
GO

-- Insert test data for TT_PARM
INSERT INTO dbo.tt_test_run01_parm (protype, envtype, proname, envname, runname, numcases, mdate, mtime)
VALUES ('T', 'STANDARD', 'testproj', 'envproj', 'run01', 42, '2025-06-01', '14:30:00');
GO

-- Insert test data for TT_SITE
INSERT INTO dbo.tt_test_run01_site (interferer, intcall1, intcall2, viccall1, viccall2, caseno, subcases, intname1, vicname1, report, processed)
VALUES
    ('I', 'CALL001  ', 'REM001   ', 'VIC001   ', 'VREM001  ', 1, 2, 'Interferer Site 1', 'Victim Site 1', 1, 0),
    ('I', 'CALL002  ', 'REM002   ', 'VIC002   ', 'VREM002  ', 2, 1, 'Interferer Site 2', 'Victim Site 2', 1, 0),
    ('I', 'CALL003  ', 'REM003   ', 'VIC003   ', 'VREM003  ', 3, 1, 'Interferer Site 3', 'Victim Site 3', 1, 0);
GO

-- Insert test data for TT_ANTE
INSERT INTO dbo.tt_test_run01_ante (interferer, intcall1, intcall2, viccall1, viccall2, caseno, intacode, vicacode, report, processed)
VALUES
    ('I', 'CALL001  ', 'REM001   ', 'VIC001   ', 'VREM001  ', 1, 'ANT001      ', 'VANT001     ', 1, 0),
    ('I', 'CALL002  ', 'REM002   ', 'VIC002   ', 'VREM002  ', 2, 'ANT002      ', 'VANT002     ', 1, 0),
    ('I', 'CALL003  ', 'REM003   ', 'VIC003   ', 'VREM003  ', 3, 'ANT003      ', 'VANT003     ', 1, 0);
GO

-- Insert test data for TT_CHAN
INSERT INTO dbo.tt_test_run01_chan (interferer, intcall1, intcall2, viccall1, viccall2, caseno, intfreqtx, vicfreqrx, resti, freqsep, report, processed)
VALUES
    ('I', 'CALL001  ', 'REM001   ', 'VIC001   ', 'VREM001  ', 1, 6175.24, 6004.50, 12.5, 0.1, 1, 0),
    ('I', 'CALL002  ', 'REM002   ', 'VIC002   ', 'VREM002  ', 2, 11245.00, 10945.00, -2.0, 0.2, 1, 0),
    ('I', 'CALL003  ', 'REM003   ', 'VIC003   ', 'VREM003  ', 3, 7500.00, 7200.00, 8.0, 0.15, 1, 0);
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
-- UPDATED: Column structures verified against micsprod (Feb 2026)
-- =============================================================================

-- FE_TITL - Title/metadata (6 columns - same as FT_TITL)
CREATE TABLE dbo.fe_envproj_titl (
    validated    CHAR(1) NULL,
    namef        CHAR(16) NULL,
    source       CHAR(6) NULL,
    descr        CHAR(40) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.fe_envproj_titl (validated, namef, source, descr, mdate, mtime)
VALUES 
    ('Y', 'envproj         ', 'ISED  ', 'Environment Project - Earth Stations    ', '2025-05-15', '09:45:00');
GO

-- FE_SHRL - Shared link approvals (3 columns - same as FT_SHRL)
CREATE TABLE dbo.fe_envproj_shrl (
    userid       CHAR(8) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.fe_envproj_shrl (userid, mdate, mtime)
VALUES 
    ('TESTUSER', '2025-05-15', '09:45:00');
GO

-- FE_SITE - Site information (18 columns)
CREATE TABLE dbo.fe_envproj_site (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    location     CHAR(10) NULL,
    name         CHAR(16) NULL,
    prov         CHAR(2) NULL,
    oper         CHAR(6) NULL,
    latit        INT NULL,
    longit       INT NULL,
    grnd         REAL NULL,
    radio        CHAR(2) NULL,
    rain         SMALLINT NULL,
    sdate        CHAR(10) NULL,
    stats        CHAR(1) NULL,
    nots         CHAR(4) NULL,
    oprtyp       CHAR(2) NULL,
    reg          CHAR(2) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.fe_envproj_site (cmd, recstat, location, name, prov, oper, latit, longit, grnd, radio, rain, stats, mdate, mtime)
VALUES 
    ('A', 'A', 'ES-DEN-001', 'Denver ES Hub   ', 'CO', 'SATOP1', 394500000, -1048500000, 1620.0, 'K ', 3, 'O', '2025-05-15', '09:45:00'),
    ('A', 'A', 'ES-LAX-001', 'Los Angeles ES  ', 'CA', 'SATOP2', 340000000, -1183000000, 71.0, 'E ', 2, 'O', '2025-05-15', '09:45:00');
GO

-- FE_AZIM - Azimuth records (11 columns)
CREATE TABLE dbo.fe_envproj_azim (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    deleteall    CHAR(1) NULL,
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    azim         REAL NULL,
    elev         REAL NULL,
    dist         REAL NULL,
    loss         REAL NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.fe_envproj_azim (cmd, recstat, location, call1, azim, elev, dist, loss, mdate, mtime)
VALUES 
    ('A', 'A', 'ES-DEN-001', 'E12345678', 210.5, 35.2, 36000.0, 200.5, '2025-05-15', '09:45:00'),
    ('A', 'A', 'ES-LAX-001', 'E23456789', 180.0, 42.1, 35800.0, 199.8, '2025-05-15', '09:45:00');
GO

-- FE_ANTE - Antenna information (35 columns)
CREATE TABLE dbo.fe_envproj_ante (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    txband       CHAR(4) NULL,
    rxband       CHAR(4) NULL,
    acodetx      CHAR(12) NULL,
    acoderx      CHAR(12) NULL,
    g_t          REAL NULL,
    lnat         REAL NULL,
    aht          REAL NULL,
    afslt        REAL NULL,
    afslr        REAL NULL,
    txhgmax      REAL NULL,
    rxhgmax      REAL NULL,
    satlongit    INT NULL,
    satlong      REAL NULL,
    satlongs     CHAR(1) NULL,
    az           REAL NULL,
    el           REAL NULL,
    sarc1        REAL NULL,
    sarc2        REAL NULL,
    rxpre        REAL NULL,
    txpre        REAL NULL,
    rxtro        REAL NULL,
    txtro        REAL NULL,
    licence      CHAR(13) NULL,
    satname      CHAR(16) NULL,
    stata        CHAR(1) NULL,
    nota         CHAR(4) NULL,
    op2          CHAR(2) NULL,
    antref       INT NULL,
    orbit        CHAR(2) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.fe_envproj_ante (cmd, recstat, location, call1, txband, rxband, acodetx, acoderx, g_t, aht, az, el, satlongit, satname, mdate, mtime)
VALUES 
    ('A', 'A', 'ES-DEN-001', 'E12345678', 'C   ', 'C   ', 'ES-ANT-4.5M ', 'ES-ANT-4.5M ', 28.5, 5.0, 210.5, 35.2, -970000000, 'GALAXY-19       ', '2025-05-15', '09:45:00'),
    ('A', 'A', 'ES-LAX-001', 'E23456789', 'KU  ', 'KU  ', 'ES-ANT-3.0M ', 'ES-ANT-3.0M ', 32.0, 3.0, 180.0, 42.1, -1030000000, 'SES-3           ', '2025-05-15', '09:45:00');
GO

-- FE_CHAN - Channel (29 columns)
CREATE TABLE dbo.fe_envproj_chan (
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    location     CHAR(10) NULL,
    call1        CHAR(9) NULL,
    chid         CHAR(4) NULL,
    freqtx       FLOAT NULL,
    poltx        CHAR(1) NULL,
    maxtxpower   REAL NULL,
    pwrtx        REAL NULL,
    p4khz        REAL NULL,
    eqpttx       CHAR(8) NULL,
    traftx       CHAR(6) NULL,
    stattx       CHAR(1) NULL,
    feetx        CHAR(2) NULL,
    freqrx       FLOAT NULL,
    polrx        CHAR(1) NULL,
    pwrrx        REAL NULL,
    eqptrx       CHAR(8) NULL,
    trafrx       CHAR(6) NULL,
    statrx       CHAR(1) NULL,
    i20          REAL NULL,
    it01         REAL NULL,
    ip01         REAL NULL,
    feerx        CHAR(2) NULL,
    notc         CHAR(4) NULL,
    srvctx       CHAR(6) NULL,
    srvcrx       CHAR(6) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL
);
GO

INSERT INTO dbo.fe_envproj_chan (cmd, recstat, location, call1, chid, freqtx, freqrx, pwrtx, eqpttx, traftx, eqptrx, trafrx, stattx, statrx, mdate, mtime)
VALUES 
    ('A', 'A', 'ES-DEN-001', 'E12345678', '01  ', 6125.00, 3900.00, 15.0, 'EQSAT-01', 'SCPC  ', 'EQSAT-01', 'SCPC  ', 'O', 'O', '2025-05-15', '09:45:00'),
    ('A', 'A', 'ES-LAX-001', 'E23456789', '01  ', 14250.00, 11950.00, 10.0, 'EQSAT-02', 'VSAT  ', 'EQSAT-02', 'VSAT  ', 'O', 'O', '2025-05-15', '09:45:00');
GO

-- FE_CLOC - Location change history (3 columns)
CREATE TABLE dbo.fe_envproj_cloc (
    newlocation  CHAR(10) NULL,
    oldlocation  CHAR(10) NULL,
    name         CHAR(16) NULL
);
GO

INSERT INTO dbo.fe_envproj_cloc (newlocation, oldlocation, name)
VALUES 
    ('ES-DEN-001', 'ES-OLD-001', 'Denver ES Hub   ');
GO

-- FE_CCAL - Call sign change history (2 columns)
CREATE TABLE dbo.fe_envproj_ccal (
    newcallsign  CHAR(9) NULL,
    oldcallsign  CHAR(9) NULL
);
GO

INSERT INTO dbo.fe_envproj_ccal (newcallsign, oldcallsign)
VALUES 
    ('E12345678', 'E00000001');
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
