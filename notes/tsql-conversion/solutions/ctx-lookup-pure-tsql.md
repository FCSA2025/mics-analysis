# CTX Lookup - Pure T-SQL Implementation (No C# Dependencies)

**STATUS**: ✅ **CHOSEN APPROACH**

This document provides the **chosen pure T-SQL solution** for CTX lookup and caching, avoiding all C# dependencies including CLR functions.

**Decision**: Use pure T-SQL set-based approach with pre-populated cache for best performance and simplest deployment.

---

## Overview

**Goal**: Implement CTX lookup and curve interpolation using **only T-SQL** - no CLR functions, no C# code, no external dependencies.

**Approach**: 
- Pure T-SQL scalar and table-valued functions
- Set-based operations with JOINs (preferred over scalar functions)
- Pre-populated cache tables (table variables or temp tables)
- Inline interpolation using window functions

---

## Solution Architecture

### 1. CTX Main Lookup Function (Pure T-SQL)

**Purpose**: Get required C/I from `sd_ctx` table

```sql
-- Simple lookup function (no caching - for reference)
CREATE FUNCTION tsip.GetRequiredCI_Simple(
    @tfcr VARCHAR(6),
    @tfci VARCHAR(6),
    @rxeqp VARCHAR(8)
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @rqco FLOAT;
    
    SELECT @rqco = rqco
    FROM main.sd_ctx
    WHERE tfcr = @tfcr
      AND tfci = @tfci
      AND rxeqp = @rxeqp;
    
    RETURN @rqco;
END;
```

**Note**: This is a simple scalar function. For better performance, use set-based JOINs instead (see below).

---

### 2. CTX Curve Interpolation Function (Pure T-SQL)

**Purpose**: Interpolate required C/I based on frequency separation using curve data from `sd_ctxd`

```sql
CREATE FUNCTION tsip.GetRequiredCI_WithInterpolation(
    @tfcr VARCHAR(6),
    @tfci VARCHAR(6),
    @rxeqp VARCHAR(8),
    @freqSep FLOAT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @rqco FLOAT;
    DECLARE @hasCurve BIT = 0;
    
    -- Check if curve data exists
    SELECT @hasCurve = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM main.sd_ctxd
    WHERE tfcr = @tfcr
      AND tfci = @tfci
      AND rxeqp = @rxeqp;
    
    IF @hasCurve = 0
    BEGIN
        -- No curve data - use base value from sd_ctx
        SELECT @rqco = rqco
        FROM main.sd_ctx
        WHERE tfcr = @tfcr
          AND tfci = @tfci
          AND rxeqp = @rxeqp;
    END
    ELSE
    BEGIN
        -- Curve data exists - interpolate
        -- Find the two bounding points and interpolate linearly
        SELECT TOP 1 @rqco = 
            CASE
                -- Exact match
                WHEN fsep = @freqSep THEN rq
                -- Interpolate between current and next point
                WHEN next_fsep IS NOT NULL AND fsep < @freqSep AND next_fsep > @freqSep THEN
                    rq + ((@freqSep - fsep) / (next_fsep - fsep)) * (next_rq - rq)
                -- Before first point - use first point value
                WHEN fsep > @freqSep AND prev_fsep IS NULL THEN rq
                -- After last point - use last point value
                WHEN fsep < @freqSep AND next_fsep IS NULL THEN rq
                -- Use closest point
                ELSE rq
            END
        FROM (
            SELECT 
                fsep,
                rq,
                LAG(fsep) OVER (ORDER BY fsep) AS prev_fsep,
                LAG(rq) OVER (ORDER BY fsep) AS prev_rq,
                LEAD(fsep) OVER (ORDER BY fsep) AS next_fsep,
                LEAD(rq) OVER (ORDER BY fsep) AS next_rq
            FROM main.sd_ctxd
            WHERE tfcr = @tfcr
              AND tfci = @tfci
              AND rxeqp = @rxeqp
        ) AS curve
        WHERE fsep <= @freqSep OR (fsep > @freqSep AND prev_fsep IS NULL)
        ORDER BY 
            CASE 
                WHEN fsep <= @freqSep THEN fsep 
                ELSE -fsep 
            END DESC;
        
        -- If still NULL, fall back to base value
        IF @rqco IS NULL
        BEGIN
            SELECT @rqco = rqco
            FROM main.sd_ctx
            WHERE tfcr = @tfcr
              AND tfci = @tfci
              AND rxeqp = @rxeqp;
        END;
    END;
    
    RETURN @rqco;
END;
```

**Key Features**:
- ✅ **Pure T-SQL**: No CLR, no C# dependencies
- ✅ **Linear interpolation**: Uses `LAG()` and `LEAD()` window functions
- ✅ **Handles edge cases**: Before first point, after last point, exact match
- ✅ **Fallback**: Uses base `rqco` if curve interpolation fails

---

### 3. Set-Based CTX Lookup (RECOMMENDED - Best Performance)

**Purpose**: Use JOIN instead of scalar function calls for better performance

```sql
-- Pre-populate CTX cache with all unique combinations
-- This is done once at the start of analysis

-- Step 1: Create cache table (table variable or temp table)
DECLARE @CtxCache TABLE (
    tfcr VARCHAR(6),
    tfci VARCHAR(6),
    rxeqp VARCHAR(8),
    rqco FLOAT,
    has_curve BIT,
    PRIMARY KEY (tfcr, tfci, rxeqp)
);

-- Step 2: Pre-populate cache with all unique CTX combinations from channel pairs
INSERT INTO @CtxCache (tfcr, tfci, rxeqp, rqco, has_curve)
SELECT DISTINCT
    pc.inttraftx AS tfcr,
    ec.victrafrx AS tfci,
    ec.viceqptrx AS rxeqp,
    ctx.rqco,
    CASE WHEN ctxd.tfcr IS NOT NULL THEN 1 ELSE 0 END AS has_curve
FROM ft_chan pc
CROSS JOIN ft_chan ec
LEFT JOIN main.sd_ctx ctx
    ON ctx.tfcr = pc.inttraftx
    AND ctx.tfci = ec.victrafrx
    AND ctx.rxeqp = ec.viceqptrx
LEFT JOIN (
    SELECT DISTINCT tfcr, tfci, rxeqp
    FROM main.sd_ctxd
) AS ctxd
    ON ctxd.tfcr = ctx.tfcr
    AND ctxd.tfci = ctx.tfci
    AND ctxd.rxeqp = ctx.rxeqp
WHERE ... -- culling criteria
  AND ctx.rqco IS NOT NULL;

-- Step 3: Use cache in channel pair calculations (set-based)
SELECT 
    pc.intcall1,
    pc.intcall2,
    pc.intchid,
    ec.viccall1,
    ec.viccall2,
    ec.vicchid,
    ABS(pc.intfreqtx - ec.vicfreqrx) AS freqsep,
    -- Get required C/I with interpolation
    CASE
        WHEN cache.has_curve = 1 THEN
            -- Interpolate from curve
            (SELECT TOP 1
                CASE
                    WHEN fsep = ABS(pc.intfreqtx - ec.vicfreqrx) THEN rq
                    WHEN next_fsep IS NOT NULL AND fsep < ABS(pc.intfreqtx - ec.vicfreqrx) AND next_fsep > ABS(pc.intfreqtx - ec.vicfreqrx) THEN
                        rq + ((ABS(pc.intfreqtx - ec.vicfreqrx) - fsep) / (next_fsep - fsep)) * (next_rq - rq)
                    WHEN fsep < ABS(pc.intfreqtx - ec.vicfreqrx) AND next_fsep IS NULL THEN rq
                    ELSE rq
                END
             FROM (
                 SELECT 
                     fsep,
                     rq,
                     LEAD(fsep) OVER (ORDER BY fsep) AS next_fsep,
                     LEAD(rq) OVER (ORDER BY fsep) AS next_rq
                 FROM main.sd_ctxd
                 WHERE tfcr = cache.tfcr
                   AND tfci = cache.tfci
                   AND rxeqp = cache.rxeqp
             ) AS curve
             WHERE fsep <= ABS(pc.intfreqtx - ec.vicfreqrx)
             ORDER BY fsep DESC)
        ELSE
            -- No curve - use base value
            cache.rqco
    END AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
INNER JOIN @CtxCache cache
    ON cache.tfcr = pc.inttraftx
    AND cache.tfci = ec.victrafrx
    AND cache.rxeqp = ec.viceqptrx
WHERE ... -- culling criteria
  AND ABS(pc.intfreqtx - ec.vicfreqrx) <= @maxFreqSep;  -- Frequency separation cull
```

**Advantages**:
- ✅ **Set-based**: Processes all channel pairs in one query
- ✅ **Pre-populated cache**: All CTX combinations loaded once
- ✅ **Inline interpolation**: No function call overhead
- ✅ **SQL Server optimization**: Query optimizer can parallelize and optimize

---

### 4. Optimized Set-Based Approach with Pre-computed Interpolation

**Purpose**: Pre-compute interpolated values for common frequency separations to avoid inline calculation

```sql
-- Step 1: Create extended cache with pre-computed interpolated values
-- This approach pre-computes required C/I for common frequency separations

DECLARE @CtxCacheExtended TABLE (
    tfcr VARCHAR(6),
    tfci VARCHAR(6),
    rxeqp VARCHAR(8),
    freqsep FLOAT,
    reqdcalc FLOAT,
    PRIMARY KEY (tfcr, tfci, rxeqp, freqsep)
);

-- Step 2: Pre-populate with interpolated values for all unique combinations
-- This can be done for:
-- a) All actual frequency separations in channel pairs, OR
-- b) Common frequency separation values (e.g., 0, 1, 2, 5, 10, 20, 50, 100 MHz)

-- Option A: Pre-compute for actual frequency separations (most accurate)
INSERT INTO @CtxCacheExtended (tfcr, tfci, rxeqp, freqsep, reqdcalc)
SELECT DISTINCT
    pc.inttraftx AS tfcr,
    ec.victrafrx AS tfci,
    ec.viceqptrx AS rxeqp,
    ABS(pc.intfreqtx - ec.vicfreqrx) AS freqsep,
    CASE
        WHEN ctxd.tfcr IS NOT NULL THEN
            -- Interpolate from curve
            (SELECT TOP 1
                CASE
                    WHEN fsep = ABS(pc.intfreqtx - ec.vicfreqrx) THEN rq
                    WHEN next_fsep IS NOT NULL AND fsep < ABS(pc.intfreqtx - ec.vicfreqrx) AND next_fsep > ABS(pc.intfreqtx - ec.vicfreqrx) THEN
                        rq + ((ABS(pc.intfreqtx - ec.vicfreqrx) - fsep) / (next_fsep - fsep)) * (next_rq - rq)
                    WHEN fsep < ABS(pc.intfreqtx - ec.vicfreqrx) AND next_fsep IS NULL THEN rq
                    ELSE rq
                END
             FROM (
                 SELECT 
                     fsep,
                     rq,
                     LEAD(fsep) OVER (ORDER BY fsep) AS next_fsep,
                     LEAD(rq) OVER (ORDER BY fsep) AS next_rq
                 FROM main.sd_ctxd
                 WHERE tfcr = pc.inttraftx
                   AND tfci = ec.victrafrx
                   AND rxeqp = ec.viceqptrx
             ) AS curve
             WHERE fsep <= ABS(pc.intfreqtx - ec.vicfreqrx)
             ORDER BY fsep DESC)
        ELSE
            -- No curve - use base value
            ctx.rqco
    END AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
LEFT JOIN main.sd_ctx ctx
    ON ctx.tfcr = pc.inttraftx
    AND ctx.tfci = ec.victrafrx
    AND ctx.rxeqp = ec.viceqptrx
LEFT JOIN (
    SELECT DISTINCT tfcr, tfci, rxeqp
    FROM main.sd_ctxd
) AS ctxd
    ON ctxd.tfcr = ctx.tfcr
    AND ctxd.tfci = ctx.tfci
    AND ctxd.rxeqp = ctx.rxeqp
WHERE ... -- culling criteria
  AND ctx.rqco IS NOT NULL;

-- Step 3: Use pre-computed cache (simple JOIN - fastest)
SELECT 
    pc.*,
    ec.*,
    cache.reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
INNER JOIN @CtxCacheExtended cache
    ON cache.tfcr = pc.inttraftx
    AND cache.tfci = ec.victrafrx
    AND cache.rxeqp = ec.viceqptrx
    AND cache.freqsep = ABS(pc.intfreqtx - ec.vicfreqrx)  -- Exact match
WHERE ... -- culling criteria
  AND ABS(pc.intfreqtx - ec.vicfreqrx) <= @maxFreqSep;
```

**Note**: For exact frequency separation matches, this is fastest. For approximate matches, use the previous approach with inline interpolation.

---

## Complete Stored Procedure Example

**Purpose**: Full example showing pure T-SQL CTX lookup in channel pair processing

```sql
CREATE PROCEDURE tsip.ProcessChannelPairs_WithCTX
    @proposedTableName VARCHAR(128),
    @envTableName VARCHAR(128),
    @maxFreqSep FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Step 1: Create CTX cache (table variable)
    DECLARE @CtxCache TABLE (
        tfcr VARCHAR(6),
        tfci VARCHAR(6),
        rxeqp VARCHAR(8),
        rqco FLOAT,
        has_curve BIT,
        PRIMARY KEY (tfcr, tfci, rxeqp)
    );
    
    -- Step 2: Pre-populate CTX cache
    INSERT INTO @CtxCache (tfcr, tfci, rxeqp, rqco, has_curve)
    SELECT DISTINCT
        pc.inttraftx AS tfcr,
        ec.victrafrx AS tfci,
        ec.viceqptrx AS rxeqp,
        ctx.rqco,
        CASE WHEN ctxd.tfcr IS NOT NULL THEN 1 ELSE 0 END AS has_curve
    FROM 
        (SELECT * FROM sys.fn_get_sql(@proposedTableName)) AS pc  -- Proposed channels
    CROSS JOIN 
        (SELECT * FROM sys.fn_get_sql(@envTableName)) AS ec  -- Environment channels
    LEFT JOIN main.sd_ctx ctx
        ON ctx.tfcr = pc.inttraftx
        AND ctx.tfci = ec.victrafrx
        AND ctx.rxeqp = ec.viceqptrx
    LEFT JOIN (
        SELECT DISTINCT tfcr, tfci, rxeqp
        FROM main.sd_ctxd
    ) AS ctxd
        ON ctxd.tfcr = ctx.tfcr
        AND ctxd.tfci = ctx.tfci
        AND ctxd.rxeqp = ctx.rxeqp
    WHERE ctx.rqco IS NOT NULL;
    
    -- Step 3: Process channel pairs with CTX lookup (set-based)
    INSERT INTO tt_chan (
        intcall1, intcall2, intchid,
        viccall1, viccall2, vicchid,
        freqsep, reqdcalc,
        -- ... other fields ...
    )
    SELECT 
        pc.intcall1,
        pc.intcall2,
        pc.intchid,
        ec.viccall1,
        ec.viccall2,
        ec.vicchid,
        ABS(pc.intfreqtx - ec.vicfreqrx) AS freqsep,
        -- Get required C/I with interpolation
        CASE
            WHEN cache.has_curve = 1 THEN
                -- Interpolate from curve
                (SELECT TOP 1
                    CASE
                        WHEN fsep = ABS(pc.intfreqtx - ec.vicfreqrx) THEN rq
                        WHEN next_fsep IS NOT NULL 
                             AND fsep < ABS(pc.intfreqtx - ec.vicfreqrx) 
                             AND next_fsep > ABS(pc.intfreqtx - ec.vicfreqrx) THEN
                            rq + ((ABS(pc.intfreqtx - ec.vicfreqrx) - fsep) / (next_fsep - fsep)) * (next_rq - rq)
                        WHEN fsep < ABS(pc.intfreqtx - ec.vicfreqrx) AND next_fsep IS NULL THEN rq
                        ELSE rq
                    END
                 FROM (
                     SELECT 
                         fsep,
                         rq,
                         LEAD(fsep) OVER (ORDER BY fsep) AS next_fsep,
                         LEAD(rq) OVER (ORDER BY fsep) AS next_rq
                     FROM main.sd_ctxd
                     WHERE tfcr = cache.tfcr
                       AND tfci = cache.tfci
                       AND rxeqp = cache.rxeqp
                 ) AS curve
                 WHERE fsep <= ABS(pc.intfreqtx - ec.vicfreqrx)
                 ORDER BY fsep DESC)
            ELSE
                -- No curve - use base value
                cache.rqco
        END AS reqdcalc,
        -- ... other calculations ...
    FROM 
        (SELECT * FROM sys.fn_get_sql(@proposedTableName)) AS pc
    CROSS JOIN 
        (SELECT * FROM sys.fn_get_sql(@envTableName)) AS ec
    INNER JOIN @CtxCache cache
        ON cache.tfcr = pc.inttraftx
        AND cache.tfci = ec.victrafrx
        AND cache.rxeqp = ec.viceqptrx
    WHERE 
        ABS(pc.intfreqtx - ec.vicfreqrx) <= @maxFreqSep  -- Frequency separation cull
        -- ... other culling criteria ...
    OPTION (MAXDOP 4);  -- Optional: Enable parallel execution
    
END;
```

**Key Features**:
- ✅ **Pure T-SQL**: No CLR, no C# dependencies
- ✅ **Set-based**: Processes all channel pairs efficiently
- ✅ **Pre-populated cache**: CTX combinations loaded once
- ✅ **Inline interpolation**: No function call overhead
- ✅ **Parallel execution**: Can use `MAXDOP` for large datasets

---

## Performance Comparison

### Scalar Function Approach (NOT RECOMMENDED)

```sql
-- Using scalar function (slow for millions of rows)
SELECT 
    pc.*,
    ec.*,
    tsip.GetRequiredCI_WithInterpolation(
        pc.inttraftx,
        ec.victrafrx,
        ec.viceqptrx,
        ABS(pc.intfreqtx - ec.vicfreqrx)
    ) AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
WHERE ...;
```

**Performance**: **Slow** - Scalar function called once per row (millions of times)

---

### Set-Based JOIN Approach (RECOMMENDED)

```sql
-- Using pre-populated cache with JOIN (fast)
SELECT 
    pc.*,
    ec.*,
    CASE
        WHEN cache.has_curve = 1 THEN
            -- Inline interpolation
            (SELECT TOP 1 ... FROM ...)
        ELSE
            cache.rqco
    END AS reqdcalc
FROM ft_chan pc
CROSS JOIN ft_chan ec
INNER JOIN @CtxCache cache
    ON cache.tfcr = pc.inttraftx
    AND cache.tfci = ec.victrafrx
    AND cache.rxeqp = ec.viceqptrx
WHERE ...;
```

**Performance**: **Fast** - Set-based operation, SQL Server can optimize and parallelize

**Estimated Speedup**: **10-100× faster** than scalar function approach

---

## Summary

### ✅ Pure T-SQL Solution (No C# Dependencies)

**Components**:
1. ✅ **CTX Main Lookup**: Simple JOIN to `sd_ctx` table
2. ✅ **CTX Curve Interpolation**: Pure T-SQL using `LAG()`/`LEAD()` window functions
3. ✅ **Caching**: Table variable or temp table (pre-populated)
4. ✅ **Set-Based Operations**: JOIN instead of scalar functions

**Advantages**:
- ✅ **No CLR required**: Pure T-SQL, no C# dependencies
- ✅ **Better performance**: Set-based operations, SQL Server optimization
- ✅ **Easier deployment**: No assembly registration, no CLR permissions
- ✅ **Portable**: Works on any SQL Server version (2012+)

**Recommendation**: **Use set-based JOIN approach with pre-populated cache** - fastest and simplest pure T-SQL solution.

---

## Implementation Checklist

- [x] Pure T-SQL CTX lookup function (optional - prefer JOIN)
- [x] Pure T-SQL curve interpolation logic
- [x] Pre-populated cache table (table variable or temp table)
- [x] Set-based channel pair processing with JOIN
- [x] Inline interpolation using window functions
- [x] Complete stored procedure example
- [x] Performance optimization (set-based > scalar functions)

**Status**: ✅ **CHOSEN APPROACH** - Pure T-SQL, no C# dependencies, ready for implementation

