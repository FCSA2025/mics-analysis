# Antenna Tables - Maintenance Guide

This document identifies all antenna-related tables in the MICS# system and specifies which tables need to be updated when a new antenna is added.

---

## Antenna Table Overview

### Master Data Tables (Subsidiary Database - SDB)

These tables contain the **master antenna catalog** used by the entire system.

#### `main.sd_ante` (Antenna Master Table)

**Purpose**: Stores antenna master information (one row per antenna code)

**Key Columns**:
- `acode` (CHAR(12)) - **Primary Key** - Antenna code (e.g., "ANT001", "CCIR-580")
- `axtype` (INT) - Antenna type
- `axref` (CHAR(12)) - Antenna cross-reference code
- `again` (REAL) - Antenna gain (dBi)
- `abw` (REAL) - Antenna beamwidth
- `arms` (TINYINT) - RMS value
- `aband` (CHAR(10)) - Frequency band
- `amanu` (CHAR(10)) - Manufacturer
- `apattern` (CHAR(12)) - Pattern reference
- `amodel` (CHAR(15)) - Model number
- `anip` (SMALLINT) - **Number of pattern points** (links to sd_antd)
- `ax0` (REAL) - X0 value
- `adesc` (CHAR(20)) - Description
- `antype` (CHAR(8)) - Antenna type code
- `aftbr` (REAL) - Front-to-back ratio
- `lofreq` (FLOAT) - Low frequency (MHz)
- `hifreq` (FLOAT) - High frequency (MHz)
- `bandcodes` (CHAR(99)) - Band codes
- `mdate` (CHAR(10)) - Modification date
- `mtime` (CHAR(8)) - Modification time

**Update Frequency**: **Extremely rarely** (approximately once per month when new antennas are added)

**Updated By**: `SdUpdateAnte.exe` program

---

#### `main.sd_antd` (Antenna Pattern/Discrimination Table)

**Purpose**: Stores antenna pattern data points (multiple rows per antenna code)

**Key Columns**:
- `acode` (CHAR(12)) - **Part of Primary Key** - Antenna code (foreign key to sd_ante.acode)
- `antang` (REAL) - **Part of Primary Key** - Angle in degrees (0-180° or 0-360°)
- `dcov` (REAL) - Co-polar discrimination (vertical)
- `dxpv` (REAL) - Cross-polar discrimination (vertical)
- `dcoh` (REAL) - Co-polar discrimination (horizontal)
- `dxph` (REAL) - Cross-polar discrimination (horizontal)
- `dtilt` (REAL) - Tilt discrimination
- `cmd` (CHAR(1)) - Command flag
- `mdate` (CHAR(10)) - Modification date
- `mtime` (CHAR(8)) - Modification time

**Relationship**: 
- One `sd_ante` record → Many `sd_antd` records
- `sd_ante.anip` = number of `sd_antd` records for that antenna

**Update Frequency**: **Extremely rarely** (approximately once per month when new antennas are added)

**Updated By**: `SdUpdateAnte.exe` program

**Example**:
```
sd_ante: acode='ANT001', anip=37
sd_antd: 37 rows with acode='ANT001', antang values: 0.0, 1.0, 2.0, 5.0, 10.0, ..., 180.0
```

---

### Input Data Tables (PDF Tables)

These tables contain antenna information for specific projects/PDFs (Proposed Data Files).

#### `{schema}.ft_ante_{project}_{runID}` (Terrestrial Station Antenna Table)

**Purpose**: Stores antenna information for terrestrial stations in a PDF

**Key Columns**:
- `call1` (CHAR(9)) - **Part of Primary Key** - Call sign 1
- `call2` (CHAR(9)) - **Part of Primary Key** - Call sign 2
- `bndcde` (CHAR(4)) - **Part of Primary Key** - Band code
- `anum` (SMALLINT) - **Part of Primary Key** - Antenna number
- `acode` (CHAR(12)) - **Antenna code** (references sd_ante.acode)
- `aht` (REAL) - Antenna height
- `azmth` (REAL) - Azimuth
- `elvtn` (REAL) - Elevation
- `dist` (REAL) - Distance
- `offazm` (CHAR(1)) - Off-axis azimuth flag
- `tazmth` (REAL) - Target azimuth
- `telvtn` (REAL) - Target elevation
- `tgain` (REAL) - Target gain
- ... (many more fields)

**Update Frequency**: **Per PDF** - Updated when PDF is created/modified

**Updated By**: PDF import/update processes

**Note**: This table **references** `sd_ante.acode` but does not need to be updated when a new antenna is added to the master catalog. It only needs updating if a PDF uses the new antenna.

---

#### `{schema}.fe_ante_{project}_{runID}` (Earth Station Antenna Table)

**Purpose**: Stores antenna information for earth stations in a PDF

**Key Columns**:
- `location` (CHAR(10)) - **Part of Primary Key** - Earth station location
- `call1` (CHAR(9)) - **Part of Primary Key** - Call sign
- `acodetx` (CHAR(12)) - TX antenna code (references sd_ante.acode)
- `acoderx` (CHAR(12)) - RX antenna code (references sd_ante.acode)
- `g_t` (REAL) - G/T ratio
- `aht` (REAL) - Antenna height
- `az` (REAL) - Azimuth
- `el` (REAL) - Elevation
- `satname` (CHAR(16)) - Satellite name
- ... (many more fields)

**Update Frequency**: **Per PDF** - Updated when PDF is created/modified

**Updated By**: PDF import/update processes

**Note**: This table **references** `sd_ante.acode` but does not need to be updated when a new antenna is added to the master catalog. It only needs updating if a PDF uses the new antenna.

---

### TSIP-Generated Tables (Working Tables)

These tables are **created dynamically** during interference analysis runs and contain calculated results.

#### `{schema}.tt_ante_{project}_{runID}` (TS-TS Antenna Pairs Table)

**Purpose**: Stores antenna pair records with calculated discrimination values for TS-TS analysis

**Key Columns**:
- `intcall1`, `intcall2`, `intbndcde`, `intanum` - Interferer antenna identifiers
- `viccall1`, `viccall2`, `vicbndcde`, `vicanum` - Victim antenna identifiers
- `intacode` (CHAR(12)) - Interferer antenna code
- `vicacode` (CHAR(12)) - Victim antenna code
- `adiscctxh`, `adiscctxv` - Antenna discrimination (co-polar, horizontal/vertical)
- `adiscxtxh`, `adiscxtxv` - Antenna discrimination (cross-polar, horizontal/vertical)
- `adisccrxh`, `adisccrxv` - Antenna discrimination (co-polar RX, horizontal/vertical)
- `adiscxrxh`, `adiscxrxv` - Antenna discrimination (cross-polar RX, horizontal/vertical)
- ... (many more calculated fields)

**Update Frequency**: **Per TSIP run** - Created and populated during each interference analysis

**Updated By**: `TpRunTsip.exe` during analysis

**Note**: This table is **temporary** and is dropped after the analysis completes. It does NOT need manual updates.

---

#### `{schema}.te_ante_{project}_{runID}` (TS-ES Antenna Pairs Table)

**Purpose**: Stores antenna pair records with calculated discrimination values for TS-ES analysis

**Key Columns**:
- `terrcall1`, `terrcall2`, `terrbndcde`, `terranum` - Terrestrial antenna identifiers
- `earthlocation`, `earthcall1`, `earthband` - Earth station identifiers
- `terracode` (CHAR(12)) - Terrestrial antenna code
- `earthacode` (CHAR(12)) - Earth station antenna code
- `adisc_set`, `adisc_ute` - Antenna discrimination values
- ... (many more calculated fields)

**Update Frequency**: **Per TSIP run** - Created and populated during each interference analysis

**Updated By**: `TpRunTsip.exe` during analysis

**Note**: This table is **temporary** and is dropped after the analysis completes. It does NOT need manual updates.

---

### New T-SQL Tables (Proposed)

#### `tsip.ant_disc_lookup` (Pre-computed Antenna Discrimination Lookup Table)

**Purpose**: Pre-computed discrimination values for all antennas at 0.1° resolution (optimization for T-SQL port)

**Key Columns**:
- `acode` (VARCHAR(12)) - **Part of Primary Key** - Antenna code (references sd_ante.acode)
- `angle_deg` (FLOAT) - **Part of Primary Key** - Angle in degrees (0.0, 0.1, 0.2, ..., 180.0)
- `disc_v_copol` (FLOAT) - Vertical co-polar discrimination
- `disc_v_xpol` (FLOAT) - Vertical cross-polar discrimination
- `disc_h_copol` (FLOAT) - Horizontal co-polar discrimination
- `disc_h_xpol` (FLOAT) - Horizontal cross-polar discrimination

**Storage**: ~1,800 rows per antenna (0.1° resolution for 0-180°)

**Update Frequency**: **Monthly** - Updated when new antennas are added to `sd_ante`/`sd_antd`

**Updated By**: Monthly maintenance job (T-SQL stored procedure)

**Note**: This is a **new table** proposed for the T-SQL port to optimize antenna discrimination lookups.

---

## Table Update Requirements When Adding a New Antenna

### ✅ Tables That MUST Be Updated

When a new antenna is added to the system, the following tables **must** be updated:

#### 1. `main.sd_ante` (Antenna Master Table)

**Action**: **INSERT** one new row

**When**: When adding a new antenna to the master catalog

**How**: Via `SdUpdateAnte.exe` program

**Example**:
```sql
INSERT INTO main.sd_ante (acode, axtype, again, anip, ...)
VALUES ('ANT999', 1, 45.5, 37, ...);
```

---

#### 2. `main.sd_antd` (Antenna Pattern Table)

**Action**: **INSERT** multiple rows (one per pattern point)

**When**: When adding a new antenna to the master catalog

**How**: Via `SdUpdateAnte.exe` program

**Example**:
```sql
-- Insert pattern points for new antenna
INSERT INTO main.sd_antd (acode, antang, dcov, dxpv, dcoh, dxph, dtilt)
VALUES 
    ('ANT999', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    ('ANT999', 1.0, 0.5, 0.3, 0.4, 0.2, 0.0),
    ('ANT999', 2.0, 1.2, 0.8, 1.0, 0.6, 0.0),
    ...
    ('ANT999', 180.0, 50.0, 50.0, 50.0, 50.0, 0.0);
```

**Note**: The number of rows inserted should match `sd_ante.anip` for that antenna.

---

#### 3. `tsip.ant_disc_lookup` (Pre-computed Lookup Table) ⭐ **NEW TABLE**

**Action**: **INSERT** ~1,800 rows (one per 0.1° angle)

**When**: **Monthly** - When new antennas are added to `sd_ante`/`sd_antd`

**How**: Via monthly maintenance job (T-SQL stored procedure)

**Example**:
```sql
-- Monthly maintenance job: Add new antennas to lookup table
INSERT INTO tsip.ant_disc_lookup (acode, angle_deg, disc_v_copol, disc_v_xpol, disc_h_copol, disc_h_xpol)
SELECT 
    a.acode,
    n.angle AS angle_deg,
    -- Interpolate discrimination values at each 0.1° angle
    -- (Complex interpolation logic - see antenna-discrimination-analysis.md)
    ...
FROM (SELECT DISTINCT acode FROM main.sd_ante 
      WHERE acode NOT IN (SELECT DISTINCT acode FROM tsip.ant_disc_lookup)) a
CROSS JOIN (
    SELECT 0.0 AS angle UNION ALL SELECT 0.1 UNION ALL SELECT 0.2 UNION ALL ...
    -- Generate 0.0 to 180.0 in 0.1° increments
) n
-- Interpolate from sd_antd pattern points
...
```

**Maintenance Strategy**:
- **Option 1: Full Rebuild** (simplest)
  ```sql
  TRUNCATE TABLE tsip.ant_disc_lookup;
  -- Then run INSERT statement for all antennas
  ```

- **Option 2: Incremental Update** (more efficient)
  ```sql
  -- Only insert new antennas
  INSERT INTO tsip.ant_disc_lookup (...)
  SELECT ...
  WHERE acode NOT IN (SELECT DISTINCT acode FROM tsip.ant_disc_lookup);
  ```

**Recommended**: **Incremental Update** - Only add new antennas, don't rebuild entire table.

---

### ❌ Tables That Do NOT Need Updates

The following tables **do NOT** need to be updated when a new antenna is added to the master catalog:

#### 1. `{schema}.ft_ante_{project}_{runID}` (PDF Antenna Tables)

**Reason**: These tables are **project-specific** and only contain antennas used in that specific PDF. They are updated when:
- A PDF is created/modified
- A PDF uses the new antenna (then it gets added to that PDF's table)

**Action**: **No action required** when adding antenna to master catalog.

---

#### 2. `{schema}.fe_ante_{project}_{runID}` (PDF Earth Station Antenna Tables)

**Reason**: Same as `ft_ante` - project-specific.

**Action**: **No action required** when adding antenna to master catalog.

---

#### 3. `{schema}.tt_ante_{project}_{runID}` (TSIP-Generated Antenna Pairs)

**Reason**: These tables are **temporary** and are created/dropped for each TSIP run. They are populated during analysis using the current `sd_ante`/`sd_antd` data.

**Action**: **No action required** - TSIP will automatically use the new antenna if it's referenced in a PDF.

---

#### 4. `{schema}.te_ante_{project}_{runID}` (TSIP-Generated Earth Station Antenna Pairs)

**Reason**: Same as `tt_ante` - temporary tables.

**Action**: **No action required** - TSIP will automatically use the new antenna if it's referenced in a PDF.

---

## Update Workflow

### When Adding a New Antenna to Master Catalog

1. **Update Master Tables** (via `SdUpdateAnte.exe`):
   - ✅ Insert into `main.sd_ante` (one row)
   - ✅ Insert into `main.sd_antd` (multiple rows - pattern points)

2. **Update Pre-computed Lookup Table** (via monthly maintenance job):
   - ✅ Insert into `tsip.ant_disc_lookup` (~1,800 rows for new antenna)

3. **No Action Required**:
   - ❌ PDF tables (`ft_ante`, `fe_ante`) - Updated only when PDFs use the antenna
   - ❌ TSIP-generated tables (`tt_ante`, `te_ante`) - Created automatically during analysis

---

## Monthly Maintenance Job

### Purpose

Update `tsip.ant_disc_lookup` with any new antennas added to `main.sd_ante`/`main.sd_antd` since the last update.

### Schedule

Run **once per month** (or whenever new antennas are added to the master catalog).

### Implementation

```sql
CREATE PROCEDURE tsip.UpdateAntennaDiscriminationLookup
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Find new antennas (in sd_ante but not in lookup table)
    DECLARE @NewAntennas TABLE (acode VARCHAR(12));
    
    INSERT INTO @NewAntennas (acode)
    SELECT DISTINCT a.acode
    FROM main.sd_ante a
    WHERE a.acode NOT IN (SELECT DISTINCT acode FROM tsip.ant_disc_lookup)
      AND a.anip > 0;  -- Only antennas with pattern data
    
    -- Generate lookup values for each new antenna
    -- (See antenna-discrimination-analysis.md for complete implementation)
    
    -- For each new antenna, insert ~1,800 rows (0.1° resolution)
    INSERT INTO tsip.ant_disc_lookup (acode, angle_deg, disc_v_copol, disc_v_xpol, disc_h_copol, disc_h_xpol)
    SELECT 
        na.acode,
        angles.angle AS angle_deg,
        -- Interpolate from sd_antd pattern points
        -- (Complex interpolation - see antenna-discrimination-analysis.md)
        ...
    FROM @NewAntennas na
    CROSS JOIN (
        -- Generate angles 0.0 to 180.0 in 0.1° increments
        SELECT 0.0 AS angle
        UNION ALL SELECT 0.1 UNION ALL SELECT 0.2 UNION ALL ...
        -- (Use numbers table or recursive CTE)
    ) angles
    INNER JOIN main.sd_antd ad ON ad.acode = na.acode
    -- Interpolation logic here
    ...
    
    SELECT COUNT(*) AS antennas_added, 
           COUNT(*) * 1800 AS rows_added
    FROM @NewAntennas;
END;
```

### Execution

```sql
-- Run monthly maintenance
EXEC tsip.UpdateAntennaDiscriminationLookup;
```

---

## Summary Table

| Table | Type | Update When? | Updated By | Action Required |
|-------|------|--------------|------------|----------------|
| `main.sd_ante` | Master | New antenna added | `SdUpdateAnte.exe` | ✅ **INSERT** 1 row |
| `main.sd_antd` | Master | New antenna added | `SdUpdateAnte.exe` | ✅ **INSERT** N rows (pattern points) |
| `tsip.ant_disc_lookup` | New (T-SQL) | Monthly | Maintenance job | ✅ **INSERT** ~1,800 rows |
| `{schema}.ft_ante_{...}` | PDF | PDF created/modified | PDF import | ❌ No action |
| `{schema}.fe_ante_{...}` | PDF | PDF created/modified | PDF import | ❌ No action |
| `{schema}.tt_ante_{...}` | TSIP temp | Per TSIP run | `TpRunTsip.exe` | ❌ No action |
| `{schema}.te_ante_{...}` | TSIP temp | Per TSIP run | `TpRunTsip.exe` | ❌ No action |

---

## Key Points

1. **Master Tables** (`sd_ante`, `sd_antd`): Updated **extremely rarely** (once per month) via `SdUpdateAnte.exe`

2. **Pre-computed Lookup** (`tsip.ant_disc_lookup`): Updated **monthly** via maintenance job to include any new antennas

3. **PDF Tables** (`ft_ante`, `fe_ante`): Updated only when PDFs are created/modified, not when master catalog is updated

4. **TSIP Tables** (`tt_ante`, `te_ante`): Temporary tables created during analysis - no manual updates needed

5. **Monthly Maintenance**: Run `tsip.UpdateAntennaDiscriminationLookup` to keep pre-computed lookup table in sync with master catalog

---

*Last updated: January 2026*

