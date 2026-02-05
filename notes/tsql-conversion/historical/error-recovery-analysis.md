# Error Recovery Analysis - T-SQL Port

This document analyzes error recovery requirements for porting TSIP to T-SQL, including how the current C# code handles errors and what recovery mechanisms (if any) are needed.

---

## Executive Summary

**Key Finding**: The current C# code **does NOT have error recovery** - if processing fails, you restart from the beginning. For T-SQL port, **error recovery is OPTIONAL** and only needed if:
1. Runs are very long (hours) and you want to resume
2. You want to avoid re-processing already-completed work
3. You want to track which sites/links failed

**Recommendation**: **Skip error recovery for initial port** - it's not in the current C# code, and T-SQL transactions provide better error handling than C#.

---

## Current C# Error Handling

### Error Handling Patterns

**1. Fatal Errors (Exit Entire Process)**
```csharp
// TpRunTsip.cs - Main()
if (nRet != Constant.SUCCESS)
{
    Qutils.ExplainQueue(Info.DbName, "READ", nRet, null);
    Application.Exit(Error.UNABLE_TO_ENTER_QUEUE);  // Exit entire process
}
```

**2. Return Error Code (Stop Current Operation)**
```csharp
// TtBuildSH.cs - TtCullNCreate()
rc = FtUtils.FtGetSiteWN(cCallFound, out pSite, 3, tpParmStruct.proname, out pSiteNulls);
if (rc != 0)
{
    Log2.e("\nTtBuildSH.TtCullNCreate(): ERROR: call to FtGetSiteWN() failed. Exit");
    return -25;  // Stop processing, return error
}
```

**3. Continue to Next Item (Skip Current Item)**
```csharp
// TtBuildSH.cs - TtCullNCreate()
rc = Vic2DimTable(...);
if (rc != Constant.SUCCESS)
{
    // Could not find the other end of the link. Continue with next case
    GenUtil.AddErr("Could not find the other end of the link, ignoring...");
    continue;  // Skip this link, continue with next
}
```

**4. Continue to Next Parameter Record (Skip Current Run)**
```csharp
// TpRunTsip.cs - Main()
if (TpPlanChan.GenChan(currParm.parmStruct) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(Error.NOPLANPDF);
    exitCode = Constant.FAILURE;
    continue;  // Skip this run, continue with next parameter record
}
```

---

## What Happens on Error in Current C# Code

### Scenario 1: Site Processing Fails

**Example**: `FtGetSiteWN()` fails for a site

**What Happens**:
1. Error is logged: `Log2.e("ERROR: call to FtGetSiteWN() failed")`
2. Function returns error code: `return -25`
3. **Processing stops** - entire `TtCullNCreate()` fails
4. **Partial results remain** - Any sites/links/channels already processed are still in `TT_SITE`, `TT_ANTE`, `TT_CHAN` tables
5. **No cleanup** - Tables are not dropped
6. **No resume** - Must restart entire run from beginning

**Result**: ❌ **No recovery** - Must restart from beginning

---

### Scenario 2: Link Processing Fails

**Example**: `Vic2DimTable()` fails for a link

**What Happens**:
1. Error is logged: `GenUtil.AddErr("Could not find the other end of the link")`
2. Code calls `continue` - skips this link
3. **Processing continues** - Next link is processed
4. **Partial results remain** - This link's results are missing, but other links are processed

**Result**: ⚠️ **Partial recovery** - Continues processing, but this link is skipped

---

### Scenario 3: Run-Level Processing Fails

**Example**: `TtBuildSH.TtBuildSHTable()` fails

**What Happens**:
1. Error is logged
2. Code calls `continue` - skips this parameter record (run)
3. **Processing continues** - Next parameter record is processed
4. **Partial results remain** - This run's tables may be partially populated
5. **Tables may be orphaned** - `TT_SITE_{proj}_{run}`, `TT_ANTE_{proj}_{run}`, `TT_CHAN_{proj}_{run}` may exist but be incomplete

**Result**: ❌ **No recovery** - Must restart this run from beginning

---

### Scenario 4: Process Crashes or Is Killed

**What Happens**:
1. Process terminates immediately
2. **Partial results remain** - All tables created so far remain in database
3. **No cleanup** - Tables are not dropped
4. **Lock is released** - Windows releases mutex when process exits (see `tsip-lock-bug-analysis.md`)
5. **No resume** - Must restart entire run from beginning

**Result**: ❌ **No recovery** - Must restart from beginning

---

## Key Observations

### 1. No Resume Capability

**Current C# Code**: If processing fails at any point, you must **restart from the beginning**. There is no mechanism to:
- Track which sites have been processed
- Resume from where it left off
- Skip already-processed sites

**Why This Works**:
- Runs are typically **idempotent** - re-processing the same site multiple times produces the same results
- Results are **incremental** - each site/link/channel is processed independently
- **No state dependencies** - Processing site B doesn't depend on site A being complete

---

### 2. Partial Results Remain

**Current Behavior**: If processing fails, **partial results remain in database tables**:
- `TT_SITE_{proj}_{run}` - May have some sites processed
- `TT_ANTE_{proj}_{run}` - May have some antenna pairs processed
- `TT_CHAN_{proj}_{run}` - May have some channel pairs processed

**What Happens Next**:
- If you restart the run, it will **re-process everything** (including already-processed sites)
- This creates **duplicate rows** in the tables (unless you drop tables first)
- Current code **does drop tables** at the start of a run (see `UtCleanupTables`)

---

### 3. Table Cleanup on Restart

**Current Code**:
```csharp
// TpRunTsip.cs - Main()
// At start of each run, cleanup old tables
UtCleanupTables(Constant.TT, tsipName);  // Drop TT_SITE, TT_ANTE, TT_CHAN
UtCleanupTables(Constant.TE, tsipName); // Drop TE_SITE, TE_ANTE, TE_CHAN
```

**What This Means**:
- **Every run starts fresh** - Old tables are dropped
- **No resume needed** - Tables are recreated from scratch
- **No state tracking needed** - Everything is reprocessed

---

## T-SQL Error Recovery Options

### Option 1: No Error Recovery (MATCHES CURRENT C# BEHAVIOR)

**Approach**: If processing fails, restart from beginning

**Implementation**:
```sql
-- Start of stored procedure
-- Drop old tables (if they exist)
IF OBJECT_ID('tt_site_proj_run', 'U') IS NOT NULL
    DROP TABLE tt_site_proj_run;
IF OBJECT_ID('tt_ante_proj_run', 'U') IS NOT NULL
    DROP TABLE tt_ante_proj_run;
IF OBJECT_ID('tt_chan_proj_run', 'U') IS NOT NULL
    DROP TABLE tt_chan_proj_run;

-- Process all sites from beginning
-- If error occurs, tables may be partially populated
-- On restart, tables are dropped and recreated
```

**Pros**:
- ✅ **Simplest** - Matches current C# behavior
- ✅ **No state tracking** - No additional complexity
- ✅ **Idempotent** - Can restart safely
- ✅ **Transactions** - Can use `BEGIN TRANSACTION` / `ROLLBACK` for atomicity

**Cons**:
- ❌ **Wastes work** - Re-processes already-completed sites
- ❌ **Slower** - Takes full time even if 90% was already done

**When to Use**: **RECOMMENDED for initial port** - Matches current behavior, simplest implementation

---

### Option 2: Transaction-Based Recovery (T-SQL ADVANTAGE)

**Approach**: Use SQL Server transactions to ensure atomicity

**Implementation**:
```sql
BEGIN TRANSACTION;

BEGIN TRY
    -- Process all sites
    -- Insert into tt_site, tt_ante, tt_chan
    
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    -- Log error
    -- Re-raise error
    THROW;
END CATCH;
```

**Pros**:
- ✅ **Atomic** - Either all sites processed or none (no partial results)
- ✅ **Automatic cleanup** - ROLLBACK removes all inserts
- ✅ **Better than C#** - C# can't rollback, T-SQL can
- ✅ **No orphaned data** - Failed runs leave no partial results

**Cons**:
- ⚠️ **Large transactions** - May lock tables for long time
- ⚠️ **Memory pressure** - Transaction log grows
- ⚠️ **No resume** - Still must restart from beginning

**When to Use**: **RECOMMENDED if runs are short** (< 1 hour) - Better error handling than C#

---

### Option 3: Savepoint-Based Recovery (PARTIAL ROLLBACK)

**Approach**: Use savepoints to rollback individual sites, but keep completed sites

**Implementation**:
```sql
DECLARE @siteCall VARCHAR(9);
DECLARE curSites CURSOR FOR ...;

OPEN curSites;
FETCH NEXT FROM curSites INTO @siteCall;

WHILE @@FETCH_STATUS = 0
BEGIN
    SAVE TRANSACTION SiteProcessing;
    
    BEGIN TRY
        -- Process this site
        -- Insert into tt_site, tt_ante, tt_chan
        
        -- Success - continue
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION SiteProcessing;  -- Rollback only this site
        -- Log error for this site
        -- Continue with next site
    END CATCH
    
    FETCH NEXT FROM curSites INTO @siteCall;
END;

CLOSE curSites;
DEALLOCATE curSites;
```

**Pros**:
- ✅ **Partial recovery** - Completed sites remain, failed sites are rolled back
- ✅ **Continue processing** - Can process remaining sites even if one fails
- ✅ **Better than C#** - More granular error handling

**Cons**:
- ⚠️ **Complexity** - More code, more error handling
- ⚠️ **Still no resume** - If entire procedure fails, must restart
- ⚠️ **Transaction log** - Savepoints still use transaction log

**When to Use**: **OPTIONAL** - If you want better error handling than C#, but still no resume capability

---

### Option 4: Full Resume Capability (NEW FEATURE)

**Approach**: Track which sites have been processed, resume from last completed site

**Implementation**:
```sql
-- Create progress tracking table
CREATE TABLE tsip.analysis_progress (
    run_id VARCHAR(50) PRIMARY KEY,
    last_processed_site VARCHAR(9),
    sites_processed INT,
    sites_total INT,
    start_time DATETIME,
    last_update DATETIME
);

-- At start of procedure
DECLARE @lastSite VARCHAR(9);
SELECT @lastSite = last_processed_site 
FROM tsip.analysis_progress 
WHERE run_id = @runId;

-- Process sites starting from @lastSite
DECLARE curSites CURSOR FOR
    SELECT call1 FROM ft_site
    WHERE call1 > @lastSite  -- Resume from last site
    ORDER BY call1;

-- After each site
UPDATE tsip.analysis_progress
SET last_processed_site = @currentSite,
    sites_processed = sites_processed + 1,
    last_update = GETDATE()
WHERE run_id = @runId;
```

**Pros**:
- ✅ **Resume capability** - Can resume from where it left off
- ✅ **No wasted work** - Doesn't re-process completed sites
- ✅ **Progress tracking** - Can see how far along it is

**Cons**:
- ❌ **Complexity** - Significant additional code
- ❌ **State management** - Must track progress
- ❌ **Not in C#** - New feature, not a port requirement
- ❌ **Edge cases** - What if site list changes between runs?

**When to Use**: **NOT RECOMMENDED for initial port** - New feature, not in current C# code

---

## Comparison: C# vs T-SQL Error Handling

| Aspect | Current C# | T-SQL Option 1 (No Recovery) | T-SQL Option 2 (Transactions) | T-SQL Option 4 (Resume) |
|--------|------------|------------------------------|-------------------------------|-------------------------|
| **Resume Capability** | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Partial Results** | ⚠️ Yes (remain) | ⚠️ Yes (remain) | ✅ No (ROLLBACK) | ✅ Yes (tracked) |
| **Restart Behavior** | Restart from beginning | Restart from beginning | Restart from beginning | Resume from last site |
| **Complexity** | Low | Low | Medium | High |
| **Matches C#** | ✅ Yes | ✅ Yes | ⚠️ Better | ❌ New feature |

---

## Recommendation: Error Recovery Strategy

### For Initial T-SQL Port: **Option 2 (Transaction-Based)**

**Why**:
1. ✅ **Better than C#** - Provides atomicity (all or nothing)
2. ✅ **No partial results** - ROLLBACK removes failed work
3. ✅ **Simple** - Standard T-SQL pattern
4. ✅ **No state tracking** - No additional complexity
5. ✅ **Matches C# behavior** - Still restart from beginning, but cleaner

**Implementation**:
```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
    @projName VARCHAR(50),
    @runName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Drop old tables (if they exist)
    IF OBJECT_ID('tt_site_' + @projName + '_' + @runName, 'U') IS NOT NULL
        DROP TABLE tt_site_...;
    
    -- Start transaction
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Process all sites
        -- (cursor loops, set-based operations, etc.)
        
        -- If we get here, everything succeeded
        COMMIT TRANSACTION;
        
        SELECT 'SUCCESS' AS status, @@ROWCOUNT AS total_cases;
    END TRY
    BEGIN CATCH
        -- Rollback everything
        ROLLBACK TRANSACTION;
        
        -- Log error
        DECLARE @errorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @errorLine INT = ERROR_LINE();
        
        -- Re-raise error
        THROW;
    END CATCH;
END;
```

**Result**:
- ✅ **Atomic** - Either all sites processed or none
- ✅ **Clean** - No partial results on failure
- ✅ **Simple** - Standard T-SQL pattern
- ✅ **Better than C#** - C# can't rollback, T-SQL can

---

### Optional: Add Savepoints for Site-Level Recovery

**If you want better error handling** (optional enhancement):

```sql
BEGIN TRANSACTION;

DECLARE @siteCall VARCHAR(9);
DECLARE curSites CURSOR FOR ...;

OPEN curSites;
FETCH NEXT FROM curSites INTO @siteCall;

WHILE @@FETCH_STATUS = 0
BEGIN
    SAVE TRANSACTION SiteProcessing;
    
    BEGIN TRY
        -- Process this site
        -- ...
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION SiteProcessing;  -- Rollback only this site
        -- Log error, continue with next site
    END CATCH
    
    FETCH NEXT FROM curSites INTO @siteCall;
END;

COMMIT TRANSACTION;  -- Commit all successful sites
```

**Result**:
- ✅ **Site-level recovery** - Failed sites are rolled back, successful sites remain
- ✅ **Continue processing** - Can process remaining sites even if one fails
- ⚠️ **More complex** - Additional error handling code

---

## Progress Tracking: Why It's Not Needed

### Current C# Code: No Progress Tracking

**Observation**: The C# code does **NOT** track progress:
- No table tracking which sites have been processed
- No resume capability
- No progress percentage
- No "last processed site" tracking

**Why It Works**:
1. **Runs are typically short** - Most runs complete in minutes to hours
2. **Idempotent processing** - Re-processing same site produces same results
3. **Incremental results** - Each site is independent
4. **Table cleanup** - Old tables are dropped on restart

---

### T-SQL: Progress Tracking is Optional

**If you want progress tracking** (optional feature):

```sql
-- Optional: Progress tracking table
CREATE TABLE tsip.analysis_progress (
    run_id VARCHAR(50) PRIMARY KEY,
    stage VARCHAR(50),
    current_site VARCHAR(9),
    sites_processed INT,
    sites_total INT,
    start_time DATETIME,
    last_update DATETIME
);

-- Update during processing
UPDATE tsip.analysis_progress
SET current_site = @currentSite,
    sites_processed = sites_processed + 1,
    last_update = GETDATE()
WHERE run_id = @runId;
```

**But**: This is **NOT needed** for T-SQL port because:
1. ❌ **Not in C#** - Current code doesn't have it
2. ❌ **Not required** - Runs complete in reasonable time
3. ❌ **Adds complexity** - Additional state management
4. ✅ **Can add later** - Easy to add if needed

---

## Conclusion

### Error Recovery: **OPTIONAL**

**Recommendation**: Use **Option 2 (Transaction-Based)** for initial port:
- ✅ **Better than C#** - Provides atomicity
- ✅ **Simple** - Standard T-SQL pattern
- ✅ **No state tracking** - No additional complexity
- ✅ **Matches C# behavior** - Still restart from beginning

**Optional Enhancement**: Add savepoints for site-level recovery (if desired)

---

### Progress Tracking: **NOT NEEDED**

**Recommendation**: **Skip progress tracking** for initial port:
- ❌ **Not in C#** - Current code doesn't have it
- ❌ **Not required** - Runs complete in reasonable time
- ❌ **Adds complexity** - Additional state management
- ✅ **Can add later** - Easy to add if needed

---

## Summary Table

| Feature | Current C# | T-SQL Recommendation | Effort | Priority |
|---------|------------|----------------------|--------|----------|
| **Error Recovery** | ❌ None (restart) | ✅ Transactions (atomic) | Low | High |
| **Resume Capability** | ❌ None | ❌ Skip (not in C#) | High | Low |
| **Progress Tracking** | ❌ None | ❌ Skip (not needed) | Medium | Low |
| **Site-Level Recovery** | ⚠️ Partial (continue) | ⚠️ Optional (savepoints) | Medium | Medium |

**Total Effort**: **Low** (just use transactions) - **No additional state management needed**

---

## Implementation Decision: Transactional Approach with Cleanup

**Decision**: Use **transaction-based error recovery** with **explicit cleanup** of artifacts from prior failed runs.

**Rationale**:
1. ✅ **Better than C#** - Provides atomicity (all or nothing)
2. ✅ **Clean state** - No partial results on failure
3. ✅ **Artifact detection** - Check for and clean up prior failed runs
4. ✅ **Simple** - Standard T-SQL pattern
5. ✅ **Matches C# behavior** - Still restart from beginning, but cleaner

---

## Implementation Pattern

### 1. Artifact Detection and Cleanup at Start

**Purpose**: Check for and clean up any artifacts (tables, data) from prior failed runs before starting a new run.

**Implementation**:
```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
    @projName VARCHAR(50),
    @runName VARCHAR(50),
    @envType VARCHAR(10)  -- 'MDB_TS', 'INTRA', 'PDF_ES', etc.
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @viewName VARCHAR(100);
    DECLARE @ttParmName VARCHAR(128);
    DECLARE @ttSiteName VARCHAR(128);
    DECLARE @ttAnteName VARCHAR(128);
    DECLARE @ttChanName VARCHAR(128);
    DECLARE @teParmName VARCHAR(128);
    DECLARE @teSiteName VARCHAR(128);
    DECLARE @teAnteName VARCHAR(128);
    DECLARE @teChanName VARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    
    -- Build view name (used for table naming)
    SET @viewName = @projName + '_' + @runName;
    
    -- Build table names
    SET @ttParmName = 'tt_' + @viewName + '_parm';
    SET @ttSiteName = 'tt_' + @viewName + '_site';
    SET @ttAnteName = 'tt_' + @viewName + '_ante';
    SET @ttChanName = 'tt_' + @viewName + '_chan';
    SET @teParmName = 'te_' + @viewName + '_parm';
    SET @teSiteName = 'te_' + @viewName + '_site';
    SET @teAnteName = 'te_' + @viewName + '_ante';
    SET @teChanName = 'te_' + @viewName + '_chan';
    
    -- ============================================================
    -- STEP 1: ARTIFACT DETECTION AND CLEANUP
    -- ============================================================
    -- Check for and drop any tables from prior failed runs
    -- This ensures we start with a clean slate
    
    -- TS-TS tables (TT_*)
    IF OBJECT_ID(@ttParmName, 'U') IS NOT NULL
    BEGIN
        PRINT 'Cleaning up artifact: ' + @ttParmName;
        SET @sql = 'DROP TABLE ' + @ttParmName;
        EXEC sp_executesql @sql;
    END;
    
    IF OBJECT_ID(@ttSiteName, 'U') IS NOT NULL
    BEGIN
        PRINT 'Cleaning up artifact: ' + @ttSiteName;
        SET @sql = 'DROP TABLE ' + @ttSiteName;
        EXEC sp_executesql @sql;
    END;
    
    IF OBJECT_ID(@ttAnteName, 'U') IS NOT NULL
    BEGIN
        PRINT 'Cleaning up artifact: ' + @ttAnteName;
        SET @sql = 'DROP TABLE ' + @ttAnteName;
        EXEC sp_executesql @sql;
    END;
    
    IF OBJECT_ID(@ttChanName, 'U') IS NOT NULL
    BEGIN
        PRINT 'Cleaning up artifact: ' + @ttChanName;
        SET @sql = 'DROP TABLE ' + @ttChanName;
        EXEC sp_executesql @sql;
    END;
    
    -- TS-ES tables (TE_*) - only if ES analysis
    IF @envType IN ('PDF_ES', 'MDB_ES') OR @projName LIKE '%_ES'
    BEGIN
        IF OBJECT_ID(@teParmName, 'U') IS NOT NULL
        BEGIN
            PRINT 'Cleaning up artifact: ' + @teParmName;
            SET @sql = 'DROP TABLE ' + @teParmName;
            EXEC sp_executesql @sql;
        END;
        
        IF OBJECT_ID(@teSiteName, 'U') IS NOT NULL
        BEGIN
            PRINT 'Cleaning up artifact: ' + @teSiteName;
            SET @sql = 'DROP TABLE ' + @teSiteName;
            EXEC sp_executesql @sql;
        END;
        
        IF OBJECT_ID(@teAnteName, 'U') IS NOT NULL
        BEGIN
            PRINT 'Cleaning up artifact: ' + @teAnteName;
            SET @sql = 'DROP TABLE ' + @teAnteName;
            EXEC sp_executesql @sql;
        END;
        
        IF OBJECT_ID(@teChanName, 'U') IS NOT NULL
        BEGIN
            PRINT 'Cleaning up artifact: ' + @teChanName;
            SET @sql = 'DROP TABLE ' + @teChanName;
            EXEC sp_executesql @sql;
        END;
    END;
    
    -- Also check for temporary tables (TT_TEMP1, TT_TEMP2, TE_TEMP1)
    DECLARE @tempTableName VARCHAR(128);
    SET @tempTableName = 'tt_' + @viewName + '_temp1';
    IF OBJECT_ID(@tempTableName, 'U') IS NOT NULL
    BEGIN
        PRINT 'Cleaning up artifact: ' + @tempTableName;
        SET @sql = 'DROP TABLE ' + @tempTableName;
        EXEC sp_executesql @sql;
    END;
    
    SET @tempTableName = 'tt_' + @viewName + '_temp2';
    IF OBJECT_ID(@tempTableName, 'U') IS NOT NULL
    BEGIN
        PRINT 'Cleaning up artifact: ' + @tempTableName;
        SET @sql = 'DROP TABLE ' + @tempTableName;
        EXEC sp_executesql @sql;
    END;
    
    -- ============================================================
    -- STEP 2: TRANSACTION-BASED PROCESSING
    -- ============================================================
    -- Start transaction to ensure atomicity
    -- If any error occurs, ROLLBACK removes all partial results
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Create tables (within transaction)
        -- Process all sites, links, antennas, channels
        -- Insert results into tables
        
        -- Example: Create TT_PARM table
        SET @sql = N'
        CREATE TABLE ' + @ttParmName + N' (
            -- Table schema here
        );';
        EXEC sp_executesql @sql;
        
        -- Example: Create TT_SITE table
        SET @sql = N'
        CREATE TABLE ' + @ttSiteName + N' (
            -- Table schema here
        );';
        EXEC sp_executesql @sql;
        
        -- ... (create other tables) ...
        
        -- Process all sites (cursor loops, set-based operations, etc.)
        -- This is where the main processing logic goes
        -- ... (processing code) ...
        
        -- If we get here, everything succeeded
        COMMIT TRANSACTION;
        
        SELECT 'SUCCESS' AS status, @@ROWCOUNT AS total_cases;
    END TRY
    BEGIN CATCH
        -- ============================================================
        -- STEP 3: ERROR HANDLING AND CLEANUP
        -- ============================================================
        -- Rollback transaction (removes all partial results)
        ROLLBACK TRANSACTION;
        
        -- Log error details
        DECLARE @errorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @errorLine INT = ERROR_LINE();
        DECLARE @errorNumber INT = ERROR_NUMBER();
        DECLARE @errorSeverity INT = ERROR_SEVERITY();
        DECLARE @errorState INT = ERROR_STATE();
        
        -- Log to error table (optional)
        -- INSERT INTO tsip.error_log (run_id, error_msg, error_line, ...)
        -- VALUES (@viewName, @errorMsg, @errorLine, ...);
        
        -- Print error details
        PRINT 'ERROR in tsip.ProcessInterferenceAnalysis:';
        PRINT '  Error Number: ' + CAST(@errorNumber AS VARCHAR(10));
        PRINT '  Error Message: ' + @errorMsg;
        PRINT '  Error Line: ' + CAST(@errorLine AS VARCHAR(10));
        PRINT '  Error Severity: ' + CAST(@errorSeverity AS VARCHAR(10));
        PRINT '  Error State: ' + CAST(@errorState AS VARCHAR(10));
        
        -- ============================================================
        -- STEP 4: EXPLICIT CLEANUP AFTER ROLLBACK
        -- ============================================================
        -- Even though ROLLBACK removed data, tables may still exist
        -- Explicitly drop tables to ensure clean state
        
        -- Note: ROLLBACK removes data but may not drop tables if they were
        -- created with IF NOT EXISTS or if DDL was committed separately
        -- So we explicitly drop them here
        
        IF OBJECT_ID(@ttParmName, 'U') IS NOT NULL
        BEGIN
            SET @sql = 'DROP TABLE ' + @ttParmName;
            EXEC sp_executesql @sql;
        END;
        
        IF OBJECT_ID(@ttSiteName, 'U') IS NOT NULL
        BEGIN
            SET @sql = 'DROP TABLE ' + @ttSiteName;
            EXEC sp_executesql @sql;
        END;
        
        IF OBJECT_ID(@ttAnteName, 'U') IS NOT NULL
        BEGIN
            SET @sql = 'DROP TABLE ' + @ttAnteName;
            EXEC sp_executesql @sql;
        END;
        
        IF OBJECT_ID(@ttChanName, 'U') IS NOT NULL
        BEGIN
            SET @sql = 'DROP TABLE ' + @ttChanName;
            EXEC sp_executesql @sql;
        END;
        
        -- TE tables (if applicable)
        IF @envType IN ('PDF_ES', 'MDB_ES') OR @projName LIKE '%_ES'
        BEGIN
            IF OBJECT_ID(@teParmName, 'U') IS NOT NULL
            BEGIN
                SET @sql = 'DROP TABLE ' + @teParmName;
                EXEC sp_executesql @sql;
            END;
            
            IF OBJECT_ID(@teSiteName, 'U') IS NOT NULL
            BEGIN
                SET @sql = 'DROP TABLE ' + @teSiteName;
                EXEC sp_executesql @sql;
            END;
            
            IF OBJECT_ID(@teAnteName, 'U') IS NOT NULL
            BEGIN
                SET @sql = 'DROP TABLE ' + @teAnteName;
                EXEC sp_executesql @sql;
            END;
            
            IF OBJECT_ID(@teChanName, 'U') IS NOT NULL
            BEGIN
                SET @sql = 'DROP TABLE ' + @teChanName;
                EXEC sp_executesql @sql;
            END;
        END;
        
        -- Re-raise error so caller knows it failed
        THROW;
    END CATCH;
END;
```

---

## Key Implementation Points

### 1. Artifact Detection at Start

**Why**: Prior failed runs may have left tables in the database (if transaction wasn't used, or if DDL was committed separately).

**What to Check**:
- ✅ All TSIP result tables (`tt_*`, `te_*`)
- ✅ Temporary tables (`tt_*_temp1`, `tt_*_temp2`)
- ✅ Parameter tables (`tt_*_parm`, `te_*_parm`)

**How**: Use `OBJECT_ID(tableName, 'U')` to check if table exists, then `DROP TABLE` if found.

---

### 2. Transaction-Based Processing

**Why**: Ensures atomicity - either all processing succeeds or all is rolled back.

**Implementation**:
- `BEGIN TRANSACTION` at start of processing
- `COMMIT TRANSACTION` on success
- `ROLLBACK TRANSACTION` on error (in CATCH block)

**Benefits**:
- ✅ No partial results on failure
- ✅ Automatic cleanup of data (ROLLBACK removes all inserts)
- ✅ Better than C# (C# can't rollback)

---

### 3. Explicit Cleanup After Error

**Why**: Even though `ROLLBACK TRANSACTION` removes data, **tables may still exist** if:
- DDL statements were committed separately
- Tables were created with `IF NOT EXISTS` and already existed
- Transaction isolation level doesn't rollback DDL

**What to Clean Up**:
- ✅ Drop all result tables (`tt_*`, `te_*`)
- ✅ Drop temporary tables
- ✅ Log error details for debugging

**Implementation**: In `CATCH` block, after `ROLLBACK`, explicitly check for and drop all tables.

---

### 4. Error Logging

**Why**: Need to know what went wrong for debugging and monitoring.

**What to Log**:
- Error message (`ERROR_MESSAGE()`)
- Error line number (`ERROR_LINE()`)
- Error number (`ERROR_NUMBER()`)
- Error severity (`ERROR_SEVERITY()`)
- Run identifier (`@viewName`)

**Implementation**: 
- Print to console/log (for immediate visibility)
- Optionally insert into error log table (for historical tracking)

---

## Comparison: C# vs T-SQL Cleanup

| Aspect | Current C# | T-SQL (Recommended) |
|--------|------------|----------------------|
| **Artifact Detection** | ⚠️ `UtCleanupTables()` called at start | ✅ Explicit check for each table |
| **Error Cleanup** | ❌ Partial results remain | ✅ ROLLBACK removes all data |
| **Table Cleanup on Error** | ❌ Tables remain (orphaned) | ✅ Explicit DROP in CATCH block |
| **Atomicity** | ❌ No (partial results possible) | ✅ Yes (all or nothing) |
| **Error Logging** | ⚠️ Log2 file only | ✅ Print + optional error table |

---

## Tables to Check and Clean Up

### TS-TS Tables (TT_*)
- `tt_{proj}_{run}_parm` - Parameter record
- `tt_{proj}_{run}_site` - Site pair records
- `tt_{proj}_{run}_ante` - Antenna pair records
- `tt_{proj}_{run}_chan` - Channel interference results
- `tt_{proj}_{run}_temp1` - Temporary table 1
- `tt_{proj}_{run}_temp2` - Temporary table 2

### TS-ES Tables (TE_*)
- `te_{proj}_{run}_parm` - Parameter record
- `te_{proj}_{run}_site` - TS-ES site pairs
- `te_{proj}_{run}_ante` - TS-ES antenna pairs
- `te_{proj}_{run}_chan` - TS-ES channel results
- `te_{proj}_{run}_temp1` - Temporary table 1

---

## Implementation Checklist

### At Start of Procedure
- [ ] Build table names from `@projName` and `@runName`
- [ ] Check for and drop `tt_*_parm` table (if exists)
- [ ] Check for and drop `tt_*_site` table (if exists)
- [ ] Check for and drop `tt_*_ante` table (if exists)
- [ ] Check for and drop `tt_*_chan` table (if exists)
- [ ] Check for and drop `tt_*_temp1` table (if exists)
- [ ] Check for and drop `tt_*_temp2` table (if exists)
- [ ] If ES analysis: Check for and drop `te_*` tables (if exist)

### During Processing
- [ ] `BEGIN TRANSACTION` before any DDL/DML
- [ ] Create tables within transaction
- [ ] Process all sites/links/antennas/channels
- [ ] `COMMIT TRANSACTION` on success

### On Error (CATCH Block)
- [ ] `ROLLBACK TRANSACTION` (removes all data)
- [ ] Log error details (message, line, number, severity)
- [ ] Explicitly drop `tt_*_parm` table (if exists)
- [ ] Explicitly drop `tt_*_site` table (if exists)
- [ ] Explicitly drop `tt_*_ante` table (if exists)
- [ ] Explicitly drop `tt_*_chan` table (if exists)
- [ ] Explicitly drop `tt_*_temp1` table (if exists)
- [ ] Explicitly drop `tt_*_temp2` table (if exists)
- [ ] If ES analysis: Explicitly drop `te_*` tables (if exist)
- [ ] `THROW` to re-raise error

---

## Summary

**Decision**: Use **transactional approach with explicit cleanup**

**Key Points**:
1. ✅ **Artifact detection** - Check for and clean up prior failed runs at start
2. ✅ **Transaction-based** - Use `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` for atomicity
3. ✅ **Explicit cleanup** - Drop tables in CATCH block even after ROLLBACK
4. ✅ **Error logging** - Log error details for debugging
5. ✅ **Better than C#** - Provides atomicity and automatic cleanup

**Result**: Clean state on start, atomic processing, clean state on error, no orphaned tables or partial results.

