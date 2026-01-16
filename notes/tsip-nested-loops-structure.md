# TSIP 6-Level Nested Loop Structure

This document provides a detailed analysis of the 6-level nested loop structure used in TSIP interference analysis processing.

---

## Overview

The TSIP processing architecture uses a **6-level nested loop structure** that processes interference cases incrementally, from high-level site pairs down to individual channel pairs. This hierarchical approach allows for efficient culling at each level, dramatically reducing the number of calculations performed.

### Level Names (for easy reference)

For easier discussion and reference, each level has been assigned a name:

| Level | Name | Short Name | Description |
|-------|------|------------|-------------|
| **Level 1** | **Site Enumeration** | **Site Loop** | Iterate through proposed sites |
| **Level 2** | **Link Enumeration** | **Link Loop** | Iterate through links in each proposed site |
| **Level 3** | **Victim Enumeration** | **Victim Loop** | Iterate through victim sites (from SQL query) |
| **Level 4** | **Victim Link Enumeration** | **Victim Link Loop** | Iterate through links in each victim site |
| **Level 5** | **Antenna Pair Processing** | **Antenna Loop** | Process antenna pairs (proposed × victim) |
| **Level 6** | **Channel Pair Processing** | **Channel Loop** | Process channel pairs and calculate interference |

**Usage in documentation**: We'll use both the full names and short names interchangeably. In code comments and discussions, the short names are preferred for brevity.

---

## Loop Hierarchy Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 1: Site Loop (Site Enumeration)                           │
│   └─> For each proposed site in PDF                             │
│       │                                                          │
│       └─> ┌──────────────────────────────────────────────────┐ │
│           │ LEVEL 2: Link Loop (Link Enumeration)             │ │
│           │   └─> For each link in proposed site              │ │
│           │       │                                            │ │
│           │       └─> ┌────────────────────────────────────┐ │ │
│           │           │ LEVEL 3: Victim Loop                │ │ │
│           │           │   (Victim Enumeration)              │ │ │
│           │           │   └─> For each victim site (SQL)     │ │ │
│           │           │       │                              │ │ │
│           │           │       └─> ┌────────────────────────┐ │ │ │
│           │           │           │ LEVEL 4: Victim Link    │ │ │ │
│           │           │           │   Loop                  │ │ │ │
│           │           │           │   └─> For each link    │ │ │ │
│           │           │           │       │                │ │ │ │
│           │           │           │       └─> ┌──────────┐ │ │ │ │
│           │           │           │           │ LEVEL 5: │ │ │ │ │
│           │           │           │           │ Antenna  │ │ │ │ │
│           │           │           │           │ Loop     │ │ │ │ │
│           │           │           │           │   └─>    │ │ │ │ │
│           │           │           │           │   For    │ │ │ │ │
│           │           │           │           │   each   │ │ │ │ │
│           │           │           │           │   pair   │ │ │ │ │
│           │           │           │           │          │ │ │ │ │
│           │           │           │           │   └─> ┌──┐ │ │ │ │ │
│           │           │           │           │      │L6│ │ │ │ │ │
│           │           │           │           │      │Ch│ │ │ │ │ │
│           │           │           │           │      │an│ │ │ │ │ │
│           │           │           │           │      │ne│ │ │ │ │ │
│           │           │           │           │      │ls│ │ │ │ │ │
│           │           │           │           │      └──┘ │ │ │ │ │
│           │           │           │           └──────────┘ │ │ │
│           │           │           └────────────────────────┘ │ │
│           │           └────────────────────────────────────┘ │ │
│           └──────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Level-by-Level Breakdown

### Level 1: Site Enumeration (Site Loop)

**Purpose**: Iterate through all proposed sites (new or modified radio systems)

**Location**: `TtBuildSH.cs` → `TtCullNCreate()` (lines 491-565)

**Code Structure**:
```csharp
rc = FtUtils.FtEnumSite("cmd != 'D'", tpParmStruct.proname, ref cCallFound);

while (rc == 0)
{
    // Get the full site structure
    rc = FtUtils.FtGetSiteWN(cCallFound, out pSite, 3, tpParmStruct.proname, out pSiteNulls);
    
    if (rc != 0)
    {
        // Error handling
        return -25;
    }
    
    // Build links for this site
    nNumLinks = FtUtils.FtMakeLinks(pSite, out pLinks);
    
    if (nNumLinks < 0)
    {
        // Error handling
        return Constant.FAILURE;
    }
    
    // Process each link (Level 2)
    for (nInd = 0; nInd < nNumLinks; nInd++)
    {
        // ... Level 2 processing ...
    }
    
    // Free memory
    FtUtils.FtFreeLinks(pLinks, nNumLinks);
    
    // Get next site
    rc = FtUtils.FtEnumSite("cmd != 'D'", tpParmStruct.proname, ref cCallFound);
}
```

**Key Operations**:
- Enumerate proposed sites (skip deleted: `cmd != 'D'`)
- Load full site structure (`FtGetSiteWN`)
- Build antenna links (`FtMakeLinks`)
- Process each link
- Free memory after processing

**State Maintained**:
- `pSite`: Full site structure (`FtSiteStr`)
- `pSiteNulls`: Null indicators for site fields
- `pLinks`: Array of link structures (`TLink[]`)
- `nNumLinks`: Number of links in this site

**Data Structures**:
- **`FtSiteStr`**: Contains site information (call signs, location, operator, etc.) plus arrays of antennas and channels
- **`TLink[]`**: Array of link structures, each containing:
  - `call1`, `call2`: The two sites in the link
  - `bndcde`: Frequency band code
  - `nNumAnts`: Number of antennas in this link
  - `aAnts[]`: Array of antenna indices

---

### Level 2: Link Enumeration (Link Loop)

**Purpose**: Process each radio link in the proposed site

**Location**: `TtBuildSH.cs` → `TtCullNCreate()` (lines 518-558)

**Code Structure**:
```csharp
// Go through the proposed site's links
for (nInd = 0; nInd < nNumLinks; nInd++)
{
    // Generate the rough cull SQL for this link
    GenRoughCull(tpParmStruct, pSite, pLinks[nInd], isMDB,
        codesSelection, out sqlCommand);
    
    // Process this link against the environment
    rc = Vic2DimTable(tpParmStruct,
                      pSite,
                      pSiteNulls,
                      pLinks,
                      nInd,
                      tpParmStruct.envname,
                      tpParmStruct.proname,
                      isMDB,
                      sqlCommand,
                      ref numCases);
    
    if (rc != Constant.SUCCESS)
    {
        // Error handling or continue
        continue;
    }
}
```

**Key Operations**:
- Generate SQL WHERE clause for rough culling (`GenRoughCull`)
- Pass to `Vic2DimTable` for victim site processing (Level 3)

**Rough Cull SQL Generation**:
The `GenRoughCull()` function creates a SQL WHERE clause that filters environment sites based on:
- **Distance**: Uses `tsip.keyhole_hs()` function to check coordination distance
- **Band Adjacency**: Filters by frequency bands that are same or adjacent
- **Operator Codes**: If user specified operator codes or call signs

**Example Generated SQL**:
```sql
(tsip.keyhole_hs(123456, -789012, latit, longit, 45.5, 100.0) <= 2) 
AND (bandwd1 & 0x0000000f != 0 or bandwd2 & 0x00000003 != 0)
AND (oper = 'TELCO1' or oper = 'TELCO2')
AND cmd != 'D'
```

**State Maintained**:
- `sqlCommand`: Generated SQL WHERE clause
- `pLinks[nInd]`: Current link being processed
- `numCases`: Running count of interference cases found

---

### Level 3: Victim Enumeration (Victim Loop)

**Purpose**: Process each victim site that passes the rough cull

**Location**: `TtBuildSH.cs` → `Vic2DimTable()` (lines 911-1109)

**Code Structure**:
```csharp
cCallFound = "";

while (true)
{
    // Enumerate victim sites using the SQL WHERE clause
    nInd = TpMdbPdfGet.TtEnumSite(sqlCommand, isMDB ? null : envName, ref cCallFound);
    
    if (nInd != 0)
    {
        // No more sites
        break;
    }
    
    // Get the full victim site structure
    nInd = TpMdbPdfGet.TtFullSiteGet(cCallFound, envName, isMDB, out pVicSite, out pVicSiteNulls);
    if (nInd != 0)
    {
        // Error handling
        break;
    }
    
    // Geometry cull (distance, azimuth, province)
    if (IntVicSiteCull(tpParmStruct, ftIntSite.stSite, pVicSite.stSite.oper,
        pVicSite.stSite.latit / 100.0, pVicSite.stSite.longit / 100.0,
        pVicSite.stSite.prov, out dist, out azimIV, out azimVI) != Constant.SUCCESS)
    {
        continue;  // Skip this victim site
    }
    
    // Get links for victim site
    nNumVicLinks = FtUtils.FtMakeLinks(pVicSite, out pVicLinks);
    if (nNumVicLinks < 0)
    {
        continue;  // Error making links
    }
    
    // Process each victim link (Level 4)
    for (nLink = 0; nLink < nNumVicLinks; nLink++)
    {
        // ... Level 4 processing ...
    }
}
```

**Key Operations**:
- Execute SQL query to enumerate victim sites
- Load full victim site structure
- Apply geometry cull (`IntVicSiteCull`)
- Build victim site links
- Process each victim link (Level 4)

**Geometry Cull Criteria** (`IntVicSiteCull`):
- Distance between sites
- Azimuth calculations
- Province/region checks
- Returns: `dist`, `azimIV` (interferer to victim), `azimVI` (victim to interferer)

**State Maintained**:
- `pVicSite`: Full victim site structure
- `pVicSiteNulls`: Null indicators
- `pVicLinks`: Array of victim links
- `nNumVicLinks`: Number of victim links
- `dist`, `azimIV`, `azimVI`: Geometry calculations

---

### Level 4: Victim Link Enumeration (Victim Link Loop)

**Purpose**: Process each link in the victim site

**Location**: `TtBuildSH.cs` → `Vic2DimTable()` (lines 969-1109)

**Code Structure**:
```csharp
// Go through the links in the victim site
for (nLink = 0; nLink < nNumVicLinks; nLink++)
{
    // Check band adjacency
    if (!Suutils.SuIsBandAdjacent(pLinks[nLinkNum].bndcde, pVicLinks[nLink].bndcde))
    {
        continue;  // Bands not adjacent, skip
    }
    
    vicCall2 = pVicLinks[nLink].call2;
    vicBndCode = pVicLinks[nLink].bndcde;
    
    // Site pair cull
    if (SitePairsCull(tpParmStruct.envtype, ftIntSite.stSite.call1,
        ftIntSite.stAntsPtr[nAntNum].call2, vicCall1, vicCall2) != Constant.SUCCESS)
    {
        continue;  // Invalid site pair combination
    }
    
    // Get remote site data
    rc = SetRemData(vicCall2, envName, isMDB, out vicSite2, out vicSite2Nulls);
    if (rc != 0)
    {
        continue;  // Remote site not found
    }
    
    // Create antenna pairs (Level 5)
    rc = CreateAnteSHTable(
        ref tpParmStruct,
        ref proSiteStruct,
        ref proSiteNulls,
        ref envSiteStruct,
        ref envSiteNulls,
        // ... many parameters ...
        out numProAnte,
        out numEnvAnte,
        ref numCases
    );
}
```

**Key Operations**:
- Check band adjacency between proposed and victim links
- Apply site pair cull (`SitePairsCull`)
- Get remote site data (`SetRemData`)
- Call `CreateAnteSHTable` for antenna pair processing (Level 5)

**Culling Criteria**:
- **Band Adjacency**: Links must operate in same or adjacent frequency bands
- **Site Pair Validity**: Certain site combinations are invalid (e.g., same site, invalid topology)

**State Maintained**:
- `vicCall2`: Remote site call sign
- `vicBndCode`: Victim link band code
- `vicSite2`: Remote site structure
- `proSiteStruct`, `envSiteStruct`: Site pair structures for antenna processing

---

### Level 5: Antenna Pair Processing (Antenna Loop)

**Purpose**: Process all antenna combinations for the current link pair

**Location**: `TtBuildSH.cs` → `CreateAnteSHTable()` (lines 1615-1976)

**Code Structure**:
```csharp
// Go through proposed antennas in link
for (nProInd = 0; nProInd < pProLink.nNumAnts; nProInd++)
{
    // Get proposed antenna index
    nProAntNum = pProLink.aAnts[nProInd];
    pProAnte = pProSite.stAntsPtr[nProAntNum];
    pProAnteNulls = pProSiteNulls.anAntsNullPtr[nProAntNum];
    
    // Extract proposed antenna data
    proAnum = pProAnte.anum;
    proAcode = pProAnte.acode;
    proGain = pProAnte.tgain;
    proAz = pProAnte.azmth;
    proEl = pProAnte.elvtn;
    // ... more fields ...
    
    // Go through environment antennas in link
    for (nEnvInd = 0; nEnvInd < pEnvLink.nNumAnts; nEnvInd++)
    {
        // Get environment antenna index
        nEnvAntNum = pEnvLink.aAnts[nEnvInd];
        pEnvAnte = pEnvSite.stAntsPtr[nEnvAntNum];
        pEnvAnteNulls = pEnvSiteNulls.anAntsNullPtr[nEnvAntNum];
        
        // Extract environment antenna data
        envAnum = pEnvAnte.anum;
        envAcode = pEnvAnte.acode;
        envGain = pEnvAnte.tgain;
        envAz = pEnvAnte.azmth;
        envEl = pEnvAnte.elvtn;
        // ... more fields ...
        
        // Calculate off-axis angles
        // (Complex logic for true azimuth/elevation vs hop azimuth/elevation)
        
        // Calculate discrimination angles
        AxSub2.AxDistan(...);
        AxSub3.AxElev(...);
        proDiscAng = GenUtil.IncAngle(proAntAz, proAntEl, dBearIV, dElevIV);
        envDiscAng = GenUtil.IncAngle(envAntAz, envAntEl, dBearVI, dElevVI);
        
        // Set topology
        SetTopology(...);
        
        // Calculate antenna discrimination and create antenna records
        rc = SetBothAntes(...);
        
        if (rc != Constant.SUCCESS)
        {
            continue;
        }
        
        // Create channel pairs (Level 6)
        rc = CreateChanSHTable(
            tpParmStruct,
            proSiteStruct,
            proSiteNulls,
            // ... many parameters ...
            ref numProChan,
            ref numEnvChan,
            ref numCases,
            envMBnd,
            proMBnd,
            envPatLoss,
            proPatLoss
        );
    }
}
```

**Key Operations**:
- Iterate through all proposed antennas × all environment antennas
- Extract antenna data (gain, azimuth, elevation, codes)
- Calculate off-axis angles (true vs hop azimuth/elevation)
- Calculate discrimination angles (3D vector math)
- Set antenna topology
- Calculate antenna discrimination values
- Create antenna pair records in `TT_ANTE` table
- Call `CreateChanSHTable` for channel processing (Level 6)

**Off-Axis Angle Processing**:
The code handles two cases:
1. **True Azimuth/Elevation**: If antenna has explicit off-axis angle (`offazm = 'Y'` or 'T'), use `tazmth` and `telvtn`
2. **Hop Azimuth/Elevation**: Otherwise, use the hop's azimuth/elevation (`azmth`, `elvtn`)

**Discrimination Angle Calculation**:
- Uses 3D vector math to calculate angle between antenna boresight and interferer/victim direction
- Accounts for elevation angles
- Handles edge cases (colocated antennas → 90°)

**State Maintained**:
- `proAnum`, `proAcode`, `proGain`, etc.: Proposed antenna data
- `envAnum`, `envAcode`, `envGain`, etc.: Environment antenna data
- `proDiscAng`, `envDiscAng`: Calculated discrimination angles
- `proAnteStruct`, `envAnteStruct`: Antenna pair structures

---

### Level 6: Channel Pair Processing (Channel Loop)

**Purpose**: Perform actual interference calculations for each channel pair

**Location**: `TtBuildSH.cs` → `CreateChanSHTable()` (lines 2200-2800+)

**Code Structure**:
```csharp
// Go through proposed channels
for (nProChan = 0; nProChan < pProLink.nNumChans; nProChan++)
{
    pProChan = pProSite.stChansPtr[nProChan];
    
    // Go through environment channels
    for (nEnvChan = 0; nEnvChan < pEnvLink.nNumChans; nEnvChan++)
    {
        pEnvChan = pEnvSite.stChansPtr[nEnvChan];
        
        // Frequency separation cull
        fsepMid = Abs(pProChan.freqtx - pEnvChan.freqrx);
        if (fsepMid > fsepMax)
        {
            continue;  // Frequency separation too large
        }
        
        // Create channel structure
        chanStruct.intcall1 = pProChan.call1;
        chanStruct.intcall2 = pProChan.call2;
        chanStruct.intfreqtx = pProChan.freqtx;
        chanStruct.vicfreqrx = pEnvChan.freqrx;
        // ... more fields ...
        
        // Perform channel calculations
        rc = TtCalcs.TtChanCalcs(
            tpParmStruct,
            ref chanStruct,
            ref chanNulls,
            anteStruct,
            anteNulls,
            siteStruct,
            siteNulls,
            intPrintMsg,
            vicPrintMsg
        );
        
        if (rc != Constant.SUCCESS)
        {
            continue;
        }
        
        // Insert channel record into TT_CHAN table
        rc = TtDynChan.TtChanInsert(tableName, ref chanStruct, ref chanNulls);
        
        numCases++;
    }
}
```

**Key Operations**:
- Iterate through all proposed channels × all environment channels
- Calculate frequency separation
- Apply frequency separation cull
- Create channel structure
- Call `TtChanCalcs()` for core interference calculations
- Insert channel record into `TT_CHAN` table

**Core Calculations** (`TtChanCalcs`):
1. **Frequency Separation**: `|freqtx - freqrx|`
2. **Path Loss**: Free space or over-horizon
3. **Antenna Discrimination**: Already calculated at Level 5
4. **EIRP Calculation**: Transmit power + antenna gain
5. **CTX Lookup**: Required C/I from protection criteria table
6. **Margin Calculation**: `resti = Calculated_C/I - Required_C/I`

**Result Fields** (in `TT_CHAN` table):
- `freqsep`: Frequency separation (MHz)
- `patloss`: Path loss (dB)
- `calcico`: Calculated C/I co-polar (dB)
- `calcixp`: Calculated C/I cross-polar (dB)
- `reqdcalc`: Required C/I from CTX table (dB)
- `resti`: **Interference margin** (dB) - Primary result
- `resti80`, `resti99`: Margins at 80% and 99% time (over-horizon)
- `ohresult`: Over-horizon calculation status

**State Maintained**:
- `chanStruct`: Channel pair structure
- `chanNulls`: Null indicators
- `numCases`: Running count of interference cases

---

## Data Flow Through Levels

```
┌─────────────────────────────────────────────────────────────┐
│ Input: Proposed PDF + Environment (MDB/PDF)                  │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 1: Site Loop (Site Enumeration)                       │
│   • Enumerate sites                                          │
│   • Load site structure                                      │
│   • Build links                                              │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 2: Link Loop (Link Enumeration)                        │
│   • Generate rough cull SQL                                 │
│   • Filter by distance, band, operator                      │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 3: Victim Loop (Victim Enumeration)                    │
│   • Execute SQL query                                        │
│   • Load victim site                                         │
│   • Geometry cull (distance, azimuth)                       │
│   • Build victim links                                       │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 4: Victim Link Loop (Victim Link Enumeration)          │
│   • Band adjacency check                                     │
│   • Site pair cull                                           │
│   • Get remote site data                                     │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 5: Antenna Loop (Antenna Pair Processing)              │
│   • Calculate off-axis angles                                │
│   • Calculate discrimination angles                         │
│   • Lookup antenna discrimination                            │
│   • Insert into TT_ANTE                                     │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 6: Channel Loop (Channel Pair Processing)              │
│   • Frequency separation                                    │
│   • Path loss calculation                                   │
│   • C/I calculation                                          │
│   • Margin calculation                                      │
│   • Insert into TT_CHAN                                     │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Output: TT_SITE, TT_ANTE, TT_CHAN tables                    │
│   • Interference margin (resti)                              │
│   • Positive = OK, Negative = Potential Interference       │
└─────────────────────────────────────────────────────────────┘
```

---

## Link Structure Details

### What is a Link?

A **link** represents a point-to-point radio connection between two sites. It groups antennas that operate together on the same hop.

**Link Properties**:
- `call1`: First site call sign
- `call2`: Second site call sign (remote end)
- `bndcde`: Frequency band code
- `nNumAnts`: Number of antennas in this link
- `aAnts[]`: Array of antenna indices

### How Links Are Built

**Function**: `FtUtils.FtMakeLinks()`

**Process**:
1. Scan all antennas at a site
2. Group antennas by `(call2, bndcde)` - same remote site and band
3. Create `TLink` structure for each unique `(call2, bndcde)` combination
4. Store antenna indices in `aAnts[]` array

**Example**:
```
Site "ABC123" has antennas:
  Antenna 1: call2="XYZ789", bndcde="6G"
  Antenna 2: call2="XYZ789", bndcde="6G"
  Antenna 3: call2="DEF456", bndcde="11G"
  Antenna 4: call2="GHI789", bndcde="18G"
  Antenna 5: call2="GHI789", bndcde="18G"
  Antenna 6: call2="GHI789", bndcde="18G"

Results in 3 links:
  Link 1: ABC123 → XYZ789, Band 6G,  Antennas [1, 2]
  Link 2: ABC123 → DEF456, Band 11G, Antennas [3]
  Link 3: ABC123 → GHI789, Band 18G, Antennas [4, 5, 6]
```

### Why Links Matter

1. **Efficiency**: Process antennas in logical groups
2. **Culling**: Can cull entire links based on band adjacency
3. **Context**: Links provide context for antenna operations
4. **Remote Site**: Links identify the remote site for geometry calculations

---

## State Management at Each Level

### Level 1 State
```csharp
FtSiteStr pSite;           // Full proposed site structure
SQLLEN[] pSiteNulls;       // Null indicators
TLink[] pLinks;            // Array of links
int nNumLinks;             // Number of links
string cCallFound;         // Current call sign
int rc;                    // Return code
```

### Level 2 State
```csharp
string sqlCommand;         // Generated SQL WHERE clause
TLink pLinks[nInd];       // Current link
int numCases;             // Running count
```

### Level 3 State
```csharp
FtSiteStr pVicSite;       // Full victim site structure
SQLLEN[] pVicSiteNulls;   // Null indicators
TLink[] pVicLinks;        // Array of victim links
int nNumVicLinks;         // Number of victim links
double dist;              // Distance between sites
double azimIV;             // Azimuth: interferer → victim
double azimVI;             // Azimuth: victim → interferer
```

### Level 4 State
```csharp
string vicCall2;           // Remote site call sign
string vicBndCode;         // Victim link band code
FtSiteStr vicSite2;        // Remote site structure
TtSite proSiteStruct;      // Proposed site pair structure
TtSite envSiteStruct;      // Environment site pair structure
```

### Level 5 State
```csharp
FtAnte pProAnte;          // Proposed antenna
FtAnte pEnvAnte;          // Environment antenna
double proDiscAng;        // Proposed discrimination angle
double envDiscAng;        // Environment discrimination angle
TtAnte proAnteStruct;     // Proposed antenna structure
TtAnte envAnteStruct;     // Environment antenna structure
```

### Level 6 State
```csharp
TtChan chanStruct;        // Channel pair structure
SQLLEN[] chanNulls;       // Null indicators
int numCases;             // Running count
```

---

## Culling Efficiency

The multi-level culling dramatically reduces calculations:

| Level | Cull Method | Typical Reduction | Example |
|-------|-------------|-------------------|---------|
| 1 | None (enumerate all) | 1× | 100 proposed sites |
| 2 | None (process all links) | 1× | 500 links total |
| 3 | Rough cull (SQL) | ~1000× | 1,000,000 → 1,000 sites |
| 4 | Geometry cull | ~10× | 1,000 → 100 site pairs |
| 5 | Band adjacency | ~2× | 100 → 50 link pairs |
| 6 | Frequency separation | ~2× | 50 → 25 channel pairs |

**Total Efficiency**: Roughly **1,200,000× reduction** from all possible combinations to final channel pairs.

---

## Memory Management

**Key Strategy**: Process incrementally, free memory after each site

```csharp
// Level 1: After processing each site
FtUtils.FtFreeLinks(pLinks, nNumLinks);  // Free link memory

// Sites are loaded one at a time, not all at once
// This keeps memory usage low even for large analyses
```

**Memory Footprint**:
- **Per Site**: ~10-50 KB (site structure + antennas + channels)
- **Total**: Processes one site at a time, so total memory is constant
- **Links**: Freed after each site is processed

---

## Error Handling

**Strategy**: Continue processing on non-fatal errors, return on fatal errors

```csharp
// Example: Level 3
if (IntVicSiteCull(...) != Constant.SUCCESS)
{
    continue;  // Skip this victim, continue with next
}

// Example: Level 2
if (rc != Constant.SUCCESS)
{
    if (rc == Constant.CONT_PROCESSING)
    {
        continue;  // Non-fatal, continue
    }
    return rc;  // Fatal error, exit
}
```

**Error Types**:
- **Fatal**: Cannot continue (e.g., database error, memory error)
- **Non-Fatal**: Skip current item, continue (e.g., site not found, invalid combination)

---

## Performance Characteristics

**Processing Time Distribution** (typical):
- Level 1-2: 5% (site enumeration, link building)
- Level 3: 10% (SQL queries, site loading)
- Level 4: 5% (link processing, culling)
- Level 5: 30% (antenna calculations, discrimination lookups)
- Level 6: 50% (channel calculations, path loss, C/I calculations)

**Bottlenecks**:
1. **Level 6**: Channel calculations (most time-consuming)
2. **Level 5**: Antenna discrimination lookups (many function calls)
3. **Level 3**: SQL queries (database I/O)

**Optimization Opportunities**:
- Level 3: Optimize SQL queries, add indexes
- Level 5: Cache antenna discrimination lookups
- Level 6: Optimize path loss calculations, parallelize if possible

---

## Source Code References

- **Level 1-2**: `TpRunTsip\TtBuildSH.cs` → `TtCullNCreate()` (lines 485-579)
- **Level 3-4**: `TpRunTsip\TtBuildSH.cs` → `Vic2DimTable()` (lines 819-1109)
- **Level 5**: `TpRunTsip\TtBuildSH.cs` → `CreateAnteSHTable()` (lines 1615-1976)
- **Level 6**: `TpRunTsip\TtBuildSH.cs` → `CreateChanSHTable()` (lines 2200-2800+)
- **Link Building**: `_Utillib\FtUtils.cs` → `FtMakeLinks()`
- **Channel Calculations**: `TpRunTsip\TtCalcs.cs` → `TtChanCalcs()`
- **Antenna Calculations**: `TpRunTsip\TtCalcs.cs` → `TtAnteCalcs()`

---

## T-SQL Cursor Type Recommendations

Given that:
- **Data is static** (doesn't change during processing)
- **Performance is not critical** (users can wait up to an hour)

Here are the recommended cursor types for each level:

### Level 1: Site Loop (Site Enumeration)

**Recommended**: `FAST_FORWARD` or `STATIC`

```sql
DECLARE curProposedSites CURSOR 
    FAST_FORWARD LOCAL
    FOR
    SELECT call1, call2, latit, longit, grnd, oper, prov
    FROM proposed_sites
    WHERE cmd != 'D'
    ORDER BY call1;
```

**Rationale**:
- Forward-only processing (no need to scroll back)
- Read-only (no updates needed)
- `FAST_FORWARD` is fastest for forward-only reads
- `STATIC` alternative: Creates snapshot in tempdb, allows scrolling if needed for progress tracking

**Alternative (if progress tracking needed)**:
```sql
DECLARE curProposedSites CURSOR 
    STATIC LOCAL
    FOR
    SELECT call1, call2, latit, longit, grnd, oper, prov
    FROM proposed_sites
    WHERE cmd != 'D'
    ORDER BY call1;
```

---

### Level 2: Link Loop (Link Enumeration)

**Recommended**: `FAST_FORWARD`

```sql
DECLARE curProposedLinks CURSOR 
    FAST_FORWARD LOCAL
    FOR
    SELECT DISTINCT call1, call2, bndcde
    FROM proposed_antennas
    WHERE call1 = @proCall1
      AND cmd != 'D';
```

**Rationale**:
- Small result set (typically 1-10 links per site)
- Forward-only processing
- No need for scrolling
- `FAST_FORWARD` provides best performance

---

### Level 3: Victim Loop (Victim Enumeration)

**Recommended**: `FAST_FORWARD` or `STATIC`

```sql
DECLARE curVictimSites CURSOR 
    FAST_FORWARD LOCAL
    FOR
    EXEC sp_executesql @sqlCommand;
```

**Rationale**:
- Result set filtered by rough cull SQL (typically 100-10,000 sites)
- Forward-only processing
- `FAST_FORWARD` is optimal for forward-only reads
- `STATIC` alternative: If you need to know total count upfront for progress tracking

**Alternative (if progress tracking needed)**:
```sql
-- First, get count for progress tracking
SELECT @totalVictimSites = COUNT(*)
FROM environment_sites
WHERE tsip.keyhole_hs(...) <= 2;

-- Then use STATIC cursor
DECLARE curVictimSites CURSOR 
    STATIC LOCAL
    FOR
    EXEC sp_executesql @sqlCommand;
```

---

### Level 4: Victim Link Loop (Victim Link Enumeration)

**Recommended**: `FAST_FORWARD`

```sql
DECLARE curVictimLinks CURSOR 
    FAST_FORWARD LOCAL
    FOR
    SELECT DISTINCT call1, call2, bndcde
    FROM ft_ante
    WHERE call1 = @vicCall1
      AND cmd != 'D'
      AND tsip.SuIsBandAdjacent(@proBndcde, bndcde) = 1;
```

**Rationale**:
- Small result set (typically 1-10 links per site)
- Forward-only processing
- No need for scrolling
- `FAST_FORWARD` provides best performance

---

### Level 5: Antenna Loop (Antenna Pair Processing)

**Recommended**: **Set-Based (Not Cursor)** or `FAST_FORWARD` if cursor needed

**Preferred Approach (Set-Based)**:
```sql
-- Use set-based for performance
INSERT INTO tt_ante (...)
SELECT 
    @proLinkCall1, @proLinkCall2, @proBndcde,
    @vicLinkCall1, @vicLinkCall2, @vicBndcde,
    tsip.GetAntennaDiscrimination(pa.acode, @offAxis, 'H'),
    ...
FROM ft_ante pa
CROSS JOIN ft_ante ea
WHERE pa.call1 = @proLinkCall1
  AND pa.call2 = @proLinkCall2
  AND pa.bndcde = @proBndcde
  AND ea.call1 = @vicLinkCall1
  AND ea.call2 = @vicLinkCall2
  AND ea.bndcde = @vicBndcde;
```

**If Cursor Needed**:
```sql
DECLARE curProposedAntennas CURSOR 
    FAST_FORWARD LOCAL
    FOR
    SELECT anum, acode, tgain, azmth, elvtn, ...
    FROM ft_ante
    WHERE call1 = @proLinkCall1
      AND call2 = @proLinkCall2
      AND bndcde = @proBndcde
      AND cmd != 'D';
```

**Rationale**:
- **Set-based is preferred**: Can process all antenna pairs in one query, leverages SQL Server optimization
- **If cursor needed**: `FAST_FORWARD` for forward-only processing
- Typically 1-10 antennas per link, so cursor overhead is minimal if needed

---

### Level 6: Channel Loop (Channel Pair Processing)

**Recommended**: **Set-Based (Not Cursor)** or `FAST_FORWARD` if cursor needed

**Preferred Approach (Set-Based)**:
```sql
-- Use set-based for performance
INSERT INTO tt_chan (...)
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
```

**If Cursor Needed**:
```sql
DECLARE curProposedChannels CURSOR 
    FAST_FORWARD LOCAL
    FOR
    SELECT chid, freqtx, freqrx, pwrtx, pwrrx, ...
    FROM ft_chan
    WHERE call1 = @proLinkCall1
      AND call2 = @proLinkCall2
      AND bndcde = @proBndcde
      AND cmd != 'D';
```

**Rationale**:
- **Set-based is strongly preferred**: This is where most calculations happen, set-based can parallelize
- **If cursor needed**: `FAST_FORWARD` for forward-only processing
- Typically 1-100 channels per link, so set-based is much more efficient

---

## Summary Table

| Level | Name | Recommended Cursor Type | Alternative | Rationale |
|-------|------|------------------------|-------------|-----------|
| **Level 1** | **Site Loop** | `FAST_FORWARD` | `STATIC` (if progress tracking) | Forward-only, read-only, fastest |
| **Level 2** | **Link Loop** | `FAST_FORWARD` | - | Small set, forward-only |
| **Level 3** | **Victim Loop** | `FAST_FORWARD` | `STATIC` (if progress tracking) | Forward-only, filtered result set |
| **Level 4** | **Victim Link Loop** | `FAST_FORWARD` | - | Small set, forward-only |
| **Level 5** | **Antenna Loop** | **Set-Based** | `FAST_FORWARD` (if cursor) | Prefer set-based for performance |
| **Level 6** | **Channel Loop** | **Set-Based** | `FAST_FORWARD` (if cursor) | Strongly prefer set-based, most calculations |

---

## Complete Implementation Example

Here's how the complete procedure would look with recommended cursor types:

```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
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
    
    -- Level 1: Site Loop - FAST_FORWARD
    DECLARE curProposedSites CURSOR 
        FAST_FORWARD LOCAL
        FOR
        SELECT s.call1, s.latit, s.longit, s.grnd,
               a.azmth
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
        -- Level 2: Link Loop - FAST_FORWARD
        DECLARE curProposedLinks CURSOR 
            FAST_FORWARD LOCAL
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
            
            -- Level 3: Victim Loop - FAST_FORWARD
            DECLARE @vicCall1 VARCHAR(9);
            DECLARE curVictimSites CURSOR 
                FAST_FORWARD LOCAL
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
                    IF @dist <= @coordDist OR 
                       (tsip.WithinKeyhole(@proCall1, @vicCall1) = 1 AND @dist <= 2 * @coordDist)
                    BEGIN
                        -- Level 4: Victim Link Loop - FAST_FORWARD
                        DECLARE curVictimLinks CURSOR 
                            FAST_FORWARD LOCAL
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
                            -- Level 5: Antenna Loop - SET-BASED (preferred)
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
                            
                            -- Level 6: Channel Loop - SET-BASED (preferred)
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

---

## Why FAST_FORWARD for Most Levels?

**FAST_FORWARD** is the optimal choice because:

1. **Combines optimizations**: It's shorthand for `FORWARD_ONLY READ_ONLY` with additional optimizations
2. **No tempdb overhead**: Unlike `STATIC`, it doesn't create a snapshot in tempdb
3. **Forward-only processing**: Matches the C# code's processing pattern exactly
4. **Read-only**: Data is static, so no updates needed
5. **Best performance**: Even though performance isn't critical, it's still the fastest option

**When to use STATIC instead**:
- If you need to know the total count upfront for progress tracking
- If you need to scroll back (rarely needed)
- If you want a guaranteed snapshot (not needed since data is static)

---

## Performance Considerations

Given that users can wait up to an hour:

- **FAST_FORWARD cursors** are still the best choice (no reason to use slower options)
- **Set-based for Levels 5-6** is still recommended (even with relaxed performance, it's cleaner and can still be faster)
- **STATIC cursors** could be used if progress tracking is important, but they add tempdb overhead

**Recommendation**: Use `FAST_FORWARD` for all cursor levels (1-4), and set-based for levels 5-6. This provides the best balance of simplicity and performance, even with relaxed time constraints.

---

*Last updated: January 2026*

