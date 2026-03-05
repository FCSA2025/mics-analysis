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
-- Verified from micsprod tt_001tom_001_parm (27 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_PARM', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_PARM;
GO

CREATE TABLE tsip_archive.ArchiveTT_PARM (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
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
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_PARM PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveTT_PARM_RunKey ON tsip_archive.ArchiveTT_PARM (RunKey);
GO

-- Archive table for TT_SITE (many rows per run)
-- Verified from micsprod tt_001tom_001_site (31 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_SITE;
GO

CREATE TABLE tsip_archive.ArchiveTT_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
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
    processed    INT NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveTT_SITE_RunKey ON tsip_archive.ArchiveTT_SITE (RunKey);
GO

-- Archive table for TT_ANTE (many rows per run)
-- Verified from micsprod tt_001tom_001_ante (47 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveTT_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
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
    vicelev      FLOAT NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveTT_ANTE_RunKey ON tsip_archive.ArchiveTT_ANTE (RunKey);
GO

-- Archive table for TT_CHAN (many rows per run)
-- Verified from micsprod tt_001tom_001_chan (60 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveTT_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveTT_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveTT_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    RunKey       NVARCHAR(128) NOT NULL,
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
    resti        FLOAT NULL,         -- margin (dB)
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
    vicbwchans   FLOAT NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveTT_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveTT_CHAN_RunKey ON tsip_archive.ArchiveTT_CHAN (RunKey);
GO

-- =============================================================================
-- FT (Terrestrial Station) Source Archive Tables
-- Captured when job is queued (INSERT into tsip_queue), linked by TQ_Job
-- Full set: TITL, SHRL, SITE, ANTE, CHAN, CHNG_CALL
-- =============================================================================

-- Archive table for FT_TITL (Title/metadata)
-- Actual columns: validated, namef, source, descr, mdate, mtime
IF OBJECT_ID(N'tsip_archive.ArchiveFT_TITL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_TITL;
GO

CREATE TABLE tsip_archive.ArchiveFT_TITL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,                 -- Links to web.tsip_queue.TQ_Job
    RunKey       NVARCHAR(128) NULL,           -- Optional link to TT archive (set later if available)
    PdfName      NVARCHAR(128) NOT NULL,
    validated    CHAR(1) NULL,                 -- Validation flag
    namef        CHAR(16) NULL,                -- File name
    source       CHAR(6) NULL,                 -- Source identifier
    descr        CHAR(40) NULL,                -- Description
    mdate        CHAR(10) NULL,                -- Modification date
    mtime        CHAR(8) NULL,                 -- Modification time
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_TITL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_TITL_TQ_Job ON tsip_archive.ArchiveFT_TITL (TQ_Job);
GO

-- Archive table for FT_SHRL (Shared link approvals)
-- Actual columns: userid, mdate, mtime
IF OBJECT_ID(N'tsip_archive.ArchiveFT_SHRL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_SHRL;
GO

CREATE TABLE tsip_archive.ArchiveFT_SHRL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    userid       CHAR(8) NULL,                 -- User identifier
    mdate        CHAR(10) NULL,                -- Modification date
    mtime        CHAR(8) NULL,                 -- Modification time
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_SHRL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_SHRL_TQ_Job ON tsip_archive.ArchiveFT_SHRL (TQ_Job);
GO

-- Archive table for FT_SITE
-- Actual columns: cmd, recstat, call1(PK), name, prov, oper, latit, longit, grnd, stats, sdate, loc,
--                 icaccount, reg, spoint, nots, oprtyp, snumb, notwr, bandwd1-8, mdate, mtime
IF OBJECT_ID(N'tsip_archive.ArchiveFT_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_SITE;
GO

CREATE TABLE tsip_archive.ArchiveFT_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,       -- TS PDF name (= proname)
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    call1        CHAR(9) NULL,                 -- Site's call sign (primary key in source)
    name         CHAR(32) NULL,                -- Site's name (NOT name1!)
    prov         CHAR(2) NULL,                 -- Province
    oper         CHAR(6) NULL,                 -- Site's operator
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
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_SITE_TQ_Job ON tsip_archive.ArchiveFT_SITE (TQ_Job);
GO

-- Archive table for FT_ANTE
-- Verified from micsprod bmce.ft_f3268_ante (37 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveFT_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    bndcde       CHAR(4) NULL,
    anum         SMALLINT NULL,
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
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_ANTE_TQ_Job ON tsip_archive.ArchiveFT_ANTE (TQ_Job);
GO

-- Archive table for FT_CHAN
-- Verified from micsprod bmce.ft_f3268_chan (52 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFT_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveFT_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    cmd          CHAR(1) NULL,
    recstat      CHAR(1) NULL,
    call1        CHAR(9) NULL,
    call2        CHAR(9) NULL,
    bndcde       CHAR(4) NULL,
    splan        CHAR(4) NULL,
    hl           TINYINT NULL,
    vh           TINYINT NULL,
    chid         CHAR(4) NULL,
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
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_CHAN_TQ_Job ON tsip_archive.ArchiveFT_CHAN (TQ_Job);
GO

-- Archive table for FT_CHNG_CALL (Call sign change history)
-- Actual columns (3): newcall1(PK), oldcall1(PK), name
IF OBJECT_ID(N'tsip_archive.ArchiveFT_CHNG_CALL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFT_CHNG_CALL;
GO

CREATE TABLE tsip_archive.ArchiveFT_CHNG_CALL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    newcall1     CHAR(9) NULL,                 -- New call sign 1 (PK in source)
    oldcall1     CHAR(9) NULL,                 -- Old call sign 1 (PK in source)
    name         CHAR(32) NULL,                -- Name
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFT_CHNG_CALL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFT_CHNG_CALL_TQ_Job ON tsip_archive.ArchiveFT_CHNG_CALL (TQ_Job);
GO

-- =============================================================================
-- FE (Earth Station) Source Archive Tables
-- Captured when job is queued (INSERT into tsip_queue), linked by TQ_Job
-- Full set: TITL, SHRL, SITE, AZIM, ANTE, CHAN, CLOC, CCAL
-- =============================================================================

-- Archive table for FE_TITL (Title/metadata)
-- Verified from micsprod fe_1_ne_pas_effacer_titl (6 columns) - Same as FT_TITL
IF OBJECT_ID(N'tsip_archive.ArchiveFE_TITL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_TITL;
GO

CREATE TABLE tsip_archive.ArchiveFE_TITL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    validated    CHAR(1) NULL,
    namef        CHAR(16) NULL,
    source       CHAR(6) NULL,
    descr        CHAR(40) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_TITL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_TITL_TQ_Job ON tsip_archive.ArchiveFE_TITL (TQ_Job);
GO

-- Archive table for FE_SHRL (Shared link approvals)
-- Verified from micsprod fe_1_ne_pas_effacer_shrl (3 columns) - Same as FT_SHRL
IF OBJECT_ID(N'tsip_archive.ArchiveFE_SHRL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_SHRL;
GO

CREATE TABLE tsip_archive.ArchiveFE_SHRL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    userid       CHAR(8) NULL,
    mdate        CHAR(10) NULL,
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_SHRL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_SHRL_TQ_Job ON tsip_archive.ArchiveFE_SHRL (TQ_Job);
GO

-- Archive table for FE_SITE
-- Verified from micsprod fe_1_ne_pas_effacer_site (18 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_SITE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_SITE;
GO

CREATE TABLE tsip_archive.ArchiveFE_SITE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
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
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_SITE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_SITE_TQ_Job ON tsip_archive.ArchiveFE_SITE (TQ_Job);
GO

-- Archive table for FE_AZIM (Azimuth records)
-- Verified from micsprod fe_1_ne_pas_effacer_azim (11 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_AZIM', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_AZIM;
GO

CREATE TABLE tsip_archive.ArchiveFE_AZIM (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
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
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_AZIM PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_AZIM_TQ_Job ON tsip_archive.ArchiveFE_AZIM (TQ_Job);
GO

-- Archive table for FE_ANTE
-- Verified from micsprod fe_1_ne_pas_effacer_ante (35 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_ANTE', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_ANTE;
GO

CREATE TABLE tsip_archive.ArchiveFE_ANTE (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
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
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_ANTE PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_ANTE_TQ_Job ON tsip_archive.ArchiveFE_ANTE (TQ_Job);
GO

-- Archive table for FE_CHAN
-- Verified from micsprod fe_1_ne_pas_effacer_chan (29 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CHAN', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CHAN;
GO

CREATE TABLE tsip_archive.ArchiveFE_CHAN (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
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
    mtime        CHAR(8) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CHAN PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CHAN_TQ_Job ON tsip_archive.ArchiveFE_CHAN (TQ_Job);
GO

-- Archive table for FE_CLOC (Location change history)
-- Verified from micsprod fe_1_ne_pas_effacer_cloc (3 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CLOC', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CLOC;
GO

CREATE TABLE tsip_archive.ArchiveFE_CLOC (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    newlocation  CHAR(10) NULL,
    oldlocation  CHAR(10) NULL,
    name         CHAR(16) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CLOC PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CLOC_TQ_Job ON tsip_archive.ArchiveFE_CLOC (TQ_Job);
GO

-- Archive table for FE_CCAL (Call sign change history)
-- Verified from micsprod fe_1_ne_pas_effacer_ccal (2 columns)
IF OBJECT_ID(N'tsip_archive.ArchiveFE_CCAL', N'U') IS NOT NULL
    DROP TABLE tsip_archive.ArchiveFE_CCAL;
GO

CREATE TABLE tsip_archive.ArchiveFE_CCAL (
    ArchiveId    BIGINT IDENTITY(1,1) NOT NULL,
    TQ_Job       INT NOT NULL,
    RunKey       NVARCHAR(128) NULL,
    PdfName      NVARCHAR(128) NOT NULL,
    newcallsign  CHAR(9) NULL,
    oldcallsign  CHAR(9) NULL,
    ArchivedAt   DATETIME2(0) NOT NULL,
    CONSTRAINT PK_ArchiveFE_CCAL PRIMARY KEY (ArchiveId)
);
GO

CREATE INDEX IX_ArchiveFE_CCAL_TQ_Job ON tsip_archive.ArchiveFE_CCAL (TQ_Job);
GO

PRINT 'Schema tsip_archive created with all archive tables:';
PRINT '';
PRINT 'TT (TSIP Results) - Archived when TT tables are dropped (DDL trigger):';
PRINT '  - ArchiveTT_PARM, ArchiveTT_SITE, ArchiveTT_ANTE, ArchiveTT_CHAN';
PRINT '  - Linked by RunKey (e.g., "test_run01")';
PRINT '';
PRINT 'FT (TS Source - 6 tables) - Archived when job is queued (INSERT trigger on tsip_queue):';
PRINT '  - ArchiveFT_TITL, ArchiveFT_SHRL, ArchiveFT_SITE, ArchiveFT_ANTE, ArchiveFT_CHAN, ArchiveFT_CHNG_CALL';
PRINT '  - Linked by TQ_Job (queue job ID)';
PRINT '';
PRINT 'FE (ES Source - 8 tables) - Archived when job is queued (INSERT trigger on tsip_queue):';
PRINT '  - ArchiveFE_TITL, ArchiveFE_SHRL, ArchiveFE_SITE, ArchiveFE_AZIM, ArchiveFE_ANTE, ArchiveFE_CHAN, ArchiveFE_CLOC, ArchiveFE_CCAL';
PRINT '  - Linked by TQ_Job (queue job ID)';
GO
