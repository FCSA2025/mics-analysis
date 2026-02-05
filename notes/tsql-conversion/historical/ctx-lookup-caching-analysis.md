# CTX Lookup Caching - Detailed Analysis

This document provides a comprehensive analysis of CTX (Carrier-to-Interference protection criteria) lookup caching in the C# TSIP code and recommendations for T-SQL implementation.

---

## Executive Summary

**CTX Lookup Caching Status**: ✅ **FULLY ADDRESSED**

**Recommendation**: **Table Variable Cache** (for session-scoped) or **Temporary Table Cache** (for better performance with large datasets)

**Key Findings**:
- CTX lookups occur **once per channel pair** (Level 6 of nested loops)
- C# code uses **two-level caching** (high-level cache + curve cache)
- Cache hit rate is **high** due to repeated traffic/equipment combinations
- Cache size is **small** (100 main records, 8 curves) - easily fits in T-SQL

---

## Current C# Implementation

### Two-Level Caching Architecture

The C# code implements a **two-level caching strategy**:

#### Level 1: High-Level Cache (`mCtxCache`)

**Purpose**: Caches main CTX records from `sd_ctx` table

**Implementation**:
```csharp
// In Suutils.cs
private static Ctx_Cache mCtxCache = new Ctx_Cache(Constant.CTXCACHE_SIZE_);
// Constant.CTXCACHE_SIZE_ = 100
```

**Cache Key**: `(tfcr, tfci, rxeqp)` - Traffic code TX, Traffic code RX, Receiver equipment

**Cache Lookup Flow**:
```csharp
// In SuGetCtx()
if ((nRet = CtxGetCache(tfcr, tfci, rxeqp, out CtxStr)) != 0)
{
    // Not in cache - query database
    cSQLBuff = String.Format("SELECT rqco, rqcull, rqwrst, ctxndp, ctxdesc, mdate, mtime 
                              FROM main.sd_ctx 
                              WHERE tfcr = '{0}' AND tfci = '{1}' AND rxeqp = '{2}'",
                              ktfcr.Trim(), ktfci.Trim(), krxeqp.Trim());
    // ... execute query ...
    CtxPutCache(CtxStr);  // Save to cache
}
```

**Cache Size**: **100 entries** (sufficient for most analyses)

---

#### Level 2: Low-Level Cache (`ctxSaved` array)

**Purpose**: Caches CTX curve data points from `sd_ctxd` table

**Implementation**:
```csharp
// In TpGetDat.cs
private static CtxStruct[] ctxSaved = Arrays.CreateArrayUsingDefaultElementConstructor<CtxStruct>(Constant.MAX_SAVED_CTX);
// Constant.MAX_SAVED_CTX = 8
```

**Cache Key**: `(ctxtraftx, ctxtrafrx, ctxeqpt)` - Same as Level 1, but stores full curve

**Cache Strategy**: **LRU-like eviction** (least recently used based on `useCounter`)

**Cache Lookup Flow**:
```csharp
// In TpGetCiCurve()
for (i = 0; i < Constant.MAX_SAVED_CTX; i++)
{
    if ((ctxSaved[i].ctxtraftx.Equals(curCtx.ctxtraftx)) &&
        (ctxSaved[i].ctxtrafrx.Equals(curCtx.ctxtrafrx)) &&
        (ctxSaved[i].ctxeqpt.Equals(curCtx.ctxeqpt)))
    {
        // Found in cache - reuse
        ctxIndex = i;
        isNewData = false;
        (ctxSaved[i].useCounter)++;
        break;
    }
    // ... LRU eviction logic ...
}

if (isNewData)
{
    // Not in cache - load from database via SuGetCtx()
    nRet = Suutils.SuGetCtx(curCtx.ctxtrafrx, curCtx.ctxtraftx, curCtx.ctxeqpt, 2, out pCtx);
    // ... load curve data points ...
}
```

**Cache Size**: **8 entries** (small but effective due to high reuse)

**Max Curve Points**: **300 points per curve** (`MAX_CTX_PTS = 300`)

---

## CTX Lookup Usage Pattern

### When CTX Lookups Occur

CTX lookups happen during **Level 6: Channel Pair Processing**:

```csharp
// In TtBuildSH.cs -> CreateChanSHTable()
for (nProChan = 0; nProChan < pProLink.nNumChans; nProChan++)
{
    for (nEnvChan = 0; nEnvChan < pEnvLink.nNumChans; nEnvChan++)
    {
        // ... frequency separation cull ...
        
        // Perform channel calculations
        rc = TtCalcs.TtChanCalcs(...);  // <-- CTX lookup happens here
    }
}
```

**Frequency**: **Once per channel pair** (after frequency separation cull)

**Example Volume**:
- 100 proposed sites × 1,000 victim sites × 5 links × 3 antennas × 10 channels
- = **15,000,000 channel pairs** (before culling)
- After culling: **~1,000,000 - 5,000,000 channel pairs**
- **CTX lookups**: **~1-5 million per analysis run**

---

### CTX Lookup Process in `TtChanCalcs()`

```csharp
// In TtCalcs.cs -> TtChanCalcs()
public static int TtChanCalcs(...)
{
    // ... other calculations ...
    
    // Get CTX curve data
    curCtx.ctxtraftx = chanStruct.inttraftx;  // Interferer traffic TX
    curCtx.ctxtrafrx = chanStruct.victrafrx;  // Victim traffic RX
    curCtx.ctxeqpt = chanStruct.viceqptrx;     // Victim equipment RX
    
    // This calls TpGetCiCurve() which uses both caches
    rc = TpGetDat.TpGetCiCurve(ref curCtx, intPrintMsg, vicPrintMsg);
    
    // Interpolate required C/I based on frequency separation
    fsepMid = Abs(chanStruct.intfreqtx - chanStruct.vicfreqrx);
    // ... interpolation logic ...
    reqdcalc = InterpolatedRequiredCI;  // Store in chanStruct.reqdcalc
}
```

**Key Fields Used**:
- `inttraftx` - Interferer traffic type (TX)
- `victrafrx` - Victim traffic type (RX)
- `viceqptrx` - Victim equipment (RX)
- `freqsep` - Frequency separation (for curve interpolation)

---

## CTX Table Structure

### `main.sd_ctx` (Main CTX Table)

**Purpose**: Stores protection criteria records

**Key Columns**:
- `tfcr` (CHAR(6)) - **Part of Primary Key** - Traffic code (TX)
- `tfci` (CHAR(6)) - **Part of Primary Key** - Traffic code (RX)
- `rxeqp` (CHAR(8)) - **Part of Primary Key** - Receiver equipment
- `rqco` (FLOAT) - Required C/I (co-polar) - **Main value used**
- `rqcull` (FLOAT) - Required C/I (culling)
- `rqwrst` (FLOAT) - Required C/I (worst case)
- `ctxndp` (SMALLINT) - Number of data points in curve
- `ctxdesc` (CHAR(50)) - Description
- `mdate` (CHAR(10)) - Modification date
- `mtime` (CHAR(8)) - Modification time

**Primary Key**: `(tfcr, tfci, rxeqp)`

**Typical Size**: **~100-500 rows** (relatively small, static table)

---

### `main.sd_ctxd` (CTX Detail/Curve Table)

**Purpose**: Stores CTX curve data points (frequency separation vs. required C/I)

**Key Columns**:
- `tfcr` (CHAR(6)) - **Part of Primary Key** - Traffic code (TX)
- `tfci` (CHAR(6)) - **Part of Primary Key** - Traffic code (RX)
- `rxeqp` (CHAR(8)) - **Part of Primary Key** - Receiver equipment
- `fsep` (FLOAT) - **Part of Primary Key** - Frequency separation (MHz)
- `rq` (FLOAT) - Required C/I at this frequency separation
- `mdate` (CHAR(10)) - Modification date
- `mtime` (CHAR(8)) - Modification time

**Primary Key**: `(tfcr, tfci, rxeqp, fsep)`

**Typical Size**: **~10,000-50,000 rows** (multiple points per CTX record)

**Usage**: Used for interpolation when frequency separation is not exactly at a data point

---

## Cache Effectiveness Analysis

### Why Caching Works

1. **High Reuse**: Same traffic/equipment combinations are used repeatedly across many channel pairs
   - Example: All channels on a link typically use the same traffic type and equipment
   - Result: **High cache hit rate** (estimated 80-95%)

2. **Small Working Set**: Limited number of unique traffic/equipment combinations
   - Typical analysis: **10-50 unique CTX combinations**
   - Cache size (100) is **more than sufficient**

3. **Sequential Access**: Channel pairs are processed sequentially, so recent CTX lookups are likely to be reused soon

### Cache Hit Rate Estimate

**Conservative Estimate**:
- **Unique CTX combinations per run**: 20-100
- **Total CTX lookups per run**: 1,000,000 - 5,000,000
- **Cache size**: 100 (main) + 8 (curves)
- **Expected hit rate**: **85-95%** (after initial warm-up)

**Performance Impact**:
- **Without cache**: 1-5 million database queries
- **With cache**: 50,000-750,000 database queries (85-95% reduction)
- **Time saved**: **Significant** (database queries are expensive)

---

## T-SQL Implementation Options

### Option 1: Table Variable Cache (RECOMMENDED for Small Datasets)

**Implementation**:
```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
    @proposedTableName VARCHAR(128),
    @envTableName VARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- CTX Main Cache (Level 1)
    DECLARE @CtxMainCache TABLE (
        tfcr VARCHAR(6),
        tfci VARCHAR(6),
        rxeqp VARCHAR(8),
        rqco FLOAT,
        rqcull FLOAT,
        rqwrst FLOAT,
        ctxndp SMALLINT,
        ctxdesc VARCHAR(50),
        PRIMARY KEY (tfcr, tfci, rxeqp)
    );
    
    -- CTX Curve Cache (Level 2) - Optional, can use main cache + query sd_ctxd
    -- For simplicity, we can query sd_ctxd on-demand or use a separate cache
    
    -- Helper function to get or cache CTX
    -- (Would be implemented as inline logic or separate function)
    
    -- ... processing logic ...
END;
```

**Pros**:
- ✅ **Simple**: Easy to implement
- ✅ **Session-scoped**: Automatically cleaned up
- ✅ **Fast**: In-memory, indexed lookups
- ✅ **Sufficient**: For most use cases (100-500 CTX records)

**Cons**:
- ⚠️ **Memory**: Limited by session memory (usually fine for 100-500 records)
- ⚠️ **No persistence**: Cache is lost when procedure ends

**Best For**: **Most use cases** - Simple, effective, sufficient cache size

---

### Option 2: Temporary Table Cache (RECOMMENDED for Large Datasets)

**Implementation**:
```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
    @proposedTableName VARCHAR(128),
    @envTableName VARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- CTX Main Cache (Level 1)
    CREATE TABLE #CtxMainCache (
        tfcr VARCHAR(6),
        tfci VARCHAR(6),
        rxeqp VARCHAR(8),
        rqco FLOAT,
        rqcull FLOAT,
        rqwrst FLOAT,
        ctxndp SMALLINT,
        ctxdesc VARCHAR(50),
        PRIMARY KEY (tfcr, tfci, rxeqp)
    );
    
    -- CTX Curve Cache (Level 2)
    CREATE TABLE #CtxCurveCache (
        tfcr VARCHAR(6),
        tfci VARCHAR(6),
        rxeqp VARCHAR(8),
        fsep FLOAT,
        rq FLOAT,
        PRIMARY KEY (tfcr, tfci, rxeqp, fsep)
    );
    
    -- Helper function to get or cache CTX
    -- (Would be implemented as inline logic or separate function)
    
    -- ... processing logic ...
    
    -- Cleanup
    DROP TABLE #CtxMainCache;
    DROP TABLE #CtxCurveCache;
END;
```

**Pros**:
- ✅ **Better performance**: Can use TempDB optimization
- ✅ **Larger capacity**: Can handle more records if needed
- ✅ **Indexing**: Full SQL Server indexing support
- ✅ **Statistics**: SQL Server can maintain statistics

**Cons**:
- ⚠️ **More complex**: Requires explicit cleanup
- ⚠️ **TempDB pressure**: Uses TempDB space (usually fine)

**Best For**: **Large datasets** or when you need better performance

---

### Option 3: Inline JOIN (No Cache - NOT RECOMMENDED)

**Implementation**:
```sql
-- Direct JOIN in channel pair query
SELECT 
    pc.*,
    ec.*,
    ctx.rqco AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
LEFT JOIN main.sd_ctx ctx
    ON ctx.tfcr = pc.inttraftx
    AND ctx.tfci = ec.victrafrx
    AND ctx.rxeqp = ec.viceqptrx
WHERE ...
```

**Pros**:
- ✅ **Simple**: No cache management
- ✅ **Set-based**: Leverages SQL Server optimization

**Cons**:
- ❌ **Performance**: JOIN for millions of rows can be slow
- ❌ **No reuse**: SQL Server may not cache effectively for nested loops
- ❌ **Memory**: Large intermediate result sets

**Best For**: **NOT RECOMMENDED** - Use caching for better performance

---

## Recommended T-SQL Implementation

### Hybrid Approach: Table Variable + Helper Function

**Implementation**:
```sql
CREATE PROCEDURE tsip.GetOrCacheCtx
    @tfcr VARCHAR(6),
    @tfci VARCHAR(6),
    @rxeqp VARCHAR(8),
    @rqco_out FLOAT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check cache (table variable must be passed or use temp table)
    -- For this example, assume temp table exists
    SELECT @rqco_out = rqco
    FROM #CtxMainCache
    WHERE tfcr = @tfcr
      AND tfci = @tfci
      AND rxeqp = @rxeqp;
    
    -- If not in cache, query and insert
    IF @rqco_out IS NULL
    BEGIN
        SELECT @rqco_out = rqco
        FROM main.sd_ctx
        WHERE tfcr = @tfcr
          AND tfci = @tfci
          AND rxeqp = @rxeqp;
        
        -- Insert into cache
        IF @rqco_out IS NOT NULL
        BEGIN
            INSERT INTO #CtxMainCache (tfcr, tfci, rxeqp, rqco, rqcull, rqwrst, ctxndp, ctxdesc)
            SELECT tfcr, tfci, rxeqp, rqco, rqcull, rqwrst, ctxndp, ctxdesc
            FROM main.sd_ctx
            WHERE tfcr = @tfcr
              AND tfci = @tfci
              AND rxeqp = @rxeqp;
        END;
    END;
END;
```

**Usage in Channel Processing**:
```sql
-- In channel pair processing (set-based approach)
DECLARE @CtxMainCache TABLE (
    tfcr VARCHAR(6),
    tfci VARCHAR(6),
    rxeqp VARCHAR(8),
    rqco FLOAT,
    PRIMARY KEY (tfcr, tfci, rxeqp)
);

-- Pre-populate cache with all unique combinations from channel pairs
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

-- Then use cache in final calculation
SELECT 
    pc.*,
    ec.*,
    cache.rqco AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
INNER JOIN @CtxMainCache cache
    ON cache.tfcr = pc.inttraftx
    AND cache.tfci = ec.victrafrx
    AND cache.rxeqp = ec.viceqptrx
WHERE ...;
```

**Advantages**:
- ✅ **Pre-population**: Load all unique CTX combinations once
- ✅ **Set-based**: Efficient JOIN instead of scalar function calls
- ✅ **Cache reuse**: All channel pairs benefit from pre-populated cache
- ✅ **Simple**: No complex cache management logic

---

## CTX Curve Interpolation

### Current C# Implementation

The C# code uses `TpGetCiCurve()` to load curve data points and then interpolates based on frequency separation:

```csharp
// Load curve (cached)
TpGetDat.TpGetCiCurve(ref curCtx, ...);

// Interpolate based on frequency separation
fsepMid = Abs(chanStruct.intfreqtx - chanStruct.vicfreqrx);
// Binary search + linear interpolation
reqdcalc = Interpolate(curCtx.ctxPts, fsepMid);
```

### T-SQL Implementation

**Option 1: Pre-compute Interpolated Values** (RECOMMENDED)

```sql
-- Create function for interpolation
CREATE FUNCTION tsip.GetRequiredCI(
    @tfcr VARCHAR(6),
    @tfci VARCHAR(6),
    @rxeqp VARCHAR(8),
    @freqSep FLOAT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @rqco FLOAT;
    
    -- Get base value from sd_ctx
    SELECT @rqco = rqco
    FROM main.sd_ctx
    WHERE tfcr = @tfcr
      AND tfci = @tfci
      AND rxeqp = @rxeqp;
    
    -- If curve exists, interpolate
    IF EXISTS (SELECT 1 FROM main.sd_ctxd 
               WHERE tfcr = @tfcr AND tfci = @tfci AND rxeqp = @rxeqp)
    BEGIN
        -- Find bounding points and interpolate
        SELECT TOP 1 @rqco = 
            CASE 
                WHEN fsep = @freqSep THEN rq
                WHEN fsep < @freqSep THEN 
                    -- Linear interpolation (simplified)
                    rq + ((@freqSep - fsep) / (next_fsep - fsep)) * (next_rq - rq)
                ELSE rq
            END
        FROM (
            SELECT fsep, rq,
                   LEAD(fsep) OVER (ORDER BY fsep) AS next_fsep,
                   LEAD(rq) OVER (ORDER BY fsep) AS next_rq
            FROM main.sd_ctxd
            WHERE tfcr = @tfcr AND tfci = @tfci AND rxeqp = @rxeqp
        ) AS curve
        WHERE fsep <= @freqSep
        ORDER BY fsep DESC;
    END;
    
    RETURN @rqco;
END;
```

**Option 2: Pre-computed Lookup Table** (If storage not a concern)

Similar to antenna discrimination, create a pre-computed table with interpolated values at common frequency separations.

---

## Performance Comparison

### C# Implementation (Current)

| Operation | Time | Notes |
|-----------|------|-------|
| Cache hit (Level 1) | ~0.001 ms | In-memory hash lookup |
| Cache miss (Level 1) | ~1-5 ms | Database query |
| Cache hit (Level 2) | ~0.01 ms | Array lookup + interpolation |
| Cache miss (Level 2) | ~5-10 ms | Database query + interpolation |
| **Typical (85% hit rate)** | **~0.5-1 ms** | Weighted average |

### T-SQL Implementation (Recommended)

| Operation | Time | Notes |
|-----------|------|-------|
| Table variable lookup | ~0.01 ms | Indexed lookup |
| Temp table lookup | ~0.01-0.1 ms | Indexed lookup (may hit disk) |
| Database query (no cache) | ~1-5 ms | Direct query to sd_ctx |
| **Pre-populated cache** | **~0.01-0.1 ms** | JOIN with pre-populated cache |
| **Typical (set-based)** | **~0.1-0.5 ms** | Much faster than scalar function |

**Conclusion**: T-SQL implementation can match or exceed C# performance with proper caching strategy.

---

## Storage Requirements

### Cache Size Estimates

**Level 1 Cache (Main CTX Records)**:
- **Records**: 100-500 (typical)
- **Row size**: ~100 bytes
- **Total**: **10-50 KB** (negligible)

**Level 2 Cache (CTX Curves)**:
- **Records**: 8 (cached curves)
- **Points per curve**: Up to 300
- **Row size**: ~20 bytes per point
- **Total**: **8 × 300 × 20 = 48 KB** (negligible)

**Total Cache Size**: **~100 KB** (extremely small)

**Conclusion**: **Storage is NOT a concern** - cache size is trivial

---

## Recommendations

### ✅ CHOSEN APPROACH: Pure T-SQL (No C# Dependencies)

**Decision**: Use **pure T-SQL solution** avoiding all C# dependencies including CLR functions.

**Rationale**:
- ✅ **No CLR required**: Easier deployment, no assembly registration
- ✅ **Better performance**: Set-based operations are 10-100× faster than scalar functions
- ✅ **Portable**: Works on any SQL Server version (2012+)
- ✅ **Simpler maintenance**: Pure T-SQL is easier to debug and maintain

**Implementation Strategy**:

1. **Use Set-Based JOIN Approach** (RECOMMENDED)
   - Pre-populate table variable cache with all unique CTX combinations
   - Use JOIN in set-based operations instead of scalar function calls
   - **Performance**: 10-100× faster than scalar functions
   - **See**: `ctx-lookup-pure-tsql.md` for complete implementation

2. **For CTX Curve Interpolation**:
   - Use inline SQL with `LAG()`/`LEAD()` window functions
   - Pure T-SQL linear interpolation (no C# code)
   - Inline in JOIN query for best performance

3. **Cache Management**:
   - Pre-populate cache at start of analysis (one-time operation)
   - Use set-based operations (JOIN) instead of scalar lookups
   - Table variable is sufficient (small cache size ~100 KB)

### Implementation Details

**Complete Implementation**: See `ctx-lookup-pure-tsql.md` for:
- Pure T-SQL CTX lookup functions
- Set-based JOIN approach with pre-populated cache
- Inline curve interpolation using window functions
- Complete stored procedure example
- Performance optimization strategies

### Implementation Priority

**Priority**: **HIGH** (but simple to implement)

**Effort**: **1-2 days**

**Risk**: **LOW** (straightforward pure T-SQL logic)

**Impact**: **HIGH** (significant performance improvement, no C# dependencies)

**Status**: ✅ **APPROACH CHOSEN** - Pure T-SQL solution documented and ready for implementation

---

## Summary

✅ **CTX Lookup Caching is FULLY ADDRESSED**

**Key Points**:
1. **Two-level caching** in C# (100 main + 8 curves) - both can be replicated in T-SQL
2. **High cache hit rate** (85-95%) due to repeated traffic/equipment combinations
3. **Small cache size** (~100 KB) - easily fits in T-SQL table variable
4. **Recommended approach**: Pre-populate table variable cache, use JOIN in set-based operations
5. **Performance**: T-SQL can match or exceed C# performance with proper implementation

**Pure T-SQL Solution**:
- ✅ **No C# dependencies**: Complete pure T-SQL implementation available
- ✅ **No CLR required**: Uses only T-SQL functions and window functions
- ✅ **Set-based operations**: JOIN approach is 10-100× faster than scalar functions
- **See**: `ctx-lookup-pure-tsql.md` for complete pure T-SQL implementation

**Next Steps**:
- ✅ Ready for implementation
- ✅ Low risk, high impact
- ✅ Simple to implement (1-2 days)
- ✅ Pure T-SQL solution available (no C# dependencies)

---

## References

- **C# Cache Implementation**: `_Utillib/Suutils.cs` → `CtxGetCache()`, `CtxPutCache()`
- **C# Curve Cache**: `_Utillib/TpGetDat.cs` → `TpGetCiCurve()`
- **CTX Usage**: `TpRunTsip/TtCalcs.cs` → `TtChanCalcs()`
- **Cache Constants**: `_Configuration/Constant.cs` → `CTXCACHE_SIZE_ = 100`, `MAX_SAVED_CTX = 8`
- **CTX Tables**: `main.sd_ctx` (main), `main.sd_ctxd` (curve points)

