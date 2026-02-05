# TT Archive Capture Scripts (Drop-Trigger Approach)

Scripts to test capturing TT table data when tables are dropped, using a DDL trigger that rolls back the drop, copies data to archive tables, then re-drops the table.

## Prerequisites

- SQL Server (dev database; e.g. MicsMin, RemicsDev).
- Replace `[YourDatabase]` in each script with your database name.

## Order

1. **00_create_schema_and_archive_tables.sql** – Creates `tsip_archive` schema and archive tables for all four non-temp TT types: `ArchiveTT_PARM`, `ArchiveTT_SITE`, `ArchiveTT_ANTE`, `ArchiveTT_CHAN`.
2. **01_create_sample_tt_tables.sql** – Creates sample `dbo.tt_test_run01_parm`, `_site`, `_ante`, `_chan` with sample rows (including proname/envname).
3. **02_create_drop_trigger.sql** – Creates DDL trigger `trg_ArchiveTT_OnDropTable` on `DATABASE` for `DROP_TABLE`; handles all non-temp TT tables (`tt_%_parm`, `tt_%_site`, `tt_%_ante`, `tt_%_chan`). Temp tables (`tt_%_tmp1`, `tt_%_tmp2`) are not captured.
4. **03_test_drop_and_verify.sql** – Drops the four sample tables and verifies archive contents for PARM, SITE, ANTE, CHAN.
5. **04_cleanup_trigger.sql** – (Optional) Drops the trigger.

## Expected Result

After running 03:

- `dbo.tt_test_run01_parm`, `_site`, `_ante`, and `_chan` no longer exist.
- `tsip_archive.ArchiveTT_PARM` has one row with RunKey `test_run01`, proname/envname/runname/numcases from the sample.
- `tsip_archive.ArchiveTT_SITE`, `ArchiveTT_ANTE`, and `ArchiveTT_CHAN` each have three rows with RunKey `test_run01` and the sample data.

## TS and ES file names

The **TS (Terrestrial Station)** and **ES (Earth Station)** file/PDF names for the run are stored in the **parameters table** (TT_PARM) and are copied into the archive when we capture `tt_*_parm`:

- **proname** (char(16)) – Proposed name = **TS file/PDF name** (Terrestrial Station data source).
- **envname** (char(16)) – Environment name = **ES file/PDF name** (Earth Station / environment data source).

They are written by the C# app into TT_PARM and are included in `ArchiveTT_PARM`; no extra capture is needed. For SITE/ANTE/CHAN archives, join to `ArchiveTT_PARM` on RunKey to get proname/envname for that run.

## RunKey Parsing

The trigger derives RunKey from the table name by stripping the `tt_` prefix and the suffix (`_parm`, `_site`, `_ante`, or `_chan`). Example: `tt_test_run01_parm` → RunKey `test_run01`. Temp tables `tt_%_tmp1` and `tt_%_tmp2` are not handled by this trigger (no archive capture).
