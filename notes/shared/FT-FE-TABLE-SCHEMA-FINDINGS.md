# FT/FE Table Schema Verification Findings

**Date**: February 4, 2026  
**Last Updated**: February 4, 2026  
**Database**: micsprod  
**Tool Used**: `db-util.js`, `test-ft-archive-columns.js`

## Summary

Direct database inspection revealed **significant discrepancies** between our original archive table definitions and actual production database schemas.

### Status
- **FT Tables**: ✅ **FIXED** - All 6 FT archive tables corrected and verified against 3 random table groups
- **FE Tables**: ⚠️ **PENDING** - Analysis and fixes still needed

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

## FE Tables (Earth Station) - ⚠️ PENDING FIXES

### FE_TITL (Title/Header)
**Same structure as FT_TITL**:
```
validated CHAR(1), namef CHAR(16), source CHAR(6), descr CHAR(40), 
mdate CHAR(10), mtime CHAR(8)
```

### FE_SHRL (Shared List/Users)
**Same structure as FT_SHRL**:
```
userid CHAR(8), mdate CHAR(10), mtime CHAR(8)
```

### FE_SITE (Site Information)
**Actual columns (18 total)**:
```
cmd, recstat, location(PK), name, prov, oper, latit, longit, grnd, 
radio, rain, sdate, stats, nots, oprtyp, reg, mdate, mtime
```

**Archive errors**:
- `rainzone` should be `rain`
- `radiozone` should be `radio`
- Missing 9 columns

### FE_AZIM (Azimuth)
**Actual columns (11 total)**:
```
cmd, recstat, deleteall, location(PK), call1(PK), azim(PK), elev, 
dist, loss, mdate, mtime
```

**Archive errors**:
- `az1`, `az2`, `el1`, `el2` don't exist
- Uses `azim`, `elev` instead
- Missing 5 columns

### FE_ANTE (Antenna)
**Actual columns (35 total)**:
```
cmd, recstat, location(PK), call1(PK), txband, rxband, acodetx, 
acoderx, g_t, lnat, aht, afslt, afslr, txhgmax, rxhgmax, satlongit, 
satlong, satlongs, az, el, sarc1, sarc2, rxpre, txpre, rxtro, txtro, 
licence, satname, stata, nota, op2, antref, orbit, mdate, mtime
```

**Archive errors**:
- `band` should be `txband`/`rxband`
- `satoper` doesn't exist
- Missing 22 columns

### FE_CHAN (Channel)
**Actual columns (29 total)**:
```
cmd, recstat, location(PK), call1(PK), chid(PK), freqtx, poltx, 
maxtxpower, pwrtx, p4khz, eqpttx, traftx, stattx, feetx, freqrx, 
polrx, pwrrx, eqptrx, trafrx, statrx, i20, it01, ip01, feerx, notc, 
srvctx, srvcrx, mdate, mtime
```

**Archive errors**:
- `band` doesn't exist
- `eirp` doesn't exist
- Missing 13 columns

### FE_CLOC (Location Change)
| Archive Definition | Actual Structure |
|-------------------|------------------|
| oldlocation CHAR(10) | oldlocation CHAR(10) |
| newlocation CHAR(10) | newlocation CHAR(10) |
| chngdate CHAR(10) | - |
| cmd CHAR(1) | - |
| - | name CHAR(16) |

**Status**: 50% match

### FE_CCAL (Call Sign Change)
| Archive Definition | Actual Structure |
|-------------------|------------------|
| location CHAR(10) | - |
| oldcall1 CHAR(9) | - |
| newcall1 CHAR(9) | - |
| chngdate CHAR(10) | - |
| cmd CHAR(1) | - |
| - | newcallsign CHAR(9) |
| - | oldcallsign CHAR(9) |

**Status**: 0% match - completely different column names

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

### Remaining
1. ⬜ **FE archive tables need same treatment** - verify against actual FE tables
2. ⬜ **Create FE validation test** similar to FT test
3. ⬜ **Update trigger INSERT statements** for FE tables after verification

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
