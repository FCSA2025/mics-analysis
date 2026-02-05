# Storage Requirements Analysis: 100,000 Channels

This document calculates the storage requirements for the T-SQL port with pre-computed lookup tables, assuming **100,000 channels** in the system.

---

## Assumptions

**Given**:
- **100,000 channels** in the system
- Storage space is **NOT a concern** (TB available)
- Pre-computed lookup tables for optimization

**Key Relationships**:
- Multiple channels can share the same antenna
- Multiple channels can share the same site pair
- Antennas are updated extremely rarely (once per month)
- Site pairs are relatively stable (new sites added occasionally)

---

## Storage Components

### 1. Antenna Discrimination Lookup Table (`tsip.ant_disc_lookup`)

**Purpose**: Pre-computed antenna discrimination values at 0.1° resolution

**Table Structure**:
```sql
CREATE TABLE tsip.ant_disc_lookup (
    acode VARCHAR(12),           -- Antenna code (12 bytes)
    angle_deg FLOAT,             -- Angle in degrees (8 bytes)
    disc_v_copol FLOAT,          -- Vertical co-polar (8 bytes)
    disc_v_xpol FLOAT,           -- Vertical cross-polar (8 bytes)
    disc_h_copol FLOAT,           -- Horizontal co-polar (8 bytes)
    disc_h_xpol FLOAT,            -- Horizontal cross-polar (8 bytes)
    PRIMARY KEY (acode, angle_deg)
);
```

**Storage per Row**: ~52 bytes (excluding index overhead)

**Calculation**:
- **Per antenna**: ~1,800 rows (0.1° resolution for 0-180°)
- **Row size**: ~52 bytes
- **Per antenna storage**: 1,800 × 52 = **93.6 KB**

**Key Question**: How many unique antennas are used across 100,000 channels?

**Actual Data**:
- **Current**: **3,500 unique antennas**
- **Growth rate**: ~30 antennas per year
- **After 10 years**: 3,500 + (30 × 10) = **3,800 antennas**

**Total Storage**:
- **3,500 antennas × 93.6 KB = 328 MB**
- **With indexes**: ~500 MB - 1 GB
- **After 10 years** (3,800 antennas): ~550 MB - 1.1 GB

**Note**: This is **independent of channel count** - it's based on number of unique antennas, which grows very slowly (~30/year).

---

### 2. Over-Horizon Path Loss Table (`tsip.over_horizon_path_loss`)

**Purpose**: Pre-computed path loss values for all site pairs

**Table Structure**:
```sql
CREATE TABLE tsip.over_horizon_path_loss (
    lat1 FLOAT,                  -- 8 bytes
    long1 FLOAT,                 -- 8 bytes
    lat2 FLOAT,                  -- 8 bytes
    long2 FLOAT,                 -- 8 bytes
    ant_height1 FLOAT,           -- 8 bytes
    ant_height2 FLOAT,           -- 8 bytes
    freq_ghz FLOAT,              -- 8 bytes
    polarization TINYINT,        -- 1 byte
    pathloss80 FLOAT,            -- 8 bytes
    pathloss99 FLOAT,            -- 8 bytes
    ohresult INT,                -- 4 bytes
    free_space_loss FLOAT,       -- 8 bytes
    additional_loss80 FLOAT,     -- 8 bytes
    additional_loss99 FLOAT,     -- 8 bytes
    calc_date DATETIME,          -- 8 bytes
    map_scale VARCHAR(10),        -- ~10 bytes
    PRIMARY KEY (lat1, long1, lat2, long2, ant_height1, ant_height2, freq_ghz, polarization)
);
```

**Storage per Row**: ~125 bytes (excluding index overhead)

**Key Question**: How many unique site pairs are represented by 100,000 channels?

**Estimation**:
- **Channels per site pair**: Typically 1-20 channels per link (average ~5)
- **100,000 channels ÷ 5 channels/link = ~20,000 unique links**
- **Links per site**: Each site typically has 1-10 links (average ~3)
- **20,000 links ÷ 3 links/site = ~6,700 unique sites**
- **Unique site pairs**: For interference analysis, we need **all pairs** of sites
  - **6,700 sites × 6,700 sites = ~45 million potential pairs**
  - But most pairs are too far apart (culled by distance)
  - **Realistic estimate**: ~1-5% of pairs are within coordination distance
  - **45 million × 0.02 = ~900,000 unique site pairs**

**But wait**: We also need to account for:
- **Antenna heights**: 8 standard heights (10, 15, 20, 30, 50, 100, 150, 200m)
- **Frequencies**: 5 standard frequencies (6, 11, 18, 23, 38 GHz)
- **Polarizations**: 2 (H, V)

**Total Combinations per Site Pair**:
- **8 heights × 8 heights × 5 frequencies × 2 polarizations = 640 combinations**

**Total Rows**:
- **900,000 site pairs × 640 combinations = 576 million rows**

**Total Storage**:
- **576 million rows × 125 bytes = 72 GB**
- **With indexes**: ~100-150 GB

**Optimization**: Only pre-compute paths that are actually used (from historical data)
- **Realistic estimate**: ~100,000-500,000 unique paths actually used
- **100,000 paths × 640 combinations = 64 million rows**
- **Storage**: ~8-12 GB (with indexes)

---

## Total Storage Summary

### Scenario 1: Conservative (All Possible Combinations)

| Component | Rows | Storage | Notes |
|-----------|------|---------|-------|
| **Antenna Discrimination** | 6.3 million | **1 GB** | 3,500 antennas × 1,800 rows |
| **Over-Horizon Path Loss** | 576 million | **150 GB** | 900,000 pairs × 640 combinations |
| **Total** | 582 million | **~150 GB** | |

### Scenario 2: Realistic (Only Used Paths)

| Component | Rows | Storage | Notes |
|-----------|------|---------|-------|
| **Antenna Discrimination** | 6.3 million | **1 GB** | 3,500 antennas × 1,800 rows |
| **Over-Horizon Path Loss** | 64 million | **12 GB** | 100,000 paths × 640 combinations |
| **Total** | 70 million | **~13 GB** | |

### Scenario 3: On-Demand Pre-Computation (No Historical Data) ⭐ **RECOMMENDED**

**Strategy**: Start with empty table, populate automatically as paths are encountered

| Component | Initial | After 1st Run | After 10 Runs | After 100 Runs | Notes |
|-----------|---------|--------------|---------------|----------------|-------|
| **Antenna Discrimination** | 0 | **1 GB** | **1 GB** | **1 GB** | Pre-compute all 3,500 antennas (monthly) |
| **Over-Horizon Path Loss** | 0 | **1-6 GB** | **6-25 GB** | **12-60 GB** | Grows with usage |
| **Total** | 0 | **~2-7 GB** | **~7-26 GB** | **~13-61 GB** | Self-populating cache |

**Key Benefits**:
- ✅ **No initial setup** - Start immediately
- ✅ **Self-populating** - Table grows with actual usage
- ✅ **Automatic caching** - Common paths cached automatically
- ✅ **No wasted computation** - Only calculate what's used

---

## Storage Growth Over Time

### Antenna Discrimination Table

**Growth Rate**: **Very slow** (30 antennas per year)
- **Current**: 3,500 antennas = **1 GB**
- New antennas: ~30 per year = ~2.5 per month
- Storage growth: ~2.5 MB per month
- **Annual growth**: ~30 MB

**After 10 years**: 
- Antennas: 3,500 + (30 × 10) = **3,800 antennas**
- Storage: **~1.1 GB** (still very manageable)

### Over-Horizon Path Loss Table

**Growth Rate**: **Moderate** (as new site pairs are encountered)
- New paths per analysis: ~100-1,000
- New paths per month: ~1,000-10,000
- Storage growth: ~125 MB - 1.25 GB per month
- **Annual growth**: ~1.5-15 GB

**After 10 years**: ~15-150 GB (depending on usage patterns)

---

## Storage by Channel Count

### Scaling Analysis

**Assumptions**:
- Channels per antenna: 20 (average)
- Channels per link: 5 (average)
- Links per site: 3 (average)

| Channels | Unique Antennas | Unique Site Pairs | Antenna Table | Path Loss Table | Total |
|----------|----------------|-------------------|---------------|-----------------|-------|
| **10,000** | 3,500 | 10,000 | **1 GB** | 1.3 GB | **~2.3 GB** |
| **50,000** | 3,500 | 50,000 | **1 GB** | 6.5 GB | **~7.5 GB** |
| **100,000** | 3,500 | 100,000 | **1 GB** | 12 GB | **~13 GB** |
| **500,000** | 3,500 | 500,000 | **1 GB** | 65 GB | **~66 GB** |
| **1,000,000** | 3,500 | 1,000,000 | **1 GB** | 130 GB | **~131 GB** |

**Key Insight**: Antenna table is **fixed at ~1 GB** regardless of channel count (only depends on number of unique antennas, which is 3,500 and grows slowly at 30/year).

**Note**: Path Loss table assumes **realistic** scenario (only used paths, not all combinations)

---

## Index Storage

### Antenna Discrimination Table

**Indexes**:
- Primary key: `(acode, angle_deg)` - Clustered
- Secondary: `(acode)` - For lookups

**Index overhead**: ~30-50% of data size
- **Data**: 328 MB (3,500 antennas)
- **Indexes**: ~100-165 MB
- **Total**: ~500 MB - 1 GB

### Over-Horizon Path Loss Table

**Indexes**:
- Primary key: `(lat1, long1, lat2, long2, ant_height1, ant_height2, freq_ghz, polarization)` - Clustered
- Secondary: `(lat1, long1, lat2, long2, freq_ghz)` - For path lookups

**Index overhead**: ~30-50% of data size
- **Data**: 12 GB
- **Indexes**: ~4-6 GB
- **Total**: ~16-18 GB

---

## Comparison: Pre-Computed vs. On-Demand

### Pre-Computed Tables (Recommended)

**Storage**: ~13-19 GB for 100,000 channels (with 3,500 antennas)
**Lookup Time**: ~1ms per lookup
**Pros**: Fastest possible, no CLR needed
**Cons**: Storage overhead (but storage is NOT a concern)

### On-Demand Calculation (Alternative)

**Storage**: Minimal (~100 MB for functions)
**Calculation Time**: ~50-200ms per calculation
**Pros**: No storage overhead
**Cons**: Slower, requires CLR or external service

**Recommendation**: **Pre-computed** - Storage is not a concern, and performance is critical.

---

## Storage Optimization Strategies

### 1. Incremental Pre-Computation

**Strategy**: Only pre-compute paths that are actually used

**Implementation**:
- Start with paths from historical TSIP runs
- Add new paths as they're encountered
- Background job pre-computes queued paths

**Benefit**: Reduces initial storage from 150 GB to ~15 GB

### 2. Discretization

**Strategy**: Round parameters to standard values

**Examples**:
- **Coordinates**: Round to 0.01° (~1km precision)
- **Heights**: Round to standard values (10, 15, 20, 30, 50, 100, 150, 200m)
- **Frequencies**: Round to band centers (6, 11, 18, 23, 38 GHz)

**Benefit**: Reduces unique combinations, enables better caching

### 3. Compression

**Strategy**: Use SQL Server compression

**Options**:
- **Row compression**: ~20-30% reduction
- **Page compression**: ~40-50% reduction

**Benefit**: Reduces storage by 30-50%

**Example**: 15 GB → 7.5-10 GB with page compression

### 4. Partitioning

**Strategy**: Partition tables by region or frequency

**Benefit**: 
- Faster queries (partition elimination)
- Easier maintenance
- Can archive old partitions

---

## Final Storage Estimate: 100,000 Channels

### On-Demand Pre-Computation Scenario (Recommended - No Historical Data)

**Initial State** (before first analysis):
- **Antenna Discrimination**: 0 GB (empty, will populate monthly)
- **Over-Horizon Path Loss**: 0 GB (empty, will populate on-demand)
- **Total**: **0 GB** (ready to start immediately)

**After First Analysis Run**:
- **Antenna Discrimination**: **1 GB** (pre-compute all 3,500 antennas)
- **Over-Horizon Path Loss**: **1-6 GB** (paths encountered in first run)
- **Total**: **~2-7 GB**

**After 10 Analysis Runs** (typical usage):
- **Antenna Discrimination**: **1 GB** (unchanged, monthly updates for new antennas)
- **Over-Horizon Path Loss**: **6-25 GB** (common paths cached)
- **Total**: **~7-26 GB**

**After 100 Analysis Runs** (mature system):
- **Antenna Discrimination**: **1 GB** (unchanged, ~30 new antennas/year)
- **Over-Horizon Path Loss**: **12-60 GB** (most paths cached)
- **Total**: **~13-61 GB**

**Note**: Growth slows over time as common paths get cached. Most growth happens in first 10-20 runs.

### With Compression

| Component | Storage | Notes |
|-----------|---------|-------|
| **Antenna Discrimination** | **1 GB** | With page compression |
| **Over-Horizon Path Loss** | **9 GB** | With page compression |
| **Total** | **~10 GB** | |

### Conservative (All Combinations)

| Component | Storage | Notes |
|-----------|---------|-------|
| **Antenna Discrimination** | **1 GB** | 3,500 antennas |
| **Over-Horizon Path Loss** | **150 GB** | All possible combinations |
| **Total** | **~150 GB** | |

---

## Conclusion

**For 100,000 channels**:

✅ **Realistic storage**: **~10-19 GB** (with compression: ~10 GB)
✅ **Conservative storage**: **~150 GB** (all combinations)
✅ **Storage is NOT a concern** - TB available

**Key Insights**:
1. **Antenna table is very small** - Only **1 GB** for 3,500 antennas (grows ~30 MB/year)
2. **Path loss table is larger** - Depends on number of unique site pairs (~100,000-900,000)
3. **On-demand pre-computation** - Start with 0 GB, grow automatically
4. **Compression helps** - Can reduce storage by 30-50%

**Recommendation**: 
- Start with **on-demand pre-computation** (no historical data needed)
- **Antenna table**: Pre-compute all 3,500 antennas monthly (**1 GB**, grows ~30 MB/year)
- **Path loss table**: Populate automatically as paths are encountered
- Use **page compression** to reduce storage by 30-50%
- Monitor growth and adjust as needed
- **Initial: 0 GB, After 10 runs: ~7-26 GB, Mature: ~13-61 GB**
- **All scenarios are trivial** with TB available

---

*Last updated: January 2026*

