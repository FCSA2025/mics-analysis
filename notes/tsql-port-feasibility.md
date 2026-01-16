# TSIP to T-SQL Port Feasibility Analysis

This document analyzes the feasibility of recreating the TSIP interference analysis process entirely in T-SQL/SQL Server.

---

## Executive Summary

**Short Answer**: **Partially feasible, but with significant challenges.**

**What's Already SQL-Based**:
- ✅ Rough culling (uses `tsip.keyhole_hs()` SQL function)
- ✅ Data storage and retrieval
- ✅ Basic filtering and joins

**What Would Be Challenging**:
- ⚠️ Complex nested loops and state management
- ⚠️ Antenna discrimination lookups (interpolation from pattern tables)
- ⚠️ Over-horizon path loss calculations
- ⚠️ Some calculations use P/Invoke to native C/C++ DLLs

**What Would Require Alternatives**:
- ❌ Native DLL dependencies (`tpruntsip.dll`, `_OHloss.dll`)
- ❌ File system access (over-horizon terrain data files)
- ❌ Complex report generation

---

## Current Architecture Analysis

### Already Using SQL Server Functions

**1. Keyhole Distance Filtering**
```sql
-- Already implemented as SQL Server function
tsip.keyhole_hs(lat1, long1, lat2, long2, azimuth, coordDist) <= 2
```
**Location**: `TtBuildSH.cs` → `GenRoughCull()` (line 710)

**Feasibility**: ✅ **Already done** - This is a SQL Server user-defined function

---

### What Runs in C# (Would Need T-SQL Implementation)

#### 1. Site-Level Processing

**Current Implementation**: `TtBuildSH.cs` → `TtCullNCreate()`

**Processing Flow**:
```
FOR each proposed site:
  Get site data
  Build links (antennas)
  FOR each link:
    Generate rough cull SQL
    Query environment sites
    FOR each victim site:
      Geometry calculations
      Create site pair records
```

**T-SQL Feasibility**: ⚠️ **Challenging**

**Why**:
- Requires nested cursors or recursive CTEs
- Complex state management (tracking which sites/links processed)
- Memory-intensive (loading full site structures)

**Possible Approach**:
- Use recursive CTEs or table-valued functions
- Process in batches (one proposed site at a time)
- Use temporary tables for intermediate results

---

#### 2. Geometry Calculations

**Current Implementation**: `TtCalcs.cs` → `TtSiteCalcs()`, `OffAngle()`, `TtCalcIAng()`

**Calculations**:
- Distance between sites (Haversine formula)
- Azimuth/bearing calculations
- Elevation angles
- Off-axis angle calculations (3D vector math)

**Example**:
```csharp
// Off-axis angle calculation
xXA = XAdist * CosD(180.0 - azimXA) * CosD(elevXA);
yXA = XAdist * CosD(azimXA - 90.0) * CosD(elevXA);
zXA = XAdist * SinD(elevXA);
Y = (xXA * xXY + yXA * yXY + zXA * zXY) / (XAdist * XYdist);
```

**T-SQL Feasibility**: ✅ **Feasible**

**Why**:
- Pure mathematical calculations
- SQL Server has trigonometric functions (`COS`, `SIN`, `ATAN2`)
- Can be implemented as scalar functions or computed columns

**Implementation**:
```sql
CREATE FUNCTION tsip.CalculateOffAxisAngle(
    @IVdist FLOAT,
    @VAdist FLOAT,
    @Igrnd FLOAT,
    @Vgrnd FLOAT,
    @AGrnd FLOAT,
    @azimVI FLOAT,
    @azimVA FLOAT
)
RETURNS FLOAT
AS
BEGIN
    -- 3D vector calculations
    DECLARE @elevXA FLOAT, @elevAX FLOAT, @elevXY FLOAT, @elevYX FLOAT;
    DECLARE @xXA FLOAT, @yXA FLOAT, @zXA FLOAT;
    DECLARE @xXY FLOAT, @yXY FLOAT, @zXY FLOAT;
    DECLARE @Y FLOAT, @iAng FLOAT;
    
    -- Calculate elevations
    SET @elevXA = ... -- Elevation calculation
    SET @elevXY = ... -- Elevation calculation
    
    -- 3D vector components
    SET @xXA = @XAdist * COS(RADIANS(180.0 - @azimXA)) * COS(RADIANS(@elevXA));
    SET @yXA = @XAdist * COS(RADIANS(@azimXA - 90.0)) * COS(RADIANS(@elevXA));
    SET @zXA = @XAdist * SIN(RADIANS(@elevXA));
    
    -- Dot product
    SET @Y = (@xXA * @xXY + @yXA * @yXY + @zXA * @zXY) / (@XAdist * @XYdist);
    
    -- Calculate angle
    IF @Y > 0.99999
        SET @iAng = 0.0;
    ELSE
        SET @iAng = DEGREES(ACOS(@Y));
    
    RETURN @iAng;
END;
```

---

#### 3. Antenna Discrimination Lookups

**Current Implementation**: `TtCalcs.cs` → `CalcTotADisc_NATIVE()` (P/Invoke to `tpruntsip.dll`)

**Processing**:
- Lookup antenna pattern from `sd_ante` table
- Interpolate discrimination value based on off-axis angle
- Handle co-polar vs cross-polar
- Consider frequency-dependent patterns

**T-SQL Feasibility**: ⚠️ **Moderately Challenging**

**Why**:
- Requires interpolation from antenna pattern tables (`sd_antd`)
- Complex lookup logic (angle ranges, frequency bands)
- Currently uses native DLL for performance

**Possible Approach**:
```sql
CREATE FUNCTION tsip.GetAntennaDiscrimination(
    @acode VARCHAR(12),
    @offAxisAngle FLOAT,
    @polarization CHAR(1),  -- 'H' or 'V'
    @frequency FLOAT
)
RETURNS FLOAT
AS
BEGIN
    -- Lookup antenna pattern
    -- Interpolate between angle points
    -- Return discrimination value
    DECLARE @discrimination FLOAT;
    
    SELECT @discrimination = 
        CASE 
            WHEN @offAxisAngle <= (SELECT MIN(antang) FROM sd_antd WHERE acode = @acode)
            THEN (SELECT dcov FROM sd_antd WHERE acode = @acode AND antang = (SELECT MIN(antang) FROM sd_antd WHERE acode = @acode))
            WHEN @offAxisAngle >= (SELECT MAX(antang) FROM sd_antd WHERE acode = @acode)
            THEN (SELECT dcov FROM sd_antd WHERE acode = @acode AND antang = (SELECT MAX(antang) FROM sd_antd WHERE acode = @acode))
            ELSE (
                -- Linear interpolation
                SELECT TOP 1
                    dcov + (@offAxisAngle - antang) * 
                    (LEAD(dcov) OVER (ORDER BY antang) - dcov) /
                    (LEAD(antang) OVER (ORDER BY antang) - antang)
                FROM sd_antd
                WHERE acode = @acode
                  AND antang <= @offAxisAngle
                ORDER BY antang DESC
            )
        END;
    
    RETURN @discrimination;
END;
```

**Performance Consideration**: May be slower than native DLL, but acceptable if indexed properly.

---

#### 4. Path Loss Calculations

**Current Implementation**: 
- Line-of-sight: `TtCalcs.cs` → Free space path loss formula
- Over-horizon: `_OHloss` library (separate DLL)

**Line-of-Sight Path Loss**:
```csharp
// Free space path loss
pathLoss = 20.0 * Log10(distance) + 20.0 * Log10(frequency) + 32.44;
```

**T-SQL Feasibility**: ✅ **Feasible** (for line-of-sight)

**Implementation**:
```sql
CREATE FUNCTION tsip.FreeSpacePathLoss(
    @distanceKm FLOAT,
    @frequencyMHz FLOAT
)
RETURNS FLOAT
AS
BEGIN
    RETURN 20.0 * LOG10(@distanceKm) + 20.0 * LOG10(@frequencyMHz) + 32.44;
END;
```

**Over-Horizon Path Loss**:
**T-SQL Feasibility**: ❌ **Not Feasible (as-is)**

**Why**:
- Uses `_OHloss.dll` which reads terrain data files (250K and 50K maps)
- Complex terrain diffraction calculations
- Requires file system access to terrain databases

**Alternatives**:
1. **SQL Server CLR**: Create CLR function that calls the DLL
2. **Pre-calculated tables**: Pre-compute common over-horizon paths
3. **Simplified model**: Use ITU-R models instead of detailed terrain
4. **External service**: Keep over-horizon as separate service

---

#### 5. Channel-Level Calculations

**Current Implementation**: `TtCalcs.cs` → `TtChanCalcs()`

**Core Calculation**:
```
Margin = Calculated_C/I - Required_C/I

Where:
Calculated_C/I = Victim_Rx_Power - Interferer_Power_at_Victim

Interferer_Power_at_Victim = 
  Tx_Power 
  + Tx_Antenna_Gain 
  - Tx_Antenna_Discrimination
  - Path_Loss
  - Rx_Antenna_Discrimination
  + Rx_Antenna_Gain
```

**T-SQL Feasibility**: ✅ **Feasible**

**Implementation**:
```sql
CREATE FUNCTION tsip.CalculateInterferenceMargin(
    @intTxPower FLOAT,
    @intAntGain FLOAT,
    @intAntDisc FLOAT,
    @pathLoss FLOAT,
    @vicAntDisc FLOAT,
    @vicAntGain FLOAT,
    @vicRxPower FLOAT,
    @requiredCI FLOAT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @interfererPower FLOAT;
    DECLARE @calculatedCI FLOAT;
    DECLARE @margin FLOAT;
    
    -- Calculate interferer power at victim
    SET @interfererPower = @intTxPower + @intAntGain - @intAntDisc - @pathLoss - @vicAntDisc + @vicAntGain;
    
    -- Calculate C/I
    SET @calculatedCI = @vicRxPower - @interfererPower;
    
    -- Calculate margin
    SET @margin = @calculatedCI - @requiredCI;
    
    RETURN @margin;
END;
```

---

#### 6. CTX (Protection Criteria) Lookups

**Current Implementation**: Lookup from `sd_ctx` table based on traffic types and frequency separation

**T-SQL Feasibility**: ✅ **Already SQL-based**

**Implementation**: Simple JOIN or lookup function
```sql
CREATE FUNCTION tsip.GetRequiredCI(
    @intTrafficCode CHAR(6),
    @vicTrafficCode CHAR(6),
    @rxEquipment CHAR(8),
    @freqSeparation FLOAT
)
RETURNS FLOAT
AS
BEGIN
    DECLARE @requiredCI FLOAT;
    
    -- Lookup from CTX table
    SELECT @requiredCI = rqco
    FROM sd_ctx
    WHERE tfcr = @intTrafficCode
      AND tfci = @vicTrafficCode
      AND rxeqp = @rxEquipment
      AND fsep <= @freqSeparation
    ORDER BY fsep DESC;
    
    RETURN @requiredCI;
END;
```

---

## Major Challenges

### 1. Nested Loop Processing

**Problem**: C# code uses nested loops:
```
FOR each proposed site
  FOR each link in site
    FOR each victim site (from SQL query)
      FOR each antenna pair
        FOR each channel pair
```

**T-SQL Solution Options**:

**Option A: Cursors (Not Recommended)**
- Performance issues
- Complex to maintain
- Not set-based

**Option B: Recursive CTEs**
```sql
WITH SitePairs AS (
    -- Base case: proposed sites
    SELECT ...
    UNION ALL
    -- Recursive: victim sites
    SELECT ...
    FROM SitePairs sp
    JOIN environment_sites es ON ...
)
```

**Option C: Stored Procedure with Temporary Tables**
```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
    @proposedTableName VARCHAR(128),
    @envTableName VARCHAR(128),
    @coordDist FLOAT
AS
BEGIN
    -- Stage 1: Create site pairs
    SELECT ... INTO #SitePairs
    FROM proposed_sites ps
    CROSS APPLY (
        SELECT * FROM environment_sites es
        WHERE tsip.keyhole_hs(...) <= 2
    ) es;
    
    -- Stage 2: Create antenna pairs
    SELECT ... INTO #AntennaPairs
    FROM #SitePairs sp
    CROSS JOIN proposed_antennas pa
    CROSS JOIN environment_antennas ea;
    
    -- Stage 3: Create channel pairs and calculate
    INSERT INTO tt_chan
    SELECT 
        ...,
        tsip.CalculateInterferenceMargin(...) AS resti
    FROM #AntennaPairs ap
    CROSS JOIN proposed_channels pc
    CROSS JOIN environment_channels ec;
END;
```

**Recommendation**: **Option C** - Use set-based operations with temporary tables

---

### 2. State Management

**Problem**: C# code maintains state (which sites processed, link structures, etc.)

**T-SQL Solution**: 
- Use temporary tables to track state
- Process in batches
- Use `processed` flags in result tables

---

### 3. Over-Horizon Calculations

**Problem**: Requires `_OHloss.dll` and terrain data files

**Solutions**:

**A. SQL Server CLR Function**
```csharp
[Microsoft.SqlServer.Server.SqlFunction]
public static SqlDouble OverHorizonPathLoss(
    SqlDouble lat1, SqlDouble long1, SqlDouble lat2, SqlDouble long2,
    SqlDouble freq, SqlString terrainPath)
{
    // Call _OHloss library
    return OHloss.Calculate(lat1, long1, lat2, long2, freq, terrainPath);
}
```

**B. Pre-computed Tables**
- Pre-calculate common over-horizon paths
- Store in database table
- Lookup during analysis

**C. External Service**
- Keep over-horizon as separate microservice
- Call via HTTP or message queue

**Recommendation**: **Option A (CLR)** if DLL access needed, **Option B** for performance

---

### 4. Performance Considerations

**Current Architecture**:
- Processes sites incrementally (memory efficient)
- Uses native DLLs for performance-critical calculations
- Rough cull reduces data set by ~1000× before detailed processing

**T-SQL Challenges**:
- Set-based operations may load large intermediate result sets
- Function calls may be slower than native code
- Need careful indexing strategy

**Optimization Strategies**:
1. **Batch Processing**: Process 100-1000 sites at a time
2. **Indexing**: Index on latitude/longitude, band codes, operator codes
3. **Partitioning**: Partition large tables by region or operator
4. **Parallel Processing**: Use SQL Server's parallel query execution
5. **Materialized Views**: Pre-compute common calculations

---

## Recommended Architecture

### Hybrid Approach (Best of Both Worlds)

```
┌─────────────────────────────────────────────────────────┐
│  SQL Server (T-SQL)                                      │
│  • Rough culling (already done)                          │
│  • Site pair generation (set-based)                      │
│  • Basic geometry calculations (functions)              │
│  • CTX lookups                                           │
│  • Data storage                                          │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│  SQL Server CLR Functions                                 │
│  • Antenna discrimination (if performance critical)     │
│  • Over-horizon path loss (calls _OHloss.dll)           │
│  • Complex 3D calculations (if needed)                  │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│  T-SQL Stored Procedures                                 │
│  • Main orchestration                                    │
│  • Channel pair calculations                             │
│  • Margin calculations                                   │
│  • Result table population                               │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Proof of Concept (Feasible)
- ✅ Port geometry calculations to T-SQL functions
- ✅ Port basic path loss (line-of-sight) to T-SQL
- ✅ Port CTX lookups to T-SQL functions
- ✅ Create stored procedure for single site pair analysis

### Phase 2: Core Processing (Moderate Difficulty)
- ⚠️ Port site pair generation to set-based T-SQL
- ⚠️ Port antenna pair processing
- ⚠️ Port channel pair calculations
- ⚠️ Implement batch processing

### Phase 3: Advanced Features (Challenging)
- ❌ Over-horizon calculations (requires CLR or alternative)
- ❌ Complex antenna discrimination (may need CLR)
- ❌ Report generation (keep in C# or use SSRS)

### Phase 4: Optimization (Ongoing)
- Performance tuning
- Indexing strategy
- Parallel processing optimization

---

## Estimated Effort

| Component | Complexity | Estimated Effort |
|-----------|-----------|------------------|
| Geometry functions | Low | 1-2 weeks |
| Path loss (LOS) | Low | 1 week |
| CTX lookups | Low | 1 week |
| Site pair generation | Medium | 2-3 weeks |
| Antenna processing | Medium | 2-3 weeks |
| Channel calculations | Medium | 2-3 weeks |
| Over-horizon (CLR) | High | 3-4 weeks |
| Antenna discrimination | Medium-High | 2-4 weeks |
| Testing & optimization | High | 4-6 weeks |
| **Total** | | **18-26 weeks** |

---

## Conclusion

**Is it possible?** **Yes, with caveats.**

**Recommended Approach**:
1. **Start with hybrid**: Keep complex calculations in CLR, use T-SQL for orchestration
2. **Gradually migrate**: Move calculations to T-SQL as performance allows
3. **Keep external dependencies**: Over-horizon and native DLLs via CLR
4. **Leverage SQL Server strengths**: Set-based operations, indexing, parallel processing

**Key Success Factors**:
- Proper indexing strategy
- Batch processing to manage memory
- Performance testing at each phase
- Fallback to CLR for performance-critical operations

**Biggest Risk**: Performance degradation if not carefully optimized. SQL Server can handle this, but requires expertise in T-SQL optimization and query plan analysis.

---

*Last updated: January 2026*

