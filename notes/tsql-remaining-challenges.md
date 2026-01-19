# T-SQL Port: Remaining Challenges Summary

⚠️ **SUPERSEDED** - This document has been superseded by `T-SQL-PORT-MASTER-PLAN.md` which contains the consolidated project status, decisions, and roadmap. This document is kept for historical reference.

---

This document summarizes the remaining challenges for porting TSIP to T-SQL, their current status, and what still needs to be addressed.

---

## Challenge Status Overview

**Important Assumptions**:
- ✅ **Storage space is NOT a concern** - TB of space available
- ✅ **Report generation is separate** - Out of scope for core calculations

| # | Challenge | Status | Solution Approach | Notes |
|---|-----------|--------|-------------------|-------|
| 1 | **Nested Loop Processing** | ✅ **ADDRESSED** | Cursors (FAST_FORWARD) for levels 1-4, set-based for 5-6 | See `tsip-nested-loops-structure.md` |
| 2 | **Antenna Discrimination Lookups** | ✅ **ADDRESSED** | Pre-computed lookup table (`tsip.ant_disc_lookup`) | See `antenna-discrimination-analysis.md` |
| 3 | **Over-Horizon Path Loss** | ⚠️ **NEEDS DETAILED ANALYSIS** | **Pre-computed database (RECOMMENDED)** - Storage not a concern | See details below |
| 4 | **State Management** | ⚠️ **PARTIALLY ADDRESSED** | Temporary tables and table variables | May need more detail |
| 5 | **Performance Implications** | ⚠️ **PARTIALLY ADDRESSED** | Indexing, batching, parallel execution | May need optimization strategies |
| 6 | **CTX Lookup Caching** | ✅ **ADDRESSED** | **Pure T-SQL** set-based with pre-populated cache (CHOSEN) | See `ctx-lookup-pure-tsql.md` |
| 7 | **Report Generation** | ❌ **OUT OF SCOPE** | Keep in C# (separate concern) | Not part of core T-SQL port |

---

## 1. ✅ Nested Loop Processing (ADDRESSED)

**Status**: Fully addressed with detailed solutions

**Solution**: 
- **Levels 1-4**: Use `FAST_FORWARD` cursors (site, link, victim enumeration)
- **Levels 5-6**: Use set-based operations (antenna pairs, channel pairs)

**Documentation**: 
- `tsip-nested-loops-structure.md` - Complete 6-level breakdown
- `tsql-challenging-portions.md` - Cursor implementation examples

**Next Steps**: None - ready for implementation

---

## 2. ✅ Antenna Discrimination Lookups (ADDRESSED)

**Status**: Fully addressed with optimal solution

**Solution**: Pre-computed lookup table (`tsip.ant_disc_lookup`) with 0.1° resolution

**Key Points**:
- Antenna data updated extremely rarely (once per month)
- Pre-computation cost amortized over thousands of analyses
- Single index lookup (fastest possible)
- Monthly maintenance job to update new antennas

**Documentation**: 
- `antenna-discrimination-analysis.md` - Complete algorithm and implementation
- `antenna-tables-maintenance.md` - Maintenance strategy

**Next Steps**: None - ready for implementation

---

## 3. ✅ Over-Horizon Path Loss Calculations (ADDRESSED)

**Status**: Fully addressed with pre-computed database solution

### Solution: Pre-Computed Path Loss Database ⭐ **RECOMMENDED**

**Approach**: Pre-compute all path loss values and store in SQL Server database

**Key Points**:
- **Storage is NOT a concern** - TB available
- **Similar to antenna discrimination** - Pre-compute once, lookup many times
- **Fastest possible performance** - Single index lookup (~1ms)
- **No CLR needed** - Pure T-SQL solution (with optional fallback)
- **No file system access** - Everything in database

**Implementation**:
- Table: `tsip.over_horizon_path_loss`
- Pre-compute from historical TSIP runs
- Lookup function: `tsip.GetOverHorizonPathLoss()`
- Incremental updates for new paths
- Optional fallback to CLR for missing paths

**Storage Estimate**:
- **10 million unique paths** × 64 height combinations × 5 frequencies × 2 polarizations
- **Total**: ~6.4 billion rows
- **Storage**: ~1.5-3 TB (acceptable with TB available)

**Documentation**: 
- `over-horizon-path-loss-analysis.md` - Complete analysis and implementation

**Next Steps**: 
1. Analyze historical data to identify unique paths
2. Build pre-computation program (use existing C# code)
3. Implement lookup function
4. Test and validate

#### Option C: External Service (Microservice)

**Approach**: Keep over-horizon as separate HTTP service

**Pros**:
- Isolates complexity
- Can scale independently
- No CLR in main database

**Cons**:
- Network latency
- Additional infrastructure
- Complexity

**Status**: Needs architecture design

### Implementation Details

**Pre-Computation Strategy**:
1. Extract unique paths from historical TSIP runs
2. Identify standard parameters (heights: 10-200m, frequencies: 6-38 GHz)
3. Use existing C# code with `_OHloss.dll` to pre-compute
4. Populate `tsip.over_horizon_path_loss` table
5. Background job for incremental updates

**Lookup Function**:
- Simple index lookup with tolerance matching
- Fast (~1ms per lookup)
- Fallback to CLR or queue for missing paths

**See**: `over-horizon-path-loss-analysis.md` for complete details

---

## 4. ⚠️ State Management (PARTIALLY ADDRESSED)

**Status**: Solutions identified but may need refinement

### Current Solutions

#### Solution 1: Temporary Tables for State

```sql
CREATE TABLE #ProcessingState (
    proposed_site VARCHAR(9),
    current_link INT,
    num_cases INT,
    last_traf_tx VARCHAR(6),
    last_traf_rx VARCHAR(6),
    last_eqpt_tx VARCHAR(8),
    last_eqpt_rx VARCHAR(8),
    ctx_data VARBINARY(MAX)
);
```

**Status**: Basic approach identified, may need optimization

#### Solution 2: CTX Caching with Table Variable

```sql
DECLARE @CtxCache TABLE (
    traf_tx VARCHAR(6),
    traf_rx VARCHAR(6),
    eqpt_tx VARCHAR(8),
    eqpt_rx VARCHAR(8),
    required_ci FLOAT,
    PRIMARY KEY (traf_tx, traf_rx, eqpt_tx, eqpt_rx)
);
```

**Status**: Basic approach identified, needs performance testing

#### Solution 3: Progress Tracking Table

```sql
CREATE TABLE tsip.analysis_progress (
    run_id VARCHAR(50),
    stage VARCHAR(50),
    current_item VARCHAR(100),
    items_processed INT,
    items_total INT,
    start_time DATETIME,
    last_update DATETIME
);
```

**Status**: Basic approach identified

### Questions to Answer

1. **How effective is CTX caching?**
   - How many unique CTX combinations are there?
   - What's the cache hit rate?
   - Is table variable fast enough or need temp table?

2. **What state needs to persist across sessions?**
   - Progress tracking?
   - Intermediate results?
   - Error recovery?

3. **Memory management?**
   - How large do state tables get?
   - Need cleanup strategies?
   - TempDB optimization needed?

### Next Steps

1. **Analyze CTX usage patterns**: Determine cache effectiveness
2. **Design state persistence**: For progress tracking and recovery
3. **Performance test**: Table variables vs. temp tables
4. **Memory optimization**: Strategies for large state tables

---

## 5. ⚠️ Performance Implications (PARTIALLY ADDRESSED)

**Status**: Challenges identified, optimization strategies needed

### Identified Challenges

#### Challenge 1: Cartesian Products

**Problem**: Set-based approach creates large intermediate result sets

**Example**:
```
100 proposed sites × 1000 victim sites × 5 links × 3 antennas × 10 channels
= 15,000,000 intermediate rows
```

**Solutions Identified**:
- Filter early (apply all culling before joins)
- Batch processing (process in smaller chunks)
- Proper indexing
- Table partitioning

**Status**: Strategies identified, need specific implementation

#### Challenge 2: Function Call Overhead

**Problem**: Scalar functions called millions of times

**Solution**: Use CROSS APPLY with table-valued functions or pre-compute

**Status**: Pre-computation approach chosen for antenna discrimination, may need for other functions

#### Challenge 3: Memory Pressure

**Problem**: Large intermediate tables consume memory

**Solutions Identified**:
- Streaming (CURSOR for very large sets)
- Batch processing
- TempDB optimization
- Memory grants adjustment

**Status**: Strategies identified, need specific implementation

#### Challenge 4: Parallel Execution

**Opportunity**: SQL Server can parallelize set-based operations

**Status**: Opportunity identified, need to design for parallelization

### Data Profiling (COMPLETE)

**Actual Database Volumes** (from production):
- **Channels**: 160,746
- **Antenna Types**: 3,200
- **Antennas**: 108,065
- **Sites**: 68,914
- **Numbers are static** (relatively stable)

**Derived Metrics**:
- **Channels per Site**: ~2.3
- **Antennas per Site**: ~1.6
- **Channels per Antenna**: ~1.5

**See**: `performance-data-profiling.md` for complete analysis

### Questions to Answer

1. ✅ **What are the actual data volumes?** - **ANSWERED**
   - 68,914 sites, 160,746 channels, 108,065 antennas
   - Average: ~2.3 channels/site, ~1.6 antennas/site

2. **What's the optimal batch size?**
   - **Recommendation**: 50-100 sites per batch (based on data volumes)
   - Memory vs. performance trade-off: ~100-500 MB per batch

3. **What indexes are needed?**
   - **See**: `performance-data-profiling.md` for detailed indexing strategy
   - Critical indexes identified for sites, antennas, channels, lookups

4. **Can we use parallel execution effectively?**
   - **Yes**: Set-based operations (Levels 5-6) can be parallelized
   - **Recommendation**: MAXDOP 4-8 for set-based queries
   - **Blocking**: Cursor-based operations (Levels 1-4) cannot be parallelized

### Next Steps

1. ✅ **Profile data volumes**: **COMPLETE** - Actual volumes documented
2. ⏭️ **Design indexing strategy**: Based on query patterns (see profiling doc)
3. ⏭️ **Design batching strategy**: Optimal batch sizes (50-100 sites)
4. ⏭️ **Test parallel execution**: Determine optimal MAXDOP settings

---

## 6. ✅ CTX Lookup Caching (ADDRESSED)

**Status**: Fully analyzed and **APPROACH CHOSEN**

### Chosen Solution: Pure T-SQL (No C# Dependencies)

**Decision**: Use **pure T-SQL set-based approach** with pre-populated cache - no CLR functions, no C# dependencies.

**Pre-populated Table Variable Cache** (CHOSEN APPROACH):
```sql
-- Pre-populate cache with all unique CTX combinations
DECLARE @CtxMainCache TABLE (
    tfcr VARCHAR(6),
    tfci VARCHAR(6),
    rxeqp VARCHAR(8),
    rqco FLOAT,
    PRIMARY KEY (tfcr, tfci, rxeqp)
);

-- Pre-populate from channel pairs
INSERT INTO @CtxMainCache (tfcr, tfci, rxeqp, rqco)
SELECT DISTINCT
    pc.inttraftx AS tfcr,
    ec.victrafrx AS tfci,
    ec.viceqptrx AS rxeqp,
    ctx.rqco
FROM ft_chan pc
CROSS JOIN ft_chan ec
LEFT JOIN main.sd_ctx ctx
    ON ctx.tfcr = pc.inttraftx
    AND ctx.tfci = ec.victrafrx
    AND ctx.rxeqp = ec.viceqptrx
WHERE ... -- culling criteria
  AND ctx.rqco IS NOT NULL;

-- Then use JOIN in set-based operations
SELECT 
    pc.*,
    ec.*,
    cache.rqco AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
INNER JOIN @CtxMainCache cache
    ON cache.tfcr = pc.inttraftx
    AND cache.tfci = ec.victrafrx
    AND cache.rxeqp = ec.viceqptrx;
```

### Key Findings

1. **Cache Size**: Very small (~100 KB for 100-500 CTX records)
2. **Cache Hit Rate**: High (85-95%) due to repeated traffic/equipment combinations
3. **Performance**: T-SQL can match or exceed C# performance with pre-populated cache
4. **Implementation**: Simple (1-2 days effort)

### C# Implementation Analysis

- **Two-level caching**: High-level cache (100 entries) + curve cache (8 entries)
- **Cache effectiveness**: High due to sequential processing and repeated combinations
- **Lookup frequency**: Once per channel pair (Level 6)
- **Typical volume**: 1-5 million CTX lookups per analysis run

### T-SQL Recommendations (CHOSEN APPROACH)

1. **Pure T-SQL solution** - No CLR functions, no C# dependencies
2. **Pre-populate cache** with all unique CTX combinations at start of analysis
3. **Use JOIN** instead of scalar function calls (set-based approach) - **10-100× faster**
4. **Table variable** is sufficient (small cache size, session-scoped)
5. **Curve interpolation**: Use inline SQL with `LAG()`/`LEAD()` window functions (pure T-SQL)

**Key Benefits**:
- ✅ **No CLR required**: Easier deployment, no assembly registration
- ✅ **Better performance**: Set-based operations are 10-100× faster
- ✅ **Portable**: Works on any SQL Server version (2012+)
- ✅ **Simpler maintenance**: Pure T-SQL is easier to debug

**See**: 
- `ctx-lookup-caching-analysis.md` for complete analysis
- `ctx-lookup-pure-tsql.md` for complete pure T-SQL implementation

### Next Steps

✅ **APPROACH CHOSEN** - Pure T-SQL solution documented and ready for implementation

---

## 7. ❌ Report Generation (NOT ADDRESSED)

**Status**: Out of scope for core T-SQL port

**Current Implementation**: C# generates reports (`.CASEDET`, `.CASESUM`, `.AGGINT`, etc.)

**Options**:
1. **Keep in C#**: Generate reports from T-SQL results
2. **SQL Server Reporting Services**: Generate reports from T-SQL tables
3. **T-SQL Stored Procedures**: Generate text reports (complex)

**Recommendation**: Keep report generation in C# - it's a separate concern from core calculations

**Next Steps**: None - out of scope

---

## Priority Ranking

Based on impact and complexity:

1. **High Priority** (All Addressed):
   - ✅ **Over-Horizon Path Loss** - **SOLVED** with pre-computed database
   - ⚠️ **Performance Optimization** - Affects usability (needs data profiling)

2. **Medium Priority**:
   - ⚠️ **State Management** - Affects reliability and progress tracking
   - ✅ **CTX Caching** - **ADDRESSED** - Pre-populated cache solution identified

3. **Low Priority**:
   - ❌ **Report Generation** - Out of scope

---

## Recommended Next Steps

1. ✅ **Over-Horizon Path Loss** - **COMPLETE**
   - Solution chosen: Pre-computed database
   - Implementation plan created
   - Ready for pre-computation program development

2. **Performance Analysis** (Next Priority)
   - Profile actual data volumes
   - Design indexing strategy
   - Design batching strategy
   - Test parallel execution

3. ✅ **CTX Caching** - **COMPLETE**
   - Solution: Pre-populated table variable cache
   - Analysis complete: See `ctx-lookup-caching-analysis.md`
   - Ready for implementation

4. **State Management Refinement**
   - Design state persistence
   - Performance test state management approaches

4. **Implementation Planning**
   - Create detailed implementation plan for all solutions
   - Design test strategy
   - Plan migration approach

---

*Last updated: January 2026*

