# TSIP Archive Capture Scripts (Drop-Trigger Approach)

Scripts to capture TSIP run data and source inputs when tables are dropped, using a DDL trigger.

## What Gets Archived

| Type | Tables | When Captured | Purpose |
|------|--------|---------------|---------|
| **TT** | `ArchiveTT_PARM`, `_SITE`, `_ANTE`, `_CHAN` | When TT tables dropped | TSIP **results** |
| **FT** | 6 tables (see below) | When `TT_PARM` dropped | TS **source data** |
| **FE** | 8 tables (see below) | When `TT_PARM` dropped | ES **source data** |

### FT (Terrestrial Station) Tables - 6 Total

| Archive Table | Source Table | Purpose |
|---------------|--------------|---------|
| `ArchiveFT_TITL` | `ft_{proname}_titl` | Title/metadata |
| `ArchiveFT_SHRL` | `ft_{proname}_shrl` | Shared link approvals |
| `ArchiveFT_SITE` | `ft_{proname}_site` | Site information |
| `ArchiveFT_ANTE` | `ft_{proname}_ante` | Antenna information |
| `ArchiveFT_CHAN` | `ft_{proname}_chan` | Channel information |
| `ArchiveFT_CHNG_CALL` | `ft_{proname}_chng_call` | Call sign change history |

### FE (Earth Station) Tables - 8 Total

| Archive Table | Source Table | Purpose |
|---------------|--------------|---------|
| `ArchiveFE_TITL` | `fe_{envname}_titl` | Title/metadata |
| `ArchiveFE_SHRL` | `fe_{envname}_shrl` | Shared link approvals |
| `ArchiveFE_SITE` | `fe_{envname}_site` | Site information |
| `ArchiveFE_AZIM` | `fe_{envname}_azim` | Azimuth records |
| `ArchiveFE_ANTE` | `fe_{envname}_ante` | Antenna information |
| `ArchiveFE_CHAN` | `fe_{envname}_chan` | Channel information |
| `ArchiveFE_CLOC` | `fe_{envname}_cloc` | Location change history |
| `ArchiveFE_CCAL` | `fe_{envname}_ccal` | Call sign change history |

**Key feature**: FT/FE source data is captured at **run completion time** (when TT_PARM is dropped), not when the PDF tables are eventually deleted. This ensures the archive has the exact source data used for each run.

## Prerequisites

- SQL Server (dev database; e.g. MicsMin, RemicsDev)
- Replace `[YourDatabase]` in each script with your database name

## Scripts

| # | Script | Purpose |
|---|--------|---------|
| 00 | `00_create_schema_and_archive_tables.sql` | Creates `tsip_archive` schema and all 18 archive tables |
| 01 | `01_create_sample_tt_tables.sql` | Creates sample TT (4), FT (6), and FE (8) tables with test data |
| 02 | `02_create_drop_trigger.sql` | Creates DDL trigger `trg_ArchiveTT_OnDropTable` |
| 03 | `03_test_drop_and_verify.sql` | Drops TT tables and verifies all 18 archives |
| 04 | `04_cleanup_trigger.sql` | (Optional) Drops the trigger |

## Running Order

1. Run `00_create_schema_and_archive_tables.sql` - Create all archive tables
2. Run `01_create_sample_tt_tables.sql` - Create test data
3. Run `02_create_drop_trigger.sql` - Create the trigger
4. Run `03_test_drop_and_verify.sql` - Test the archive capture

## Expected Results After Test

**TT (TSIP Results)** - archived when each TT table is dropped:
- `ArchiveTT_PARM`: 1 row (RunKey `test_run01`, proname=`testproj`, envname=`envproj`)
- `ArchiveTT_SITE`, `_ANTE`, `_CHAN`: 3 rows each

**FT (TS Source - 6 tables)** - all archived when TT_PARM is dropped:
- `ArchiveFT_TITL`: 1 row
- `ArchiveFT_SHRL`: 2 rows
- `ArchiveFT_SITE`, `_ANTE`, `_CHAN`: 2 rows each
- `ArchiveFT_CHNG_CALL`: 1 row

**FE (ES Source - 8 tables)** - all archived when TT_PARM is dropped:
- `ArchiveFE_TITL`: 1 row
- `ArchiveFE_SHRL`: 1 row
- `ArchiveFE_SITE`, `_AZIM`, `_ANTE`, `_CHAN`: 2 rows each
- `ArchiveFE_CLOC`: 1 row
- `ArchiveFE_CCAL`: 1 row

**Note**: FT/FE source tables still exist after the test - they're snapshotted, not dropped.

## Data Model

All archives are linked by `RunKey`:

```
                    ┌──────────────────────┐
                    │   ArchiveTT_PARM     │
                    │   (Master Record)    │
                    │   ───────────────    │
                    │   RunKey (PK)        │
                    │   proname ─────────────────┐
                    │   envname ───────────┐     │
                    └──────────────────────┘     │
                              │                  │     │
        ┌─────────────────────┼─────────────────┐     │
        ▼                     ▼                 ▼     │
┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│ArchiveTT_SITE│  │ArchiveTT_ANTE│  │ArchiveTT_CHAN│ │
│  (Results)   │  │  (Results)   │  │  (Results)   │ │
│ RunKey (FK)  │  │ RunKey (FK)  │  │ RunKey (FK)  │ │
└──────────────┘  └──────────────┘  └──────────────┘ │
                                                     │
        ┌────────────────────────────────────────────┘
        │ (proname → FT tables)
        ▼
┌──────────────────────────────────────────────────────────────┐
│ FT (TS Source) - 6 tables                                    │
│ ArchiveFT_TITL, _SHRL, _SITE, _ANTE, _CHAN, _CHNG_CALL       │
│ All linked by: RunKey (FK), PdfName = proname                │
└──────────────────────────────────────────────────────────────┘

        │ (envname → FE tables)
        ▼
┌──────────────────────────────────────────────────────────────┐
│ FE (ES Source) - 8 tables                                    │
│ ArchiveFE_TITL, _SHRL, _SITE, _AZIM, _ANTE, _CHAN, _CLOC,    │
│              _CCAL                                           │
│ All linked by: RunKey (FK), PdfName = envname                │
└──────────────────────────────────────────────────────────────┘
```

## Query Examples

### Get complete run data

```sql
DECLARE @RunKey NVARCHAR(128) = 'test_run01';

-- Run parameters and summary
SELECT * FROM tsip_archive.ArchiveTT_PARM WHERE RunKey = @RunKey;

-- TSIP Results
SELECT * FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = @RunKey;

-- TS Source (all 6 tables as they were at run time)
SELECT * FROM tsip_archive.ArchiveFT_TITL WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFT_SHRL WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFT_SITE WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFT_ANTE WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFT_CHAN WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFT_CHNG_CALL WHERE RunKey = @RunKey;

-- ES Source (all 8 tables as they were at run time)
SELECT * FROM tsip_archive.ArchiveFE_TITL WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_SHRL WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_SITE WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_AZIM WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_ANTE WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_CHAN WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_CLOC WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveFE_CCAL WHERE RunKey = @RunKey;
```

### Run summary with all counts

```sql
SELECT 
    p.RunKey,
    p.ArchivedAt,
    RTRIM(p.proname) AS TS_Pdf,
    RTRIM(p.envname) AS ES_Pdf,
    p.numcases,
    -- TT Results
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = p.RunKey) AS TT_Channels,
    -- FT Source (6 tables)
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_TITL WHERE RunKey = p.RunKey) AS FT_Titl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SHRL WHERE RunKey = p.RunKey) AS FT_Shrl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SITE WHERE RunKey = p.RunKey) AS FT_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_ANTE WHERE RunKey = p.RunKey) AS FT_Ante,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_CHAN WHERE RunKey = p.RunKey) AS FT_Chan,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_CHNG_CALL WHERE RunKey = p.RunKey) AS FT_ChngCall,
    -- FE Source (8 tables)
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_TITL WHERE RunKey = p.RunKey) AS FE_Titl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SHRL WHERE RunKey = p.RunKey) AS FE_Shrl,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SITE WHERE RunKey = p.RunKey) AS FE_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_AZIM WHERE RunKey = p.RunKey) AS FE_Azim,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_ANTE WHERE RunKey = p.RunKey) AS FE_Ante,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CHAN WHERE RunKey = p.RunKey) AS FE_Chan,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CLOC WHERE RunKey = p.RunKey) AS FE_Cloc,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CCAL WHERE RunKey = p.RunKey) AS FE_Ccal
FROM tsip_archive.ArchiveTT_PARM p;
```

## RunKey Parsing

The trigger derives `RunKey` from the table name:
- `tt_test_run01_parm` → RunKey `test_run01`
- Strips `tt_` prefix and `_parm`/`_site`/`_ante`/`_chan` suffix

Temp tables (`tt_%_tmp1`, `tt_%_tmp2`) are not archived.

## Table Count Summary

| Category | Tables | Total Columns (approx) |
|----------|--------|------------------------|
| TT Results | 4 | ~25 |
| FT Source | 6 | ~50 |
| FE Source | 8 | ~60 |
| **Total** | **18** | ~135 |
