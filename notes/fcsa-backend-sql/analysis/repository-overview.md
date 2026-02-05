# FCSA_BACKEND_SQL Repository Overview

**Repository**: `FCSA2025/FCSA_BACKEND_SQL`  
**Type**: Private  
**Created**: 2026-01-16  
**Status**: Active T-SQL port project

---

## Executive Summary

The `FCSA_BACKEND_SQL` repository contains a **T-SQL port** of the C# `TpRunTsip` application. It converts the entire TSIP (Terrestrial Station Interference Processor) system from C# to SQL Server stored procedures.

**Key Characteristics**:
- **Direct port** from C# to T-SQL
- **200+ stored procedures** implementing the full TSIP workflow
- **~2.4 MB** of SQL code
- **~75-80% complete** (structurally complete, needs bug fixes)

---

## Repository Structure

### Core Files

| File | Size | Lines | Purpose |
|------|------|-------|---------|
| `CreateTables.sql` | 53 KB | ~690 | Creates `tpruntsip` schema and all tables |
| `CreateProcedures.sql` | 387 KB | 8,505 | Creates stored procedure definitions |
| `StoredProcedure.sql` | 1.96 MB | 47,289 | Implementation of all stored procedures |
| `TprunTsip.sql` | 71 KB | 1,114 | Main entry point script (T-SQL version of `TpRunTsip.cs`) |
| `DropTables.sql` | 21 KB | ~637 | Cleanup script for tables |
| `DropProcedures.sql` | 68 KB | ~873 | Cleanup script for procedures |
| `test1.sql` | 9 KB | ~280 | Minimal test script |
| `test2.sql` | 12 KB | ~343 | More complete test script |

---

## Architecture

### Schema: `tpruntsip`

All objects are created in the `tpruntsip` schema.

### Table Categories

1. **Working Tables** (TSIP-generated):
   - `TtSite`, `TtAnte`, `TtChan` (TS-TS interference results)
   - `TeSite`, `TeAnte`, `TeChan` (TS-ES interference results)

2. **Input Data Tables**:
   - `FtSite`, `FtAnte`, `FtChan` (Terrestrial station data)
   - `FeSite`, `FeAnte`, `FeChan` (Earth station data)

3. **Caching Tables**:
   - `PatternStruct`, `PatternStruct_Pattern` (Antenna pattern cache)
   - `ctxSaved`, `ctxSaved_ctxPts` (CTX curve cache)
   - `CtxStruct` (CTX main cache)

4. **Configuration Tables**:
   - `TpParm` (Parameter records)
   - `Tsip_Info` (Runtime configuration)
   - `UserInfoData` (User information)

5. **Report Helper Tables**:
   - `TsipReportHelper` (Report flags)
   - `ExportFileHandle`, `ExportFileNames` (File I/O tracking)

6. **Supporting Tables**:
   - ~80+ additional tables for calculations, temporary data, etc.

### Stored Procedure Categories

**Core Processing** (20+ procedures):
- `TtBuildSH_TtBuildSHTable` - TS-TS interference calculations
- `TeBuildSH_TeBuildSHTable` - TS-ES interference calculations
- `TtCalcs_*` - TS calculation functions
- `TeCalcs_*` - ES calculation functions

**Data Access** (30+ procedures):
- `TpMdbPdfGet_*` - Database queries
- `FtUtils_*` - Terrestrial station utilities
- `FeUtils_*` - Earth station utilities

**Calculations** (40+ procedures):
- `GenUtil_*` - General utilities (interpolation, path loss, etc.)
- `TpGetDat_*` - Data retrieval and calculations
- `Suutils_*` - Subsidiary data utilities

**Reports** (20+ procedures):
- `TpRunTsip_ReportStudy` - Study report
- `TpRunTsip_ReportNew` - New report
- `TpRunTsip_TpExecRpt` - Executive report
- `TpRunTsip_TpExportRpt` - Export report
- `Tstsrp*`, `Tsesrp*`, `Estsrp*` - Detailed report procedures

**File I/O** (10+ procedures):
- `OpenReportStreams` - Open report files
- `CloseReportStreams` - Close report files
- `spCreateFileStream`, `spWriteStringToFile`, `spCloseFileStream` - File operations

**Utilities** (80+ procedures):
- Various helper functions for calculations, conversions, etc.

---

## Key Features

### 1. Direct C# to T-SQL Port

The code structure closely mirrors the C# source:
- Same function names (prefixed with schema)
- Same data structures (implemented as tables)
- Same processing flow

### 2. File I/O via OLE Automation

Uses SQL Server OLE Automation (`sp_OACreate`) for file operations:
- Opening/closing report files
- Writing report content
- File system access

**Security Note**: Requires `Ole Automation Procedures` to be enabled (disabled after use).

### 3. Cursor-Based Processing

Uses T-SQL cursors for nested loop processing:
- Site enumeration
- Link enumeration
- Victim enumeration
- Antenna/channel pair processing

### 4. Report Generation

Generates the same report files as the C# version:
- `.STUDY` - Study report
- `.CASEDET` - Case detail report
- `.CASESUM` - Case summary report
- `.AGGINT` - Aggregate interference report
- `.EXEC` - Executive report
- `.EXPORT` - Export report
- `.ORBIT` - Orbit report
- `.HILO` - HiLo check report

---

## Current Issues

### Critical (Blocks Compilation)

1. **Missing Variable Declarations** (14 variables)
   - See `../fixes/missing-variable-declarations.md`
   - Variables used but never declared
   - **Fix Time**: 30-60 minutes

2. **Incorrect Function Call Syntax**
   - Line 865: `GenUtil.UtGetDateTime(out endDate, out endTime);`
   - Should be: `exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out`
   - **Fix Time**: 5 minutes

### High Priority

3. **Over-Horizon Path Loss**
   - References `CTEfunctions.Calc_OhLoss()` (CLR function)
   - Not implemented in pure T-SQL
   - **Fix Time**: 2-4 days

4. **Hardcoded Test Values**
   - `@ProjectCode = 'compa4_0'`, `@Username = 'bell1'`, etc.
   - Needs parameterization
   - **Fix Time**: 2-3 hours

### Medium Priority

5. **Queue/Lock Management**
   - `FileGate`/`FileGateClose` commented out
   - No concurrency control
   - **Fix Time**: 1-2 days

6. **Error Handling**
   - Many error messages commented out
   - `@exitCode` set but not used
   - **Fix Time**: 1 day

---

## Comparison with C# Source

### What's Ported

✅ **Core Calculations**:
- Geometry (distance, azimuth, elevation)
- Antenna discrimination (interpolation)
- CTX lookups
- Free space path loss
- Interference margin calculations

✅ **Processing Flow**:
- Site enumeration
- Link enumeration
- Victim enumeration
- Antenna pair processing
- Channel pair processing

✅ **Report Generation**:
- All report types
- File I/O operations
- Report formatting

### What's Different

⚠️ **Over-Horizon Path Loss**:
- C#: Uses `_OHloss.dll` via P/Invoke
- T-SQL: References `CTEfunctions.Calc_OhLoss()` (CLR - not implemented)

⚠️ **Queue Management**:
- C#: Uses `Qutils.EnterQueue`/`ExitQueue` and `FileGate`
- T-SQL: Commented out (not implemented)

⚠️ **Error Handling**:
- C#: Comprehensive error messages and logging
- T-SQL: Many error messages commented out

---

## Test Scripts

### `test1.sql`
- **Purpose**: Minimal test
- **What it does**: Opens report streams, closes immediately
- **Status**: Basic functionality test

### `test2.sql`
- **Purpose**: More complete test
- **What it does**: Includes ES processing with `TeBuildSH_TeBuildSHTable`
- **Status**: Extended functionality test

---

## Relationship to mics-analysis

The `mics-analysis` workspace contains:
- **Planning documents** for a T-SQL port (`notes/tsql-conversion/`)
- **Analysis** of the C# source code
- **Bug fixes** for the C# production code (`notes/bug-fixes/`)

The `FCSA_BACKEND_SQL` repository represents:
- **Actual implementation** of a T-SQL port
- **Working code** (though incomplete)
- **Separate project** with its own repository

**Key Insight**: The T-SQL port feasibility analysis in `mics-analysis` was planning work. The `FCSA_BACKEND_SQL` repository shows that someone has actually started implementing it.

---

## Next Steps

1. **Immediate** (1-2 days):
   - Fix missing variable declarations
   - Fix `UtGetDateTime` call syntax
   - Test compilation

2. **Short-term** (1 week):
   - Implement over-horizon path loss
   - Parameterize main script
   - Complete error handling

3. **Medium-term** (1-2 weeks):
   - Testing and debugging
   - Performance optimization
   - Production readiness

---

*Last Updated: January 2026*

