# FT/FE Archive Capture Scripts

> **NOTE**: This approach has been **superseded**. FT/FE source data is now captured automatically at TSIP run completion time by the enhanced TT trigger.
>
> **See instead**: `../tt-archive-capture/` - The main archive scripts now capture TT results AND FT/FE source data together, linked by `RunKey`.

---

## Old Approach (Deprecated)

The scripts below used a separate DDL trigger to capture FT/FE data when those tables were dropped. This had a timing problem: the PDF tables might be deleted days after the TSIP run, disconnecting the source data from the run that used it.

## New Approach (Recommended)

The enhanced TT trigger in `../tt-archive-capture/02_create_drop_trigger.sql` now:
1. Captures TT results when TT tables are dropped (existing behavior)
2. **Also captures FT/FE source data** when `TT_PARM` is dropped (new)
3. Links everything via `RunKey` for easy querying

This ensures source data is captured at run completion, not at PDF deletion time.

---

## Legacy: Relationship to TT Archive

These scripts complement the TT (TSIP results) archive capture. Together they provide a complete picture:

| Archive Type | Tables | Key Field | Contains |
|--------------|--------|-----------|----------|
| **TT** | `ArchiveTT_PARM`, `_SITE`, `_ANTE`, `_CHAN` | `RunKey` | Interference analysis **results** |
| **FT** | `ArchiveFT_SITE`, `_ANTE`, `_CHAN` | `PdfName` | Terrestrial Station **source data** |
| **FE** | `ArchiveFE_SITE`, `_ANTE`, `_CHAN` | `PdfName` | Earth Station **source data** |

**Linking**: `ArchiveTT_PARM.proname` = FT `PdfName`, `ArchiveTT_PARM.envname` = FE `PdfName`

## Prerequisites

- SQL Server (dev database; e.g. MicsMin, RemicsDev)
- Replace `[YourDatabase]` in each script with your database name
- TT archive tables should be created first (see `../tt-archive-capture/`)

## Scripts

| # | Script | Purpose |
|---|--------|---------|
| 00 | `00_create_ft_fe_archive_tables.sql` | Creates `tsip_archive.ArchiveFT_*` and `ArchiveFE_*` tables |
| 01 | `01_create_sample_ft_fe_tables.sql` | Creates sample `ft_test_ts_pdf_*` and `fe_test_es_pdf_*` tables with test data |
| 02 | `02_create_ft_fe_drop_trigger.sql` | Creates DDL trigger `trg_ArchiveFtFe_OnDropTable` |
| 03 | `03_test_drop_and_verify.sql` | Drops sample tables and verifies archive contents |
| 04 | `04_cleanup_trigger.sql` | (Optional) Drops the trigger |
| 05 | `05_query_examples.sql` | Example queries linking TT results with FT/FE source data |

## Running Order

1. Run `00_create_ft_fe_archive_tables.sql` - Create archive tables
2. Run `01_create_sample_ft_fe_tables.sql` - Create test data
3. Run `02_create_ft_fe_drop_trigger.sql` - Create the trigger
4. Run `03_test_drop_and_verify.sql` - Test the archive capture

## Expected Results After Test

**FT (Terrestrial Station) archives:**
- `ArchiveFT_SITE`: 3 rows with PdfName `test_ts_pdf`
- `ArchiveFT_ANTE`: 4 rows with PdfName `test_ts_pdf`
- `ArchiveFT_CHAN`: 4 rows with PdfName `test_ts_pdf`

**FE (Earth Station) archives:**
- `ArchiveFE_SITE`: 3 rows with PdfName `test_es_pdf`
- `ArchiveFE_ANTE`: 3 rows with PdfName `test_es_pdf`
- `ArchiveFE_CHAN`: 4 rows with PdfName `test_es_pdf`

## Table Structures

### FT (Terrestrial Station) Tables

**Key differences from FE:**
- Sites identified by `call1`/`call2` (call signs)
- Antennas linked by `call1`, `call2`, `bndcde`, `anum`
- Point-to-point microwave links between two sites

### FE (Earth Station) Tables

**Key differences from FT:**
- Sites identified by `location` (earth station location code)
- Antennas include satellite info (`satname`, `satlongit`, `g_t`)
- Earth-to-space links via satellite

## Query Examples

### Get all data for a TSIP run

```sql
DECLARE @RunKey NVARCHAR(128) = 'myproj_run01';

-- Get run parameters (links to FT/FE via proname/envname)
SELECT * FROM tsip_archive.ArchiveTT_PARM WHERE RunKey = @RunKey;

-- Get TS source data (linked by proname)
SELECT ft.* 
FROM tsip_archive.ArchiveFT_SITE ft
INNER JOIN tsip_archive.ArchiveTT_PARM p ON ft.PdfName = RTRIM(p.proname)
WHERE p.RunKey = @RunKey;

-- Get ES source data (linked by envname)
SELECT fe.* 
FROM tsip_archive.ArchiveFE_SITE fe
INNER JOIN tsip_archive.ArchiveTT_PARM p ON fe.PdfName = RTRIM(p.envname)
WHERE p.RunKey = @RunKey;
```

### Run summary with counts

```sql
SELECT 
    p.RunKey,
    RTRIM(p.proname) AS TS_Pdf,
    RTRIM(p.envname) AS ES_Pdf,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFT_SITE WHERE PdfName = RTRIM(p.proname)) AS TS_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveFE_SITE WHERE PdfName = RTRIM(p.envname)) AS ES_Sites,
    (SELECT COUNT(*) FROM tsip_archive.ArchiveTT_CHAN WHERE RunKey = p.RunKey) AS ResultChannels
FROM tsip_archive.ArchiveTT_PARM p;
```

## Data Model

```
┌─────────────────────┐
│  ArchiveTT_PARM     │
│  (Run Master)       │
│  ─────────────────  │
│  RunKey (PK)        │
│  proname ──────────────────┐
│  envname ─────────────┐    │
│  ArchivedAt          │    │
└─────────────────────┘    │    │
        │                  │    │
        ▼                  │    │
┌─────────────────────┐    │    │
│  ArchiveTT_SITE     │    │    │
│  ArchiveTT_ANTE     │    │    │
│  ArchiveTT_CHAN     │    │    │
│  (Results)          │    │    │
└─────────────────────┘    │    │
                           │    │
                           ▼    │
              ┌─────────────────────┐
              │  ArchiveFE_SITE     │
              │  ArchiveFE_ANTE     │
              │  ArchiveFE_CHAN     │
              │  (ES Source Data)   │
              │  PdfName = envname  │
              └─────────────────────┘
                                │
                                ▼
              ┌─────────────────────┐
              │  ArchiveFT_SITE     │
              │  ArchiveFT_ANTE     │
              │  ArchiveFT_CHAN     │
              │  (TS Source Data)   │
              │  PdfName = proname  │
              └─────────────────────┘
```

## Notes

- FT/FE PDFs may be used in multiple TSIP runs. The archive captures the state at the time of deletion.
- Multiple archives of the same PdfName are allowed (each gets a unique ArchiveId).
- Use `ArchivedAt` to correlate which archive snapshot corresponds to which run.
