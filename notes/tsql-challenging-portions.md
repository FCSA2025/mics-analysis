# T-SQL Port: Detailed Analysis of Challenging Portions

This document provides an in-depth analysis of the most challenging aspects of porting TSIP to T-SQL, with detailed explanations, code examples, and implementation strategies.

---

## 1. Nested Loop Processing Architecture

### The Problem

The C# code uses a **5-level nested loop structure** that processes data incrementally:

```csharp
// Level 1: For each proposed site
while (rc == 0) {
    FtGetSiteWN(cCallFound, out pSite, ...);  // Load full site structure
    nNumLinks = FtMakeLinks(pSite, out pLinks); // Build antenna links
    
    // Level 2: For each link in the site
    for (nInd = 0; nInd < nNumLinks; nInd++) {
        GenRoughCull(..., out sqlCommand);  // Generate SQL WHERE clause
        
        // Level 3: For each victim site (from SQL query)
        while (true) {
            nInd = TpMdbPdfGet.TtEnumSite(sqlCommand, ..., ref cCallFound);
            TtFullSiteGet(cCallFound, ..., out pVicSite, ...);  // Load victim site
            
            // Level 4: For each victim link
            for (nLink = 0; nLink < nNumVicLinks; nLink++) {
                // Level 5: For each antenna pair
                for (nProInd = 0; nProInd < pProLink.nNumAnts; nProInd++) {
                    for (nEnvInd = 0; nEnvInd < pEnvLink.nNumAnts; nEnvInd++) {
                        // Level 6: For each channel pair
                        CreateChanSHTable(...);
                    }
                }
            }
        }
    }
}
```

**Location**: `TtBuildSH.cs` → `TtCullNCreate()` (lines 491-565), `Vic2DimTable()` (lines 819-1109), `CreateAnteSHTable()` (lines 1615-1925)

### Why This Is Challenging in T-SQL

1. **State Management**: Each level maintains state (current site, current link, processed flags)
2. **Memory Efficiency**: C# loads one site at a time; T-SQL would need to handle all combinations
3. **Complex Data Structures**: `FtSiteStr` contains nested arrays of antennas, links, channels
4. **Incremental Processing**: Results are inserted as they're calculated, not in batch

### The Link Structure

**TLink** is a critical data structure that groups antennas:

```csharp
// TLink represents a radio link (point-to-point connection)
// Contains:
// - call1, call2: The two sites in the link
// - bndcde: Frequency band
// - nNumAnts: Number of antennas in this link
// - aAnts[]: Array of antenna indices
```

**Why Links Matter**:
- A site can have multiple links (different bands, different remote sites)
- Each link contains multiple antennas (diversity, redundancy)
- Processing is done per-link, not per-antenna

**Example**:
```
Site "ABC123" has:
  Link 1: ABC123 → XYZ789, Band 6GHz, Antennas [1, 2]
  Link 2: ABC123 → DEF456, Band 11GHz, Antennas [3]
  Link 3: ABC123 → GHI789, Band 18GHz, Antennas [4, 5, 6]
```

### T-SQL Solution Strategies

#### Strategy A: Set-Based with Temporary Tables (Recommended)

```sql
-- Stage 1: Create site pairs (one-time, set-based)
SELECT 
    ps.call1 AS intcall1,
    ps.call2 AS intcall2,
    vs.call1 AS viccall1,
    vs.call2 AS viccall2,
    -- ... distance, azimuth calculations
INTO #SitePairs
FROM proposed_sites ps
CROSS APPLY (
    SELECT * FROM environment_sites es
    WHERE tsip.keyhole_hs(ps.latit, ps.longit, es.latit, es.longit, 
                          ps.azmth, @coordDist) <= 2
      AND (es.bandwd1 & ps.adjacent_bands) != 0
) vs;

-- Stage 2: Create link pairs
SELECT 
    sp.*,
    pl.call1 AS pro_link_call1,
    pl.call2 AS pro_link_call2,
    pl.bndcde AS pro_bndcde,
    vl.call1 AS vic_link_call1,
    vl.call2 AS vic_link_call2,
    vl.bndcde AS vic_bndcde
INTO #LinkPairs
FROM #SitePairs sp
CROSS JOIN proposed_links pl
CROSS JOIN environment_links vl
WHERE pl.call1 = sp.intcall1
  AND vl.call1 = sp.viccall1
  AND SuIsBandAdjacent(pl.bndcde, vl.bndcde) = 1;

-- Stage 3: Create antenna pairs
SELECT 
    lp.*,
    pa.anum AS pro_anum,
    pa.acode AS pro_acode,
    ea.anum AS vic_anum,
    ea.acode AS vic_acode
INTO #AntennaPairs
FROM #LinkPairs lp
CROSS JOIN proposed_antennas pa
CROSS JOIN environment_antennas ea
WHERE pa.call1 = lp.pro_link_call1
  AND pa.call2 = lp.pro_link_call2
  AND pa.bndcde = lp.pro_bndcde
  AND ea.call1 = lp.vic_link_call1
  AND ea.call2 = lp.vic_link_call2
  AND ea.bndcde = lp.vic_bndcde;

-- Stage 4: Create channel pairs and calculate
INSERT INTO tt_chan
SELECT 
    ap.*,
    pc.chid AS pro_chid,
    ec.chid AS vic_chid,
    tsip.CalculateInterferenceMargin(...) AS resti
FROM #AntennaPairs ap
CROSS JOIN proposed_channels pc
CROSS JOIN environment_channels ec
WHERE pc.call1 = ap.pro_link_call1
  AND pc.call2 = ap.pro_link_call2
  AND pc.bndcde = ap.pro_bndcde
  AND ec.call1 = ap.vic_link_call1
  AND ec.call2 = ap.vic_link_call2
  AND ec.bndcde = ap.vic_bndcde;
```

**Pros**:
- Leverages SQL Server's set-based optimization
- Can use parallel execution
- Single pass through data

**Cons**:
- May create very large intermediate result sets
- Memory intensive for large analyses
- Less incremental (can't show progress)

#### Strategy B: Batch Processing (Hybrid)

```sql
-- Process in batches of 100 proposed sites
DECLARE @BatchSize INT = 100;
DECLARE @Processed INT = 0;

WHILE @Processed < (SELECT COUNT(*) FROM proposed_sites)
BEGIN
    -- Process one batch
    WITH ProposedBatch AS (
        SELECT TOP (@BatchSize) *
        FROM proposed_sites
        WHERE processed = 0
        ORDER BY call1
    )
    -- ... perform analysis for this batch ...
    
    UPDATE proposed_sites SET processed = 1
    WHERE call1 IN (SELECT call1 FROM ProposedBatch);
    
    SET @Processed = @Processed + @BatchSize;
END;
```

**Pros**:
- Manages memory better
- Can show progress
- Can resume if interrupted

**Cons**:
- More complex logic
- Requires state tracking

#### Strategy C: Recursive CTEs (Not Recommended)

```sql
WITH SitePairs AS (
    -- Base: proposed sites
    SELECT call1, call2, latit, longit, ...
    FROM proposed_sites
    
    UNION ALL
    
    -- Recursive: victim sites
    SELECT sp.call1, sp.call2, es.call1, es.call2, ...
    FROM SitePairs sp
    CROSS JOIN environment_sites es
    WHERE tsip.keyhole_hs(...) <= 2
)
```

**Why Not Recommended**:
- SQL Server limits recursion depth (default 100)
- Performance degrades with depth
- Complex to maintain

#### Strategy D: T-SQL Cursors (When Appropriate)

Cursors provide a procedural approach that closely mirrors the C# nested loop structure, making them useful in specific scenarios.

**How Cursors Map to Nested Loops**:

```sql
-- Level 1: Proposed Sites Cursor
DECLARE curProposedSites CURSOR 
    FORWARD_ONLY READ_ONLY FAST_FORWARD
    FOR
    SELECT call1, call2, latit, longit, grnd, oper, prov
    FROM proposed_sites
    WHERE cmd != 'D'
    ORDER BY call1;

DECLARE @proCall1 VARCHAR(9), @proCall2 VARCHAR(9);
DECLARE @proLatit INT, @proLongit INT, @proGrnd FLOAT;

OPEN curProposedSites;
FETCH NEXT FROM curProposedSites INTO @proCall1, @proCall2, @proLatit, @proLongit, @proGrnd, ...;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Level 2: Links for this site
    DECLARE curProposedLinks CURSOR 
        FORWARD_ONLY READ_ONLY FAST_FORWARD
        FOR
        SELECT DISTINCT call1, call2, bndcde
        FROM proposed_antennas
        WHERE call1 = @proCall1
          AND cmd != 'D';
    
    DECLARE @proLinkCall1 VARCHAR(9), @proLinkCall2 VARCHAR(9), @proBndcde VARCHAR(4);
    
    OPEN curProposedLinks;
    FETCH NEXT FROM curProposedLinks INTO @proLinkCall1, @proLinkCall2, @proBndcde;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Generate rough cull SQL
        DECLARE @sqlCommand NVARCHAR(MAX);
        SET @sqlCommand = N'
            SELECT call1
            FROM ' + @envTableName + N'_site
            WHERE tsip.keyhole_hs(' + CAST(@proLatit AS VARCHAR) + N', ' + 
                  CAST(@proLongit AS VARCHAR) + N', latit, longit, ' +
                  CAST(@proAzmth AS VARCHAR) + N', ' + 
                  CAST(@coordDist AS VARCHAR) + N') <= 2
              AND (bandwd1 & 0x0000000f != 0)
              AND cmd != ''D''';
        
        -- Level 3: Victim Sites Cursor
        DECLARE @vicCall1 VARCHAR(9);
        DECLARE curVictimSites CURSOR 
            FORWARD_ONLY READ_ONLY FAST_FORWARD
            FOR
            EXEC sp_executesql @sqlCommand;
        
        OPEN curVictimSites;
        FETCH NEXT FROM curVictimSites INTO @vicCall1;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Geometry cull and further processing...
            -- (Levels 4-6 continue with nested cursors or set-based operations)
            
            FETCH NEXT FROM curVictimSites INTO @vicCall1;
        END;
        
        CLOSE curVictimSites;
        DEALLOCATE curVictimSites;
        
        FETCH NEXT FROM curProposedLinks INTO @proLinkCall1, @proLinkCall2, @proBndcde;
    END;
    
    CLOSE curProposedLinks;
    DEALLOCATE curProposedLinks;
    
    FETCH NEXT FROM curProposedSites INTO @proCall1, @proCall2, ...;
END;

CLOSE curProposedSites;
DEALLOCATE curProposedSites;
```

**Cursor Types and Performance**:

1. **FAST_FORWARD** (Recommended for read-only forward-only):
   ```sql
   DECLARE curSites CURSOR FAST_FORWARD FOR SELECT ...;
   ```
   - Combines `FORWARD_ONLY` + `READ_ONLY` + optimizations
   - Fastest cursor type
   - Can only move forward, cannot update

2. **STATIC**:
   ```sql
   DECLARE curSites CURSOR STATIC FOR SELECT ...;
   ```
   - Creates snapshot in tempdb
   - Can scroll, but slower
   - Use when: Need to scroll or data changes during processing

3. **KEYSET**:
   ```sql
   DECLARE curSites CURSOR KEYSET FOR SELECT ...;
   ```
   - Creates keyset in tempdb
   - Can see updates to non-key columns
   - Moderate performance

4. **DYNAMIC** (Slowest):
   ```sql
   DECLARE curSites CURSOR DYNAMIC FOR SELECT ...;
   ```
   - Sees all changes in real-time
   - Slowest, most overhead
   - Rarely needed

**When to Use Cursors**:

✅ **Use Cursors When**:
- Need incremental progress tracking
- Need to pause/resume processing
- Outer loop is low volume (< 10,000 rows)
- Complex conditional logic per row
- Row-by-row dependencies
- Need to show progress to users

❌ **Avoid Cursors When**:
- High volume processing (> 100,000 rows)
- Can express logic in set-based SQL
- Need maximum performance
- Can handle all data in memory

**Performance Considerations**:

**Cursor Overhead**:
- Each `FETCH` operation has overhead
- For 1 million rows: 1,000,000 FETCH operations vs. 1 set-based query
- Typically 10-100× slower than set-based for large datasets

**Example Performance**:
```
Set-Based: 100 sites × 1000 victims = 1 query, ~30 seconds
Cursor:    100 sites × 1000 victims = 100,000 FETCH operations, ~5-10 minutes
```

**Optimization Tips**:

1. **Use FAST_FORWARD when possible**:
   ```sql
   DECLARE curSites CURSOR FAST_FORWARD FOR SELECT ...;
   ```

2. **Minimize cursor scope**:
   ```sql
   BEGIN
       DECLARE curSites CURSOR FOR SELECT ...;
       OPEN curSites;
       -- Process immediately
       WHILE @@FETCH_STATUS = 0 ...
       CLOSE curSites;
       DEALLOCATE curSites;
   END;
   ```

3. **Use LOCAL cursors**:
   ```sql
   DECLARE curSites CURSOR LOCAL FOR SELECT ...;
   ```
   - Automatically cleaned up if procedure exits unexpectedly

4. **Index the cursor query**:
   ```sql
   DECLARE curSites CURSOR FOR
       SELECT call1 FROM proposed_sites
       WHERE cmd != 'D'
       ORDER BY call1;  -- Uses index on call1
   ```

**Hybrid Approach (Best Practice)**:

Use cursors for outer loops (low volume, need state), set-based for inner operations (high volume, can parallelize):

```sql
-- Outer loop: Cursor (low volume, needs state)
DECLARE curProposedSites CURSOR FOR
    SELECT call1 FROM proposed_sites WHERE processed = 0;

OPEN curProposedSites;
FETCH NEXT FROM curProposedSites INTO @proCall1;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Inner operations: Set-based (high volume, can parallelize)
    INSERT INTO tt_chan
    SELECT 
        @proCall1 AS intcall1,
        es.call1 AS viccall1,
        tsip.CalculateInterferenceMargin(...) AS resti
    FROM environment_sites es
    WHERE tsip.keyhole_hs(@proLatit, @proLongit, es.latit, es.longit, ...) <= 2
      AND tsip.IntVicSiteCull(@proCall1, es.call1, ...) = 1;
    -- This inner query can still be parallelized!
    
    UPDATE proposed_sites SET processed = 1 WHERE call1 = @proCall1;
    FETCH NEXT FROM curProposedSites INTO @proCall1;
END;
```

**Benefits of Hybrid**:
- Outer loop: Low overhead (100-1000 sites)
- Inner operations: Fast set-based (millions of rows)
- Can show progress
- Can pause/resume
- Inner queries can still use parallel execution

**Complete Cursor Implementation Example**:

See the detailed example in the "Specific Code Examples" section below for a full implementation showing all 6 levels of nested processing using cursors.

**Pros**:
- Mirrors C# structure closely
- Easy to show progress
- Can pause/resume processing
- Good for low-volume outer loops
- Can handle complex conditional logic

**Cons**:
- Slower than set-based (10-100× for large datasets)
- Sequential processing (no parallelization)
- More complex code (nested cursors)
- Higher maintenance burden

**Recommendation**: Use **hybrid approach** - cursors for outer loops (sites, links), set-based for inner operations (antennas, channels).

---

## 2. Antenna Discrimination Lookups

### The Problem

Antenna discrimination values must be **interpolated** from antenna pattern tables based on:
- Off-axis angle (degrees from boresight)
- Polarization (horizontal/vertical)
- Frequency (some patterns are frequency-dependent)

**Current Implementation**: `TpGetDat.TpCalcDisc()` → Calls native DLL `tpruntsip.dll` → `CalcTotADisc()`

**Location**: `TtCalcs.cs` → `TtAnteCalcs()` (lines 474-484, 557-568)

### Data Structure

**Antenna Pattern Table** (`sd_antd`):
```
acode    | antang | dcov  | dxpv  | dcoh  | dxph  | dtilt
---------|--------|-------|-------|-------|-------|-------
ANT001   | 0.0    | 0.0   | 0.0   | 0.0   | 0.0   | 0.0
ANT001   | 1.0    | 0.5   | 0.3   | 0.4   | 0.2   | 0.0
ANT001   | 2.0    | 1.2   | 0.8   | 1.0   | 0.6   | 0.0
ANT001   | 5.0    | 3.5   | 2.1   | 2.8   | 1.7   | 0.0
ANT001   | 10.0   | 8.2   | 5.1   | 6.5   | 4.2   | 0.0
...
ANT001   | 180.0  | 50.0  | 50.0  | 50.0  | 50.0  | 0.0
```

**Fields**:
- `dcov`: Co-polar discrimination (vertical)
- `dxpv`: Cross-polar discrimination (vertical)
- `dcoh`: Co-polar discrimination (horizontal)
- `dxph`: Cross-polar discrimination (horizontal)
- `dtilt`: Tilt discrimination

### Interpolation Logic

**Required**: Linear interpolation between angle points

**Example**: If off-axis angle is 3.5°, find values at 2.0° and 5.0°, then interpolate:

```
discrimination = value_at_2.0 + (3.5 - 2.0) * (value_at_5.0 - value_at_2.0) / (5.0 - 2.0)
```

### T-SQL Implementation

#### Option 1: Scalar Function (Simple but Slow)

```sql
CREATE FUNCTION tsip.GetAntennaDiscrimination(
    @acode VARCHAR(12),
    @offAxisAngle FLOAT,
    @polarization CHAR(1)  -- 'H' or 'V'
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @discrimination FLOAT;
    DECLARE @lowerAngle FLOAT, @upperAngle FLOAT;
    DECLARE @lowerValue FLOAT, @upperValue FLOAT;
    
    -- Handle edge cases
    IF @offAxisAngle <= 0.0
    BEGIN
        SELECT @discrimination = 
            CASE @polarization
                WHEN 'V' THEN dcov
                WHEN 'H' THEN dcoh
                ELSE dcov
            END
        FROM sd_antd
        WHERE acode = @acode
          AND antang = (SELECT MIN(antang) FROM sd_antd WHERE acode = @acode);
        RETURN @discrimination;
    END;
    
    -- Find bounding angles
    SELECT TOP 1
        @lowerAngle = antang,
        @lowerValue = CASE @polarization WHEN 'V' THEN dcov WHEN 'H' THEN dcoh END
    FROM sd_antd
    WHERE acode = @acode
      AND antang <= @offAxisAngle
    ORDER BY antang DESC;
    
    SELECT TOP 1
        @upperAngle = antang,
        @upperValue = CASE @polarization WHEN 'V' THEN dcov WHEN 'H' THEN dcoh END
    FROM sd_antd
    WHERE acode = @acode
      AND antang > @offAxisAngle
    ORDER BY antang ASC;
    
    -- Interpolate
    IF @upperAngle = @lowerAngle
        SET @discrimination = @lowerValue;
    ELSE
        SET @discrimination = @lowerValue + 
            (@offAxisAngle - @lowerAngle) * 
            (@upperValue - @lowerValue) / 
            (@upperAngle - @lowerAngle);
    
    RETURN @discrimination;
END;
```

**Performance Issue**: This function is called **millions of times** during analysis. Each call does 2-3 table lookups.

#### Option 2: Inline Table-Valued Function (Better Performance)

```sql
CREATE FUNCTION tsip.GetAntennaDiscriminationTVF(
    @acode VARCHAR(12),
    @offAxisAngle FLOAT,
    @polarization CHAR(1)
)
RETURNS TABLE
AS
RETURN
(
    WITH AngleBounds AS (
        SELECT 
            antang,
            CASE @polarization WHEN 'V' THEN dcov WHEN 'H' THEN dcoh END AS disc_value,
            LAG(antang) OVER (ORDER BY antang) AS prev_angle,
            LAG(CASE @polarization WHEN 'V' THEN dcov WHEN 'H' THEN dcoh END) 
                OVER (ORDER BY antang) AS prev_value
        FROM sd_antd
        WHERE acode = @acode
    )
    SELECT TOP 1
        CASE 
            WHEN @offAxisAngle <= antang THEN disc_value
            WHEN prev_angle IS NULL THEN disc_value
            ELSE prev_value + 
                 (@offAxisAngle - prev_angle) * 
                 (disc_value - prev_value) / 
                 (antang - prev_angle)
        END AS discrimination
    FROM AngleBounds
    WHERE antang >= @offAxisAngle
    ORDER BY antang ASC
);
```

**Usage**:
```sql
SELECT 
    ap.*,
    disc.discrimination AS int_ant_disc
FROM #AntennaPairs ap
CROSS APPLY tsip.GetAntennaDiscriminationTVF(ap.pro_acode, ap.off_axis_angle, 'V') disc;
```

#### Option 3: Pre-computed Lookup Table (Best Performance)

```sql
-- Create lookup table with all common angles
CREATE TABLE tsip.ant_disc_lookup (
    acode VARCHAR(12),
    angle_deg FLOAT,
    disc_v_copol FLOAT,
    disc_v_xpol FLOAT,
    disc_h_copol FLOAT,
    disc_h_xpol FLOAT,
    PRIMARY KEY (acode, angle_deg)
);

-- Populate with 0.1° resolution (or whatever precision needed)
INSERT INTO tsip.ant_disc_lookup
SELECT 
    a.acode,
    angles.angle,
    -- Interpolate values for each angle
    ...
FROM sd_antd a
CROSS JOIN (SELECT 0.0 AS angle UNION ALL SELECT 0.1 UNION ALL ...) angles;
```

**Then simple lookup**:
```sql
SELECT 
    ap.*,
    lookup.disc_v_copol AS int_ant_disc
FROM #AntennaPairs ap
INNER JOIN tsip.ant_disc_lookup lookup
    ON lookup.acode = ap.pro_acode
    AND lookup.angle_deg = ROUND(ap.off_axis_angle, 1);
```

**Trade-off**: Storage space vs. query performance

---

## 3. Over-Horizon Path Loss Calculations

### The Problem

Over-horizon path loss requires:
1. **Terrain data files** (250K and 50K scale maps)
2. **Complex diffraction calculations** (multiple knife-edge diffraction)
3. **File system access** to read terrain databases
4. **Native DLL** (`_OHloss.dll`) for calculations

**Current Implementation**: 
- Uses `_OHloss` library (separate DLL)
- Reads terrain files from disk: `dir250k` and `dir50k`
- Calculates path loss at 80% and 99% time availability

**Location**: `TpRunTsip.cs` (lines 196-200), `TtCalcs.cs` → `TtChanCalcs()` (over-horizon sections)

### What Over-Horizon Calculations Do

1. **Terrain Profile Extraction**: 
   - Extract elevation profile along path between two sites
   - Uses 250K or 50K scale terrain data
   - Accounts for Earth's curvature

2. **Knife-Edge Diffraction**:
   - Identifies obstacles (hills, mountains) along path
   - Calculates diffraction loss for each obstacle
   - Combines multiple obstacles

3. **Time Availability**:
   - Calculates path loss at different time percentages
   - 80% time: Typical conditions
   - 99% time: Worst-case conditions (more diffraction)

4. **Result**:
   - `pathloss80`, `pathloss99`: Path loss values
   - `ohresult`: Status code (0=line-of-sight, 1-99=over-horizon percentage, 100+=error)

### Why This Is Challenging

1. **File System Access**: T-SQL cannot directly read files from disk (without xp_cmdshell or CLR)
2. **Large Terrain Databases**: Terrain files can be gigabytes in size
3. **Complex Algorithms**: Diffraction calculations are computationally intensive
4. **Native Code Dependency**: Current implementation uses C/C++ DLL

### T-SQL Solution Options

#### Option A: SQL Server CLR Function (Recommended)

```csharp
[Microsoft.SqlServer.Server.SqlFunction]
public static SqlDouble OverHorizonPathLoss(
    SqlDouble lat1, SqlDouble long1,
    SqlDouble lat2, SqlDouble long2,
    SqlDouble freqMHz,
    SqlString terrainPath250K,
    SqlString terrainPath50K,
    SqlInt16 timePercent  // 80 or 99
)
{
    // Call the existing _OHloss library
    return OHloss.CalculatePathLoss(
        (double)lat1, (double)long1,
        (double)lat2, (double)long2,
        (double)freqMHz,
        (string)terrainPath250K,
        (string)terrainPath50K,
        (short)timePercent
    );
}
```

**Deployment**:
```sql
CREATE ASSEMBLY OHlossAssembly
FROM 'C:\Path\To\_OHloss.dll'
WITH PERMISSION_SET = UNSAFE;  -- Required for file system access

CREATE FUNCTION tsip.OverHorizonPathLoss(
    @lat1 FLOAT,
    @long1 FLOAT,
    @lat2 FLOAT,
    @long2 FLOAT,
    @freqMHz FLOAT,
    @terrainPath250K VARCHAR(500),
    @terrainPath50K VARCHAR(500),
    @timePercent SMALLINT
)
RETURNS FLOAT
AS EXTERNAL NAME OHlossAssembly.[Namespace.Class].OverHorizonPathLoss;
```

**Pros**:
- Reuses existing code
- Maintains accuracy
- Can access file system

**Cons**:
- Requires CLR enabled
- Security concerns (UNSAFE permission)
- Deployment complexity

#### Option B: Pre-computed Terrain Database

**Concept**: Store terrain profiles in SQL Server database

```sql
-- Terrain profile table
CREATE TABLE tsip.terrain_profiles (
    path_id BIGINT IDENTITY PRIMARY KEY,
    lat1 FLOAT, long1 FLOAT,
    lat2 FLOAT, long2 FLOAT,
    profile_data VARBINARY(MAX),  -- Serialized elevation points
    path_length_km FLOAT,
    INDEX IX_terrain_profiles_coords (lat1, long1, lat2, long2)
);

-- Pre-compute common paths
-- (Background job populates this table)
```

**Lookup**:
```sql
CREATE FUNCTION tsip.GetTerrainProfile(
    @lat1 FLOAT, @long1 FLOAT,
    @lat2 FLOAT, @long2 FLOAT,
    @tolerance FLOAT  -- Distance tolerance in km
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP 1 profile_data, path_length_km
    FROM tsip.terrain_profiles
    WHERE ABS(lat1 - @lat1) < @tolerance
      AND ABS(long1 - @long1) < @tolerance
      AND ABS(lat2 - @lat2) < @tolerance
      AND ABS(long2 - @long2) < @tolerance
    ORDER BY 
        (ABS(lat1 - @lat1) + ABS(long1 - @long1) + 
         ABS(lat2 - @lat2) + ABS(long2 - @long2))
);
```

**Then calculate diffraction in T-SQL** (simplified model):
```sql
CREATE FUNCTION tsip.CalculateDiffractionLoss(
    @profile_data VARBINARY(MAX),
    @freqMHz FLOAT,
    @timePercent SMALLINT
)
RETURNS FLOAT
AS
BEGIN
    -- Simplified ITU-R P.526 model
    -- (Full implementation would deserialize profile_data and calculate)
    DECLARE @loss FLOAT;
    -- ... complex calculation ...
    RETURN @loss;
END;
```

**Pros**:
- No file system access needed
- Fast lookups
- Can cache common paths

**Cons**:
- Massive storage requirements
- Pre-computation overhead
- May not cover all paths

#### Option C: External Service (Microservice)

**Architecture**:
```
SQL Server → HTTP Request → Over-Horizon Service → _OHloss.dll → Response
```

**T-SQL**:
```sql
CREATE FUNCTION tsip.OverHorizonPathLoss_HTTP(
    @lat1 FLOAT, @long1 FLOAT,
    @lat2 FLOAT, @long2 FLOAT,
    @freqMHz FLOAT,
    @timePercent SMALLINT
)
RETURNS FLOAT
AS
BEGIN
    -- Use SQL Server CLR to make HTTP request
    -- Or use xp_cmdshell (not recommended)
    -- Or use Service Broker for async processing
    RETURN ...;
END;
```

**Pros**:
- Isolates complexity
- Can scale independently
- No CLR in main database

**Cons**:
- Network latency
- Additional infrastructure
- Complexity

---

## 4. State Management and Memory

### The Problem

C# code maintains complex state throughout processing:

```csharp
// Global state
private static string oldTrafTx = "";
private static string oldTrafRx = "";
private static string oldEqptTx = "";
private static string oldEqptRx = "";
private static CtxStruct curCtx = new CtxStruct();

// Per-site state
FtSiteStr pSite;  // Full site structure with nested arrays
TLink[] pLinks;   // Array of links
int nNumLinks;    // Number of links

// Per-link state
string sqlCommand;  // Generated WHERE clause
int numCases;       // Running count
```

**Why State Matters**:
- **Caching**: CTX lookups are cached (if same traffic/equipment, reuse)
- **Progress Tracking**: `numCases` increments as cases are found
- **Error Context**: Error messages include current site/link info
- **Memory Management**: `FtFreeLinks()` releases memory after each site

### T-SQL Challenges

1. **No Global Variables**: T-SQL doesn't have static/global variables like C#
2. **Session State**: Can use `#temp` tables, but they're session-scoped
3. **Caching**: Hard to implement efficient caching in T-SQL
4. **Progress Tracking**: Difficult to show incremental progress

### Solutions

#### Solution 1: Temporary Tables for State

```sql
-- State tracking table
CREATE TABLE #ProcessingState (
    proposed_site VARCHAR(9),
    current_link INT,
    num_cases INT,
    last_traf_tx VARCHAR(6),
    last_traf_rx VARCHAR(6),
    last_eqpt_tx VARCHAR(8),
    last_eqpt_rx VARCHAR(8),
    ctx_data VARBINARY(MAX)  -- Serialized CTX structure
);

-- Update state as processing progresses
UPDATE #ProcessingState
SET num_cases = num_cases + 1,
    last_traf_tx = @current_traf_tx
WHERE proposed_site = @current_site;
```

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

-- Check cache before lookup
IF NOT EXISTS (
    SELECT 1 FROM @CtxCache
    WHERE traf_tx = @intTrafTx
      AND traf_rx = @vicTrafRx
      AND eqpt_tx = @intEqptTx
      AND eqpt_rx = @vicEqptRx
)
BEGIN
    -- Lookup and cache
    INSERT INTO @CtxCache
    SELECT @intTrafTx, @vicTrafRx, @intEqptTx, @vicEqptRx, rqco
    FROM sd_ctx
    WHERE tfcr = @intTrafTx
      AND tfci = @vicTrafRx
      AND rxeqp = @vicEqptRx;
END;

-- Use cached value
SELECT @requiredCI = required_ci
FROM @CtxCache
WHERE traf_tx = @intTrafTx
  AND traf_rx = @vicTrafRx
  AND eqpt_tx = @intEqptTx
  AND eqpt_rx = @vicEqptRx;
```

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

-- Update progress
UPDATE tsip.analysis_progress
SET items_processed = items_processed + 1,
    last_update = GETDATE()
WHERE run_id = @runId;
```

---

## 5. Performance Implications

### Current C# Performance Characteristics

1. **Incremental Processing**: Processes one site at a time (low memory)
2. **Early Termination**: Stops processing invalid pairs immediately
3. **Native Code**: Critical calculations in C/C++ (fast)
4. **Caching**: CTX lookups cached in memory
5. **Lazy Loading**: Sites loaded only when needed

### T-SQL Performance Challenges

#### Challenge 1: Cartesian Products

**Problem**: Set-based approach creates large intermediate result sets

**Example**:
```
100 proposed sites × 1000 victim sites × 5 links × 3 antennas × 10 channels
= 15,000,000 intermediate rows
```

**Solutions**:
- **Filter Early**: Apply all culling criteria before joins
- **Batch Processing**: Process in smaller chunks
- **Indexing**: Proper indexes on join columns
- **Partitioning**: Partition large tables

#### Challenge 2: Function Call Overhead

**Problem**: Scalar functions called millions of times

**Example**:
```sql
-- BAD: Called for every row
SELECT 
    *,
    tsip.GetAntennaDiscrimination(acode, angle, 'V') AS disc
FROM #AntennaPairs;  -- 1 million rows = 1 million function calls
```

**Solution**: Use CROSS APPLY with table-valued functions or pre-compute

#### Challenge 3: Memory Pressure

**Problem**: Large intermediate tables consume memory

**Solutions**:
- **Streaming**: Use CURSOR for very large sets (last resort)
- **Batch Processing**: Process 1000 sites at a time
- **TempDB Optimization**: Optimize tempdb for large operations
- **Memory Grants**: Adjust query memory grants

#### Challenge 4: Parallel Execution

**Opportunity**: SQL Server can parallelize set-based operations

**Example**:
```sql
-- SQL Server can parallelize this automatically
SELECT 
    *,
    tsip.CalculateInterferenceMargin(...) AS resti
FROM #AntennaPairs ap
CROSS JOIN proposed_channels pc
CROSS JOIN environment_channels ec
OPTION (MAXDOP 8);  -- Use 8 parallel threads
```

**Benefit**: Can be **much faster** than sequential C# processing

---

## 6. Specific Code Examples

### Example 1: Converting Site Loop to Set-Based

**C# Code**:
```csharp
rc = FtUtils.FtEnumSite("cmd != 'D'", tpParmStruct.proname, ref cCallFound);
while (rc == 0) {
    rc = FtUtils.FtGetSiteWN(cCallFound, out pSite, 3, tpParmStruct.proname, out pSiteNulls);
    nNumLinks = FtUtils.FtMakeLinks(pSite, out pLinks);
    for (nInd = 0; nInd < nNumLinks; nInd++) {
        // Process link
    }
    rc = FtUtils.FtEnumSite("cmd != 'D'", tpParmStruct.proname, ref cCallFound);
}
```

**T-SQL Equivalent**:
```sql
-- Get all proposed sites with their links
WITH ProposedSitesWithLinks AS (
    SELECT 
        s.call1,
        s.call2,
        s.latit,
        s.longit,
        l.bndcde,
        l.link_id,
        -- Aggregate antennas in link
        (SELECT anum FROM ft_ante 
         WHERE call1 = l.call1 AND call2 = l.call2 AND bndcde = l.bndcde
         FOR XML PATH('')) AS antenna_list
    FROM ft_site s
    INNER JOIN (
        SELECT DISTINCT call1, call2, bndcde,
               ROW_NUMBER() OVER (PARTITION BY call1 ORDER BY call2, bndcde) AS link_id
        FROM ft_ante
        WHERE cmd != 'D'
    ) l ON l.call1 = s.call1
    WHERE s.cmd != 'D'
)
SELECT * FROM ProposedSitesWithLinks;
```

### Example 2: Converting Antenna Nested Loop

**C# Code**:
```csharp
for (nProInd = 0; nProInd < pProLink.nNumAnts; nProInd++) {
    nProAntNum = pProLink.aAnts[nProInd];
    pProAnte = pProSite.stAntsPtr[nProAntNum];
    for (nEnvInd = 0; nEnvInd < pEnvLink.nNumAnts; nEnvInd++) {
        nEnvAntNum = pEnvLink.aAnts[nEnvInd];
        pEnvAnte = pEnvSite.stAntsPtr[nEnvAntNum];
        // Process antenna pair
    }
}
```

**T-SQL Equivalent (Set-Based)**:
```sql
SELECT 
    lp.*,
    pa.anum AS pro_anum,
    pa.acode AS pro_acode,
    ea.anum AS vic_anum,
    ea.acode AS vic_acode,
    -- Calculate off-axis angles
    tsip.CalculateOffAxisAngle(...) AS pro_off_axis,
    tsip.CalculateOffAxisAngle(...) AS vic_off_axis
FROM #LinkPairs lp
CROSS JOIN proposed_antennas pa
CROSS JOIN environment_antennas ea
WHERE pa.call1 = lp.pro_call1
  AND pa.call2 = lp.pro_call2
  AND pa.bndcde = lp.pro_bndcde
  AND ea.call1 = lp.vic_call1
  AND ea.call2 = lp.vic_call2
  AND ea.bndcde = lp.vic_bndcde;
```

### Example 3: Complete Cursor Implementation (6-Level Nested Loops)

**Full T-SQL stored procedure using cursors for all 6 levels**:

```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis_Cursor
    @proposedTableName VARCHAR(128),
    @envTableName VARCHAR(128),
    @coordDist FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @numCases INT = 0;
    DECLARE @proCall1 VARCHAR(9), @proCall2 VARCHAR(9);
    DECLARE @proLatit INT, @proLongit INT, @proGrnd FLOAT;
    DECLARE @proAzmth FLOAT;
    
    -- Level 1: Proposed Sites
    DECLARE curProposedSites CURSOR 
        FORWARD_ONLY READ_ONLY FAST_FORWARD LOCAL
        FOR
        SELECT s.call1, s.latit, s.longit, s.grnd,
               a.azmth  -- First antenna's azimuth for keyhole
        FROM ft_site s
        INNER JOIN (
            SELECT call1, MIN(azmth) AS azmth
            FROM ft_ante
            WHERE cmd != 'D'
            GROUP BY call1
        ) a ON a.call1 = s.call1
        WHERE s.cmd != 'D'
        ORDER BY s.call1;
    
    OPEN curProposedSites;
    FETCH NEXT FROM curProposedSites INTO @proCall1, @proLatit, @proLongit, @proGrnd, @proAzmth;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Level 2: Proposed Links
        DECLARE curProposedLinks CURSOR 
            FORWARD_ONLY READ_ONLY FAST_FORWARD LOCAL
            FOR
            SELECT DISTINCT call1, call2, bndcde
            FROM ft_ante
            WHERE call1 = @proCall1
              AND cmd != 'D';
        
        DECLARE @proLinkCall1 VARCHAR(9), @proLinkCall2 VARCHAR(9), @proBndcde VARCHAR(4);
        
        OPEN curProposedLinks;
        FETCH NEXT FROM curProposedLinks INTO @proLinkCall1, @proLinkCall2, @proBndcde;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Generate rough cull SQL
            DECLARE @sqlCommand NVARCHAR(MAX);
            SET @sqlCommand = N'
                SELECT call1
                FROM ' + @envTableName + N'_site
                WHERE tsip.keyhole_hs(' + CAST(@proLatit AS VARCHAR) + N', ' + 
                      CAST(@proLongit AS VARCHAR) + N', latit, longit, ' +
                      CAST(@proAzmth AS VARCHAR) + N', ' + 
                      CAST(@coordDist AS VARCHAR) + N') <= 2
                  AND (bandwd1 & 0x0000000f != 0)
                  AND cmd != ''D''';
            
            -- Level 3: Victim Sites (using dynamic SQL)
            DECLARE @vicCall1 VARCHAR(9);
            DECLARE curVictimSites CURSOR 
                FORWARD_ONLY READ_ONLY FAST_FORWARD LOCAL
                FOR
                EXEC sp_executesql @sqlCommand;
            
            OPEN curVictimSites;
            FETCH NEXT FROM curVictimSites INTO @vicCall1;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Geometry cull
                DECLARE @dist FLOAT, @azimIV FLOAT, @azimVI FLOAT;
                
                IF tsip.IntVicSiteCull(@proCall1, @vicCall1, @proLatit, @proLongit, 
                                       @dist OUTPUT, @azimIV OUTPUT, @azimVI OUTPUT) = 1
                BEGIN
                    -- Keyhole cull
                    IF @dist <= @coordDist OR 
                       (tsip.WithinKeyhole(@proCall1, @vicCall1) = 1 AND @dist <= 2 * @coordDist)
                    BEGIN
                        -- Level 4: Victim Links
                        DECLARE curVictimLinks CURSOR 
                            FORWARD_ONLY READ_ONLY FAST_FORWARD LOCAL
                            FOR
                            SELECT DISTINCT call1, call2, bndcde
                            FROM ft_ante
                            WHERE call1 = @vicCall1
                              AND cmd != 'D'
                              AND tsip.SuIsBandAdjacent(@proBndcde, bndcde) = 1;
                        
                        DECLARE @vicLinkCall1 VARCHAR(9), @vicLinkCall2 VARCHAR(9), @vicBndcde VARCHAR(4);
                        
                        OPEN curVictimLinks;
                        FETCH NEXT FROM curVictimLinks INTO @vicLinkCall1, @vicLinkCall2, @vicBndcde;
                        
                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                            -- Level 5: Antenna Pairs (set-based for performance)
                            INSERT INTO tt_ante (
                                intcall1, intcall2, intbndcde,
                                viccall1, viccall2, vicbndcde,
                                adiscctxh, adiscctxv, ...
                            )
                            SELECT 
                                @proLinkCall1, @proLinkCall2, @proBndcde,
                                @vicLinkCall1, @vicLinkCall2, @vicBndcde,
                                tsip.GetAntennaDiscrimination(pa.acode, @offAxis, 'H'),
                                tsip.GetAntennaDiscrimination(pa.acode, @offAxis, 'V'),
                                ...
                            FROM ft_ante pa
                            CROSS JOIN ft_ante ea
                            WHERE pa.call1 = @proLinkCall1
                              AND pa.call2 = @proLinkCall2
                              AND pa.bndcde = @proBndcde
                              AND ea.call1 = @vicLinkCall1
                              AND ea.call2 = @vicLinkCall2
                              AND ea.bndcde = @vicBndcde;
                            
                            -- Level 6: Channel Pairs (also set-based)
                            INSERT INTO tt_chan (
                                intcall1, intcall2, intbndcde, intchid,
                                viccall1, viccall2, vicbndcde, vicchid,
                                resti, calcico, ...
                            )
                            SELECT 
                                @proLinkCall1, @proLinkCall2, @proBndcde, pc.chid,
                                @vicLinkCall1, @vicLinkCall2, @vicBndcde, ec.chid,
                                tsip.CalculateInterferenceMargin(...) AS resti,
                                ...
                            FROM ft_chan pc
                            CROSS JOIN ft_chan ec
                            WHERE pc.call1 = @proLinkCall1
                              AND pc.call2 = @proLinkCall2
                              AND pc.bndcde = @proBndcde
                              AND ec.call1 = @vicLinkCall1
                              AND ec.call2 = @vicLinkCall2
                              AND ec.bndcde = @vicBndcde;
                            
                            SET @numCases = @numCases + @@ROWCOUNT;
                            
                            FETCH NEXT FROM curVictimLinks INTO @vicLinkCall1, @vicLinkCall2, @vicBndcde;
                        END;
                        
                        CLOSE curVictimLinks;
                        DEALLOCATE curVictimLinks;
                    END;
                END;
                
                FETCH NEXT FROM curVictimSites INTO @vicCall1;
            END;
            
            CLOSE curVictimSites;
            DEALLOCATE curVictimSites;
            
            FETCH NEXT FROM curProposedLinks INTO @proLinkCall1, @proLinkCall2, @proBndcde;
        END;
        
        CLOSE curProposedLinks;
        DEALLOCATE curProposedLinks;
        
        FETCH NEXT FROM curProposedSites INTO @proCall1, @proLatit, @proLongit, @proGrnd, @proAzmth;
    END;
    
    CLOSE curProposedSites;
    DEALLOCATE curProposedSites;
    
    SELECT @numCases AS total_cases;
END;
```

**Note**: This example shows cursors for levels 1-4, but uses set-based operations for levels 5-6 (antennas and channels) to optimize performance. This is the **hybrid approach** recommended for best results.

---

## 7. Migration Strategy

### Phase 1: Proof of Concept (Low Risk)
1. Port geometry calculations (distance, azimuth, elevation)
2. Port line-of-sight path loss
3. Port basic CTX lookups
4. Test with single site pair

### Phase 2: Core Processing (Medium Risk)
1. Port site pair generation (set-based)
2. Port antenna pair processing
3. Port channel calculations
4. Test with small dataset (100 sites)

### Phase 3: Performance Optimization (High Risk)
1. Optimize antenna discrimination lookups
2. Implement batch processing
3. Add proper indexing
4. Test with production-sized dataset

### Phase 4: Advanced Features (Very High Risk)
1. Over-horizon via CLR or alternative
2. Complex state management
3. Progress tracking
4. Error handling and recovery

---

## Conclusion

The challenging portions are **solvable** but require:

1. **Architectural Changes**: From procedural to set-based thinking
2. **Performance Engineering**: Careful indexing, batching, caching
3. **Hybrid Approach**: CLR for native dependencies, T-SQL for orchestration
4. **Testing**: Extensive performance testing at each phase

**Biggest Risks**:
- Performance degradation if not optimized
- Memory pressure with large datasets
- Complexity of state management
- Over-horizon calculations (requires CLR or alternative)

**Biggest Opportunities**:
- Parallel execution (SQL Server strength)
- Set-based optimization (can be faster than loops)
- Reduced deployment complexity (no C# executables)
- Better integration with existing SQL infrastructure

---

*Last updated: January 2026*

