# FT/FE Table Schema Verification Findings

**Date**: February 4, 2026  
**Database**: micsprod  
**Tool Used**: `db-util.js`

## Summary

Direct database inspection revealed **significant discrepancies** between our archive table definitions and actual production database schemas. Every archive table definition contained errors.

## FT Tables (Terrestrial Station)

### FT_TITL (Title/Header)
| Archive Definition | Actual Structure |
|-------------------|------------------|
| proname CHAR(10) | - |
| envname CHAR(10) | - |
| title CHAR(80) | - |
| cdate CHAR(10) | - |
| cmd CHAR(1) | - |
| - | validated CHAR(1) |
| - | namef CHAR(16) |
| - | source CHAR(6) |
| - | descr CHAR(40) |
| - | mdate CHAR(10) |
| - | mtime CHAR(8) |

**Status**: 0% match - completely different columns

### FT_SHRL (Shared List/Users)
| Archive Definition | Actual Structure |
|-------------------|------------------|
| call1 CHAR(9) | - |
| call2 CHAR(9) | - |
| bndcde CHAR(4) | - |
| shession CHAR(10) | - |
| approval CHAR(1) | - |
| cmd CHAR(1) | - |
| - | userid CHAR(8) |
| - | mdate CHAR(10) |
| - | mtime CHAR(8) |

**Status**: 0% match - completely different columns

### FT_SITE (Site Information)
**Actual columns (29 total)**:
```
cmd, recstat, call1(PK), name, prov, oper, latit, longit, grnd, stats, 
sdate, loc, icaccount, reg, spoint, nots, oprtyp, snumb, notwr, 
bandwd1-8, mdate, mtime
```

**Archive errors**:
- `name1` should be `name`
- Missing 22 columns

### FT_ANTE (Antenna)
**Actual columns (37 total)**:
```
cmd, recstat, call1(PK), call2(PK), bndcde(PK), anum(PK), ause, acode, 
aht, azmth, elvtn, dist, offazm, tazmth, telvtn, tgain, txfdlnth, 
txfdlnlh, txfdlntv, txfdlnlv, rxfdlnth, rxfdlnlh, rxfdlntv, rxfdlnlv, 
txpadpam, rxpadlna, txcompl, rxcompl, obsloss, kvalue, atwrno, nota, 
apoint, sdate, mdate, mtime, licence
```

**Archive errors**:
- `gain` doesn't exist
- Missing 25 columns

### FT_CHAN (Channel)
**Actual columns (52 total)**:
```
cmd, recstat, call1(PK), call2(PK), bndcde(PK), splan, hl, vh, chid(PK), 
freqtx, poltx, antnumbtx1, antnumbtx2, eqpttx, eqptutx, pwrtx, atpccde, 
afsltx1, afsltx2, traftx, srvctx, stattx, freqrx, polrx, antnumbrx1, 
antnumbrx2, antnumbrx3, eqptrx, eqpturx, afslrx1, afslrx2, afslrx3, 
pwrrx1, pwrrx2, pwrrx3, trafrx, esint, tsint, srvcrx, statrx, routnumb, 
stnnumb, hopnumb, sdate, notetx, noterx, notegnl, cpoint, feetx, feerx, 
mdate, mtime
```

**Archive errors**:
- `pwrrx` should be `pwrrx1`, `pwrrx2`, `pwrrx3`
- Missing 37 columns

### FT_CHNG (Call Sign Change)
| Archive Definition | Actual Structure |
|-------------------|------------------|
| oldcall2 CHAR(9) | - |
| newcall2 CHAR(9) | - |
| chngdate CHAR(10) | - |
| cmd CHAR(1) | - |
| - | newcall1(PK) CHAR(9) |
| - | oldcall1(PK) CHAR(9) |
| - | name CHAR(32) |

**Status**: 33% match - uses call1, not call2

---

## FE Tables (Earth Station)

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

1. **Archive tables need complete rewrite** based on actual schemas
2. **Consider capturing all columns** rather than a subset for complete data preservation
3. **Use SELECT * with dynamic column discovery** in trigger if full capture is needed
4. **Alternative**: Define minimum required columns for TSIP analysis and document what's excluded

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
