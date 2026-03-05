# TSIP Archive Capture Scripts

Scripts to capture TSIP run data and source inputs using two complementary triggers.

## Architecture Overview

| Data Type | Archive Trigger | Trigger Type | Why |
|-----------|----------------|--------------|-----|
| **TT** (Results) | `DROP TABLE tt_*` | DDL trigger on DATABASE | TT tables only exist after TSIP run |
| **FT** (Source) | `INSERT INTO tsip_queue` | DML trigger on table | Source data exists before run |
| **FE** (Source) | `INSERT INTO tsip_queue` | DML trigger on table | Source data exists before run |

### Why Two Triggers?

The external TSIP process drops TT tables when finished, and we can't control that timing. Attempting to archive FT/FE tables from within a DDL `DROP_TABLE` trigger caused transaction issues due to SQL Server's `ROLLBACK` behavior.

**Solution**: Archive FT/FE source data *before* the TSIP run begins (when the job is queued), and archive TT results *after* the run (when tables are dropped).

## What Gets Archived

### TT (TSIP Results) - 4 Tables
| Archive Table | Source Table | Purpose |
|---------------|--------------|---------|
| `ArchiveTT_PARM` | `tt_{runkey}_parm` | Run parameters |
| `ArchiveTT_SITE` | `tt_{runkey}_site` | Site analysis results |
| `ArchiveTT_ANTE` | `tt_{runkey}_ante` | Antenna analysis results |
| `ArchiveTT_CHAN` | `tt_{runkey}_chan` | Channel analysis results |

**Linked by**: `RunKey` (e.g., "test_run01")

### FT (Terrestrial Station Source) - 6 Tables
| Archive Table | Source Table | Purpose |
|---------------|--------------|---------|
| `ArchiveFT_TITL` | `ft_{proname}_titl` | Title/metadata |
| `ArchiveFT_SHRL` | `ft_{proname}_shrl` | Shared link approvals |
| `ArchiveFT_SITE` | `ft_{proname}_site` | Site information |
| `ArchiveFT_ANTE` | `ft_{proname}_ante` | Antenna information |
| `ArchiveFT_CHAN` | `ft_{proname}_chan` | Channel information |
| `ArchiveFT_CHNG_CALL` | `ft_{proname}_chng_call` | Call sign changes |

**Linked by**: `TQ_Job` (queue job ID)

### FE (Earth Station Source) - 8 Tables
| Archive Table | Source Table | Purpose |
|---------------|--------------|---------|
| `ArchiveFE_TITL` | `fe_{envname}_titl` | Title/metadata |
| `ArchiveFE_SHRL` | `fe_{envname}_shrl` | Shared link approvals |
| `ArchiveFE_SITE` | `fe_{envname}_site` | Site information |
| `ArchiveFE_AZIM` | `fe_{envname}_azim` | Azimuth records |
| `ArchiveFE_ANTE` | `fe_{envname}_ante` | Antenna information |
| `ArchiveFE_CHAN` | `fe_{envname}_chan` | Channel information |
| `ArchiveFE_CLOC` | `fe_{envname}_cloc` | Location changes |
| `ArchiveFE_CCAL` | `fe_{envname}_ccal` | Call sign changes |

**Linked by**: `TQ_Job` (queue job ID)

## Scripts

| # | Script | Purpose |
|---|--------|---------|
| 00 | `00_create_schema_and_archive_tables.sql` | Creates `tsip_archive` schema and all 18 archive tables |
| 01 | `01_create_sample_tt_tables.sql` | Creates sample TT, FT, FE tables with test data (reference) |
| 02 | `02_create_drop_trigger.sql` | Creates DDL trigger for TT archiving on DROP TABLE |
| 03 | `03_create_schema_lookup_function.sql` | Creates helper function to map MicsID to schema |
| 04 | `04_create_queue_insert_trigger.sql` | Creates INSERT trigger on tsip_queue for FT/FE archiving |
| 05 | `05_test_and_verify.sql` | **Self-contained test** - creates test data and verifies both triggers |
| 06 | `06_cleanup_triggers.sql` | Removes triggers and function (for uninstall) |

## Deployment Order

1. **Schema & Tables**: Run `00_create_schema_and_archive_tables.sql`
2. **Helper Function**: Run `03_create_schema_lookup_function.sql`
3. **TT Trigger**: Run `02_create_drop_trigger.sql`
4. **FT/FE Trigger**: Run `04_create_queue_insert_trigger.sql`
5. **Verify**: Run `05_test_and_verify.sql` to test the complete solution

**Note**: Replace `[YourDatabase]` in each script with your actual database name.

## Testing

The test script (`05_test_and_verify.sql`) is self-contained and:
- Creates test tables in `dbo` schema (TT) and a valid user schema like `bchy` (FT/FE)
- Tests FT/FE archiving via an INSERT into `web.tsip_queue`
- Tests TT archiving via DROP TABLE commands
- Verifies all 18 archive tables are populated correctly

**Status**: Tested successfully on micsprod (2026-02-04)

**Note**: The DDL trigger displays "transaction ended in trigger" messages - this is expected behavior due to the ROLLBACK + re-DROP architecture and does not indicate failure.

## Data Flow

```
                                  ┌─────────────────┐
                                  │ web.tsip_queue  │
                                  │ INSERT trigger  │
                                  └────────┬────────┘
                                           │
                         ┌─────────────────┼─────────────────┐
                         │                 │                 │
                         ▼                 │                 ▼
              ┌──────────────────┐         │      ┌──────────────────┐
              │  FT Archive      │         │      │  FE Archive      │
              │  (6 tables)      │         │      │  (8 tables)      │
              │  TQ_Job (FK)     │         │      │  TQ_Job (FK)     │
              └──────────────────┘         │      └──────────────────┘
                                           │
                                           ▼
                                  ┌────────────────┐
                                  │  TSIP Runs...  │
                                  │  Creates TT    │
                                  │  tables        │
                                  └────────┬───────┘
                                           │
                                           ▼
                                  ┌────────────────┐
                                  │  DROP TT       │
                                  │  tables        │
                                  │  DDL trigger   │
                                  └────────┬───────┘
                                           │
                                           ▼
                                  ┌──────────────────┐
                                  │  TT Archive      │
                                  │  (4 tables)      │
                                  │  RunKey (FK)     │
                                  └──────────────────┘
```

## MicsID to Schema Mapping

The `fn_GetSchemaFromMicsID` function handles variable-length MicsIDs:

| MicsID | Derived Schema |
|--------|----------------|
| `rctl6` | `rctl` |
| `rctl13` | `rctl` |
| `bchy2` | `bchy` |
| `glw1` | `glw` |

**Algorithm**: Find the longest schema name that is a prefix of the MicsID.

## Query Examples

### Get FT/FE source data by job ID

```sql
DECLARE @TQ_Job INT = 12345;

-- FT Source
SELECT * FROM tsip_archive.ArchiveFT_TITL WHERE TQ_Job = @TQ_Job;
SELECT * FROM tsip_archive.ArchiveFT_SITE WHERE TQ_Job = @TQ_Job;
SELECT * FROM tsip_archive.ArchiveFT_CHAN WHERE TQ_Job = @TQ_Job;

-- FE Source
SELECT * FROM tsip_archive.ArchiveFE_TITL WHERE TQ_Job = @TQ_Job;
SELECT * FROM tsip_archive.ArchiveFE_SITE WHERE TQ_Job = @TQ_Job;
SELECT * FROM tsip_archive.ArchiveFE_CHAN WHERE TQ_Job = @TQ_Job;
```

### Get TT results by RunKey

```sql
DECLARE @RunKey NVARCHAR(128) = 'test_run01';

SELECT * FROM tsip_archive.ArchiveTT_PARM WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveTT_SITE WHERE RunKey = @RunKey;
SELECT * FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = @RunKey;
```

### Archive summary by job

```sql
SELECT 
    tq.TQ_Job,
    tq.TQ_ArgFile,
    tq.TQ_MicsID,
    -- FT counts
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SITE WHERE TQ_Job = tq.TQ_Job) AS FT_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_CHAN WHERE TQ_Job = tq.TQ_Job) AS FT_Channels,
    -- FE counts  
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SITE WHERE TQ_Job = tq.TQ_Job) AS FE_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_CHAN WHERE TQ_Job = tq.TQ_Job) AS FE_Channels
FROM web.tsip_queue tq
WHERE TQ_Status = 'F'  -- Finished jobs
ORDER BY TQ_Job DESC;
```

## Table Count Summary

| Category | Tables | Triggered By |
|----------|--------|--------------|
| TT Results | 4 | DROP TABLE |
| FT Source | 6 | INSERT tsip_queue |
| FE Source | 8 | INSERT tsip_queue |
| **Total** | **18** | |

## Related Documentation

- [tsip-queue-analysis.md](../../tsip-queue-analysis.md) - Detailed analysis of the tsip_queue table structure
- [database-tables.md](../../database-tables.md) - Complete database schema documentation
