# Performance Data Profiling - Actual Database Volumes

This document contains the actual data volumes from the production database, used for performance analysis and optimization planning.

---

## Actual Database Volumes

**Data Source**: Production database (static numbers)

| Entity | Count | Notes |
|--------|-------|-------|
| **Channels** | **160,746** | Total channels in system |
| **Antenna Types** | **3,200** | Unique antenna types (acode) |
| **Antennas** | **108,065** | Total antenna instances |
| **Sites** | **68,914** | Total sites in system |

**Data Characteristics**:
- ✅ **Numbers are static** - Relatively stable, not growing rapidly
- ✅ **Large dataset** - Significant volume for performance considerations

---

## Derived Metrics

### Average Relationships

| Relationship | Calculation | Result |
|--------------|-------------|--------|
| **Channels per Site** | 160,746 ÷ 68,914 | **~2.3 channels per site** |
| **Antennas per Site** | 108,065 ÷ 68,914 | **~1.6 antennas per site** |
| **Antennas per Antenna Type** | 108,065 ÷ 3,200 | **~33.8 antennas per type** |
| **Channels per Antenna** | 160,746 ÷ 108,065 | **~1.5 channels per antenna** |

**Key Insights**:
- Relatively low ratios (2-3 items per site) - good for performance
- Sites are the primary entity (68,914)
- Antennas are more numerous than sites (1.6×)

---

## Performance Impact Analysis

### Worst-Case Scenario (Before Culling)

**Assumption**: Typical analysis with 100 proposed sites vs. 68,914 environment sites

| Level | Entity | Count | Calculation | Result |
|-------|--------|-------|--------------|--------|
| **Level 1** | Proposed Sites | 100 | Given | 100 |
| **Level 2** | Proposed Links | ~230 | 100 sites × 2.3 links/site | 230 |
| **Level 3** | Victim Sites | 68,914 | All environment sites | 68,914 |
| **Level 4** | Victim Links | ~158,502 | 68,914 sites × 2.3 links/site | 158,502 |
| **Level 5** | Antenna Pairs | ~37,000,000 | 230 links × 1.6 ants × 158,502 links × 1.6 ants | 37M |
| **Level 6** | Channel Pairs | ~83,000,000 | 37M antenna pairs × 1.5 chans/ant × 1.5 chans/ant | 83M |

**Note**: These are **worst-case before culling**. Actual numbers after culling will be much lower.

---

## Culling Efficiency Estimates

Based on the 7-stage culling hierarchy:

| Stage | Cull Method | Efficiency | Remaining After Cull |
|-------|-------------|------------|---------------------|
| **1** | Rough Cull (distance, band, operator) | ~1000× | ~69 sites |
| **2** | Geometry Cull | ~10× | ~7 sites |
| **3** | Site Pairs Cull | ~2× | ~3-4 sites |
| **4** | Keyhole Cull | ~5× | ~0.6-1 sites |
| **5** | Band Adjacency | ~2× | ~0.3-0.5 sites |
| **6** | Antenna Cull | ~3× | ~0.1-0.2 sites |
| **7** | Channel Cull | ~2× | **~0.05-0.1 sites** |

**Realistic Estimate**: After all culling, **~1-10% of victim sites** remain for detailed processing.

**Example**: 100 proposed sites × 68,914 victim sites = 6.9M site pairs
- After culling: **~6,900 - 69,000 site pairs** (0.1% - 1%)
- Channel pairs: **~83,000 - 830,000** (0.1% - 1% of worst-case)

---

## Storage Requirements (Updated)

### Antenna Discrimination Lookup Table

**Previous Estimate**: 3,500 antennas
**Actual**: **3,200 antenna types**

**Storage Calculation**:
- **3,200 antenna types** × 1,800 rows (0.1° resolution) = **5.76M rows**
- **Row size**: ~52 bytes
- **Total storage**: 5.76M × 52 = **~300 MB** (with indexes: ~500 MB - 1 GB)

**Growth**: Static numbers, minimal growth expected

---

### Over-Horizon Path Loss Table

**Assumption**: Unique site pairs for path loss calculation

**Storage Calculation**:
- **Unique site pairs**: Depends on analysis patterns
- **Per path**: 64 height combinations × 5 frequencies × 2 polarizations = **640 rows**
- **Storage per path**: 640 × ~100 bytes = **64 KB**

**Example Scenarios**:
- **1,000 unique paths**: 1,000 × 640 = 640K rows = **~64 MB**
- **10,000 unique paths**: 10,000 × 640 = 6.4M rows = **~640 MB**
- **100,000 unique paths**: 100,000 × 640 = 64M rows = **~6.4 GB**

**Note**: On-demand pre-computation means table grows organically with usage.

---

## Performance Optimization Implications

### 1. Indexing Strategy

**Critical Indexes Needed**:

#### Site Tables (`ft_site`, `fe_site`)
```sql
-- Primary lookup: call1
CREATE INDEX IX_site_call1 ON ft_site(call1) INCLUDE (latit, longit, grnd, cmd);

-- Distance/geometry queries
CREATE INDEX IX_site_location ON ft_site(latit, longit) INCLUDE (call1, grnd);
```

#### Antenna Tables (`ft_ante`, `fe_ante`)
```sql
-- Primary lookup: call1, call2, bndcde
CREATE INDEX IX_ante_link ON ft_ante(call1, call2, bndcde) INCLUDE (acode, azmth, aht);

-- Antenna code lookup
CREATE INDEX IX_ante_acode ON ft_ante(acode) INCLUDE (call1, call2, bndcde);
```

#### Channel Tables (`ft_chan`, `fe_chan`)
```sql
-- Primary lookup: call1, call2, bndcde, chid
CREATE INDEX IX_chan_link ON ft_chan(call1, call2, bndcde, chid) INCLUDE (freqtx, freqrx, traftx, trafrx);

-- Frequency range queries
CREATE INDEX IX_chan_freq ON ft_chan(freqtx, freqrx) INCLUDE (call1, call2, bndcde);
```

#### Antenna Discrimination Lookup
```sql
-- Primary lookup: acode, angle_deg
CREATE INDEX IX_ant_disc_lookup ON tsip.ant_disc_lookup(acode, angle_deg) INCLUDE (disc_v_copol, disc_v_xpol, disc_h_copol, disc_h_xpol);
```

#### Over-Horizon Path Loss
```sql
-- Primary lookup: lat1, long1, lat2, long2, ant_height1, ant_height2, freq_ghz, polarization
CREATE INDEX IX_oh_pathloss ON tsip.over_horizon_path_loss(lat1, long1, lat2, long2, ant_height1, ant_height2, freq_ghz, polarization) INCLUDE (pathloss80, pathloss99, ohresult);
```

---

### 2. Batching Strategy

**Recommended Batch Sizes**:

| Operation | Batch Size | Rationale |
|-----------|-----------|-----------|
| **Site Processing** | 10-50 sites | Balance memory vs. performance |
| **Link Processing** | 100-500 links | Based on ~2.3 links/site |
| **Antenna Pairs** | 1,000-5,000 pairs | Set-based processing |
| **Channel Pairs** | 10,000-50,000 pairs | Set-based processing |

**Memory Considerations**:
- **68,914 sites** - Too large for single batch
- **Recommended**: Process in batches of **50-100 proposed sites** at a time
- **Memory per batch**: ~100-500 MB (estimated)

---

### 3. Parallel Execution

**Opportunities for Parallelization**:

1. **Site Pair Processing** (Level 1-2)
   - Each proposed site can be processed independently
   - **Parallelization**: Process multiple proposed sites simultaneously
   - **MAXDOP**: 4-8 (depending on CPU cores)

2. **Set-Based Operations** (Level 5-6)
   - Antenna pairs and channel pairs can be parallelized
   - **Parallelization**: SQL Server automatic parallelization
   - **MAXDOP**: 4-8

**Blocking Operations**:
- Cursor-based processing (Levels 1-4) - **NOT parallelizable**
- Set-based processing (Levels 5-6) - **Parallelizable**

**Recommendation**: Use `OPTION (MAXDOP 4)` for set-based queries in Levels 5-6.

---

### 4. Memory Management

**Estimated Memory Requirements**:

| Component | Size | Notes |
|-----------|------|-------|
| **Site Cache** | ~10-50 MB | 100-500 sites × ~100 KB/site |
| **Link Cache** | ~50-250 MB | 230-1,150 links × ~200 KB/link |
| **Antenna Cache** | ~100-500 MB | Antenna pair processing |
| **Channel Cache** | ~500 MB - 2 GB | Channel pair processing (largest) |
| **CTX Cache** | ~100 KB | Small, negligible |
| **Antenna Disc Cache** | ~500 MB - 1 GB | Pre-computed lookup table |
| **Path Loss Cache** | Variable | On-demand growth |

**Total Estimated Memory**: **~1-4 GB** per analysis run

**TempDB Considerations**:
- Temp tables for intermediate results
- Estimated: **500 MB - 2 GB** per run
- **Recommendation**: Monitor TempDB size and optimize if needed

---

## Query Performance Estimates

### Typical Analysis Run

**Assumptions**:
- 100 proposed sites
- 68,914 environment sites
- After culling: ~1% remain (~690 site pairs)
- ~690 site pairs × 2.3 links × 1.6 antennas × 1.5 channels = **~3,800 channel pairs**

**Performance Estimates**:

| Operation | Rows | Estimated Time | Notes |
|-----------|------|----------------|-------|
| **Rough Cull** | 68,914 sites | ~1-5 seconds | SQL function, indexed |
| **Site Pair Processing** | 690 pairs | ~10-30 seconds | Cursor-based (Levels 1-4) |
| **Antenna Pair Processing** | ~2,500 pairs | ~5-15 seconds | Set-based (Level 5) |
| **Channel Pair Processing** | ~3,800 pairs | ~10-30 seconds | Set-based (Level 6) |
| **CTX Lookups** | ~3,800 lookups | ~1-5 seconds | Pre-populated cache |
| **Path Loss Lookups** | ~3,800 lookups | ~5-15 seconds | Pre-computed or on-demand |
| **Total** | - | **~30-100 seconds** | **0.5-1.7 minutes** |

**Note**: These are estimates. Actual performance depends on:
- Index effectiveness
- Memory availability
- CPU cores (parallelization)
- Disk I/O speed

---

## Optimization Recommendations

### High Priority

1. **Create Critical Indexes** (see Indexing Strategy above)
   - **Impact**: 10-100× performance improvement
   - **Effort**: 1-2 days

2. **Implement Batching** (50-100 sites per batch)
   - **Impact**: Prevents memory pressure
   - **Effort**: 2-3 days

3. **Enable Parallel Execution** (MAXDOP 4-8 for set-based operations)
   - **Impact**: 2-4× performance improvement
   - **Effort**: 1 day (query hints)

### Medium Priority

4. **TempDB Optimization**
   - **Impact**: Prevents disk I/O bottlenecks
   - **Effort**: 1-2 days

5. **Memory Grant Tuning**
   - **Impact**: Prevents memory spills
   - **Effort**: 1 day

---

## Summary

**Key Findings**:
- ✅ **Large but manageable dataset** - 68,914 sites, 160,746 channels
- ✅ **Low ratios** - ~2.3 channels/site, ~1.6 antennas/site (good for performance)
- ✅ **Culling is effective** - Reduces 83M worst-case to ~3,800 actual channel pairs (99.995% reduction)
- ✅ **Performance is achievable** - Estimated 30-100 seconds per analysis run

**Next Steps**:
1. ✅ **Data profiling complete** - Actual volumes documented
2. ⏭️ **Design indexing strategy** - Based on query patterns
3. ⏭️ **Design batching strategy** - Optimal batch sizes
4. ⏭️ **Test and optimize** - Validate performance estimates

---

## Related Documents

- `tsql-remaining-challenges.md` - Performance implications section
- `tsip-nested-loops-structure.md` - Processing architecture
- `antenna-discrimination-analysis.md` - Antenna lookup optimization
- `over-horizon-path-loss-analysis.md` - Path loss optimization
- `ctx-lookup-pure-tsql.md` - CTX caching optimization

