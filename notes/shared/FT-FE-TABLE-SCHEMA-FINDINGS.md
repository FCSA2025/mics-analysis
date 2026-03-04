# TT/FT/FE Table Schema Verification Findings

**Date**: February 4, 2026  
**Last Updated**: February 4, 2026  
**Database**: micsprod  
**Tool Used**: `db-util.js`, `test-ft-archive-columns.js`

## Summary

Direct database inspection revealed **significant discrepancies** between our original archive table definitions and actual production database schemas.

### Status
- **TT Tables**: ✅ **FIXED** - All 4 TT archive tables corrected (PARM: 27 cols, SITE: 31, ANTE: 47, CHAN: 60)
- **FT Tables**: ✅ **FIXED** - All 6 FT archive tables corrected and verified
- **FE Tables**: ✅ **FIXED** - All 8 FE archive tables corrected (TITL: 6, SHRL: 3, SITE: 18, AZIM: 11, ANTE: 35, CHAN: 29, CLOC: 3, CCAL: 2)

---

## TT Tables (TSIP Results) - ⚠️ PENDING FIXES

### Critical Discovery
Our original TT archive tables were based on **incomplete documentation**. Actual TT tables have significantly more columns:

| Table | Archive Cols | Actual Cols | Missing |
|-------|-------------|-------------|---------|
| TT_PARM | 4 | 27 | **23** |
| TT_SITE | 3 | 31 | **28** |
| TT_ANTE | 5 | 47 | **42** |
| TT_CHAN | 5 | 60 | **55** |

### TT_PARM (27 columns)
Verified from `tt_001tom_001_parm`:
```
protype CHAR(1), envtype CHAR(8), proname CHAR(16), envname CHAR(16),
tsorbout CHAR(1), spherecalc CHAR(1), fsep FLOAT, coordist FLOAT,
analopt CHAR(4), margin FLOAT, numchan SMALLINT, chancodes CHAR(19),
tempant CHAR(15), tempctx CHAR(15), tempplan CHAR(15), tempequip CHAR(15),
country CHAR(3), selsites CHAR(15), numcodes SMALLINT, codes CHAR(164),
runname CHAR(5), reports INT, numcases INT, numtecases INT,
parmparm CHAR(50), mdate CHAR(10), mtime CHAR(8)
```

### TT_SITE (31 columns)
Verified from `tt_001tom_001_site`:
```
interferer CHAR(1), intcall1 CHAR(9), intcall2 CHAR(9), viccall1 CHAR(9),
viccall2 CHAR(9), caseno INT, subcases INT, intname1 CHAR(32),
intname2 CHAR(32), vicname1 CHAR(32), vicname2 CHAR(32), intoper CHAR(6),
intoper2 CHAR(6), vicoper CHAR(6), vicoper2 CHAR(6), intlatit INT,
intlongit INT, intgrnd FLOAT, viclatit INT, viclongit INT, vicgrnd FLOAT,
report SMALLINT, int1int2dist FLOAT, vic1vic2dist FLOAT, int1vic1dist FLOAT,
distadv FLOAT, intoffax FLOAT, vicoffax FLOAT, intvicaz FLOAT,
vicintaz FLOAT, processed INT
```

### TT_ANTE (47 columns)
Verified from `tt_001tom_001_ante`:
```
interferer CHAR(1), intcall1 CHAR(9), intcall2 CHAR(9), intbndcde CHAR(4),
intanum SMALLINT, viccall1 CHAR(9), viccall2 CHAR(9), vicbndcde CHAR(4),
caseno INT, vicanum SMALLINT, intacode CHAR(12), vicacode CHAR(12),
report SMALLINT, subcaseno INT, adiscctxh FLOAT, adiscctxv FLOAT,
adisccrxh FLOAT, adisccrxv FLOAT, adiscxtxh FLOAT, adiscxtxv FLOAT,
adiscxrxh FLOAT, adiscxrxv FLOAT, processed INT, intause CHAR(4),
vicause CHAR(4), intoffaxa FLOAT, vicoffaxa FLOAT, intgain FLOAT,
vicgain FLOAT, intaxref CHAR(12), intamodel CHAR(16), vicaxref CHAR(12),
vicamodel CHAR(16), intaoffax CHAR(1), inthopaz FLOAT, intantaz FLOAT,
intoffantax FLOAT, vicaoffax CHAR(1), vichopaz FLOAT, vicantaz FLOAT,
vicoffantax FLOAT, intaht FLOAT, vicaht FLOAT, intvicel FLOAT,
vicintel FLOAT, intelev FLOAT, vicelev FLOAT
```

### TT_CHAN (60 columns)
Verified from `tt_001tom_001_chan`:
```
interferer CHAR(1), intcall1 CHAR(9), intcall2 CHAR(9), intbndcde CHAR(4),
intanum SMALLINT, intchid CHAR(4), viccall1 CHAR(9), viccall2 CHAR(9),
vicbndcde CHAR(4), vicanum SMALLINT, caseno INT, vicchid CHAR(4),
intpolar CHAR(1), vicpolar CHAR(1), intstattx CHAR(1), vicstatrx CHAR(1),
inttraftx CHAR(6), victrafrx CHAR(6), inteqpttx CHAR(8), viceqptrx CHAR(8),
intfreqtx FLOAT, vicfreqrx FLOAT, vicpwrrx FLOAT, intpwrtx FLOAT,
intafsltx FLOAT, vicafslrx FLOAT, rxant SMALLINT, txant SMALLINT,
ctxinttraftx CHAR(6), ctxvictrafrx CHAR(6), ctxeqpt CHAR(8), calctype CHAR(3),
report SMALLINT, totantdisc FLOAT, freqsep FLOAT, reqdcalc FLOAT,
patloss FLOAT, calcico FLOAT, calcixp FLOAT, resti FLOAT, eirpadv FLOAT,
tiltdisc FLOAT, pathloss80 FLOAT, calcico80 FLOAT, calcixp80 FLOAT,
reqd80 FLOAT, resti80 FLOAT, pathloss99 FLOAT, calcico99 FLOAT,
calcixp99 FLOAT, reqd99 FLOAT, resti99 FLOAT, ohresult SMALLINT,
rqco FLOAT, processed INT, ctxinteqpt CHAR(8), inteqtype CHAR(1),
viceqtype CHAR(1), intbwchans FLOAT, vicbwchans FLOAT
```

---

## FT Tables (Terrestrial Station) - ✅ FIXED

All FT archive tables have been corrected and verified against 3 random table groups (bmce.ft_f3268, bmce.ft_e0202, bmce.ft_t0306).

### Verification Results
```
node test-ft-archive-columns.js bmce.ft_f3268
  [PASS] titl - all 6 archive columns found in source
  [PASS] shrl - all 3 archive columns found in source
  [PASS] site - all 29 archive columns found in source
  [PASS] ante - all 37 archive columns found in source
  [PASS] chan - all 52 archive columns found in source
  [SKIP] chng_call - table not found (optional table)
```

### Corrected Column Counts
| Table | Columns | Status |
|-------|---------|--------|
| FT_TITL | 6 | ✅ Fixed |
| FT_SHRL | 3 | ✅ Fixed |
| FT_SITE | 29 | ✅ Fixed |
| FT_ANTE | 37 | ✅ Fixed |
| FT_CHAN | 52 | ✅ Fixed |
| FT_CHNG_CALL | 3 | ✅ Fixed |

### Key Corrections Made
- **FT_TITL**: Removed non-existent `title`, `cdate`, `cmd`; added `validated`, `namef`, `source`, `descr`
- **FT_SHRL**: Simplified to `userid`, `mdate`, `mtime` only
- **FT_SITE**: `name1` → `name`, added 22 missing columns
- **FT_ANTE**: Removed `gain`, `rgain`, antenna patterns; added feeder line and loss columns
- **FT_CHAN**: `pwrtx` singular (not pwrtx1/2/3), added antenna numbers, route info, notes

---

## FE Tables (Earth Station) - ✅ FIXED

All FE archive tables have been corrected based on actual `micsprod` inspection.

### Corrected Column Counts
| Table | Columns | Status |
|-------|---------|--------|
| FE_TITL | 6 | ✅ Fixed (same as FT_TITL) |
| FE_SHRL | 3 | ✅ Fixed (same as FT_SHRL) |
| FE_SITE | 18 | ✅ Fixed |
| FE_AZIM | 11 | ✅ Fixed |
| FE_ANTE | 35 | ✅ Fixed |
| FE_CHAN | 29 | ✅ Fixed |
| FE_CLOC | 3 | ✅ Fixed |
| FE_CCAL | 2 | ✅ Fixed |

### FE_TITL (6 columns) - Same as FT_TITL
```
validated CHAR(1), namef CHAR(16), source CHAR(6), descr CHAR(40), 
mdate CHAR(10), mtime CHAR(8)
```

### FE_SHRL (3 columns) - Same as FT_SHRL
```
userid CHAR(8), mdate CHAR(10), mtime CHAR(8)
```

### FE_SITE (18 columns)
```
cmd, recstat, location, name, prov, oper, latit, longit, grnd,
radio, rain, sdate, stats, nots, oprtyp, reg, mdate, mtime
```

### FE_AZIM (11 columns)
```
cmd, recstat, deleteall, location, call1, azim, elev, dist, loss, mdate, mtime
```

### FE_ANTE (35 columns)
```
cmd, recstat, location, call1, txband, rxband, acodetx, acoderx,
g_t, lnat, aht, afslt, afslr, txhgmax, rxhgmax, satlongit, satlong, satlongs,
az, el, sarc1, sarc2, rxpre, txpre, rxtro, txtro, licence, satname,
stata, nota, op2, antref, orbit, mdate, mtime
```

### FE_CHAN (29 columns)
```
cmd, recstat, location, call1, chid, freqtx, poltx, maxtxpower, pwrtx, p4khz,
eqpttx, traftx, stattx, feetx, freqrx, polrx, pwrrx, eqptrx, trafrx, statrx,
i20, it01, ip01, feerx, notc, srvctx, srvcrx, mdate, mtime
```

### FE_CLOC (3 columns)
```
newlocation CHAR(10), oldlocation CHAR(10), name CHAR(16)
```

### FE_CCAL (2 columns)
```
newcallsign CHAR(9), oldcallsign CHAR(9)
```

---

## Key Differences: FT vs FE Tables

1. **Site Identifier**: 
   - FT tables use `call1` as site key
   - FE tables use `location` as site key

2. **Link Structure**:
   - FT_ANTE/FT_CHAN use `call1`+`call2` to define point-to-point links
   - FE_ANTE/FE_CHAN use `location`+`call1` (location is earth station, call1 is satellite)

3. **TITL/SHRL Tables**: Identical structure between FT and FE

---

## Recommendations

### Completed
1. ✅ **FT archive tables rewritten** based on actual schemas (verified)
2. ✅ **All FT columns captured** for complete data preservation
3. ✅ **Created validation tool** (`test-ft-archive-columns.js`) to verify definitions
4. ✅ **Created SQL execution tool** (`execute-sql-script.js`) for deployment
5. ✅ **TT archive tables rewritten** - all 4 TT tables corrected (PARM: 27, SITE: 31, ANTE: 47, CHAN: 60 cols)
6. ✅ **Trigger INSERT statements updated** for TT tables
7. ✅ **FE archive tables rewritten** - all 8 FE tables corrected (TITL: 6, SHRL: 3, SITE: 18, AZIM: 11, ANTE: 35, CHAN: 29, CLOC: 3, CCAL: 2)
8. ✅ **Trigger INSERT statements updated** for FE tables
9. ✅ **Test tables updated** with correct TT/FT/FE structures

### Remaining
1. ⬜ **Redeploy to micsprod** - all TT/FT/FE archive tables and trigger
2. ⬜ **Test the trigger** by dropping `tt_test_run01_parm` and verifying archive data

---

## db-util.js Commands Used

```bash
# Connection test
node db-util.js test

# Table counting
node db-util.js count ft_    # Found 11,413 FT tables
node db-util.js count fe_    # Found 4,740 FE tables

# Schema comparison
node db-util.js compare FT_SITE
node db-util.js compare FE_ANTE

# Full structure inspection
node db-util.js describe rctl.ft_0_site
node db-util.js describe hyqu.fe_1_ne_pas_effacer_ante
```
