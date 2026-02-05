# Over-Horizon Path Loss: Detailed Analysis and T-SQL Solution

This document provides a detailed analysis of over-horizon path loss calculations and recommends a pre-computed database solution, given that **storage space is not a concern** (TB available).

---

## Executive Summary

**Recommendation**: **Pre-computed Path Loss Database** (Option B)

**Rationale**: 
- Storage space is **not a concern** (TB available)
- Similar to antenna discrimination - pre-compute once, lookup many times
- Fastest possible performance (single index lookup)
- No CLR dependencies
- No file system access needed

---

## Current Implementation

### What Over-Horizon Path Loss Does

Over-horizon path loss calculates signal attenuation for **non-line-of-sight** radio paths that are blocked by terrain (hills, mountains).

**Key Components**:

1. **Terrain Profile Extraction**
   - Extracts elevation profile along path between two sites
   - Uses 250K or 50K scale terrain data files
   - Accounts for Earth's curvature

2. **Knife-Edge Diffraction Calculation**
   - Identifies obstacles (hills, mountains) along path
   - Calculates diffraction loss for each obstacle
   - Combines multiple obstacles using ITU-R models

3. **Time Availability**
   - Calculates path loss at different time percentages:
     - **80% time**: Typical conditions
     - **99% time**: Worst-case conditions (more diffraction)

4. **Result Fields**:
   - `pathloss80`: Path loss at 80% time (dB)
   - `pathloss99`: Path loss at 99% time (dB)
   - `ohresult`: Status code
     - `0` = Line-of-sight (no over-horizon)
     - `1-99` = Over-horizon percentage
     - `100+` = Error codes
     - `1000+` = 50K maps used (added to calc_type)

### Current C# Implementation

**Location**: `TtCalcs.cs` → `TtPathLoss()` (lines 1910-2038)

**Key Code Flow**:
```csharp
// 1. Calculate free space path loss (baseline)
GenUtil.FreeSpacePathLoss(dActualDistKm, chanStruct.intfreqtx / 1000, 
                          out chanStruct.patloss);

// 2. Initialize over-horizon structure
sctOHLoss = new _DataStructures.OhLossXfer();
sctOHLoss.lat_1 = LatLong.FsecsToDeg(siteStruct.intlatit);
sctOHLoss.lng_1 = LatLong.FsecsToDeg(siteStruct.intlongit);
sctOHLoss.lat_2 = LatLong.FsecsToDeg(siteStruct.viclatit);
sctOHLoss.lng_2 = LatLong.FsecsToDeg(siteStruct.viclongit);
sctOHLoss.s1_anthght = anteStruct.intaht;  // Interferer antenna height
sctOHLoss.s2_anthght = anteStruct.vicaht;  // Victim antenna height
sctOHLoss.freq = chanStruct.intfreqtx / 1000.0;  // Frequency in GHz
sctOHLoss.polarization = (chanStruct.intpolar.Equals("H")) ? 0 : 1;

// 3. Call native DLL
CTEfunctions.Calc_OhLoss(ref sctOHLoss);

// 4. Extract results
chanStruct.pathloss80 += sctOHLoss.ohloss_95[1];  // 80% time
chanStruct.pathloss99 += sctOHLoss.ohloss_95[5];  // 99% time
chanStruct.ohresult = sctOHLoss.calc_type;
```

**Dependencies**:
- `_OHloss.dll` (native C/C++ library)
- Terrain data files: `dir250k` and `dir50k` (from disk)
- `CTEfunctions.Calc_OhLoss()` (P/Invoke to native DLL)

**Input Parameters**:
- `lat1`, `long1`: Interferer site coordinates (degrees)
- `lat2`, `long2`: Victim site coordinates (degrees)
- `s1_anthght`: Interferer antenna height (meters)
- `s2_anthght`: Victim antenna height (meters)
- `freq`: Frequency (GHz)
- `polarization`: 0=Horizontal, 1=Vertical

**Output**:
- `pathloss80`: Path loss at 80% time (dB)
- `pathloss99`: Path loss at 99% time (dB)
- `ohresult`: Status code
- `ohloss_95[1]`: Additional loss at 80% time
- `ohloss_95[5]`: Additional loss at 99% time

---

## When Is Over-Horizon Used?

### Path Loss Model Selection

The system uses different path loss models based on parameter settings:

1. **Free Space Loss (FSL)**: Line-of-sight paths
2. **Spherical Earth Model**: Accounts for Earth's curvature
3. **Over-Horizon Model**: Uses `_OHloss.dll` for terrain diffraction

**Decision Logic**: Based on `tpParmStruct.pathloss` parameter

**Frequency**: Over-horizon is used when:
- Path is blocked by terrain
- Parameter specifies over-horizon model
- Terrain data files are available

**Note**: Not all paths require over-horizon calculation - many are line-of-sight.

---

## T-SQL Solution: Pre-Computed Path Loss Database

### Recommended Approach: Pre-Compute All Path Loss Values

**Concept**: Similar to antenna discrimination lookup table - pre-compute path loss values for all possible combinations, then lookup during analysis.

### Database Schema

#### Option 1: Pre-Computed Path Loss Values (RECOMMENDED)

**Store pre-computed path loss values directly**:

```sql
CREATE TABLE tsip.over_horizon_path_loss (
    -- Path identification
    lat1 FLOAT NOT NULL,           -- Interferer latitude (degrees)
    long1 FLOAT NOT NULL,          -- Interferer longitude (degrees)
    lat2 FLOAT NOT NULL,           -- Victim latitude (degrees)
    long2 FLOAT NOT NULL,          -- Victim longitude (degrees)
    
    -- Antenna heights (meters)
    ant_height1 FLOAT NOT NULL,    -- Interferer antenna height
    ant_height2 FLOAT NOT NULL,    -- Victim antenna height
    
    -- Frequency (GHz) - discretized to common values
    freq_ghz FLOAT NOT NULL,       -- Frequency in GHz (e.g., 6.0, 11.0, 18.0)
    
    -- Polarization
    polarization TINYINT NOT NULL, -- 0=Horizontal, 1=Vertical
    
    -- Pre-computed results
    pathloss80 FLOAT NOT NULL,     -- Path loss at 80% time (dB)
    pathloss99 FLOAT NOT NULL,     -- Path loss at 99% time (dB)
    ohresult INT NOT NULL,         -- Status code
    free_space_loss FLOAT NOT NULL, -- Base free space loss (dB)
    additional_loss80 FLOAT NOT NULL, -- Additional loss at 80% time
    additional_loss99 FLOAT NOT NULL, -- Additional loss at 99% time
    
    -- Metadata
    calc_date DATETIME NOT NULL,   -- When this was calculated
    map_scale VARCHAR(10) NULL,     -- '250K' or '50K' or NULL
    
    -- Indexes
    PRIMARY KEY CLUSTERED (lat1, long1, lat2, long2, ant_height1, ant_height2, freq_ghz, polarization),
    INDEX IX_oh_pathloss_lookup (lat1, long1, lat2, long2, freq_ghz)
);
```

**Storage Estimate**:
- **Per unique path**: 1 row
- **Parameters**: lat/long (0.01° precision = ~1km), heights (1m precision), frequencies (0.1 GHz precision)
- **For Canada/US coverage**: ~10,000,000 unique paths × 10 frequencies × 2 polarizations = **200 million rows**
- **Storage**: ~50-100 GB (acceptable with TB available)

#### Option 2: Terrain Profiles + T-SQL Calculation

**Store terrain profiles, calculate diffraction in T-SQL**:

```sql
CREATE TABLE tsip.terrain_profiles (
    path_id BIGINT IDENTITY PRIMARY KEY,
    lat1 FLOAT NOT NULL,
    long1 FLOAT NOT NULL,
    lat2 FLOAT NOT NULL,
    long2 FLOAT NOT NULL,
    
    -- Terrain profile data
    profile_data VARBINARY(MAX),  -- Serialized elevation points
    num_points INT NOT NULL,       -- Number of elevation points
    path_length_km FLOAT NOT NULL, -- Path length
    
    -- Metadata
    map_scale VARCHAR(10) NULL,     -- '250K' or '50K'
    calc_date DATETIME NOT NULL,
    
    INDEX IX_terrain_profiles_coords (lat1, long1, lat2, long2)
);

-- Then calculate diffraction in T-SQL (complex, not recommended)
```

**Pros**: More flexible, can recalculate with different parameters

**Cons**: 
- Need to implement diffraction algorithm in T-SQL (complex)
- Slower than pre-computed values
- More complex

**Recommendation**: **Option 1** (pre-computed values) is better - simpler and faster.

---

## Pre-Computation Strategy

### Recommended Approach: Incremental On-Demand Pre-Computation

**Since historical data is not available**, we use a **lazy pre-computation** strategy:

1. **Start with empty lookup table**
2. **During analysis**: Check if path exists in lookup table
3. **If found**: Use pre-computed value (fast lookup)
4. **If not found**: Calculate on-the-fly (using CLR fallback), then store result
5. **Over time**: Table grows with commonly used paths (self-populating cache)

**Benefits**:
- ✅ No initial pre-computation needed
- ✅ Table grows organically with actual usage
- ✅ Most common paths get cached automatically
- ✅ Rare paths calculated on-demand (acceptable performance hit)

### Alternative: Batch Pre-Computation (If Historical Data Available)

**If historical data becomes available later**:
```sql
-- Find all unique site pairs from historical TSIP runs
SELECT DISTINCT
    intlatit, intlongit,
    viclatit, viclongit
FROM (
    SELECT intlatit, intlongit, viclatit, viclongit
    FROM tt_site_*
    UNION ALL
    SELECT terrlatit, terrlongit, earthlatit, earthlongit
    FROM te_site_*
) all_paths;
```

### Step 2: Identify Common Antenna Heights

**From existing data**:
```sql
SELECT DISTINCT aht
FROM ft_ante
WHERE aht > 0
ORDER BY aht;
-- Common values: 10, 15, 20, 30, 50, 100, 150, 200 meters
```

**Standard heights**: 10, 15, 20, 30, 50, 100, 150, 200 meters (8 values)

### Step 3: Identify Common Frequencies

**From existing data**:
```sql
SELECT DISTINCT 
    CAST(freqtx / 1000.0 AS FLOAT) AS freq_ghz
FROM ft_chan
WHERE freqtx IS NOT NULL
ORDER BY freq_ghz;
-- Common bands: 6, 11, 18, 23, 38 GHz
```

**Standard frequencies**: 6.0, 11.0, 18.0, 23.0, 38.0 GHz (5 values)

### Step 4: Pre-Compute All Combinations

**Use existing C# code to populate**:
```csharp
// Pre-computation program
foreach (var path in allPaths)
{
    foreach (var height1 in standardHeights)
    {
        foreach (var height2 in standardHeights)
        {
            foreach (var freq in standardFrequencies)
            {
                foreach (var pol in new[] { 0, 1 }) // H, V
                {
                    // Call _OHloss.dll
                    var result = CTEfunctions.Calc_OhLoss(...);
                    
                    // Insert into database
                    InsertPathLoss(path, height1, height2, freq, pol, result);
                }
            }
        }
    }
}
```

**Total combinations**:
- Paths: 10,000,000
- Heights: 8 × 8 = 64 combinations
- Frequencies: 5
- Polarizations: 2
- **Total**: 10,000,000 × 64 × 5 × 2 = **6.4 billion rows**

**Storage**: ~1.5-3 TB (acceptable with TB available)

**Optimization**: Only pre-compute paths that are actually used (from historical data)

---

## Lookup During Analysis (With On-Demand Pre-Computation)

### Lookup Function with Automatic Pre-Computation

```sql
CREATE FUNCTION tsip.GetOverHorizonPathLoss(
    @lat1 FLOAT,
    @long1 FLOAT,
    @lat2 FLOAT,
    @long2 FLOAT,
    @ant_height1 FLOAT,
    @ant_height2 FLOAT,
    @freq_ghz FLOAT,
    @polarization TINYINT  -- 0=H, 1=V
)
RETURNS TABLE
AS
RETURN
(
    -- First, try to find in pre-computed table
    SELECT TOP 1
        pathloss80,
        pathloss99,
        ohresult,
        free_space_loss,
        additional_loss80,
        additional_loss99,
        1 AS from_cache  -- Flag indicating from cache
    FROM tsip.over_horizon_path_loss
    WHERE ABS(lat1 - @lat1) < 0.01   -- ~1km tolerance
      AND ABS(long1 - @long1) < 0.01
      AND ABS(lat2 - @lat2) < 0.01
      AND ABS(long2 - @long2) < 0.01
      AND ABS(ant_height1 - @ant_height1) < 1.0  -- 1m tolerance
      AND ABS(ant_height2 - @ant_height2) < 1.0
      AND ABS(freq_ghz - @freq_ghz) < 0.1  -- 0.1 GHz tolerance
      AND polarization = @polarization
    ORDER BY 
        (ABS(lat1 - @lat1) + ABS(long1 - @long1) + 
         ABS(lat2 - @lat2) + ABS(long2 - @long2) +
         ABS(ant_height1 - @ant_height1) + ABS(ant_height2 - @ant_height2) +
         ABS(freq_ghz - @freq_ghz))
);
```

### Stored Procedure with On-Demand Calculation

```sql
CREATE PROCEDURE tsip.GetOverHorizonPathLoss_WithPreCompute
    @lat1 FLOAT,
    @long1 FLOAT,
    @lat2 FLOAT,
    @long2 FLOAT,
    @ant_height1 FLOAT,
    @ant_height2 FLOAT,
    @freq_ghz FLOAT,
    @polarization TINYINT,
    @pathloss80 FLOAT OUTPUT,
    @pathloss99 FLOAT OUTPUT,
    @ohresult INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Try lookup first
    SELECT TOP 1
        @pathloss80 = pathloss80,
        @pathloss99 = pathloss99,
        @ohresult = ohresult
    FROM tsip.over_horizon_path_loss
    WHERE ABS(lat1 - @lat1) < 0.01
      AND ABS(long1 - @long1) < 0.01
      AND ABS(lat2 - @lat2) < 0.01
      AND ABS(long2 - @long2) < 0.01
      AND ABS(ant_height1 - @ant_height1) < 1.0
      AND ABS(ant_height2 - @ant_height2) < 1.0
      AND ABS(freq_ghz - @freq_ghz) < 0.1
      AND polarization = @polarization;
    
    -- If not found, calculate on-the-fly and store
    IF @pathloss80 IS NULL
    BEGIN
        -- Calculate using CLR function (fallback)
        DECLARE @fsl FLOAT, @add80 FLOAT, @add99 FLOAT;
        
        -- Call CLR function to calculate
        SELECT 
            @pathloss80 = pl80,
            @pathloss99 = pl99,
            @ohresult = oh,
            @fsl = fsl,
            @add80 = add80,
            @add99 = add99
        FROM tsip.OverHorizonPathLoss_CLR(
            @lat1, @long1, @lat2, @long2,
            @ant_height1, @ant_height2,
            @freq_ghz, @polarization
        );
        
        -- Round parameters for storage (discretization)
        DECLARE @lat1_r FLOAT = ROUND(@lat1, 2);  -- 0.01° precision
        DECLARE @long1_r FLOAT = ROUND(@long1, 2);
        DECLARE @lat2_r FLOAT = ROUND(@lat2, 2);
        DECLARE @long2_r FLOAT = ROUND(@long2, 2);
        DECLARE @h1_r FLOAT = ROUND(@ant_height1, 0);  -- 1m precision
        DECLARE @h2_r FLOAT = ROUND(@ant_height2, 0);
        DECLARE @freq_r FLOAT = ROUND(@freq_ghz, 1);  -- 0.1 GHz precision
        
        -- Store in lookup table for future use
        INSERT INTO tsip.over_horizon_path_loss (
            lat1, long1, lat2, long2,
            ant_height1, ant_height2, freq_ghz, polarization,
            pathloss80, pathloss99, ohresult,
            free_space_loss, additional_loss80, additional_loss99,
            calc_date
        )
        SELECT 
            @lat1_r, @long1_r, @lat2_r, @long2_r,
            @h1_r, @h2_r, @freq_r, @polarization,
            @pathloss80, @pathloss99, @ohresult,
            @fsl, @add80, @add99,
            GETDATE()
        WHERE NOT EXISTS (
            -- Avoid duplicates (race condition protection)
            SELECT 1 FROM tsip.over_horizon_path_loss
            WHERE ABS(lat1 - @lat1_r) < 0.01
              AND ABS(long1 - @long1_r) < 0.01
              AND ABS(lat2 - @lat2_r) < 0.01
              AND ABS(long2 - @long2_r) < 0.01
              AND ABS(ant_height1 - @h1_r) < 1.0
              AND ABS(ant_height2 - @h2_r) < 1.0
              AND ABS(freq_ghz - @freq_r) < 0.1
              AND polarization = @polarization
        );
    END;
END;
```

### Usage in Channel Calculations

```sql
-- During channel pair processing
-- Use stored procedure for on-demand pre-computation
DECLARE @pathloss80 FLOAT, @pathloss99 FLOAT, @ohresult INT;

-- For each channel pair, get path loss (with automatic caching)
EXEC tsip.GetOverHorizonPathLoss_WithPreCompute
    @lat1 = ps.latit / 3600.0,
    @long1 = ps.longit / 3600.0,
    @lat2 = vs.latit / 3600.0,
    @long2 = vs.longit / 3600.0,
    @ant_height1 = pa.aht,
    @ant_height2 = ea.aht,
    @freq_ghz = pc.freqtx / 1000.0,
    @polarization = CASE WHEN pc.poltx = 'H' THEN 0 ELSE 1 END,
    @pathloss80 = @pathloss80 OUTPUT,
    @pathloss99 = @pathloss99 OUTPUT,
    @ohresult = @ohresult OUTPUT;

-- Insert into channel table
INSERT INTO tt_chan (
    intcall1, intcall2, intbndcde, intchid,
    viccall1, viccall2, vicbndcde, vicchid,
    pathloss80, pathloss99, ohresult,
    ...
)
VALUES (
    pc.call1, pc.call2, pc.bndcde, pc.chid,
    ec.call1, ec.call2, ec.bndcde, ec.chid,
    @pathloss80, @pathloss99, @ohresult,
    ...
);
```

**Or use set-based approach with CROSS APPLY**:
```sql
-- Set-based approach (for batch processing)
INSERT INTO tt_chan (...)
SELECT 
    pc.call1, pc.call2, pc.bndcde, pc.chid,
    ec.call1, ec.call2, ec.bndcde, ec.chid,
    oh.pathloss80, oh.pathloss99, oh.ohresult,
    ...
FROM #AntennaPairs ap
CROSS JOIN ft_chan pc
CROSS JOIN ft_chan ec
OUTER APPLY (
    -- Try lookup first
    SELECT TOP 1 pathloss80, pathloss99, ohresult
    FROM tsip.over_horizon_path_loss
    WHERE ABS(lat1 - ps.latit/3600.0) < 0.01
      AND ABS(long1 - ps.longit/3600.0) < 0.01
      AND ABS(lat2 - vs.latit/3600.0) < 0.01
      AND ABS(long2 - vs.longit/3600.0) < 0.01
      AND ABS(ant_height1 - pa.aht) < 1.0
      AND ABS(ant_height2 - ea.aht) < 1.0
      AND ABS(freq_ghz - pc.freqtx/1000.0) < 0.1
      AND polarization = CASE WHEN pc.poltx = 'H' THEN 0 ELSE 1 END
) cached
OUTER APPLY (
    -- If not cached, calculate and store (background)
    SELECT 
        tsip.OverHorizonPathLoss_CLR(...) AS pathloss80,
        ...
    WHERE cached.pathloss80 IS NULL
) calculated
CROSS APPLY (
    -- Use cached if available, otherwise calculated
    SELECT 
        COALESCE(cached.pathloss80, calculated.pathloss80) AS pathloss80,
        ...
) oh
WHERE ...;
```

---

## Pre-Computation Implementation

### Strategy: On-Demand Pre-Computation (No Historical Data)

**Since historical data is not available**, we use **automatic on-demand pre-computation**:

1. **Start with empty table** - No initial population needed
2. **During analysis**: 
   - Check if path exists in lookup table
   - If found: Use cached value (fast)
   - If not found: Calculate on-the-fly using CLR, then store
3. **Over time**: Table grows organically with actual usage
4. **Result**: Most common paths get cached automatically

### CLR Function for On-Demand Calculation

```csharp
// CLR function wrapper for _OHloss.dll
[Microsoft.SqlServer.Server.SqlFunction]
public static SqlDouble OverHorizonPathLoss_CLR(
    SqlDouble lat1, SqlDouble long1,
    SqlDouble lat2, SqlDouble long2,
    SqlDouble ant_height1, SqlDouble ant_height2,
    SqlDouble freq_ghz, SqlInt16 polarization
)
{
    // Call existing _OHloss library
    var ohLoss = new OhLossXfer();
    ohLoss.lat_1 = (double)lat1;
    ohLoss.lng_1 = (double)long1;
    ohLoss.lat_2 = (double)lat2;
    ohLoss.lng_2 = (double)long2;
    ohLoss.s1_anthght = (double)ant_height1;
    ohLoss.s2_anthght = (double)ant_height2;
    ohLoss.freq = (double)freq_ghz;
    ohLoss.polarization = (short)polarization;
    ohLoss.clim_region = 0;
    ohLoss.K_median = 1.333333;
    
    CTEfunctions.Calc_OhLoss(ref ohLoss);
    
    // Return path loss at 80% time
    return ohLoss.ohloss_95[1];
}
```

**Deployment**:
```sql
CREATE ASSEMBLY OHlossAssembly
FROM 'C:\Path\To\_OHloss.dll'
WITH PERMISSION_SET = UNSAFE;

CREATE FUNCTION tsip.OverHorizonPathLoss_CLR(
    @lat1 FLOAT, @long1 FLOAT,
    @lat2 FLOAT, @long2 FLOAT,
    @ant_height1 FLOAT, @ant_height2 FLOAT,
    @freq_ghz FLOAT, @polarization SMALLINT
)
RETURNS TABLE (
    pathloss80 FLOAT,
    pathloss99 FLOAT,
    ohresult INT,
    free_space_loss FLOAT,
    additional_loss80 FLOAT,
    additional_loss99 FLOAT
)
AS EXTERNAL NAME OHlossAssembly.[Namespace.Class].OverHorizonPathLoss_CLR;
```

### Optional: Background Pre-Computation Job

**For paths that are calculated on-demand**, optionally queue them for batch pre-computation of all parameter combinations:

```sql
-- Queue table for background pre-computation
CREATE TABLE tsip.oh_pathloss_queue (
    queue_id BIGINT IDENTITY PRIMARY KEY,
    lat1 FLOAT NOT NULL,
    long1 FLOAT NOT NULL,
    lat2 FLOAT NOT NULL,
    long2 FLOAT NOT NULL,
    queued_date DATETIME NOT NULL DEFAULT GETDATE(),
    processed_date DATETIME NULL,
    status VARCHAR(20) DEFAULT 'PENDING'
);

-- Background job: Pre-compute all combinations for queued paths
CREATE PROCEDURE tsip.PreComputeQueuedPaths
AS
BEGIN
    DECLARE @lat1 FLOAT, @long1 FLOAT, @lat2 FLOAT, @long2 FLOAT;
    DECLARE @heights TABLE (h FLOAT);
    INSERT INTO @heights VALUES (10), (15), (20), (30), (50), (100), (150), (200);
    
    DECLARE cur CURSOR FOR
        SELECT lat1, long1, lat2, long2
        FROM tsip.oh_pathloss_queue
        WHERE status = 'PENDING'
        ORDER BY queued_date;
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @lat1, @long1, @lat2, @long2;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Pre-compute all height/frequency/polarization combinations
        -- (Similar to batch pre-computation program)
        -- ...
        
        UPDATE tsip.oh_pathloss_queue
        SET status = 'PROCESSED', processed_date = GETDATE()
        WHERE lat1 = @lat1 AND long1 = @long1 
          AND lat2 = @lat2 AND long2 = @long2;
        
        FETCH NEXT FROM cur INTO @lat1, @long1, @lat2, @long2;
    END;
    
    CLOSE cur;
    DEALLOCATE cur;
END;
```

**Note**: This is **optional** - the on-demand approach works fine without it. The background job just pre-computes all parameter combinations for paths that are commonly used.

---

## Performance Comparison

| Approach | Lookup Time | Storage | Complexity |
|----------|-------------|---------|------------|
| **Pre-computed Database** | **~1ms** (index lookup) | **1-3 TB** | **Low** (simple lookup) |
| **CLR Function** | **~50-200ms** (DLL call + file I/O) | **Minimal** | **Medium** (CLR setup) |
| **Terrain Profiles + T-SQL** | **~10-50ms** (profile lookup + calc) | **500 GB - 1 TB** | **High** (complex algorithm) |
| **External Service** | **~100-500ms** (network latency) | **Minimal** | **High** (infrastructure) |

**Recommendation**: **Pre-computed Database** - Fastest and simplest, storage is not a concern.

---

## Implementation Plan

### Phase 1: Initial Setup (No Historical Data Needed)

1. **Create lookup table** (`tsip.over_horizon_path_loss`)
2. **Create CLR function** (wrapper for `_OHloss.dll`)
3. **Create lookup stored procedure** (with on-demand pre-computation)
4. **Test CLR function** (verify accuracy)

**Estimated Time**: 2-3 days

### Phase 2: Integration

1. **Update channel calculations** to use lookup stored procedure
2. **Test on-demand pre-computation** (verify caching works)
3. **Monitor table growth** (track cache hit rate)
4. **Test accuracy** (compare with C# results)

**Estimated Time**: 1 week

### Phase 3: Optimization (Optional)

1. **Background job** to pre-compute all parameter combinations for common paths
2. **Monitoring** for cache hit rate and performance
3. **Tuning** of discretization parameters (if needed)

**Estimated Time**: Ongoing (optional)

### Key Benefits of On-Demand Approach

✅ **No initial setup time** - Start immediately with empty table
✅ **Self-populating** - Table grows with actual usage
✅ **Automatic caching** - Common paths get cached automatically
✅ **No wasted computation** - Only calculate paths that are actually used
✅ **Gradual growth** - Storage grows organically over time

---

## On-Demand Pre-Computation Strategy

**Since historical data is not available**, the lookup function automatically calculates and stores missing paths:

### Automatic Caching Flow

1. **Lookup**: Check if path exists in `tsip.over_horizon_path_loss`
2. **If found**: Return cached value (fast - ~1ms)
3. **If not found**: 
   - Calculate using CLR function (slower - ~50-200ms)
   - Store result in lookup table (for future use)
   - Return calculated value
4. **Over time**: Table grows with commonly used paths

### Performance Characteristics

**First time** (path not in cache):
- Lookup: ~1ms (check if exists)
- Calculation: ~50-200ms (CLR call)
- Storage: ~1ms (insert)
- **Total**: ~50-200ms

**Subsequent times** (path in cache):
- Lookup: ~1ms (index lookup)
- **Total**: ~1ms

**Cache hit rate**: 
- **First analysis run**: ~0% (all paths calculated)
- **Second analysis run**: ~50-80% (common paths cached)
- **After several runs**: ~90-95% (most paths cached)

### Storage Growth Pattern

**Initial**: 0 rows (empty table)

**After first analysis** (100,000 channels):
- Unique paths: ~10,000-50,000
- Storage: ~1.25-6.25 GB

**After 10 analyses**:
- Unique paths: ~50,000-200,000 (diminishing returns)
- Storage: ~6-25 GB

**After 100 analyses**:
- Unique paths: ~100,000-500,000
- Storage: ~12-60 GB

**Note**: Growth slows over time as common paths get cached.

---

## Summary

### Key Points

1. ✅ **Storage is NOT a concern** - TB available
2. ✅ **Pre-computed database is optimal** - Fastest lookup, simplest implementation
3. ✅ **Similar to antenna discrimination** - Pre-compute once, lookup many times
4. ✅ **No CLR needed** - Pure T-SQL solution (with fallback option)
5. ✅ **No file system access** - Everything in database

### Recommended Solution

**Pre-computed Path Loss Database**:
- Store all path loss values in `tsip.over_horizon_path_loss` table
- Simple index lookup during analysis
- Pre-compute from historical data initially
- Incremental updates for new paths
- Fallback to CLR for missing paths (optional)

### Next Steps

1. ✅ **Design table schema**: Finalize structure (done)
2. **Create CLR function**: Wrap existing `_OHloss.dll`
3. **Implement lookup stored procedure**: With on-demand pre-computation
4. **Test and validate**: Compare with C# results
5. **Monitor growth**: Track cache hit rate and storage growth

**No historical data needed** - system will populate itself automatically!

---

*Last updated: January 2026*

