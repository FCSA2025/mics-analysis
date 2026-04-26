# TSIP Result File Write Guide (Environment-Agnostic)

## Purpose

This document explains how TSIP writes result files during a run, including filename patterns, sequencing, cleanup behavior, and edge cases.

It is intended as a practical implementation guide for use on other servers/environments.

## Scope and confidence

- This guide is based on the current C# flow in `TpRunTsip`.
- Use it as a **strong reference**, not absolute truth.
- Minor differences are expected across codebases/branches/deployments.
- Drive letters, UNC/server names, and machine-specific directories are intentionally excluded.

---

## Inputs that determine output filenames

TSIP combines three values to produce per-run report filenames:

- `DestName` (output prefix): command-line `-o<prefix>`
- `PdfName` (parameter file token): mandatory arg `<paramTableName>` (the `XXX` in `tp_XXX_parm`)
- `runname`: each record in the parameter table

Core per-run filename stub:

- `{DestName}_{PdfName}_{runname}`

Shared error filename stub (all runs in one invocation):

- `{DestName}_{PdfName}`

---

## Where files are written (path behavior)

Path root is controlled by environment variable:

- `TARGETDIRFORTSIPREPORTS`

Behavior:

- If set: that directory is used (with a trailing slash normalized internally).
- If not set: relative/current process directory is used.

This guide focuses on filenames/patterns only; do not assume any specific drive/server path.

---

## File output mode vs console mode

### File mode

Enabled when `-o<prefix>` is provided and the prefix passes filename-char validation.

- `TsipReportHelper.OutputToFiles = true`
- Full report set is opened as file streams.

### Console mode

Default when `-o` is not provided.

- Most report writers point to console output (`Console.Out`).
- Exception: `AGGINT.csv` is still written to a disk file.

---

## Result filenames produced per run

For each run (`{DestName}_{PdfName}_{runname}`):

- `.AGGINT.csv`
- `.AGGINTREP`
- `.CASEDET`
- `.CASEOHL`
- `.CASESUM`
- `.EXEC`
- `.HILO`
- `.ORBIT`
- `.STATSUM`
- `.STUDY`
- `.TS_EXPORT` (TS run, `protype = "T"`)
- `.ES_EXPORT` (non-TS run)

Shared across all runs in one TSIP invocation:

- `{DestName}_{PdfName}.ERR`

Example patterns only:

- `TSIP_paramA_run01.CASEDET`
- `TSIP_paramA_run01.TS_EXPORT`
- `TSIP_paramA.ERR`

---

## End-to-end write sequence

## 1) Startup (before processing runs)

- Build run context from arguments/environment.
- Create/truncate the shared error file (`.ERR`) once.
- Read parameter records from `tp_{PdfName}_parm`.

## 2) Per-run pre-write setup

- Determine requested report set for this run.
- Force export report on (TS/ES export file generation is enabled per run).
- Pre-delete prior report files for the same `{DestName}_{PdfName}_{runname}` stub.
- Open all report streams (truncate mode).
- Acquire run lock token:
  - `{DbName}_{proname}_{runname}_LOCK`
- Re-open error stream context for this run and append run header text.

## 3) Computation + report writing

- Build SH/result tables (TS or ES path).
- Write ORBIT header/content.
- Write STUDY report.
- Write main report suite (`STATSUM`, `CASEDET`, `CASEOHL`, `CASESUM`, `AGGINTREP`, `AGGINT.csv`, `HILO`).
- Write EXEC if requested.
- Write EXPORT (`.TS_EXPORT` or `.ES_EXPORT`).

## 4) Per-run finalize

- Drop temporary DB artifacts used for report assembly.
- Release lock token.
- Close all open report streams.
- Delete report files not actually written (based on report-written flags).
- Persist per-run normalized report checksums/metadata to report table storage.

## 5) Post-all-runs finalize

- Close shared `.ERR`.
- Persist `.ERR` report metadata/checksum.
- Insert final aggregate checksum record ("checksum of checksums").

---

## Pre-clean and cleanup behavior details

### Pre-clean (rerun hygiene)

Before each run, TSIP deletes any old files with the same run stub.

Notable legacy mismatch:

- Pre-clean list includes legacy export names like `_ts.EXPORT` / `_es.EXPORT`.
- Current write naming uses `.TS_EXPORT` / `.ES_EXPORT`.

Practical implication: old export artifacts may survive pre-clean in some scenarios.

### Post-run deletion

TSIP may create all report streams up front, then remove files for reports that were not actually written. This is controlled by per-report `*Written` flags.

---

## Queue and parameter linkage (filename context)

In queue-driven execution:

- `web.tsip_queue.TQ_ArgFile` maps to parameter table token (`tp_{TQ_ArgFile}_parm`), i.e., the `PdfName`-style identifier.
- Output prefix is passed through launch parameters (`-o<prefix>`), becoming `DestName`.

This linkage explains how queue jobs determine report filename stubs without embedding machine-specific paths.

---

## Known caveats and portability notes

- `-t` (output-to-table mode) exists and stores reports/checksums in DB table form in addition to or instead of file consumers, depending on deployment behavior.
- Console mode still writes `AGGINT.csv` to disk.
- One `.ERR` file spans all runs in a single TSIP invocation.
- On certain failure paths, stream cleanup occurs but lock-release behavior can differ by code version.
- Different branches may vary in:
  - exact report list,
  - export naming,
  - pre-clean filename set,
  - checksum persistence details.

Treat this as implementation guidance, then verify behavior in the target environment by running a small multi-run parameter file and inspecting the resulting filenames.

---

## Validation checklist (target environment)

Use this checklist after deployment or when comparing another branch/server.

- [ ] **Confirm argument mapping**: run TSIP with a known `-o<prefix>` and verify output files start with `{prefix}_{paramTableName}_{runname}`.
- [ ] **Confirm directory behavior**: run once with `TARGETDIRFORTSIPREPORTS` set and once unset; verify files go to configured directory vs current working directory.
- [ ] **Confirm one shared ERR file**: for a multi-run parameter table, verify exactly one `{DestName}_{PdfName}.ERR` is created and contains multiple run headers.
- [ ] **Confirm per-run report set**: verify expected per-run outputs appear (`.STUDY`, `.STATSUM`, `.CASEDET`, `.CASEOHL`, `.CASESUM`, `.AGGINTREP`, `.AGGINT.csv`, `.HILO`, `.ORBIT`, plus `.TS_EXPORT`/`.ES_EXPORT`).
- [ ] **Confirm TS vs ES export naming**: for TS and ES runs, verify extension format is `.TS_EXPORT` and `.ES_EXPORT` respectively (or document local variant if different).
- [ ] **Confirm console mode behavior**: run without `-o`; verify most output goes to console while `AGGINT.csv` is still materialized as a file.
- [ ] **Confirm rerun pre-clean**: run the same `{DestName, PdfName, runname}` twice and ensure stale files from prior run are removed or overwritten as expected.
- [ ] **Check legacy export cleanup gap**: verify whether old-style `_ts.EXPORT` / `_es.EXPORT` artifacts are removed; if not, document and add environment-specific cleanup.
- [ ] **Confirm empty report pruning**: choose report options that suppress some report types and verify zero-content/unwritten report files are deleted post-run.
- [ ] **Confirm checksum/report-table writes**: if report-table mode/checksum persistence is enabled in your branch, verify per-run records plus final aggregate checksum record are inserted.
- [ ] **Confirm queue linkage** (if queue-driven): insert/launch a queue job and verify `TQ_ArgFile` aligns with `{PdfName}` portion of report filenames.
- [ ] **Capture branch-specific deltas**: record any differences in filename extensions, report list, cleanup order, or lock/error handling and treat those as local overrides to this guide.

### Suggested minimal test matrix

- **Case A (TS single run)**: one TS run, `-o` enabled.
- **Case B (ES single run)**: one ES run, `-o` enabled.
- **Case C (multi-run parm file)**: at least two runs sharing same `DestName/PdfName`.
- **Case D (console mode)**: no `-o` flag.
- **Case E (rerun same identifiers)**: rerun Case A with same `DestName/PdfName/runname`.

