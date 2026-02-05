# MICS# Database Tables Reference

This document describes the SQL Server tables generated and used by **TpRunTsip** (the TSIP interference analysis engine).

---

## Table Naming Convention

Tables follow a dynamic naming pattern:

```
{schema}.{prefix}_{tableName}_{runID}_{suffix}
```

- **schema**: User's database schema (e.g., `fcsa`)
- **prefix**: Table type identifier (e.g., `tt_`, `te_`, `ft_`, `fe_`)
- **tableName**: Project/PDF name
- **runID**: Run identifier
- **suffix**: Table category (`site`, `ante`, `chan`, `parm`, etc.)

---

## TSIP-Generated Tables (Working Tables)

These tables are **created dynamically** when TpRunTsip executes an interference analysis run.

### TS-TS (Terrestrial-to-Terrestrial) Tables — Prefix: `tt_`

| Table Type | Constant | Purpose |
|------------|----------|---------|
| TT_PARM | 400 | Run parameters and configuration |
| TT_SITE | 401 | Site pairs under analysis |
| TT_ANTE | 402 | Antenna pairs with discrimination values |
| TT_CHAN | 403 | Channel interference calculation results |
| TT_TEMP1 | 404 | Temporary 1-dimensional lookup table |
| TT_TEMP2 | - | Temporary 2-dimensional lookup table |

#### TT_PARM (Parameter Table)

```sql
create table {0}(
    protype char(1) null,           -- Protocol type
    envtype char(8) null,           -- Environment type
    proname char(16) null,          -- Proposed name
    envname char(16) null,          -- Environment name
    tsorbout char(1) null,          -- TS orbit output flag
    spherecalc char(1) null,        -- Sphere calculation type
    fsep double precision null,     -- Frequency separation
    coordist double precision null, -- Coordination distance
    analopt char(4) null,           -- Analysis options
    margin double precision null,   -- Margin value
    numchan smallint null,          -- Number of channels
    chancodes char(19) null,        -- Channel codes
    tempant char(15) null,          -- Temporary antenna
    tempctx char(15) null,          -- Temporary CTX
    tempplan char(15) null,         -- Temporary plan
    tempequip char(15) null,        -- Temporary equipment
    country char(3) null,           -- Country code
    selsites char(15) null,         -- Site selection method
    numcodes smallint null,         -- Number of codes
    codes char(164) null,           -- Operator/call sign codes
    runname char(5) null,           -- Run name identifier
    reports integer null,           -- Reports flag
    numcases integer null,          -- Number of cases
    numtecases integer null,        -- Number of TE cases
    parmparm char(50) null,         -- Parameter parameters
    mdate char(10) null,            -- Modification date
    mtime char(8) null              -- Modification time
)
```

#### TT_SITE (Site Table)

```sql
create table {0}(
    interferer char(1) null,        -- Interferer flag (T/E)
    intcall1 char(9) null,          -- Interferer call sign 1
    intcall2 char(9) null,          -- Interferer call sign 2
    viccall1 char(9) null,          -- Victim call sign 1
    viccall2 char(9) null,          -- Victim call sign 2
    caseno integer null,            -- Case number
    subcases integer null,          -- Number of subcases
    intname1 char(32) null,         -- Interferer name 1
    intname2 char(32) null,         -- Interferer name 2
    vicname1 char(32) null,         -- Victim name 1
    vicname2 char(32) null,         -- Victim name 2
    intoper char(6) null,           -- Interferer operator
    intoper2 char(6) null,          -- Interferer operator 2
    vicoper char(6) null,           -- Victim operator
    vicoper2 char(6) null,          -- Victim operator 2
    intlatit integer null,          -- Interferer latitude
    intlongit integer null,         -- Interferer longitude
    intgrnd double precision null,  -- Interferer ground elevation
    viclatit integer null,          -- Victim latitude
    viclongit integer null,         -- Victim longitude
    vicgrnd double precision null,  -- Victim ground elevation
    report smallint null,           -- Report flag
    int1int2dist double precision null,  -- Int1 to Int2 distance
    vic1vic2dist double precision null,  -- Vic1 to Vic2 distance
    int1vic1dist double precision null,  -- Int1 to Vic1 distance
    distadv double precision null,       -- Distance advantage
    intoffax double precision null,      -- Interferer off-axis
    vicoffax double precision null,      -- Victim off-axis
    intvicaz double precision null,      -- Int to Vic azimuth
    vicintaz double precision null,      -- Vic to Int azimuth
    processed integer null               -- Processed flag
)
```

#### TT_ANTE (Antenna Table)

```sql
create table {0}(
    interferer char(1) null,
    intcall1 char(9) null,
    intcall2 char(9) null,
    intbndcde char(4) null,         -- Interferer band code
    intanum smallint null,          -- Interferer antenna number
    viccall1 char(9) null,
    viccall2 char(9) null,
    vicbndcde char(4) null,         -- Victim band code
    caseno integer null,
    vicanum smallint null,          -- Victim antenna number
    intacode char(12) null,         -- Interferer antenna code
    vicacode char(12) null,         -- Victim antenna code
    report smallint null,
    subcaseno integer null,
    adiscctxh double precision null,  -- Antenna disc CTX horizontal
    adiscctxv double precision null,  -- Antenna disc CTX vertical
    adisccrxh double precision null,  -- Antenna disc CRX horizontal
    adisccrxv double precision null,  -- Antenna disc CRX vertical
    adiscxtxh double precision null,  -- Antenna disc XTX horizontal
    adiscxtxv double precision null,  -- Antenna disc XTX vertical
    adiscxrxh double precision null,  -- Antenna disc XRX horizontal
    adiscxrxv double precision null,  -- Antenna disc XRX vertical
    processed integer null,
    intause char(4) null,           -- Interferer antenna use
    vicause char(4) null,           -- Victim antenna use
    intoffaxa double precision null,
    vicoffaxa double precision null,
    intgain double precision null,  -- Interferer antenna gain
    vicgain double precision null,  -- Victim antenna gain
    intaxref char(12) null,         -- Interferer antenna xref
    intamodel char(16) null,        -- Interferer antenna model
    vicaxref char(12) null,         -- Victim antenna xref
    vicamodel char(16) null,        -- Victim antenna model
    intaoffax char(1) null,
    inthopaz double precision null,
    intantaz double precision null,
    intoffantax double precision null,
    vicaoffax char(1) null,
    vichopaz double precision null,
    vicantaz double precision null,
    vicoffantax double precision null,
    intaht double precision null,   -- Interferer antenna height
    vicaht double precision null,   -- Victim antenna height
    intvicel double precision null,
    vicintel double precision null,
    intelev double precision null,
    vicelev double precision null
)
```

#### TT_CHAN (Channel Table) — **Primary Results Table**

```sql
create table {0}(
    interferer char(1) null,
    intcall1 char(9) null,
    intcall2 char(9) null,
    intbndcde char(4) null,
    intanum smallint null,
    intchid char(4) null,           -- Interferer channel ID
    viccall1 char(9) null,
    viccall2 char(9) null,
    vicbndcde char(4) null,
    vicanum smallint null,
    caseno integer null,
    vicchid char(4) null,           -- Victim channel ID
    intpolar char(1) null,          -- Interferer polarization
    vicpolar char(1) null,          -- Victim polarization
    intstattx char(1) null,         -- Interferer TX status
    vicstatrx char(1) null,         -- Victim RX status
    inttraftx char(6) null,         -- Interferer traffic TX
    victrafrx char(6) null,         -- Victim traffic RX
    inteqpttx char(8) null,         -- Interferer equipment TX
    viceqptrx char(8) null,         -- Victim equipment RX
    intfreqtx double precision null,  -- Interferer TX frequency
    vicfreqrx double precision null,  -- Victim RX frequency
    vicpwrrx double precision null,   -- Victim RX power
    intpwrtx double precision null,   -- Interferer TX power
    intafsltx double precision null,  -- Interferer TX AFSL
    vicafslrx double precision null,  -- Victim RX AFSL
    rxant smallint null,
    txant smallint null,
    ctxinttraftx char(6) null,      -- CTX interferer traffic
    ctxvictrafrx char(6) null,      -- CTX victim traffic
    ctxeqpt char(8) null,           -- CTX equipment
    calctype char(3) null,          -- Calculation type (C/I, -I)
    report smallint null,
    -- KEY RESULT FIELDS:
    totantdisc double precision null,  -- Total antenna discrimination
    freqsep double precision null,     -- Frequency separation (MHz)
    reqdcalc double precision null,    -- Required C/I from CTX
    patloss double precision null,     -- Path loss (dB)
    calcico double precision null,     -- Calculated C/I (co-polar)
    calcixp double precision null,     -- Calculated C/I (cross-polar)
    resti double precision null,       -- MARGIN (dB) - KEY RESULT
    eirpadv double precision null,     -- EIRP advantage
    tiltdisc double precision null,    -- Tilt discrimination
    -- OVER-HORIZON RESULTS (80% time):
    pathloss80 double precision null,
    calcico80 double precision null,
    calcixp80 double precision null,
    reqd80 double precision null,
    resti80 double precision null,
    -- OVER-HORIZON RESULTS (99% time):
    pathloss99 double precision null,
    calcico99 double precision null,
    calcixp99 double precision null,
    reqd99 double precision null,
    resti99 double precision null,
    ohresult smallint null,         -- Over-horizon result code
    rqco double precision null,     -- Required C/I
    processed integer null,
    ctxinteqpt char(8) null,
    inteqtype char(1) null,
    viceqtype char(1) null,
    intbwchans double precision null,
    vicbwchans double precision null
)
```

---

### TS-ES / ES-TS (Terrestrial-Earth Station) Tables — Prefix: `te_`

| Table Type | Constant | Purpose |
|------------|----------|---------|
| TE_PARM | 405 | Run parameters (same structure as TT_PARM) |
| TE_SITE | 406 | TS-ES site pairs |
| TE_ANTE | 407 | TS-ES antenna pairs with satellite info |
| TE_CHAN | 408 | TS-ES channel interference results |
| TE_TEMP1 | - | Temporary 1-dimensional lookup table |

#### TE_SITE (Earth Station Site Table)

```sql
create table {0}(
    terrcall1 char(9) null,         -- Terrestrial call sign 1
    terrcall2 char(9) null,         -- Terrestrial call sign 2
    earthlocation char(10) null,    -- Earth station location
    terrname1 char(32) null,        -- Terrestrial name 1
    terrname2 char(32) null,        -- Terrestrial name 2
    earthname char(16) null,        -- Earth station name
    terroper char(6) null,          -- Terrestrial operator
    terroper2 char(6) null,
    earthoper char(6) null,         -- Earth station operator
    terrlatit integer null,
    terrlongit integer null,
    terrgrnd double precision null,
    earthlatit integer null,
    earthlongit integer null,
    earthgrnd double precision null,
    radiozone char(2) null,         -- Radio zone
    rainzone smallint null,         -- Rain zone
    etreport smallint null,         -- ET report flag
    tereport smallint null,         -- TE report flag
    etcaseno integer null,
    tecaseno integer null,
    etsubcases integer null,
    tesubcases integer null,
    intreq char(4) null,            -- Interface requirement
    etdist double precision null,   -- ET distance
    etazim double precision null,   -- ET azimuth
    teazim double precision null,   -- TE azimuth
    tudist double precision null,   -- TU distance
    tuazim double precision null,   -- TU azimuth
    utazim double precision null,   -- UT azimuth
    eudist double precision null,   -- EU distance
    euazim double precision null,   -- EU azimuth
    ueazim double precision null,   -- UE azimuth
    processed integer null
)
```

#### TE_ANTE (Earth Station Antenna Table)

```sql
create table {0}(
    interferer char(1) null,
    terrcall1 char(9) null,
    terrcall2 char(9) null,
    terrbndcde char(4) null,
    terranum smallint null,
    earthlocation char(10) null,
    earthcall1 char(9) null,
    earthband char(4) null,
    terracode char(12) null,        -- Terrestrial antenna code
    earthacode char(12) null,       -- Earth station antenna code
    satname char(16) null,          -- Satellite name
    satoper char(3) null,           -- Satellite operator
    satlongit integer null,         -- Satellite longitude
    txpre real null,                -- TX precipitation margin
    txtro real null,                -- TX tropospheric margin
    rxpre real null,                -- RX precipitation margin
    rxtro real null,                -- RX tropospheric margin
    sarc1 double precision null,    -- Satellite arc 1
    sarc2 double precision null,    -- Satellite arc 2
    mode1 smallint null,            -- Mode 1
    mode2 smallint null,            -- Mode 2
    intause char(4) null,
    etreport smallint null,
    tereport smallint null,
    etsubcaseno integer null,
    tesubcaseno integer null,
    esazim double precision null,   -- ES azimuth
    eselev double precision null,   -- ES elevation
    teelev double precision null,
    etelev double precision null,
    tuelev double precision null,
    utelev double precision null,
    euelev double precision null,
    ediscang double precision null, -- Earth disc angle
    tdiscang double precision null, -- Terr disc angle
    adisc_set double precision null,
    adisc_ute double precision null,
    terrht double precision null,
    earthht double precision null,
    tvazim double precision null,
    evazim double precision null,
    tvelev double precision null,
    evelev double precision null,
    tvdistes double precision null,
    tvdisttu double precision null,
    evdistes double precision null,
    evdisttu double precision null,
    angleutv double precision null,
    anglesev double precision null,
    tsoffaxis char(1) null,
    tstrueaz double precision null,
    tstrueel double precision null,
    angleute double precision null,
    angleuta double precision null,
    angleeta double precision null,
    angleatv double precision null,
    adisc_atv double precision null,
    terragain double precision null,
    terramodel char(15) null,
    terraxref char(12) null,
    earthagain double precision null,
    earthamodel char(15) null,
    earthaxref char(12) null,
    processed integer null
)
```

#### TE_CHAN (Earth Station Channel Table) — **Primary Results Table**

```sql
create table {0}(
    interferer char(1) null,
    terrcall1 char(9) null,
    terrcall2 char(9) null,
    terrbndcde char(4) null,
    terranum smallint null,
    terrchid char(4) null,
    earthlocation char(10) null,
    earthcall1 char(9) null,
    earthchid char(4) null,
    inttraftx char(6) null,
    victrafrx char(6) null,
    inteqpttx char(8) null,
    viceqptrx char(8) null,
    intfreqtx double precision null,
    inttxpwr double precision null,
    inttxpwr2 double precision null,
    inttxafls double precision null,
    inttxafls2 double precision null,
    vicrxafls double precision null,
    vicfreqrx double precision null,
    vicpwrrx double precision null,
    stattx char(1) null,
    statrx char(1) null,
    energy double precision null,
    etreport smallint null,
    tereport smallint null,
    ctxinttraftx char(6) null,
    ctxvictrafrx char(6) null,
    ctxeqpt char(8) null,
    calctype char(3) null,
    -- KEY RESULT FIELDS:
    earthmdsc double precision null,    -- Earth station MDSC
    terrmdsc double precision null,     -- Terrestrial MDSC
    eartheirp double precision null,    -- Earth station EIRP
    terreirp double precision null,     -- Terrestrial EIRP
    freqsep double precision null,      -- Frequency separation
    scang double precision null,        -- Scattering angle
    loss20mode1 double precision null,  -- Loss 20% Mode 1
    calci20mode1 double precision null, -- Calc I 20% Mode 1
    loss01mode1 double precision null,  -- Loss 0.1% Mode 1
    calci01mode1 double precision null, -- Calc I 0.1% Mode 1
    loss01mode2 double precision null,  -- Loss 0.1% Mode 2
    calci01mode2 double precision null, -- Calc I 0.1% Mode 2
    reqd20mode1 double precision null,  -- Required 20% Mode 1
    reqd01mode1 double precision null,  -- Required 0.1% Mode 1
    reqd01mode2 double precision null,  -- Required 0.1% Mode 2
    marg20mode1 double precision null,  -- MARGIN 20% Mode 1
    marg01mode1 double precision null,  -- MARGIN 0.1% Mode 1
    marg01mode2 double precision null,  -- MARGIN 0.1% Mode 2
    remterracode char(12) null,
    remterragain double precision null,
    processed integer null,
    terrant smallint null
)
```

---

## Source Data Tables (Input)

These tables contain the **master data** that TpRunTsip reads from.

### Terrestrial Station (TS) Tables — Prefix: `ft_`

| Table | Suffix | Purpose |
|-------|--------|---------|
| FT_TITL | `_titl` | Title/metadata |
| FT_SHRL | `_shrl` | Shared link approvals |
| FT_SITE | `_site` | Site information (call sign, location, operator) |
| FT_ANTE | `_ante` | Antenna information (code, height, azimuth, gain) |
| FT_CHAN | `_chan` | Channel information (frequency, power, equipment) |
| FT_CHNG_CALL | `_chng_call` | Call sign change history |

### Earth Station (ES) Tables — Prefix: `fe_`

| Table | Suffix | Purpose |
|-------|--------|---------|
| FE_TITL | `_titl` | Title/metadata |
| FE_SHRL | `_shrl` | Shared link approvals |
| FE_SITE | `_site` | Site information (location, operator, rain zone) |
| FE_AZIM | `_azim` | Azimuth records |
| FE_ANTE | `_ante` | Antenna information (G/T, satellite, azimuth, elevation) |
| FE_CHAN | `_chan` | Channel information |
| FE_CLOC | `_cloc` | Location change history |
| FE_CCAL | `_ccal` | Call sign change history |

---

## Subsidiary Data (SDF) Tables — Prefix: `su_`

These contain **reference data** used in calculations.

| Table | Suffix | Purpose |
|-------|--------|---------|
| SU_BAND | `_band` | Frequency band definitions (lo, mid, hi, adjacent) |
| SU_ANTE | `_ante` | Antenna patterns and models |
| SU_ANTD | `_antd` | Antenna discrimination curves |
| SU_CTX | `_ctx` | C/I protection criteria |
| SU_CTXD | `_ctxd` | CTX detail by frequency separation |
| SU_EQPT | `_eqpt` | Equipment specifications |
| SU_OPER | `_oper` | Operator information |
| SU_PLAN | `_plan` | Channel plans |
| SU_PLND | `_plnd` | Channel plan details |
| SU_TRAF | `_traf` | Traffic codes |
| SU_NOTE | `_note` | Notes |
| SU_OCOO | `_ocoo` | Operating company coordination |
| SU_ROUT | `_rout` | Routes |
| SU_TOWR | `_towr` | Tower types |
| SU_TOWN | `_town` | Tower notes |

---

## Key Result Columns Explained

### Interference Margin (`resti`, `marg*`)

The **margin** columns are the primary interference indicators:

| Column | Description |
|--------|-------------|
| `resti` | Line-of-sight margin (dB) |
| `resti80` | Margin at 80% time availability |
| `resti99` | Margin at 99% time availability |
| `marg20mode1` | Margin at 20% (ES) |
| `marg01mode1` | Margin at 0.1% Mode 1 (ES) |
| `marg01mode2` | Margin at 0.1% Mode 2 (ES) |

**Interpretation:**
- **Positive margin** = No interference (meets protection criteria)
- **Negative margin** = Potential interference (fails protection criteria)

### Calculation Types (`calctype`)

| Value | Meaning |
|-------|---------|
| `C/I` | Carrier-to-Interference ratio |
| `-I` | Interference power only |
| `I` | Interference (variant) |

### Over-Horizon Result (`ohresult`)

| Value | Meaning |
|-------|---------|
| 0 | Line-of-sight calculation |
| 1-99 | Over-horizon calculation percentage |
| 100+ | Calculation error/invalid |

---

## Example: Complete Table Names

For a TSIP run:
- **Database**: `game_db`
- **Schema**: `fcsa`
- **Project**: `testproj`
- **Run ID**: `run01`

**Generated working tables:**
```
fcsa.tt_testproj_run01_parm
fcsa.tt_testproj_run01_site
fcsa.tt_testproj_run01_ante
fcsa.tt_testproj_run01_chan
fcsa.tt_testproj_run01_tmp1   -- C# uses suffix _tmp1 (see Cvt.cs)
fcsa.tt_testproj_run01_tmp2   -- C# uses suffix _tmp2 (see Cvt.cs)
```

**Source data tables (read from):**
```
fcsa.ft_testproj_site
fcsa.ft_testproj_ante
fcsa.ft_testproj_chan
main.sd_band          -- Shared band table
main.sd_ante          -- Shared antenna table
main.sd_ctx           -- Shared CTX table
```

---

## Source Code References

- **Table definitions**: `_DataStructures\TabDef.cs`
- **Table creation**: `_Utillib\Ssutil.cs` → `UtCreateTable()`, `CreateTab()`
- **Table dropping**: `_Utillib\Ssutil.cs` → `UtDropTable()`, `UtCleanupTables()`, `DropTable()`
- **Name conversion**: `_Utillib\GenUtil.cs` → `UtCvtName()`
- **TT table operations**: `TpRunTsip\TtDynSite.cs`, `TtDynAnte.cs`, `TtDynChan.cs`
- **TE table operations**: `TpRunTsip\TeDynSite.cs`, `TeDynAnte.cs`, `TeDynChan.cs`
- **Constants**: `_Configuration\Constant.cs` (lines 1566-1828)

---

## Table Dropping and Cleanup

The system provides several functions in `_Utillib\Ssutil.cs` for dropping temporary tables.

### Function Hierarchy

| Function | Purpose | Updates Central Table? |
|----------|---------|------------------------|
| `DropTable(tableName)` | Low-level DROP TABLE execution | No |
| `UtCleanupTables(tableType, tableName)` | Drops all tables for a type (cleanup on error) | No |
| `UtDropTable(tableType, tableName)` | Formal drop with tracking update | Yes |
| `KillTable(tableName)` | Generic drop for non-MICS tables | No |

### DropTable() — Core DROP TABLE Execution

**Location**: `_Utillib\Ssutil.cs` (lines 3071-3109)

This is the low-level function that executes the actual `DROP TABLE` SQL command:

```csharp
public static int DropTable(string tableName)
{
    string buf;
    string tabName;

    SQLRETURN nRet = 0;
    SQLRETURN sqlRet = 0;
    SQLHANDLE hStmt = IntPtr.Zero;
    SQLHDBC hConn = Ssutil.NewConn();

    // If the table does not already exist in the DB we have nothing to do.
    if (!IntTableExist(tableName))
    {
        return Constant.SUCCESS;
    }

    /* remove the record for this table from the project billing table */
    tabName = tableName;
    sqlRet = ODBC.SQLAllocHandle(ODBC.SQL_HANDLE_STMT, hConn, out hStmt);

    buf = String.Format("drop table {0}", tableName);

    nRet = ODBC.SQLExecDirect(hStmt, buf, buf.Length);

    if (!ODBC.IsOK(nRet))
    {
        Ssutil.DbGetDiagStmt(hStmt, "Could not drop " + tableName + ":-\n");
        Log2.e("\nSsutil.DropTable(): ERROR: Could not drop " + tableName + ":-\n");
    }

    sqlRet = ODBC.SQLFreeHandle(ODBC.SQL_HANDLE_STMT, hStmt);
    Ssutil.DisConn(hConn);

    return ((int)nRet);
}
```

**Key behavior:**
- Checks if table exists before attempting drop (avoids errors)
- Uses ODBC direct execution
- Returns success even if table doesn't exist

---

### C# Drop Commands for Each TT Table

Table names are built with `GenUtil.UtCvtName(Constant.TT_xxx, tableName, out intName)` using the mappings in `_DataStructures\Cvt.cs`. The actual SQL executed for each is **`drop table {tableName}`** via `DropTable(intName)`.

#### Name mapping (Cvt.cs)

| Constant   | Prefix | Suffix  | Resulting name              |
|------------|--------|---------|-----------------------------|
| TT_PARM    | `tt_`  | `_parm` | `tt_{tableName}_parm`       |
| TT_SITE    | `tt_`  | `_site` | `tt_{tableName}_site`       |
| TT_ANTE    | `tt_`  | `_ante` | `tt_{tableName}_ante`       |
| TT_CHAN    | `tt_`  | `_chan` | `tt_{tableName}_chan`       |
| TT_TEMP1   | `tt_`  | `_tmp1` | `tt_{tableName}_tmp1`       |
| TT_TEMP2   | `tt_`  | `_tmp2` | `tt_{tableName}_tmp2`       |

**Note:** Temp tables use suffix **`_tmp1`** / **`_tmp2`** in code, not `_temp1` / `_temp2`.

#### UtDropTable(Constant.TT, tableName) — drops the four main TT tables

**Location:** `_Utillib\Ssutil.cs` (lines 2985-3005)

```csharp
case Constant.TT:
    GenUtil.UtCvtName(Constant.TT_PARM, tableName, out intName);
    rc = DropTable(intName);           // drop table tt_{tableName}_parm
    if (rc != Constant.SUCCESS) return (rc);

    GenUtil.UtCvtName(Constant.TT_SITE, tableName, out intName);
    rc = DropTable(intName);           // drop table tt_{tableName}_site
    if (rc != Constant.SUCCESS) return (rc);

    GenUtil.UtCvtName(Constant.TT_ANTE, tableName, out intName);
    rc = DropTable(intName);           // drop table tt_{tableName}_ante
    if (rc != Constant.SUCCESS) return (rc);

    GenUtil.UtCvtName(Constant.TT_CHAN, tableName, out intName);
    rc = DropTable(intName);           // drop table tt_{tableName}_chan

    rc = UserInfo.UtUpdateCentralTable("D", tableName, tableType, "D", "Y");
    break;
```

**TT_TEMP1 and TT_TEMP2 are not dropped here**; they are dropped separately (see below).

#### UtCleanupTables(Constant.TT, tableName) — same four tables (cleanup path)

**Location:** `_Utillib\Ssutil.cs` (lines 3272-3280)

```csharp
case Constant.TT:
    GenUtil.UtCvtName(Constant.TT_PARM, tableName, out intName);
    DropTable(intName);
    GenUtil.UtCvtName(Constant.TT_SITE, tableName, out intName);
    DropTable(intName);
    GenUtil.UtCvtName(Constant.TT_ANTE, tableName, out intName);
    DropTable(intName);
    GenUtil.UtCvtName(Constant.TT_CHAN, tableName, out intName);
    DropTable(intName);
    break;
```

#### TT_TEMP1 and TT_TEMP2 — dropped separately

Dropped via `UtDropTable(Constant.TT_TEMP1, paramName)` and `UtDropTable(Constant.TT_TEMP2, paramName)`.

**Example (TSIP run cleanup):** `TpRunTsip\TeBuildSH.cs` (lines 218-219)

```csharp
Ssutil.UtDropTable(Constant.TT_TEMP1, paramName);   // drop table tt_{paramName}_tmp1
Ssutil.UtDropTable(Constant.TT_TEMP2, paramName);  // drop table tt_{paramName}_tmp2
```

#### Summary: command that drops each TT table

| TT table  | Constant  | C# drop call | Resulting SQL (conceptually)          |
|-----------|-----------|--------------|----------------------------------------|
| TT_PARM   | TT_PARM   | `DropTable(intName)` after `UtCvtName(TT_PARM, ...)`  | `drop table tt_{tableName}_parm`  |
| TT_SITE   | TT_SITE   | `DropTable(intName)` after `UtCvtName(TT_SITE, ...)`  | `drop table tt_{tableName}_site`  |
| TT_ANTE   | TT_ANTE   | `DropTable(intName)` after `UtCvtName(TT_ANTE, ...)`  | `drop table tt_{tableName}_ante`  |
| TT_CHAN   | TT_CHAN   | `DropTable(intName)` after `UtCvtName(TT_CHAN, ...)`  | `drop table tt_{tableName}_chan`  |
| TT_TEMP1  | TT_TEMP1  | `UtDropTable(Constant.TT_TEMP1, paramName)`          | `drop table tt_{paramName}_tmp1`  |
| TT_TEMP2  | TT_TEMP2  | `UtDropTable(Constant.TT_TEMP2, paramName)`          | `drop table tt_{paramName}_tmp2`  |

**Source files:** `MICS#\_Utillib\Ssutil.cs`, `MICS#\_DataStructures\Cvt.cs`, `MICS#\TpRunTsip\TeBuildSH.cs` (paths relative to CloudMICS# 20230116).

---

### UtCleanupTables() — Resilient Multi-Table Cleanup

**Location**: `_Utillib\Ssutil.cs` (lines 3121-3303)

This function drops **all tables** associated with a table type, continuing even if individual drops fail. This is critical for cleanup after errors to prevent orphaned tables.

```csharp
public static void UtCleanupTables(int tableType, string tableName)
{
    string intName;

    switch (tableType)
    {
        case Constant.FT:  // Terrestrial Station PDF tables
            GenUtil.UtCvtName(Constant.FT_TITL, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FT_SHRL, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FT_SITE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FT_ANTE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FT_CHAN, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FT_CHNG_CALL, tableName, out intName);
            DropTable(intName);
            break;

        case Constant.FE:  // Earth Station PDF tables
            GenUtil.UtCvtName(Constant.FE_TITL, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_SHRL, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_AZIM, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_SITE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_ANTE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_CHAN, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_CLOC, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.FE_CCAL, tableName, out intName);
            DropTable(intName);
            break;

        case Constant.TT:  // TS-TS TSIP working tables
            GenUtil.UtCvtName(Constant.TT_PARM, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.TT_SITE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.TT_ANTE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.TT_CHAN, tableName, out intName);
            DropTable(intName);
            break;

        case Constant.TE:  // TS-ES TSIP working tables
            GenUtil.UtCvtName(Constant.TE_PARM, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.TE_SITE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.TE_ANTE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.TE_CHAN, tableName, out intName);
            DropTable(intName);
            break;

        // Single-table types (temp tables, subsidiary tables)
        case Constant.TT_TEMP1:
        case Constant.TE_TEMP1:
        case Constant.TT_TEMP2:
        case Constant.TP_PARM:
        case Constant.PP_PARM:
        case Constant.BI_USAGE:
        // ... other single-table types ...
            GenUtil.UtCvtName(tableType, tableName, out intName);
            DropTable(intName);
            break;

        // Multi-table subsidiary types
        case Constant.SU_ANTE:
            GenUtil.UtCvtName(Constant.SU_ANTE, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.SU_ANTD, tableName, out intName);
            DropTable(intName);
            break;

        case Constant.SU_CTX:
            GenUtil.UtCvtName(Constant.SU_CTX, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.SU_CTXD, tableName, out intName);
            DropTable(intName);
            break;

        case Constant.SU_PLAN:
            GenUtil.UtCvtName(Constant.SU_PLAN, tableName, out intName);
            DropTable(intName);
            GenUtil.UtCvtName(Constant.SU_PLND, tableName, out intName);
            DropTable(intName);
            break;

        // ... additional cases ...
    }
}
```

**Key behavior:**
- No return value — always attempts to drop all tables
- Continues even if individual drops fail
- Used for cleanup after creation errors

---

### UtDropTable() — Formal Drop with Central Table Update

**Location**: `_Utillib\Ssutil.cs` (lines 2654-2762)

This function drops tables **and** updates the central tracking table. It stops on first error (unlike `UtCleanupTables`).

```csharp
public static int UtDropTable(int tableType, string tableName)
{
    string intName;
    int rc = Constant.SUCCESS;

    switch (tableType)
    {
        case Constant.FT:
            GenUtil.UtCvtName(Constant.FT_TITL, tableName, out intName);
            rc = DropTable(intName);
            if (rc != Constant.SUCCESS) return (rc);
            
            GenUtil.UtCvtName(Constant.FT_SHRL, tableName, out intName);
            rc = DropTable(intName);
            if (rc != Constant.SUCCESS) return (rc);
            
            // ... drops remaining FT tables ...
            
            // Update central tracking table
            rc = UserInfo.UtUpdateCentralTable("D", tableName, tableType, "D", "Y");
            if (rc != Constant.SUCCESS)
            {
                UtCleanupTables(tableType, tableName);
                return (rc);
            }
            break;

        case Constant.FE:
            // ... similar pattern for FE tables ...
            break;

        // ... other table types ...
    }
    return rc;
}
```

**Key behavior:**
- Returns error code on first failure
- Updates central table after successful drop
- Calls `UtCleanupTables()` if central table update fails

---

### KillTable() — Generic Table Drop

**Location**: `_Utillib\Ssutil.cs` (lines 3932-3960)

Used for dropping non-MICS tables (doesn't update tracking):

```csharp
public static int KillTable(string cTableName)
{
    string cBuf;
    SQLHANDLE hStmt;
    SQLRETURN sqlRet = 0;

    SQLHDBC hConn = Ssutil.NewConn();

    cBuf = String.Format("drop table {0} ", cTableName);

    sqlRet = ODBC.SQLAllocHandle(ODBC.SQL_HANDLE_STMT, hConn, out hStmt);

    if (!ODBC.IsOK(sqlRet))
    {
        return Constant.FAILURE;
    }

    sqlRet = ODBC.SQLExecDirect(hStmt, cBuf, cBuf.Length);

    // ... cleanup and return ...
}
```

---

### Table Types Handled by Cleanup

| Table Type Constant | Tables Dropped |
|---------------------|----------------|
| `Constant.FT` | FT_TITL, FT_SHRL, FT_SITE, FT_ANTE, FT_CHAN, FT_CHNG_CALL |
| `Constant.FE` | FE_TITL, FE_SHRL, FE_AZIM, FE_SITE, FE_ANTE, FE_CHAN, FE_CLOC, FE_CCAL |
| `Constant.TT` | TT_PARM, TT_SITE, TT_ANTE, TT_CHAN |
| `Constant.TE` | TE_PARM, TE_SITE, TE_ANTE, TE_CHAN |
| `Constant.CT` | CT_SITE, CT_ANTE, CT_CHAN, CT_TEMP, CT_RSLT |
| `Constant.CE` | CE_SITE, CE_ANTE, CE_CHAN, CE_RSLT |
| `Constant.SU_ANTE` | SU_ANTE, SU_ANTD |
| `Constant.SU_CTX` | SU_CTX, SU_CTXD |
| `Constant.SU_PLAN` | SU_PLAN, SU_PLND |
| `Constant.TT_TEMP1` | Single temp table |
| `Constant.TE_TEMP1` | Single temp table |
| `Constant.TT_TEMP2` | Single temp table |

---

### When Tables Are Dropped

1. **On Creation Error**: If table creation fails partway through, `UtCleanupTables()` is called to remove any partially-created tables.

2. **Explicit Deletion**: When a user deletes a PDF or TSIP run, `UtDropTable()` is called.

3. **Before Re-creation**: Some operations call `UtDropTable()` before creating new tables to ensure clean slate.

---

*Last updated: January 2026*

