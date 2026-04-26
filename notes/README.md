# MICS# Analysis Documentation

This directory contains documentation for three distinct projects:

1. **Bug Fixes** - Analysis and fixes for existing C# production code issues
2. **T-SQL Conversion Project** - Planning and analysis for porting TSIP to T-SQL
3. **FCSA_BACKEND_SQL Repository Analysis** - Analysis of the existing T-SQL port implementation

---

## 📁 Directory Structure

```
notes/
├── README.md                    # This file - main index
├── bug-fixes/                   # C# Production Code Bug Fixes
│   ├── README.md                # Bug fixes overview
│   └── BUG-FIXES-MASTER.md      # Consolidated bug analysis and fixes
├── tsql-conversion/             # T-SQL Port Planning (from mics-analysis perspective)
│   ├── README.md                # T-SQL conversion overview
│   ├── T-SQL-PORT-MASTER-PLAN.md  # Master plan and status
│   ├── solutions/               # Detailed implementation solutions
│   ├── reference/               # Reference documents
│   ├── fixes/                   # Fix guides (for planning)
│   └── historical/              # Superseded documents
├── fcsa-backend-sql/            # FCSA_BACKEND_SQL Repository Analysis
│   ├── README.md                # Repository analysis overview
│   ├── analysis/                # General analysis
│   ├── fixes/                   # Bug fixes for T-SQL code
│   ├── comparison/              # Comparison with C# source
│   └── status/                  # Completion status
└── shared/                      # Shared reference documents
    ├── database-tables.md       # Table schemas and naming
    ├── sql-server-cursorai-access.md  # SQL Server CursorAiAccess login (local/dev)
    └── tsip-process-flow.md     # High-level TSIP process flow
```

---

## 🐛 Bug Fixes

**IMPORTANT**: These are bug fixes for the **existing C# production code** (TpRunTsip, TsipInitiator, etc.), **NOT** bugs in T-SQL development or the T-SQL port project.

**Location**: [`bug-fixes/`](./bug-fixes/)

**Primary Document**: [`BUG-FIXES-MASTER.md`](./bug-fixes/BUG-FIXES-MASTER.md)

**Summary**: Analysis of 5 critical bugs in the C# production code that cause:
- Infinite retry loops (TSIP runs multiple times)
- Endless error streams
- Results never written to output files
- Lock starvation and resource leaks

**See**: [`bug-fixes/README.md`](./bug-fixes/README.md) for detailed overview

---

## 🔄 T-SQL Conversion Project

**Location**: [`tsql-conversion/`](./tsql-conversion/)

**Primary Document**: [`T-SQL-PORT-MASTER-PLAN.md`](./tsql-conversion/T-SQL-PORT-MASTER-PLAN.md)

**Summary**: Planning and analysis for porting TSIP interference calculation code from C# to T-SQL stored procedures.

**Status**: Analysis Phase Complete, Ready for Implementation

**See**: [`tsql-conversion/README.md`](./tsql-conversion/README.md) for detailed overview

**Note**: This is **planning work** from the mics-analysis perspective. For analysis of the **actual T-SQL port implementation**, see [`fcsa-backend-sql/`](./fcsa-backend-sql/) below.

---

## 🗄️ FCSA_BACKEND_SQL Repository Analysis

**Location**: [`fcsa-backend-sql/`](./fcsa-backend-sql/)

**Primary Document**: [`README.md`](./fcsa-backend-sql/README.md)

**Summary**: Analysis and documentation of the existing T-SQL port in the `FCSA2025/FCSA_BACKEND_SQL` GitHub repository. This is a **separate project** from the planning work in `tsql-conversion/`.

**Status**: ~75-80% Complete (structurally complete, needs bug fixes)

**⚠️ IMPORTANT**: **Reference Only - NOT for Modification**
- We will NOT modify `FCSA_BACKEND_SQL`
- Our T-SQL conversion will be a completely independent implementation
- This analysis is for learning and understanding approaches only
- See `tsql-conversion/T-SQL-PORT-MASTER-PLAN.md` for our independent implementation plan

**Key Documents**:
- [`analysis/repository-overview.md`](./fcsa-backend-sql/analysis/repository-overview.md) - Comprehensive repository overview
- [`status/completion-assessment.md`](./fcsa-backend-sql/status/completion-assessment.md) - Detailed completion analysis
- [`fixes/missing-variable-declarations.md`](./fcsa-backend-sql/fixes/missing-variable-declarations.md) - Critical compilation fixes

**See**: [`fcsa-backend-sql/README.md`](./fcsa-backend-sql/README.md) for detailed overview

---

## 📚 Shared Reference Documents

**Location**: [`shared/`](./shared/)

Documents used by both projects:
- [`database-tables.md`](./shared/database-tables.md) - Table schemas, naming conventions, cleanup functions
- [`sql-server-cursorai-access.md`](./shared/sql-server-cursorai-access.md) - SQL Server CursorAiAccess login (server, password, databases)
- [`tsip-process-flow.md`](./shared/tsip-process-flow.md) - High-level TSIP process flow
- [`tsip-result-file-write-guide.md`](./shared/tsip-result-file-write-guide.md) - Detailed TSIP result file write process and filename patterns

---

## 🎯 Quick Navigation

### Need to fix production bugs?
→ [`bug-fixes/BUG-FIXES-MASTER.md`](./bug-fixes/BUG-FIXES-MASTER.md)

### Need T-SQL port planning status?
→ [`tsql-conversion/T-SQL-PORT-MASTER-PLAN.md`](./tsql-conversion/T-SQL-PORT-MASTER-PLAN.md)

### Need FCSA_BACKEND_SQL repository analysis?
→ [`fcsa-backend-sql/README.md`](./fcsa-backend-sql/README.md)

### Need reference information?
→ [`shared/`](./shared/) directory

### Need SQL Server CursorAiAccess login?
→ [`shared/sql-server-cursorai-access.md`](./shared/sql-server-cursorai-access.md)

---

*Last Updated: January 2026*
