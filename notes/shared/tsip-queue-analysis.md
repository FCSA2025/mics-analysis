# TSIP Queue Table Analysis

**Date**: 2026-02-04  
**Database**: micsprod

## Overview

The `web.tsip_queue` table is the central job queue for TSIP (Terrestrial Station Interference Processor) analysis runs. Understanding this table is critical for implementing source data archiving.

## Table Structure

```sql
web.tsip_queue
├── TQ_Job         INT (PK)      -- Job ID, unique identifier
├── TQ_Status      CHAR(1)       -- Status: 'F' = Finished, etc.
├── TQ_Finish      INT           -- Finish code
├── TQ_ArgDB       CHAR(4)       -- Database argument
├── TQ_ArgPC       CHAR(11)      -- PC/workstation identifier
├── TQ_ArgDest     VARCHAR(255)  -- Destination (typically 'tsip')
├── TQ_ArgFile     VARCHAR(255)  -- Analysis file name (KEY FIELD)
├── TQ_ProcID      INT           -- Process ID
├── TQ_EventName   CHAR(32)      -- Windows event name
├── TQ_MicsID      CHAR(32)      -- MICS user identifier (KEY FIELD)
├── TQ_TimeIn      DATETIME      -- Time job was queued
├── TQ_TimeStart   DATETIME      -- Time job started
└── TQ_TimeEnd     DATETIME      -- Time job completed
```

## Key Relationships

### TQ_MicsID → Database Schema

The `TQ_MicsID` field (e.g., 'rctl6', 'bchy2', 'bmce3') maps to a database schema where the user's tables reside.

**Important**: MicsID values have variable length suffixes:
- 'rctl1' and 'rctl13' both map to schema 'rctl'
- 'bchy6' maps to schema 'bchy'

**Mapping Algorithm**: Find the longest schema name that is a prefix of the MicsID:
```sql
SELECT TOP 1 s.name 
FROM sys.schemas s 
WHERE RTRIM(@MicsID) LIKE s.name + '%'
ORDER BY LEN(s.name) DESC
```

### TQ_ArgFile → Configuration Tables

The `TQ_ArgFile` field links to TSIP configuration tables:
- `<schema>.tp_<TQ_ArgFile>_parm` - TS (Terrestrial Station) analysis parameters
- `<schema>.te_<TQ_ArgFile>_ES_parm` - ES (Earth Station) analysis parameters

### Configuration → Source Data Tables

The `tp_*_parm` and `te_*_parm` tables contain:
- `proname` - Name of the FT (Terrestrial Station) source file → `ft_<proname>_*` tables
- `envname` - Name of the FE (Earth Station) source file → `fe_<envname>_*` tables

## Data Flow

```
Job Queued (INSERT into tsip_queue)
    │
    ├── TQ_MicsID: 'bchy6' ──────────────→ Schema: 'bchy'
    │
    └── TQ_ArgFile: 'new11ghzdnd_v5' ────→ Config: bchy.tp_new11ghzdnd_v5_parm
                                                    │
                                                    ├── proname: 'new11ghzdnd_v5'
                                                    │   └── FT tables: ft_new11ghzdnd_v5_*
                                                    │
                                                    └── envname: (often empty)
                                                        └── FE tables: fe_<envname>_*
```

## Sample Data

| TQ_Job | TQ_ArgFile       | TQ_MicsID | Derived Schema |
|--------|------------------|-----------|----------------|
| 12453  | 01rng            | rctl6     | rctl           |
| 12452  | m_int_ts         | glw3      | glw            |
| 12451  | vp_new_h0119     | bmce2     | bmce           |
| 12445  | new11ghzdnd_v5   | bchy6     | bchy           |

## Source Data Table Types

### FT Tables (Terrestrial Station) - tabletype=0 in user_tables
- `ft_<proname>_titl` - Title/metadata
- `ft_<proname>_shrl` - Shared link info
- `ft_<proname>_site` - Site catalog (29 columns)
- `ft_<proname>_ante` - Antenna data (37 columns)
- `ft_<proname>_chan` - Channel data (52 columns)
- `ft_<proname>_chng_call` - Call sign changes

### FE Tables (Earth Station) - tabletype=5 in user_tables
- `fe_<envname>_titl` - Title/metadata
- `fe_<envname>_shrl` - Shared link info
- `fe_<envname>_site` - Site info (18 columns)
- `fe_<envname>_azim` - Azimuth records (11 columns)
- `fe_<envname>_ante` - Antenna data (35 columns)
- `fe_<envname>_chan` - Channel data (29 columns)
- `fe_<envname>_cloc` - Location changes
- `fe_<envname>_ccal` - Call sign changes

## Archiving Strategy

### When to Archive

| Data Type | Archive Trigger Point | Trigger Mechanism |
|-----------|----------------------|-------------------|
| FT tables | Job queued (INSERT into tsip_queue) | DML INSERT trigger |
| FE tables | Job queued (INSERT into tsip_queue) | DML INSERT trigger |
| TT tables | Table dropped (DROP TABLE tt_*) | DDL DROP_TABLE trigger |

### Why This Strategy

1. **FT/FE at queue time**: The `tp_*_parm` table exists and contains `proname`/`envname` before TSIP runs
2. **TT at drop time**: TT tables are created by TSIP during the run, only exist after completion
3. **Separation**: Avoids DDL trigger ROLLBACK issues that prevented combined archiving

## Available Schemas (User Schemas)

The following schemas exist in micsprod for user data:
- abccom, aliant, bchy, bell, bmce, bragg, compa, comph
- dnd, fcsa, fmda, fmda2, foad, frfas, frfcs, frse, ftrain
- glw, hulme, hyone, hyqu, koza, mda, mts, navi, nono
- nttel, nwt, ont, rctl, shaw, stel, tbay, TekSav, tels
- terago, tlusab, tlusbc, tlusmc, tlusqc, vdtr, venn, wireie, xci, zayo

## Notes

- Most TSIP runs only use `proname` (FT/TS analysis) - `envname` is often empty
- The `web.user_tables` table tracks all FT/FE files with `tabletype` field:
  - 0 = FT files (1875 entries)
  - 5 = FE files (552 entries)
  - 417 = Mixed/other (576 entries)
