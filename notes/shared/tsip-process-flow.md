# TSIP Interference Analysis - Process Flow

This document describes the high-level process flow for TSIP (Terrestrial Station Interference Processor) interference analysis in the MICS# system.

---

## Overview

TSIP analyzes whether **proposed radio systems** will cause interference with **existing radio systems** (the "environment"). It calculates the **C/I (Carrier-to-Interference) ratio** or **interference margin** for every potential interferer-victim pair.

---

## High-Level Process Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    TSIP INTERFERENCE ANALYSIS                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  INPUT                                                          │
│  • Proposed PDF (new/modified radio systems)                    │
│  • Environment (MDB master database OR another PDF)             │
│  • Parameters (coordination distance, margin, freq separation)  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: ROUGH CULL (Server-side SQL)                          │
│  • Distance filter (coordination distance + keyhole)            │
│  • Band adjacency filter (same/adjacent frequency bands)        │
│  • Operator/call sign filter (if specified)                     │
│  Result: Reduces millions of sites to thousands                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: SITE PAIRS                                            │
│  • Geometry calculations (distance, azimuth, bearing)           │
│  • Keyhole check (±5° off-axis gets 2× distance allowance)      │
│  • Skip invalid pairs (same site, etc.)                         │
│  Result: Valid interferer-victim site pairs                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: ANTENNA PAIRS                                         │
│  • Off-axis angle calculations                                  │
│  • Antenna discrimination (pattern rolloff)                     │
│  • Elevation angles                                             │
│  Result: Antenna pair records with discrimination values        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: CHANNEL PAIRS (Core Calculations)                     │
│  • Frequency separation                                         │
│  • Path loss (free space + terrain/over-horizon)                │
│  • EIRP (transmit power + antenna gain)                         │
│  • CTX lookup (required C/I for traffic type pair)              │
│  • Calculate: Margin = Calculated_CI - Required_CI              │
│  Result: Interference margin for each channel pair              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  OUTPUT                                                         │
│  • TT/TE tables (SITE, ANTE, CHAN with results)                 │
│  • Reports (.CASEDET, .CASESUM, .AGGINT, etc.)                  │
│  • Margin: Positive = OK, Negative = Potential Interference     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Calculation: Interference Margin

The fundamental calculation performed by TSIP is the **interference margin**:

```
Margin (dB) = Calculated_C/I - Required_C/I
```

### Where:

**Calculated_C/I** = Victim_Rx_Power - Interferer_Power_at_Victim

**Interferer_Power_at_Victim** = 
```
  Tx_Power 
  + Tx_Antenna_Gain 
  - Tx_Antenna_Discrimination
  - Path_Loss
  - Rx_Antenna_Discrimination
  + Rx_Antenna_Gain
```

**Required_C/I** = From CTX table (based on traffic types & equipment)

### Result Interpretation

- **Positive margin** → No interference (passes protection criteria)
- **Negative margin** → Potential interference (fails protection criteria, needs investigation)

---

## Analysis Types

TSIP supports multiple interference analysis scenarios:

| Type | Code Module | Description |
|------|-------------|-------------|
| **TS-TS** | `TtBuildSH` | Terrestrial Station ↔ Terrestrial Station |
| **TS-ES** | `TeBuildSH` | Terrestrial Station ↔ Earth Station |
| **ES-TS** | `TeBuildSH` | Earth Station ↔ Terrestrial Station |
| **INTRA** | Special mode | Within same PDF (intra-system interference) |

---

## Detailed Processing Stages

### Stage 1: Rough Cull (Server-Side SQL)

**Purpose**: Efficiently filter millions of environment sites down to thousands using database queries.

**Methods**:
- **Distance filter**: Uses SQL Server function `tsip.keyhole_hs()` to check if sites fall within coordination distance or keyhole area
- **Band adjacency**: Filters by frequency bands that are the same or adjacent to the proposed system
- **Operator/call sign filter**: If user specifies operator codes or call signs, only those are considered

**Location**: `TtBuildSH.cs` → `GenRoughCull()`

**Example SQL WHERE clause**:
```sql
(tsip.keyhole_hs(123456, -789012, latit, longit, 45.5, 100.0) <= 2) 
AND (bandwd1 & 0x0000000f != 0 or bandwd2 & 0x00000003 != 0)
AND (oper = 'TELCO1' or oper = 'TELCO2')
```

---

### Stage 2: Site Pairs

**Purpose**: Validate and create site pair records for further analysis.

**Processing**:
1. **Geometry calculations**: Distance, azimuth, bearing between sites
2. **Keyhole check**: Sites within ±5° of antenna boresight get 2× coordination distance allowance
3. **Invalid pair filtering**: Skip same site, invalid combinations
4. **Site record creation**: Populate `TT_SITE` or `TE_SITE` tables

**Location**: `TtBuildSH.cs` → `Vic2DimTable()`, `IntVicSiteCull()`, `SetBothSites()`

**Key fields calculated**:
- `int1vic1dist` - Distance between interferer and victim
- `intvicaz` - Azimuth from interferer to victim
- `vicintaz` - Azimuth from victim to interferer
- `intoffax`, `vicoffax` - Off-axis angles

---

### Stage 3: Antenna Pairs

**Purpose**: Process all antenna combinations for each valid site pair.

**Processing**:
1. **Nested loops**: For each proposed antenna × each environment antenna
2. **Off-axis calculations**: Angle between antenna boresight and interferer/victim direction
3. **Antenna discrimination**: Lookup discrimination values from antenna pattern tables
4. **Elevation angles**: Calculate elevation angles for path analysis
5. **Antenna record creation**: Populate `TT_ANTE` or `TE_ANTE` tables

**Location**: `TtBuildSH.cs` → `CreateAnteSHTable()`

**Key fields calculated**:
- `adiscctxh`, `adiscctxv` - Antenna discrimination (co-polar, horizontal/vertical)
- `adisccrxh`, `adisccrxv` - Cross-polar discrimination
- `intgain`, `vicgain` - Antenna gains
- `intaht`, `vicaht` - Antenna heights

---

### Stage 4: Channel Pairs (Core Calculations)

**Purpose**: Perform the actual interference calculations at the channel level.

**Processing**:
1. **Frequency separation**: Calculate frequency difference between interferer TX and victim RX
2. **Path loss**: 
   - Line-of-sight: Free space path loss
   - Over-horizon: Uses `_OHloss` library for terrain diffraction
3. **EIRP calculation**: Effective Isotropic Radiated Power (transmit power + antenna gain)
4. **CTX lookup**: Retrieve required C/I from `sd_ctx` table based on:
   - Traffic types (interferer TX, victim RX)
   - Equipment types
   - Frequency separation
5. **Margin calculation**: `resti = Calculated_C/I - Required_C/I`

**Location**: `TtCalcs.cs` → `TtChanCalcs()`, `TeCalcs.cs` → `TeChanCalcs()`

**Key result fields** (in `TT_CHAN` / `TE_CHAN` tables):
- `freqsep` - Frequency separation (MHz)
- `patloss` - Path loss (dB)
- `calcico` - Calculated C/I (co-polar)
- `calcixp` - Calculated C/I (cross-polar)
- `reqdcalc` - Required C/I from CTX table
- `resti` - **MARGIN (dB)** - Primary result field
- `resti80`, `resti99` - Margins at 80% and 99% time availability (over-horizon)
- `ohresult` - Over-horizon calculation status

---

## Culling Hierarchy

The system implements a **multi-stage culling** strategy to efficiently reduce the number of calculations:

| Stage | Method | Filter Criteria | Efficiency Gain |
|-------|--------|-----------------|----------------|
| 1 | `GenRoughCull()` | Distance (keyhole), band adjacency, operator codes | ~1000× reduction |
| 2 | `IntVicSiteCull()` | Geometry, province, distance | ~10× reduction |
| 3 | `SitePairsCull()` | Invalid site combinations | ~2× reduction |
| 4 | Keyhole Cull | Off-axis ≤5° OR distance ≤2× coordination | ~5× reduction |
| 5 | Band Adjacency | `SuIsBandAdjacent()` | ~2× reduction |
| 6 | Antenna Cull | Per-antenna criteria | ~3× reduction |
| 7 | Channel Cull | Frequency separation, status | ~2× reduction |

**Total efficiency**: Roughly 1,200,000× reduction from all sites to final channel pairs.

---

## Data Flow

```
Input: Proposed PDF + Environment (MDB/PDF/INTRA)
         │
         ▼
    ┌─────────────────┐
    │  Rough Cull     │  SQL WHERE clause filters environment
    │  (Server-side)  │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Site Pairs     │  Geometry, distance, keyhole
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Antenna Pairs  │  Off-axis, discrimination
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Channel Pairs  │  Frequency, C/I calculations
    └────────┬────────┘
             │
             ▼
Output: TT_SITE, TT_ANTE, TT_CHAN tables with interference results
```

---

## Key Components

### Main Entry Points

- **TS-TS Analysis**: `TpRunTsip.cs` → `TtBuildSH.TtBuildSHTable()`
- **TS-ES Analysis**: `TpRunTsip.cs` → `TeBuildSH.TeBuildSHTable()`

### Core Processing Modules

- **Table Building**: `TtBuildSH.cs`, `TeBuildSH.cs`
- **Calculations**: `TtCalcs.cs`, `TeCalcs.cs`
- **Database Operations**: `TtDynSite.cs`, `TtDynAnte.cs`, `TtDynChan.cs`
- **Over-Horizon**: `_OHloss` library

### Supporting Modules

- **Culling**: `GenRoughCull()`, `IntVicSiteCull()`, `SitePairsCull()`
- **Geometry**: `TtCalcs.TtSiteCalcs()`, `TpKeyhole.WithinRange()`
- **Antenna**: `CreateAnteSHTable()`, antenna discrimination lookups
- **Channel**: `CreateChanSHTable()`, `TtChanCalcs()`, `TeChanCalcs()`

---

## Output Tables

All results are stored in dynamically-named tables:

### TS-TS Tables (prefix: `tt_`)
- `tt_{name}_{run}_parm` - Run parameters
- `tt_{name}_{run}_site` - Site pair records
- `tt_{name}_{run}_ante` - Antenna pair records
- `tt_{name}_{run}_chan` - **Channel interference results** (primary output)

### TS-ES Tables (prefix: `te_`)
- `te_{name}_{run}_parm` - Run parameters
- `te_{name}_{run}_site` - TS-ES site pairs
- `te_{name}_{run}_ante` - TS-ES antenna pairs
- `te_{name}_{run}_chan` - **TS-ES channel results** (primary output)

See `notes/database-tables.md` for complete table schemas.

---

## Reports Generated

After analysis completes, multiple report types are generated:

| Report | Extension | Description |
|--------|-----------|-------------|
| Case Detail | `.CASEDET` | Detailed interference case information |
| Case Summary | `.CASESUM` | Summary of interference cases |
| Aggregate Interference | `.AGGINT` | Aggregated interference by victim |
| Executive Summary | `.EXEC` | High-level summary |
| Study Report | `.STUDY` | Study-specific analysis |
| Statistics Summary | `.STATSUM` | Statistical summary |
| Orbit | `.ORBIT` | Satellite orbit calculations (if requested) |
| Export | `.{type}_EXPORT` | Export format for external systems |

---

## Performance Considerations

1. **Server-Side Filtering**: Rough cull uses SQL Server functions to filter at database level
2. **Incremental Processing**: Sites processed one at a time to manage memory
3. **Link-Based Processing**: Antennas organized into links for efficient iteration
4. **Native Code**: Some calculations use P/Invoke to native C/C++ DLLs for performance
5. **Parallel Processing**: Not currently implemented (single-threaded)

---

## Source Code References

- **Main orchestration**: `TpRunTsip\TpRunTsip.cs` (Main method)
- **TS-TS processing**: `TpRunTsip\TtBuildSH.cs`
- **TS-ES processing**: `TpRunTsip\TeBuildSH.cs`
- **TS-TS calculations**: `TpRunTsip\TtCalcs.cs`
- **TS-ES calculations**: `TpRunTsip\TeCalcs.cs`
- **Database operations**: `TpRunTsip\TtDynSite.cs`, `TtDynAnte.cs`, `TtDynChan.cs`
- **Over-horizon**: `_OHloss` library
- **Antenna patterns**: `_Utillib\Suutils.cs` → antenna discrimination lookups
- **CTX tables**: `_Utillib\Suutils.cs` → CTX protection criteria lookups

---

*Last updated: January 2026*

