-- =============================================================================
-- 05_test_and_verify.sql
-- SELF-CONTAINED test script for the archive solution.
-- Creates all sample data, then tests both triggers.
--
-- Prerequisites (database objects must exist):
--   - tsip_archive schema and 18 archive tables
--   - tsip_archive.fn_GetSchemaFromMicsID function
--   - trg_ArchiveTT_OnDropTable DDL trigger
--   - web.trg_ArchiveFTFE_OnQueueInsert INSERT trigger
-- =============================================================================

USE micsprod;  -- Change to your database if needed
GO

PRINT '==============================================================================';
PRINT 'TSIP Archive Solution - Complete Test';
PRINT '==============================================================================';
PRINT '';

-- =============================================================================
-- Prerequisite Check
-- =============================================================================
PRINT 'Checking prerequisites...';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'tsip_archive')
    PRINT 'WARNING: tsip_archive schema not found - run 00_create_schema_and_archive_tables.sql first';

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'tsip_archive.fn_GetSchemaFromMicsID'))
    PRINT 'WARNING: fn_GetSchemaFromMicsID function not found - run 03_create_schema_lookup_function.sql first';

IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_ArchiveTT_OnDropTable' AND parent_class = 0)
    PRINT 'WARNING: trg_ArchiveTT_OnDropTable DDL trigger not found - run 02_create_drop_trigger.sql first';

IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_ArchiveFTFE_OnQueueInsert')
    PRINT 'WARNING: trg_ArchiveFTFE_OnQueueInsert trigger not found - run 04_create_queue_insert_trigger.sql first';

PRINT '';
GO

-- =============================================================================
-- PART 0: Create all test data (TT, FT, FE tables)
-- =============================================================================
PRINT '==============================================================================';
PRINT 'PART 0: Creating test data';
PRINT '==============================================================================';
PRINT '';

-- Drop existing test tables if they exist (without triggering archive)
-- Disable DDL trigger temporarily to avoid archiving during cleanup (if it exists)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_ArchiveTT_OnDropTable' AND parent_class = 0)
    DISABLE TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
GO

PRINT 'Cleaning up any existing test tables...';

-- TT tables
IF OBJECT_ID(N'dbo.tt_test_run01_parm', N'U') IS NOT NULL DROP TABLE dbo.tt_test_run01_parm;
IF OBJECT_ID(N'dbo.tt_test_run01_site', N'U') IS NOT NULL DROP TABLE dbo.tt_test_run01_site;
IF OBJECT_ID(N'dbo.tt_test_run01_ante', N'U') IS NOT NULL DROP TABLE dbo.tt_test_run01_ante;
IF OBJECT_ID(N'dbo.tt_test_run01_chan', N'U') IS NOT NULL DROP TABLE dbo.tt_test_run01_chan;

-- tp_parm table (configuration) - must be in bchy schema for trigger to find it
IF OBJECT_ID(N'bchy.tp_test_run01_parm', N'U') IS NOT NULL DROP TABLE bchy.tp_test_run01_parm;

-- FT tables (in bchy schema - maps from MicsID 'bchy1')
IF OBJECT_ID(N'bchy.ft_testproj_titl', N'U') IS NOT NULL DROP TABLE bchy.ft_testproj_titl;
IF OBJECT_ID(N'bchy.ft_testproj_shrl', N'U') IS NOT NULL DROP TABLE bchy.ft_testproj_shrl;
IF OBJECT_ID(N'bchy.ft_testproj_site', N'U') IS NOT NULL DROP TABLE bchy.ft_testproj_site;
IF OBJECT_ID(N'bchy.ft_testproj_ante', N'U') IS NOT NULL DROP TABLE bchy.ft_testproj_ante;
IF OBJECT_ID(N'bchy.ft_testproj_chan', N'U') IS NOT NULL DROP TABLE bchy.ft_testproj_chan;
IF OBJECT_ID(N'bchy.ft_testproj_chng_call', N'U') IS NOT NULL DROP TABLE bchy.ft_testproj_chng_call;

-- FE tables (in bchy schema - maps from MicsID 'bchy1')
IF OBJECT_ID(N'bchy.fe_envproj_titl', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_titl;
IF OBJECT_ID(N'bchy.fe_envproj_shrl', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_shrl;
IF OBJECT_ID(N'bchy.fe_envproj_site', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_site;
IF OBJECT_ID(N'bchy.fe_envproj_azim', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_azim;
IF OBJECT_ID(N'bchy.fe_envproj_ante', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_ante;
IF OBJECT_ID(N'bchy.fe_envproj_chan', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_chan;
IF OBJECT_ID(N'bchy.fe_envproj_cloc', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_cloc;
IF OBJECT_ID(N'bchy.fe_envproj_ccal', N'U') IS NOT NULL DROP TABLE bchy.fe_envproj_ccal;
GO

-- Re-enable DDL trigger (if it exists)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_ArchiveTT_OnDropTable' AND parent_class = 0)
    ENABLE TRIGGER trg_ArchiveTT_OnDropTable ON DATABASE;
GO

PRINT 'Existing test tables cleaned up.';
PRINT '';

-- =============================================================================
-- Create TT (TSIP Result) Tables
-- =============================================================================
PRINT 'Creating TT tables...';

-- TT_PARM (27 columns)
CREATE TABLE dbo.tt_test_run01_parm (
    protype CHAR(1) NULL, envtype CHAR(8) NULL, proname CHAR(16) NULL, envname CHAR(16) NULL,
    tsorbout CHAR(1) NULL, spherecalc CHAR(1) NULL, fsep FLOAT NULL, coordist FLOAT NULL,
    analopt CHAR(4) NULL, margin FLOAT NULL, numchan SMALLINT NULL, chancodes CHAR(19) NULL,
    tempant CHAR(15) NULL, tempctx CHAR(15) NULL, tempplan CHAR(15) NULL, tempequip CHAR(15) NULL,
    country CHAR(3) NULL, selsites CHAR(15) NULL, numcodes SMALLINT NULL, codes CHAR(164) NULL,
    runname CHAR(5) NULL, reports INT NULL, numcases INT NULL, numtecases INT NULL,
    parmparm CHAR(50) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL
);

-- TT_SITE (31 columns)
CREATE TABLE dbo.tt_test_run01_site (
    interferer CHAR(1) NULL, intcall1 CHAR(9) NULL, intcall2 CHAR(9) NULL,
    viccall1 CHAR(9) NULL, viccall2 CHAR(9) NULL, caseno INT NULL, subcases INT NULL,
    intname1 CHAR(32) NULL, intname2 CHAR(32) NULL, vicname1 CHAR(32) NULL, vicname2 CHAR(32) NULL,
    intoper CHAR(6) NULL, intoper2 CHAR(6) NULL, vicoper CHAR(6) NULL, vicoper2 CHAR(6) NULL,
    intlatit INT NULL, intlongit INT NULL, intgrnd FLOAT NULL,
    viclatit INT NULL, viclongit INT NULL, vicgrnd FLOAT NULL,
    report SMALLINT NULL, int1int2dist FLOAT NULL, vic1vic2dist FLOAT NULL, int1vic1dist FLOAT NULL,
    distadv FLOAT NULL, intoffax FLOAT NULL, vicoffax FLOAT NULL, intvicaz FLOAT NULL,
    vicintaz FLOAT NULL, processed INT NULL
);

-- TT_ANTE (47 columns)
CREATE TABLE dbo.tt_test_run01_ante (
    interferer CHAR(1) NULL, intcall1 CHAR(9) NULL, intcall2 CHAR(9) NULL,
    intbndcde CHAR(4) NULL, intanum SMALLINT NULL, viccall1 CHAR(9) NULL, viccall2 CHAR(9) NULL,
    vicbndcde CHAR(4) NULL, caseno INT NULL, vicanum SMALLINT NULL, intacode CHAR(12) NULL,
    vicacode CHAR(12) NULL, report SMALLINT NULL, subcaseno INT NULL,
    adiscctxh FLOAT NULL, adiscctxv FLOAT NULL, adisccrxh FLOAT NULL, adisccrxv FLOAT NULL,
    adiscxtxh FLOAT NULL, adiscxtxv FLOAT NULL, adiscxrxh FLOAT NULL, adiscxrxv FLOAT NULL,
    processed INT NULL, intause CHAR(4) NULL, vicause CHAR(4) NULL,
    intoffaxa FLOAT NULL, vicoffaxa FLOAT NULL, intgain FLOAT NULL, vicgain FLOAT NULL,
    intaxref CHAR(12) NULL, intamodel CHAR(16) NULL, vicaxref CHAR(12) NULL, vicamodel CHAR(16) NULL,
    intaoffax CHAR(1) NULL, inthopaz FLOAT NULL, intantaz FLOAT NULL, intoffantax FLOAT NULL,
    vicaoffax CHAR(1) NULL, vichopaz FLOAT NULL, vicantaz FLOAT NULL, vicoffantax FLOAT NULL,
    intaht FLOAT NULL, vicaht FLOAT NULL, intvicel FLOAT NULL, vicintel FLOAT NULL,
    intelev FLOAT NULL, vicelev FLOAT NULL
);

-- TT_CHAN (60 columns)
CREATE TABLE dbo.tt_test_run01_chan (
    interferer CHAR(1) NULL, intcall1 CHAR(9) NULL, intcall2 CHAR(9) NULL,
    intbndcde CHAR(4) NULL, intanum SMALLINT NULL, intchid CHAR(4) NULL,
    viccall1 CHAR(9) NULL, viccall2 CHAR(9) NULL, vicbndcde CHAR(4) NULL, vicanum SMALLINT NULL,
    caseno INT NULL, vicchid CHAR(4) NULL, intpolar CHAR(1) NULL, vicpolar CHAR(1) NULL,
    intstattx CHAR(1) NULL, vicstatrx CHAR(1) NULL, inttraftx CHAR(6) NULL, victrafrx CHAR(6) NULL,
    inteqpttx CHAR(8) NULL, viceqptrx CHAR(8) NULL, intfreqtx FLOAT NULL, vicfreqrx FLOAT NULL,
    vicpwrrx FLOAT NULL, intpwrtx FLOAT NULL, intafsltx FLOAT NULL, vicafslrx FLOAT NULL,
    rxant SMALLINT NULL, txant SMALLINT NULL, ctxinttraftx CHAR(6) NULL, ctxvictrafrx CHAR(6) NULL,
    ctxeqpt CHAR(8) NULL, calctype CHAR(3) NULL, report SMALLINT NULL, totantdisc FLOAT NULL,
    freqsep FLOAT NULL, reqdcalc FLOAT NULL, patloss FLOAT NULL, calcico FLOAT NULL,
    calcixp FLOAT NULL, resti FLOAT NULL, eirpadv FLOAT NULL, tiltdisc FLOAT NULL,
    pathloss80 FLOAT NULL, calcico80 FLOAT NULL, calcixp80 FLOAT NULL, reqd80 FLOAT NULL,
    resti80 FLOAT NULL, pathloss99 FLOAT NULL, calcico99 FLOAT NULL, calcixp99 FLOAT NULL,
    reqd99 FLOAT NULL, resti99 FLOAT NULL, ohresult SMALLINT NULL, rqco FLOAT NULL,
    processed INT NULL, ctxinteqpt CHAR(8) NULL, inteqtype CHAR(1) NULL, viceqtype CHAR(1) NULL,
    intbwchans FLOAT NULL, vicbwchans FLOAT NULL
);
GO

-- Insert TT test data
INSERT INTO dbo.tt_test_run01_parm (protype, envtype, proname, envname, runname, numcases, mdate, mtime)
VALUES ('T', 'STANDARD', 'testproj', 'envproj', 'run01', 42, '2025-06-01', '14:30:00');

INSERT INTO dbo.tt_test_run01_site (interferer, intcall1, intcall2, viccall1, viccall2, caseno, subcases, intname1, vicname1, report, processed)
VALUES ('I', 'CALL001  ', 'REM001   ', 'VIC001   ', 'VREM001  ', 1, 2, 'Interferer Site 1', 'Victim Site 1', 1, 0),
       ('I', 'CALL002  ', 'REM002   ', 'VIC002   ', 'VREM002  ', 2, 1, 'Interferer Site 2', 'Victim Site 2', 1, 0),
       ('I', 'CALL003  ', 'REM003   ', 'VIC003   ', 'VREM003  ', 3, 1, 'Interferer Site 3', 'Victim Site 3', 1, 0);

INSERT INTO dbo.tt_test_run01_ante (interferer, intcall1, intcall2, viccall1, viccall2, caseno, intacode, vicacode, report, processed)
VALUES ('I', 'CALL001  ', 'REM001   ', 'VIC001   ', 'VREM001  ', 1, 'ANT001      ', 'VANT001     ', 1, 0),
       ('I', 'CALL002  ', 'REM002   ', 'VIC002   ', 'VREM002  ', 2, 'ANT002      ', 'VANT002     ', 1, 0),
       ('I', 'CALL003  ', 'REM003   ', 'VIC003   ', 'VREM003  ', 3, 'ANT003      ', 'VANT003     ', 1, 0);

INSERT INTO dbo.tt_test_run01_chan (interferer, intcall1, intcall2, viccall1, viccall2, caseno, intfreqtx, vicfreqrx, resti, freqsep, report, processed)
VALUES ('I', 'CALL001  ', 'REM001   ', 'VIC001   ', 'VREM001  ', 1, 6175.24, 6004.50, 12.5, 0.1, 1, 0),
       ('I', 'CALL002  ', 'REM002   ', 'VIC002   ', 'VREM002  ', 2, 11245.00, 10945.00, -2.0, 0.2, 1, 0),
       ('I', 'CALL003  ', 'REM003   ', 'VIC003   ', 'VREM003  ', 3, 7500.00, 7200.00, 8.0, 0.15, 1, 0);
GO

PRINT '  Created: tt_test_run01_parm (1 row), _site (3 rows), _ante (3 rows), _chan (3 rows)';

-- =============================================================================
-- Create FT (Terrestrial Station Source) Tables - proname = 'testproj'
-- =============================================================================
PRINT 'Creating FT source tables...';

-- FT_TITL
CREATE TABLE bchy.ft_testproj_titl (validated CHAR(1) NULL, namef CHAR(16) NULL, source CHAR(6) NULL, descr CHAR(40) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL);
INSERT INTO bchy.ft_testproj_titl VALUES ('Y', 'testproj        ', 'ISED  ', 'Test Project - Denver/Boulder Links     ', '2025-06-01', '14:30:00');

-- FT_SHRL
CREATE TABLE bchy.ft_testproj_shrl (userid CHAR(8) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL);
INSERT INTO bchy.ft_testproj_shrl VALUES ('TESTUSER', '2025-06-01', '14:30:00');

-- FT_SITE
CREATE TABLE bchy.ft_testproj_site (
    cmd CHAR(1) NULL, recstat CHAR(1) NULL, call1 CHAR(9) NOT NULL, name CHAR(32) NULL, prov CHAR(2) NULL,
    oper CHAR(6) NULL, latit INT NULL, longit INT NULL, grnd FLOAT NULL, stats CHAR(2) NULL,
    sdate CHAR(10) NULL, loc CHAR(40) NULL, icaccount CHAR(10) NULL, reg CHAR(1) NULL, spoint CHAR(4) NULL,
    nots CHAR(60) NULL, oprtyp CHAR(1) NULL, snumb CHAR(8) NULL, notwr CHAR(40) NULL,
    bandwd1 CHAR(6) NULL, bandwd2 CHAR(6) NULL, bandwd3 CHAR(6) NULL, bandwd4 CHAR(6) NULL,
    bandwd5 CHAR(6) NULL, bandwd6 CHAR(6) NULL, bandwd7 CHAR(6) NULL, bandwd8 CHAR(6) NULL,
    mdate CHAR(10) NULL, mtime CHAR(8) NULL, CONSTRAINT PK_ft_testproj_site PRIMARY KEY (call1)
);
INSERT INTO bchy.ft_testproj_site (cmd, recstat, call1, name, prov, oper, latit, longit, grnd, stats, mdate, mtime)
VALUES ('A', 'A', 'CALL001  ', 'Denver Main                     ', 'CO', 'OP01  ', 394000000, -1049000000, 1609.0, 'OP', '2025-06-01', '14:30:00'),
       ('A', 'A', 'CALL002  ', 'Boulder Site                    ', 'CO', 'OP02  ', 400150000, -1052200000, 1655.0, 'OP', '2025-06-01', '14:30:00');

-- FT_ANTE
CREATE TABLE bchy.ft_testproj_ante (
    cmd CHAR(1) NULL, recstat CHAR(1) NULL, call1 CHAR(9) NOT NULL, call2 CHAR(9) NOT NULL,
    bndcde CHAR(4) NOT NULL, anum SMALLINT NOT NULL, ause CHAR(3) NULL, acode CHAR(12) NULL,
    aht REAL NULL, azmth REAL NULL, elvtn REAL NULL, dist REAL NULL, offazm CHAR(1) NULL,
    tazmth REAL NULL, telvtn REAL NULL, tgain REAL NULL, txfdlnth CHAR(2) NULL, txfdlnlh REAL NULL,
    txfdlntv CHAR(2) NULL, txfdlnlv REAL NULL, rxfdlnth CHAR(2) NULL, rxfdlnlh REAL NULL,
    rxfdlntv CHAR(2) NULL, rxfdlnlv REAL NULL, txpadpam REAL NULL, rxpadlna REAL NULL,
    txcompl REAL NULL, rxcompl REAL NULL, obsloss REAL NULL, kvalue REAL NULL,
    atwrno TINYINT NULL, nota CHAR(4) NULL, apoint CHAR(4) NULL, sdate CHAR(10) NULL,
    mdate CHAR(10) NULL, mtime CHAR(8) NULL, licence CHAR(13) NULL,
    CONSTRAINT PK_ft_testproj_ante PRIMARY KEY (call1, call2, bndcde, anum)
);
INSERT INTO bchy.ft_testproj_ante (cmd, recstat, call1, call2, bndcde, anum, acode, aht, azmth, tgain, mdate, mtime)
VALUES ('A', 'A', 'CALL001  ', 'REM001   ', '6GH ', 1, 'ANT6G-STD   ', 30.0, 45.5, 38.5, '2025-06-01', '14:30:00'),
       ('A', 'A', 'CALL002  ', 'REM002   ', '11G ', 1, 'ANT11G-STD  ', 25.0, 120.0, 40.0, '2025-06-01', '14:30:00');

-- FT_CHAN
CREATE TABLE bchy.ft_testproj_chan (
    cmd CHAR(1) NULL, recstat CHAR(1) NULL, call1 CHAR(9) NOT NULL, call2 CHAR(9) NOT NULL,
    bndcde CHAR(4) NOT NULL, splan CHAR(4) NULL, hl TINYINT NULL, vh TINYINT NULL, chid CHAR(4) NOT NULL,
    freqtx FLOAT NULL, poltx CHAR(1) NULL, antnumbtx1 TINYINT NULL, antnumbtx2 TINYINT NULL,
    eqpttx CHAR(8) NULL, eqptutx CHAR(1) NULL, pwrtx REAL NULL, atpccde REAL NULL,
    afsltx1 REAL NULL, afsltx2 REAL NULL, traftx CHAR(6) NULL, srvctx CHAR(6) NULL, stattx CHAR(1) NULL,
    freqrx FLOAT NULL, polrx CHAR(1) NULL, antnumbrx1 TINYINT NULL, antnumbrx2 TINYINT NULL,
    antnumbrx3 TINYINT NULL, eqptrx CHAR(8) NULL, eqpturx CHAR(1) NULL,
    afslrx1 REAL NULL, afslrx2 REAL NULL, afslrx3 REAL NULL, pwrrx1 REAL NULL, pwrrx2 REAL NULL, pwrrx3 REAL NULL,
    trafrx CHAR(6) NULL, esint REAL NULL, tsint REAL NULL, srvcrx CHAR(6) NULL, statrx CHAR(1) NULL,
    routnumb CHAR(8) NULL, stnnumb TINYINT NULL, hopnumb TINYINT NULL, sdate CHAR(10) NULL,
    notetx CHAR(4) NULL, noterx CHAR(4) NULL, notegnl CHAR(4) NULL, cpoint CHAR(4) NULL,
    feetx CHAR(2) NULL, feerx CHAR(2) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL,
    CONSTRAINT PK_ft_testproj_chan PRIMARY KEY (call1, call2, bndcde, chid)
);
INSERT INTO bchy.ft_testproj_chan (cmd, recstat, call1, call2, bndcde, chid, freqtx, freqrx, pwrtx, traftx, trafrx, eqpttx, eqptrx, stattx, statrx, mdate, mtime)
VALUES ('A', 'A', 'CALL001  ', 'REM001   ', '6GH ', '01  ', 6175.24, 6004.50, 30.0, 'T64QAM', 'R64QAM', 'EQ6G-01 ', 'EQ6G-01 ', 'O', 'O', '2025-06-01', '14:30:00'),
       ('A', 'A', 'CALL002  ', 'REM002   ', '11G ', '01  ', 11245.00, 10945.00, 25.0, 'T256Q ', 'R256Q ', 'EQ11G-02', 'EQ11G-02', 'O', 'O', '2025-06-01', '14:30:00');

-- FT_CHNG_CALL
CREATE TABLE bchy.ft_testproj_chng_call (newcall1 CHAR(9) NOT NULL, oldcall1 CHAR(9) NOT NULL, name CHAR(32) NULL, CONSTRAINT PK_ft_testproj_chng_call PRIMARY KEY (newcall1, oldcall1));
INSERT INTO bchy.ft_testproj_chng_call VALUES ('CALL001  ', 'OLDCAL01 ', 'Denver Main Call Sign Change    ');
GO

PRINT '  Created: ft_testproj_titl (1), _shrl (1), _site (2), _ante (2), _chan (2), _chng_call (1)';

-- =============================================================================
-- Create FE (Earth Station Source) Tables - envname = 'envproj'
-- These are in bchy schema to match the MicsID 'bchy1'
-- =============================================================================
PRINT 'Creating FE source tables...';

-- FE_TITL
CREATE TABLE bchy.fe_envproj_titl (validated CHAR(1) NULL, namef CHAR(16) NULL, source CHAR(6) NULL, descr CHAR(40) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL);
INSERT INTO bchy.fe_envproj_titl VALUES ('Y', 'envproj         ', 'ISED  ', 'Environment Project - Earth Stations    ', '2025-05-15', '09:45:00');

-- FE_SHRL
CREATE TABLE bchy.fe_envproj_shrl (userid CHAR(8) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL);
INSERT INTO bchy.fe_envproj_shrl VALUES ('TESTUSER', '2025-05-15', '09:45:00');

-- FE_SITE
CREATE TABLE bchy.fe_envproj_site (
    cmd CHAR(1) NULL, recstat CHAR(1) NULL, location CHAR(10) NULL, name CHAR(16) NULL, prov CHAR(2) NULL,
    oper CHAR(6) NULL, latit INT NULL, longit INT NULL, grnd REAL NULL, radio CHAR(2) NULL,
    rain SMALLINT NULL, sdate CHAR(10) NULL, stats CHAR(1) NULL, nots CHAR(4) NULL, oprtyp CHAR(2) NULL,
    reg CHAR(2) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL
);
INSERT INTO bchy.fe_envproj_site (cmd, recstat, location, name, prov, oper, latit, longit, grnd, radio, rain, stats, mdate, mtime)
VALUES ('A', 'A', 'ES-DEN-001', 'Denver ES Hub   ', 'CO', 'SATOP1', 394500000, -1048500000, 1620.0, 'K ', 3, 'O', '2025-05-15', '09:45:00'),
       ('A', 'A', 'ES-LAX-001', 'Los Angeles ES  ', 'CA', 'SATOP2', 340000000, -1183000000, 71.0, 'E ', 2, 'O', '2025-05-15', '09:45:00');

-- FE_AZIM
CREATE TABLE bchy.fe_envproj_azim (cmd CHAR(1) NULL, recstat CHAR(1) NULL, deleteall CHAR(1) NULL, location CHAR(10) NULL, call1 CHAR(9) NULL, azim REAL NULL, elev REAL NULL, dist REAL NULL, loss REAL NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL);
INSERT INTO bchy.fe_envproj_azim VALUES ('A', 'A', NULL, 'ES-DEN-001', 'E12345678', 210.5, 35.2, 36000.0, 200.5, '2025-05-15', '09:45:00'),
                                        ('A', 'A', NULL, 'ES-LAX-001', 'E23456789', 180.0, 42.1, 35800.0, 199.8, '2025-05-15', '09:45:00');

-- FE_ANTE
CREATE TABLE bchy.fe_envproj_ante (
    cmd CHAR(1) NULL, recstat CHAR(1) NULL, location CHAR(10) NULL, call1 CHAR(9) NULL,
    txband CHAR(4) NULL, rxband CHAR(4) NULL, acodetx CHAR(12) NULL, acoderx CHAR(12) NULL,
    g_t REAL NULL, lnat REAL NULL, aht REAL NULL, afslt REAL NULL, afslr REAL NULL,
    txhgmax REAL NULL, rxhgmax REAL NULL, satlongit INT NULL, satlong REAL NULL, satlongs CHAR(1) NULL,
    az REAL NULL, el REAL NULL, sarc1 REAL NULL, sarc2 REAL NULL, rxpre REAL NULL, txpre REAL NULL,
    rxtro REAL NULL, txtro REAL NULL, licence CHAR(13) NULL, satname CHAR(16) NULL, stata CHAR(1) NULL,
    nota CHAR(4) NULL, op2 CHAR(2) NULL, antref INT NULL, orbit CHAR(2) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL
);
INSERT INTO bchy.fe_envproj_ante (cmd, recstat, location, call1, txband, rxband, acodetx, acoderx, g_t, aht, az, el, satlongit, satname, mdate, mtime)
VALUES ('A', 'A', 'ES-DEN-001', 'E12345678', 'C   ', 'C   ', 'ES-ANT-4.5M ', 'ES-ANT-4.5M ', 28.5, 5.0, 210.5, 35.2, -970000000, 'GALAXY-19       ', '2025-05-15', '09:45:00'),
       ('A', 'A', 'ES-LAX-001', 'E23456789', 'KU  ', 'KU  ', 'ES-ANT-3.0M ', 'ES-ANT-3.0M ', 32.0, 3.0, 180.0, 42.1, -1030000000, 'SES-3           ', '2025-05-15', '09:45:00');

-- FE_CHAN
CREATE TABLE bchy.fe_envproj_chan (
    cmd CHAR(1) NULL, recstat CHAR(1) NULL, location CHAR(10) NULL, call1 CHAR(9) NULL, chid CHAR(4) NULL,
    freqtx FLOAT NULL, poltx CHAR(1) NULL, maxtxpower REAL NULL, pwrtx REAL NULL, p4khz REAL NULL,
    eqpttx CHAR(8) NULL, traftx CHAR(6) NULL, stattx CHAR(1) NULL, feetx CHAR(2) NULL,
    freqrx FLOAT NULL, polrx CHAR(1) NULL, pwrrx REAL NULL, eqptrx CHAR(8) NULL, trafrx CHAR(6) NULL,
    statrx CHAR(1) NULL, i20 REAL NULL, it01 REAL NULL, ip01 REAL NULL, feerx CHAR(2) NULL,
    notc CHAR(4) NULL, srvctx CHAR(6) NULL, srvcrx CHAR(6) NULL, mdate CHAR(10) NULL, mtime CHAR(8) NULL
);
INSERT INTO bchy.fe_envproj_chan (cmd, recstat, location, call1, chid, freqtx, freqrx, pwrtx, eqpttx, traftx, eqptrx, trafrx, stattx, statrx, mdate, mtime)
VALUES ('A', 'A', 'ES-DEN-001', 'E12345678', '01  ', 6125.00, 3900.00, 15.0, 'EQSAT-01', 'SCPC  ', 'EQSAT-01', 'SCPC  ', 'O', 'O', '2025-05-15', '09:45:00'),
       ('A', 'A', 'ES-LAX-001', 'E23456789', '01  ', 14250.00, 11950.00, 10.0, 'EQSAT-02', 'VSAT  ', 'EQSAT-02', 'VSAT  ', 'O', 'O', '2025-05-15', '09:45:00');

-- FE_CLOC
CREATE TABLE bchy.fe_envproj_cloc (newlocation CHAR(10) NULL, oldlocation CHAR(10) NULL, name CHAR(16) NULL);
INSERT INTO bchy.fe_envproj_cloc VALUES ('ES-DEN-001', 'ES-OLD-001', 'Denver ES Hub   ');

-- FE_CCAL
CREATE TABLE bchy.fe_envproj_ccal (newcallsign CHAR(9) NULL, oldcallsign CHAR(9) NULL);
INSERT INTO bchy.fe_envproj_ccal VALUES ('E12345678', 'E00000001');
GO

PRINT '  Created: fe_envproj_titl (1), _shrl (1), _site (2), _azim (2), _ante (2), _chan (2), _cloc (1), _ccal (1)';

-- =============================================================================
-- Create tp_parm table (configuration used by queue trigger)
-- This must be in bchy schema to match the MicsID 'bchy1' -> schema 'bchy'
-- =============================================================================
PRINT 'Creating tp_parm configuration table...';

CREATE TABLE bchy.tp_test_run01_parm (proname CHAR(16), envname CHAR(16));
INSERT INTO bchy.tp_test_run01_parm (proname, envname) VALUES ('testproj', 'envproj');
GO

PRINT '  Created: bchy.tp_test_run01_parm (proname=testproj, envname=envproj)';
PRINT '';
PRINT 'Test data creation complete.';
PRINT '';

-- =============================================================================
-- PART 1: Test FT/FE archiving via queue INSERT trigger
-- =============================================================================
PRINT '==============================================================================';
PRINT 'PART 1: Testing FT/FE archiving via tsip_queue INSERT';
PRINT '==============================================================================';
PRINT '';

PRINT '=== Before test: archive row counts ===';
SELECT 'ArchiveTT_PARM' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_PARM
UNION ALL SELECT 'ArchiveTT_SITE', COUNT(*) FROM tsip_archive.ArchiveTT_SITE
UNION ALL SELECT 'ArchiveTT_ANTE', COUNT(*) FROM tsip_archive.ArchiveTT_ANTE
UNION ALL SELECT 'ArchiveTT_CHAN', COUNT(*) FROM tsip_archive.ArchiveTT_CHAN
UNION ALL SELECT 'ArchiveFT_TITL', COUNT(*) FROM tsip_archive.ArchiveFT_TITL
UNION ALL SELECT 'ArchiveFT_SHRL', COUNT(*) FROM tsip_archive.ArchiveFT_SHRL
UNION ALL SELECT 'ArchiveFT_SITE', COUNT(*) FROM tsip_archive.ArchiveFT_SITE
UNION ALL SELECT 'ArchiveFT_ANTE', COUNT(*) FROM tsip_archive.ArchiveFT_ANTE
UNION ALL SELECT 'ArchiveFT_CHAN', COUNT(*) FROM tsip_archive.ArchiveFT_CHAN
UNION ALL SELECT 'ArchiveFT_CHNG_CALL', COUNT(*) FROM tsip_archive.ArchiveFT_CHNG_CALL
UNION ALL SELECT 'ArchiveFE_TITL', COUNT(*) FROM tsip_archive.ArchiveFE_TITL
UNION ALL SELECT 'ArchiveFE_SHRL', COUNT(*) FROM tsip_archive.ArchiveFE_SHRL
UNION ALL SELECT 'ArchiveFE_SITE', COUNT(*) FROM tsip_archive.ArchiveFE_SITE
UNION ALL SELECT 'ArchiveFE_AZIM', COUNT(*) FROM tsip_archive.ArchiveFE_AZIM
UNION ALL SELECT 'ArchiveFE_ANTE', COUNT(*) FROM tsip_archive.ArchiveFE_ANTE
UNION ALL SELECT 'ArchiveFE_CHAN', COUNT(*) FROM tsip_archive.ArchiveFE_CHAN
UNION ALL SELECT 'ArchiveFE_CLOC', COUNT(*) FROM tsip_archive.ArchiveFE_CLOC
UNION ALL SELECT 'ArchiveFE_CCAL', COUNT(*) FROM tsip_archive.ArchiveFE_CCAL;
GO

PRINT '';
PRINT '=== Inserting test job into web.tsip_queue ===';

DECLARE @NextJob INT;
SELECT @NextJob = ISNULL(MAX(TQ_Job), 0) + 1 FROM web.tsip_queue;

INSERT INTO web.tsip_queue (TQ_Job, TQ_Status, TQ_ArgFile, TQ_MicsID, TQ_TimeIn)
VALUES (@NextJob, 'P', 'test_run01', 'bchy1', GETDATE());

PRINT 'Inserted TQ_Job = ' + CAST(@NextJob AS VARCHAR(10));
PRINT 'TQ_ArgFile = test_run01, TQ_MicsID = bchy1 (maps to schema bchy)';
PRINT '';
PRINT 'The INSERT trigger should have archived FT/FE source data.';
GO

PRINT '';
PRINT '=== FT Archive Contents (from queue trigger) ===';
SELECT 'FT_TITL' AS TblType, TQ_Job, PdfName, ArchivedAt FROM tsip_archive.ArchiveFT_TITL ORDER BY ArchiveId DESC;
SELECT 'FT_SITE' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveFT_SITE WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
SELECT 'FT_CHAN' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveFT_CHAN WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
GO

PRINT '';
PRINT '=== FE Archive Contents (from queue trigger) ===';
SELECT 'FE_TITL' AS TblType, TQ_Job, PdfName, ArchivedAt FROM tsip_archive.ArchiveFE_TITL ORDER BY ArchiveId DESC;
SELECT 'FE_SITE' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveFE_SITE WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
SELECT 'FE_CHAN' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveFE_CHAN WHERE TQ_Job = (SELECT MAX(TQ_Job) FROM web.tsip_queue);
GO

-- =============================================================================
-- PART 2: Test TT archiving via DDL DROP trigger
-- =============================================================================
PRINT '';
PRINT '==============================================================================';
PRINT 'PART 2: Testing TT archiving via DROP TABLE DDL trigger';
PRINT '==============================================================================';
PRINT '';

PRINT '=== Dropping TT tables (triggers TT archiving) ===';
PRINT '';
PRINT 'Dropping dbo.tt_test_run01_parm ...';
DROP TABLE dbo.tt_test_run01_parm;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.tt_test_run01_site ...';
DROP TABLE dbo.tt_test_run01_site;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.tt_test_run01_ante ...';
DROP TABLE dbo.tt_test_run01_ante;
PRINT 'Dropped.';
GO

PRINT 'Dropping dbo.tt_test_run01_chan ...';
DROP TABLE dbo.tt_test_run01_chan;
PRINT 'Dropped.';
GO

-- =============================================================================
-- PART 3: Verify all archives
-- =============================================================================
PRINT '';
PRINT '==============================================================================';
PRINT 'PART 3: Verification';
PRINT '==============================================================================';
PRINT '';

PRINT '=== TT Archive Contents (RunKey = test_run01) ===';
SELECT * FROM tsip_archive.ArchiveTT_PARM WHERE RunKey = 'test_run01';
SELECT 'TT_SITE' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_SITE WHERE RunKey = 'test_run01';
SELECT 'TT_ANTE' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_ANTE WHERE RunKey = 'test_run01';
SELECT 'TT_CHAN' AS TblType, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = 'test_run01';
GO

PRINT '';
PRINT '=== After test: archive row counts ===';
SELECT 'ArchiveTT_PARM' AS Tbl, COUNT(*) AS Cnt FROM tsip_archive.ArchiveTT_PARM
UNION ALL SELECT 'ArchiveTT_SITE', COUNT(*) FROM tsip_archive.ArchiveTT_SITE
UNION ALL SELECT 'ArchiveTT_ANTE', COUNT(*) FROM tsip_archive.ArchiveTT_ANTE
UNION ALL SELECT 'ArchiveTT_CHAN', COUNT(*) FROM tsip_archive.ArchiveTT_CHAN
UNION ALL SELECT 'ArchiveFT_TITL', COUNT(*) FROM tsip_archive.ArchiveFT_TITL
UNION ALL SELECT 'ArchiveFT_SHRL', COUNT(*) FROM tsip_archive.ArchiveFT_SHRL
UNION ALL SELECT 'ArchiveFT_SITE', COUNT(*) FROM tsip_archive.ArchiveFT_SITE
UNION ALL SELECT 'ArchiveFT_ANTE', COUNT(*) FROM tsip_archive.ArchiveFT_ANTE
UNION ALL SELECT 'ArchiveFT_CHAN', COUNT(*) FROM tsip_archive.ArchiveFT_CHAN
UNION ALL SELECT 'ArchiveFT_CHNG_CALL', COUNT(*) FROM tsip_archive.ArchiveFT_CHNG_CALL
UNION ALL SELECT 'ArchiveFE_TITL', COUNT(*) FROM tsip_archive.ArchiveFE_TITL
UNION ALL SELECT 'ArchiveFE_SHRL', COUNT(*) FROM tsip_archive.ArchiveFE_SHRL
UNION ALL SELECT 'ArchiveFE_SITE', COUNT(*) FROM tsip_archive.ArchiveFE_SITE
UNION ALL SELECT 'ArchiveFE_AZIM', COUNT(*) FROM tsip_archive.ArchiveFE_AZIM
UNION ALL SELECT 'ArchiveFE_ANTE', COUNT(*) FROM tsip_archive.ArchiveFE_ANTE
UNION ALL SELECT 'ArchiveFE_CHAN', COUNT(*) FROM tsip_archive.ArchiveFE_CHAN
UNION ALL SELECT 'ArchiveFE_CLOC', COUNT(*) FROM tsip_archive.ArchiveFE_CLOC
UNION ALL SELECT 'ArchiveFE_CCAL', COUNT(*) FROM tsip_archive.ArchiveFE_CCAL;
GO

PRINT '';
PRINT '=== Verify TT tables are dropped ===';
IF OBJECT_ID(N'dbo.tt_test_run01_parm', N'U') IS NULL PRINT 'OK: tt_test_run01_parm no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_site', N'U') IS NULL PRINT 'OK: tt_test_run01_site no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_ante', N'U') IS NULL PRINT 'OK: tt_test_run01_ante no longer exists.';
IF OBJECT_ID(N'dbo.tt_test_run01_chan', N'U') IS NULL PRINT 'OK: tt_test_run01_chan no longer exists.';

PRINT '';
PRINT '=== Verify FT/FE source tables STILL EXIST (not dropped) ===';
IF OBJECT_ID(N'bchy.ft_testproj_site', N'U') IS NOT NULL PRINT 'OK: bchy.ft_testproj_site still exists.';
IF OBJECT_ID(N'bchy.fe_envproj_site', N'U') IS NOT NULL PRINT 'OK: bchy.fe_envproj_site still exists.';
GO

PRINT '';
PRINT '==============================================================================';
PRINT 'TEST COMPLETE';
PRINT '';
PRINT 'Expected Results:';
PRINT '  - FT/FE archives: Populated when job was INSERTed into tsip_queue';
PRINT '  - TT archives: Populated when TT tables were DROPped';
PRINT '  - TT tables: Gone (dropped)';
PRINT '  - FT/FE source tables: Still exist (only archived, not dropped)';
PRINT '==============================================================================';
GO
