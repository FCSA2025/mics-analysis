# T-SQL Port Documentation

This directory contains all documentation for the TSIP to T-SQL port project.

---

## 🎯 Start Here

**For project status, decisions, and roadmap**:  
→ **[T-SQL-PORT-MASTER-PLAN.md](./T-SQL-PORT-MASTER-PLAN.md)** ⭐

This is the **single source of truth** for the project. It contains:
- Project status overview
- All implementation decisions
- Fully addressed challenges
- Remaining work
- Implementation roadmap

---

## 📚 Document Organization

### Primary Reference
- **`T-SQL-PORT-MASTER-PLAN.md`** ⭐ - **START HERE** - Consolidated project plan and status

### Solution Documents (Detailed Implementation)
Located in [`solutions/`](./solutions/):
- `tsip-nested-loops-structure.md` - 6-level nested loop architecture and cursor strategy
- `antenna-discrimination-analysis.md` - Pre-computed lookup table solution
- `antenna-tables-maintenance.md` - Antenna table update workflow
- `over-horizon-path-loss-analysis.md` - Pre-computed database solution
- `ctx-lookup-pure-tsql.md` - Pure T-SQL CTX caching solution
- `state-management-tsql-analysis.md` - State management analysis (not a blocker)
- `error-recovery-implementation-decision.md` - Transactional error recovery with cleanup

### Reference Documents (Supporting Information)
Located in [`reference/`](./reference/):
- `performance-data-profiling.md` - Actual data volumes and performance metrics
- `storage-requirements-analysis.md` - Storage estimates for lookup tables

**Shared Reference Documents** (used by both T-SQL conversion and C# bug fixes):
- [`../shared/tsip-process-flow.md`](../shared/tsip-process-flow.md) - High-level TSIP process flow
- [`../shared/database-tables.md`](../shared/database-tables.md) - Table schemas, naming conventions, cleanup functions

### Historical/Superseded (Kept for Reference)
Located in [`historical/`](./historical/):
- `tsql-port-feasibility.md` ⚠️ - Superseded by master plan
- `tsql-remaining-challenges.md` ⚠️ - Superseded by master plan
- `tsql-challenging-portions.md` ⚠️ - Partially superseded (info moved to solution docs)
- `error-recovery-analysis.md` - Detailed error recovery options analysis
- `ctx-lookup-caching-analysis.md` - CTX caching options analysis

---

## 📋 Quick Reference

### Project Status
- ✅ **5 challenges fully addressed** (Nested Loops, Antenna Discrimination, Over-Horizon Path Loss, CTX Caching, State Management)
- ⚠️ **1 challenge partially addressed** (Performance Implications - needs indexing/batching)
- ❌ **1 item out of scope** (Report Generation - keep in C#)

### Key Decisions
- **Nested Loops**: Cursors (levels 1-4) + Set-based (levels 5-6)
- **Antenna Discrimination**: Pre-computed lookup table
- **Over-Horizon Path Loss**: Pre-computed database (on-demand)
- **CTX Caching**: Pure T-SQL set-based
- **State Management**: Not needed (T-SQL handles naturally)
- **Error Recovery**: Transactional with explicit cleanup

### Remaining Work
- **Performance Optimization**: 4-8 days (indexing, batching, parallel execution)

---

## 🔍 Finding Information

### Need to know project status?
→ `T-SQL-PORT-MASTER-PLAN.md`

### Need implementation details for a specific challenge?
→ See solution documents in [`solutions/`](./solutions/)

### Need reference information (tables, data volumes, etc.)?
→ See reference documents in [`reference/`](./reference/) and [`../shared/`](../shared/)

### Need historical context?
→ See historical/superseded documents in [`historical/`](./historical/)

---

## 📝 Document Maintenance

**Primary Document**: `T-SQL-PORT-MASTER-PLAN.md`  
**Update Frequency**: As decisions are made and status changes  
**Other Documents**: Update as needed for implementation details

---

*Last Updated: January 2026*

