# Document Consolidation Plan

**Purpose**: Reduce document fragmentation and create a clear, maintainable documentation structure.

---

## Current Document Count: 20 Documents

### Analysis
- **Too many status/summary documents** (4 documents with overlapping content)
- **Some documents are superseded** by newer, more comprehensive documents
- **Need a single source of truth** for project status

---

## Proposed Structure

### Tier 1: Master Documents (Primary Reference)

1. **`T-SQL-PORT-MASTER-PLAN.md`** ⭐ **NEW - PRIMARY REFERENCE**
   - Consolidated project status
   - All decisions in one place
   - Implementation roadmap
   - **Status**: Keep and maintain as primary reference

---

### Tier 2: Solution Documents (Detailed Implementation)

**Keep These** (detailed technical solutions):
- `tsip-nested-loops-structure.md` - 6-level architecture details
- `antenna-discrimination-analysis.md` - Antenna solution details
- `over-horizon-path-loss-analysis.md` - Path loss solution details
- `ctx-lookup-pure-tsql.md` - CTX solution details
- `state-management-tsql-analysis.md` - State management analysis
- `error-recovery-implementation-decision.md` - Error recovery implementation

**Status**: Keep - these contain detailed technical information needed for implementation

---

### Tier 3: Reference Documents (Supporting Information)

**Keep These** (reference material):
- `tsip-process-flow.md` - High-level process flow
- `database-tables.md` - Table schemas and naming
- `performance-data-profiling.md` - Actual data volumes
- `storage-requirements-analysis.md` - Storage estimates
- `antenna-tables-maintenance.md` - Antenna maintenance workflow
- `tsip-queue-management.md` - Queue mechanisms
- `tsip-lock-bug-analysis.md` - Production bug analysis

**Status**: Keep - these are reference documents

---

### Tier 4: Documents to Consolidate/Archive

#### Option A: Archive (Mark as Superseded)

**These documents are superseded by `T-SQL-PORT-MASTER-PLAN.md`**:

1. **`tsql-port-feasibility.md`** 
   - **Status**: ⚠️ **SUPERSEDED** by master plan
   - **Action**: Add header note "⚠️ SUPERSEDED - See T-SQL-PORT-MASTER-PLAN.md"
   - **Keep**: Yes (for historical reference)

2. **`tsql-remaining-challenges.md`**
   - **Status**: ⚠️ **SUPERSEDED** by master plan
   - **Action**: Add header note "⚠️ SUPERSEDED - See T-SQL-PORT-MASTER-PLAN.md"
   - **Keep**: Yes (for historical reference)

3. **`tsql-challenging-portions.md`**
   - **Status**: ⚠️ **PARTIALLY SUPERSEDED** - information now in solution docs
   - **Action**: Add header note "⚠️ INFORMATION MOVED - See solution documents"
   - **Keep**: Yes (for historical reference)

#### Option B: Consolidate into Master Plan

**These documents can be consolidated**:

1. **`trouble-spots-summary.md`**
   - **Status**: ⚠️ **REDUNDANT** - information in master plan
   - **Action**: Delete or archive
   - **Rationale**: Master plan has better organization

2. **`remaining-unaddressed-concerns.md`**
   - **Status**: ⚠️ **REDUNDANT** - information in master plan
   - **Action**: Delete or archive
   - **Rationale**: Master plan has better organization

3. **`error-recovery-analysis.md`**
   - **Status**: ⚠️ **PARTIALLY REDUNDANT** - decision in implementation doc
   - **Action**: Keep detailed analysis, but decision is in implementation doc
   - **Rationale**: Detailed analysis is still useful

4. **`ctx-lookup-caching-analysis.md`**
   - **Status**: ⚠️ **PARTIALLY REDUNDANT** - solution in pure T-SQL doc
   - **Action**: Keep for historical reference, but pure T-SQL doc is primary
   - **Rationale**: Analysis is still useful

---

## Recommended Actions

### Immediate Actions

1. ✅ **Create `T-SQL-PORT-MASTER-PLAN.md`** - **DONE**
   - Single source of truth for project status
   - All decisions in one place
   - Implementation roadmap

2. **Mark Superseded Documents**
   - Add header notes to `tsql-port-feasibility.md`
   - Add header notes to `tsql-remaining-challenges.md`
   - Add header notes to `tsql-challenging-portions.md`

3. **Archive Redundant Documents**
   - Delete or archive `trouble-spots-summary.md` (info in master plan)
   - Delete or archive `remaining-unaddressed-concerns.md` (info in master plan)

### Future Actions

4. **Create README in notes/ directory**
   - Point to master plan as primary reference
   - List all documents with brief descriptions
   - Indicate which documents are superseded

---

## Final Document Structure

### Primary Reference (1 document)
- `T-SQL-PORT-MASTER-PLAN.md` ⭐

### Solution Documents (6 documents)
- `tsip-nested-loops-structure.md`
- `antenna-discrimination-analysis.md`
- `over-horizon-path-loss-analysis.md`
- `ctx-lookup-pure-tsql.md`
- `state-management-tsql-analysis.md`
- `error-recovery-implementation-decision.md`

### Reference Documents (7 documents)
- `tsip-process-flow.md`
- `database-tables.md`
- `performance-data-profiling.md`
- `storage-requirements-analysis.md`
- `antenna-tables-maintenance.md`
- `tsip-queue-management.md`
- `tsip-lock-bug-analysis.md`

### Historical/Superseded (3 documents - marked)
- `tsql-port-feasibility.md` (marked as superseded)
- `tsql-remaining-challenges.md` (marked as superseded)
- `tsql-challenging-portions.md` (marked as partially superseded)

### Supporting Analysis (2 documents - optional)
- `error-recovery-analysis.md` (detailed analysis, decision in implementation doc)
- `ctx-lookup-caching-analysis.md` (detailed analysis, solution in pure T-SQL doc)

**Total**: **19 documents** (down from 20, with better organization)

---

## Document Navigation

### For Project Status
→ **Start here**: `T-SQL-PORT-MASTER-PLAN.md`

### For Implementation Details
→ See solution documents listed in master plan

### For Reference Information
→ See reference documents listed in master plan

---

## Benefits of Consolidation

1. ✅ **Single source of truth** - Master plan has all status and decisions
2. ✅ **Reduced redundancy** - No duplicate status information
3. ✅ **Clear navigation** - Easy to find what you need
4. ✅ **Better maintenance** - Update one document instead of multiple
5. ✅ **Historical preservation** - Superseded documents kept but marked

---

*Last Updated: January 2026*

