# T-SQL Port Master Plan

**Project**: Port TSIP (Terrestrial Station Interference Processor) from C# to T-SQL  
**Status**: Analysis Phase Complete, Ready for Implementation  
**Last Updated**: January 2026

---

## Executive Summary

**Goal**: Port all TSIP interference calculation code to T-SQL stored procedures running in SQL Server.

**Feasibility**: ✅ **FEASIBLE** - All major challenges have been analyzed and solutions identified.

**Status**: 
- ✅ **5 major challenges fully addressed** (Nested Loops, Antenna Discrimination, Over-Horizon Path Loss, CTX Caching, State Management)
- ⚠️ **1 challenge partially addressed** (Performance Implications - needs indexing/batching strategy)
- ❌ **1 item out of scope** (Report Generation - keep in C#)

**Estimated Remaining Effort**: **4-8 days** (performance optimization only)

---

## Project Status Overview

| Category | Status | Items | Notes |
|----------|--------|-------|-------|
| ✅ **FULLY ADDRESSED** | Complete | 5 | All solutions documented and ready |
| ⚠️ **PARTIALLY ADDRESSED** | In Progress | 1 | Performance optimization needed |
| ❌ **OUT OF SCOPE** | N/A | 1 | Report generation stays in C# |

---

## Fully Addressed Challenges

### 1. ✅ Nested Loop Processing

**Solution**: Hybrid approach - cursors for levels 1-4, set-based for 5-6

**Implementation**:
- **Levels 1-4** (Site, Link, Victim, Victim Link): Use `FAST_FORWARD` cursors
- **Levels 5-6** (Antenna Pairs, Channel Pairs): Use set-based operations (CROSS JOIN)

**Documentation**: `solutions/tsip-nested-loops-structure.md`

**Status**: ✅ Ready for implementation

---

### 2. ✅ Antenna Discrimination Lookups

**Solution**: Pre-computed lookup table (`tsip.ant_disc_lookup`)

**Implementation**:
- Pre-compute discrimination values for all antennas at 0.1° resolution
- Monthly maintenance when new antennas added
- Simple index lookup during processing

**Storage**: ~1 GB for 3,500 antennas (grows ~30 MB/year)

**Documentation**: `solutions/antenna-discrimination-analysis.md`, `solutions/antenna-tables-maintenance.md`

**Status**: ✅ Ready for implementation

---

### 3. ✅ Over-Horizon Path Loss

**Solution**: Pre-computed database with on-demand population

**Implementation**:
- Pre-compute path loss for common paths
- On-demand calculation for new paths (using CLR function as fallback)
- Lookup table with index on (lat1, long1, lat2, long2, heights, freq, polarization)

**Storage**: ~10-60 GB (depends on unique site pairs, grows on-demand)

**Documentation**: `solutions/over-horizon-path-loss-analysis.md`, `reference/storage-requirements-analysis.md`

**Status**: ✅ Ready for implementation

---

### 4. ✅ CTX Lookup Caching

**Solution**: Pure T-SQL set-based with pre-populated cache

**Implementation**:
- Pre-populate cache table variable with distinct CTX combinations
- Use JOINs for lookups (no function calls)
- Use `LAG()`/`LEAD()` window functions for interpolation

**Documentation**: `solutions/ctx-lookup-pure-tsql.md`, `historical/ctx-lookup-caching-analysis.md`

**Status**: ✅ Ready for implementation

---

### 5. ✅ State Management

**Solution**: No special state management needed - T-SQL handles naturally

**Key Finding**: Most "state" in C# is actually:
- Database data → T-SQL uses JOINs
- Running counters → T-SQL uses COUNT()/SUM()/@@ROWCOUNT
- Caching → Pre-populated tables (already solved)
- Loop variables → Cursor tracks position automatically

**Documentation**: `solutions/state-management-tsql-analysis.md`

**Status**: ✅ Not a blocker

---

## Partially Addressed Challenge

### ⚠️ Performance Implications

**Status**: Data profiling complete, performance decisions made, tuning deferred

**What's Done**:
- ✅ Actual data volumes documented (68,914 sites, 160,746 channels, 108,065 antennas)
- ✅ Performance analysis complete
- ✅ Performance decisions documented (300-600 seconds acceptable, sequential processing, 12 GB threshold)
- ✅ General strategies identified

**What's Deferred** (until after operational run):
1. **Indexing Strategy** (2-3 days)
   - Specific index definitions
   - Covering indexes
   - Index maintenance plan

2. **Batching Strategy** (2-3 days)
   - Optimal batch sizes
   - Batch boundaries
   - Memory vs. performance trade-offs

3. **Performance Testing** (2-3 days)
   - Test scenarios
   - Benchmarks
   - Optimization validation

**Note**: Parallel execution is **NOT** part of the strategy (sequential processing required by business rules).

**Documentation**: `reference/performance-data-profiling.md`

**Priority**: **MEDIUM** (deferred until after operational run)  
**Estimated Effort**: **4-8 days** (when tuning begins)

---

## Out of Scope

### ❌ Report Generation

**Decision**: Keep report generation in C# (separate concern)

**Rationale**:
- Report generation is separate from core calculations
- C# is better suited for file I/O and formatting
- Can call T-SQL stored procedures from C# and generate reports

**Status**: Not part of T-SQL port

---

## Implementation Decisions

### Error Recovery

**Decision**: ✅ **Transactional approach with explicit cleanup**

**Implementation**:
1. **Artifact Detection**: Check for and drop tables from prior failed runs at start
2. **Transaction-Based**: Use `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` for atomicity
3. **Explicit Cleanup**: Drop tables in CATCH block even after ROLLBACK
4. **Error Logging**: Log error details for debugging

**Documentation**: `solutions/error-recovery-implementation-decision.md`, `historical/error-recovery-analysis.md`

**Status**: ✅ Decision made, ready for implementation

---

### Progress Tracking

**Decision**: ✅ **NOT NEEDED**

**Rationale**:
- Current C# code doesn't have it
- Runs complete in reasonable time
- Not required for T-SQL port

**Status**: Skipped

---

### Performance Decisions

**Decision**: ✅ **Performance requirements and constraints defined**

**Key Decisions**:

1. **Acceptable Runtime**: **300-600 seconds (5-10 minutes)** per analysis run
   - This is significantly more lenient than initial estimates (30-100 seconds)
   - Allows for sequential processing without aggressive optimization

2. **Processing Model**: **Sequential processing only** (no parallelization)
   - Business rules require sequential processing
   - Cursor-based operations (Levels 1-4) run sequentially
   - Set-based operations (Levels 5-6) also run sequentially (no MAXDOP)
   - No parallel execution hints or settings

3. **Memory Threshold**: **12 GB concern threshold**
   - Monitor memory usage during runs
   - Optimize if memory usage exceeds 12 GB
   - Current estimates (1-4 GB) are well below threshold

4. **Performance Tuning**: **Deferred until after operational run**
   - Focus on getting simple operational run working first
   - Performance optimization is secondary priority
   - Tuning will occur after initial implementation is complete

**Impact**:
- Removes parallel execution from optimization strategy
- Simplifies implementation (no MAXDOP tuning needed)
- Allows more focus on correctness over performance
- Performance tuning can be done incrementally after operational run

**Documentation**: `reference/performance-data-profiling.md`

**Status**: ✅ Decisions documented, ready for implementation

---

## Data Volumes

**Actual Database Volumes**:
- **Sites**: 68,914
- **Channels**: 160,746
- **Antennas**: 108,065
- **Antenna Types**: 3,200
- **Unique Antennas**: 3,500 (grows ~30/year)

**Derived Metrics**:
- Average channels per site: ~2.3
- Average antennas per site: ~1.6
- Average channels per antenna: ~1.5

**Documentation**: `performance-data-profiling.md`

---

## Storage Requirements

### Pre-Computed Lookup Tables

| Table | Initial Size | Growth Rate | Notes |
|-------|-------------|-------------|-------|
| `tsip.ant_disc_lookup` | ~1 GB | ~30 MB/year | 3,500 antennas, 0.1° resolution |
| `tsip.over_horizon_path_loss` | 0 GB | On-demand | Populates as paths encountered |

**Total Storage**: ~10-60 GB (depends on unique site pairs)

**Documentation**: `reference/storage-requirements-analysis.md`

---

## Implementation Roadmap

### Phase 1: Core Implementation (Ready)

**Status**: ✅ All solutions documented, ready to implement

**Tasks**:
1. Implement nested loop structure (cursors + set-based)
2. Create pre-computed lookup tables (antenna discrimination, over-horizon)
3. Implement CTX lookup with pure T-SQL
4. Implement error recovery (transactional with cleanup)

**Estimated Effort**: **8-12 weeks** (full implementation)

---

### Phase 2: Performance Optimization (Deferred)

**Status**: ⚠️ Deferred until after operational run

**Tasks** (to be done after Phase 1 is operational):
1. Design indexing strategy (2-3 days)
2. Design batching strategy (2-3 days)
3. Performance testing and validation (2-3 days)

**Note**: Parallel execution is not part of the strategy (sequential processing required).

**Estimated Effort**: **4-8 days**

**Priority**: **MEDIUM** (deferred)

---

### Phase 3: Testing and Validation

**Tasks**:
1. Unit testing of stored procedures
2. Integration testing with C# report generation
3. Performance benchmarking
4. Validation against C# results

**Estimated Effort**: **4-6 weeks**

---

## Document Organization

### Master Documents (This Document)
- `T-SQL-PORT-MASTER-PLAN.md` - **This document** - Consolidated plan and status

### Status/Summary Documents
- `trouble-spots-summary.md` - Quick reference for remaining issues
- `remaining-unaddressed-concerns.md` - Detailed remaining concerns

### Solution Documents (Detailed)
Located in [`solutions/`](./solutions/):
- `tsip-nested-loops-structure.md` - 6-level nested loop architecture
- `antenna-discrimination-analysis.md` - Antenna lookup solution
- `antenna-tables-maintenance.md` - Antenna table update workflow
- `over-horizon-path-loss-analysis.md` - Path loss solution
- `ctx-lookup-pure-tsql.md` - CTX caching solution
- `state-management-tsql-analysis.md` - State management analysis
- `error-recovery-implementation-decision.md` - Error recovery decision

### Reference Documents
Located in [`reference/`](./reference/):
- `performance-data-profiling.md` - Actual data volumes and metrics
- `storage-requirements-analysis.md` - Storage estimates

**Shared Reference Documents** (used by both T-SQL conversion and C# bug fixes):
- [`../shared/tsip-process-flow.md`](../shared/tsip-process-flow.md) - High-level process flow
- [`../shared/database-tables.md`](../shared/database-tables.md) - Table schemas and naming conventions

### Historical/Superseded Documents
Located in [`historical/`](./historical/):
- `ctx-lookup-caching-analysis.md` - CTX caching analysis (superseded by `solutions/ctx-lookup-pure-tsql.md`)
- `error-recovery-analysis.md` - Error recovery analysis (superseded by `solutions/error-recovery-implementation-decision.md`)
- `tsql-port-feasibility.md` - Superseded by this master plan
- `tsql-remaining-challenges.md` - Superseded by this master plan
- `tsql-challenging-portions.md` - Partially superseded (info moved to solution docs)

**Note**: C# production code bug analysis documents are in [`../bug-fixes/`](../bug-fixes/), not in this T-SQL conversion directory.

### Legacy Documents (Can be consolidated)
- `tsql-port-feasibility.md` - Initial feasibility analysis (superseded by this document)
- `tsql-remaining-challenges.md` - Challenge status (superseded by this document)
- `tsql-challenging-portions.md` - Detailed challenge analysis (information now in solution docs)

---

## Next Steps

### Immediate (High Priority)
1. **Implementation Planning** - Create detailed implementation plan for Phase 1
2. **Begin Core Implementation** - Start with nested loop structure and basic calculations

### Short Term
3. **Create Lookup Tables** - Set up pre-computed tables
4. **Get Operational Run Working** - Complete Phase 1 implementation

### Long Term
5. **Performance Tuning** - Optimize after operational run (indexing, batching)
6. **Integration** - Integrate with C# report generation

---

## Key Decisions Summary

| Decision | Status | Document |
|----------|--------|----------|
| **Nested Loops** | ✅ Cursors (1-4) + Set-based (5-6) | `solutions/tsip-nested-loops-structure.md` |
| **Antenna Discrimination** | ✅ Pre-computed lookup table | `solutions/antenna-discrimination-analysis.md` |
| **Over-Horizon Path Loss** | ✅ Pre-computed database (on-demand) | `solutions/over-horizon-path-loss-analysis.md` |
| **CTX Caching** | ✅ Pure T-SQL set-based | `solutions/ctx-lookup-pure-tsql.md` |
| **State Management** | ✅ Not needed (T-SQL handles naturally) | `solutions/state-management-tsql-analysis.md` |
| **Error Recovery** | ✅ Transactional with cleanup | `solutions/error-recovery-implementation-decision.md` |
| **Progress Tracking** | ✅ Not needed | `state-management-tsql-analysis.md` |
| **Report Generation** | ✅ Keep in C# | N/A |

---

## Success Criteria

### Functional
- ✅ All interference calculations produce same results as C# code
- ✅ All major challenges addressed with documented solutions
- ✅ Error handling provides atomicity and cleanup

### Performance
- ✅ Performance acceptable (300-600 seconds per run is acceptable)
- ✅ Sequential processing (no parallelization required)
- ✅ Memory usage below 12 GB threshold
- ⚠️ Performance tuning deferred until after operational run

### Quality
- ✅ Clean code with proper error handling
- ✅ Comprehensive documentation
- ✅ No orphaned tables or partial results

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|------------|
| **Performance** | MEDIUM | Indexing and batching strategies identified |
| **Complexity** | LOW | All solutions documented, clear implementation path |
| **Data Migration** | LOW | Pre-computed tables can be populated incrementally |
| **Integration** | LOW | C# can call T-SQL stored procedures |

---

## Conclusion

**Status**: ✅ **Ready for Implementation**

All major challenges have been analyzed and solutions documented. The only remaining work is performance optimization (indexing, batching, parallel execution), which is well-understood and can be addressed during implementation.

**Recommendation**: Proceed with Phase 1 implementation while continuing Phase 2 performance optimization work in parallel.

---

*Last Updated: January 2026*

