# Multiple Runs Attempted - Root Cause Analysis

**Symptoms**:
- TSIP runs multiple times
- Outputs endless streams to error log
- Never outputs results to output files
- Successfully calculates several individual interference cases

**Analysis Date**: January 2026

---

## The Core Problem

**Root Cause**: **Lock not released on error paths + Process exit behavior + Potential retry mechanism**

When TSIP encounters an error:
1. Lock is acquired but not released (bug)
2. Process exits (completes other parameter records or crashes)
3. Windows releases mutex when process exits
4. **Something causes TSIP to be re-invoked** (scheduler, retry, user)
5. New process starts, acquires lock (now available), fails again
6. **Cycle repeats indefinitely**

---

## Code Structure Analysis

### Parameter Record Processing Loop

**Location**: `TpRunTsip.cs`, lines 302-634

```csharp
// Load all parameter records into memory
rc = ParmFileInit(Info.PdfName, ref parmTableCount, out parmTables);

// For each parameter record in the current parameter file ...
foreach (ParmTableWN currParm in parmTables)
{
    // Open report streams
    OpenReportStreams(...);
    
    // Acquire lock
    if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
    {
        continue;  // Skip if lock held
    }
    
    // ... processing (many error paths with continue) ...
    
    // Release lock (ONLY on success)
    GenUtil.FileGateClose(cLockFile);
    
    // Close streams (ONLY on success)
    CloseReportStreams();
}
```

**Key Points**:
- **Single process** processes **multiple parameter records**
- Each parameter record gets its **own lock** (`{DB}_{PROJ}_{RUN}_LOCK`)
- If one record fails, process **continues to next record**
- Process only exits after **all records processed** (or fatal error)

---

## Exit Code Management

### Exit Code Variable

**Declaration**: Line 126
```csharp
int exitCode;
```

**Initialization**: Line 168
```csharp
exitCode = Constant.SUCCESS;
```

### Exit Code Updates

**Multiple locations set `exitCode = Constant.FAILURE`**:
- Line 372: PLAN PDF generation fails
- Line 411: ParmRecInit fails
- Line 462: TeBuildSH fails
- Line 504: TtBuildSH fails
- Line 522: UpdateParmRec fails
- Line 548: ReportStudy fails
- Line 586: ReportNew fails

**But**: Process **does NOT exit** on these errors - it calls `continue` and processes next parameter record!

### Final Exit

**Line 650**: Process exits with `exitCode`
```csharp
Application.Exit("Successful normal exit from TpRunTsip.Main()", exitCode);
```

**Key Point**: Process exits with **FAILURE** if any parameter record failed, even if others succeeded.

---

## What Causes Multiple Runs?

### Hypothesis 1: Scheduler/Retry Mechanism (MOST LIKELY)

**Scenario**: External scheduler or retry mechanism monitors TSIP exit codes

**How It Works**:
1. TSIP process starts, processes parameter records
2. One record fails (e.g., ReportStudy fails at line 549)
3. `exitCode = Constant.FAILURE` (line 548)
4. Process continues, processes other records
5. Process exits with `exitCode = FAILURE` (line 650)
6. **Scheduler sees FAILURE exit code**
7. **Scheduler immediately restarts TSIP** (retry mechanism)
8. New process starts, tries same parameter records
9. **Same error occurs** (e.g., ReportStudy still fails)
10. **Cycle repeats indefinitely**

**Evidence**:
- Comment at line 170: "Set our priority class to normal. This will allow tsipInitiator to continue executing while it updates the tsip queue after we have started."
- This suggests there's a `tsipInitiator` process that manages TSIP execution
- `tsipInitiator` likely monitors exit codes and retries on failure

---

### Hypothesis 2: User Manual Retry

**Scenario**: User sees error, manually restarts TSIP

**How It Works**:
1. TSIP fails, exits with FAILURE
2. User sees error in logs
3. User manually restarts TSIP
4. Same error occurs
5. User retries again
6. **Cycle continues**

**Less Likely**: Wouldn't cause "endless streams" unless user is very persistent

---

### Hypothesis 3: Process Crash and Auto-Restart

**Scenario**: Process crashes, Windows Task Scheduler or service manager restarts it

**How It Works**:
1. TSIP process crashes (unhandled exception)
2. Windows service manager or Task Scheduler detects crash
3. Automatically restarts process
4. Same error occurs, process crashes again
5. **Auto-restart cycle continues**

**Evidence**:
- Line 652-660: Top-level try-catch catches exceptions
- But if exception occurs in unmanaged code or during stream operations, might not be caught

---

## The Critical Sequence

### Step-by-Step: Why Multiple Runs Happen

**Run 1**:
1. TSIP process starts
2. Loads parameter records: `[PROJ1_RUN1, PROJ2_RUN2, PROJ3_RUN3]`
3. Processes PROJ1_RUN1:
   - Acquires lock: `FCSA_PROJ1_RUN1_LOCK` ✅
   - Opens report streams ✅
   - Calculations succeed ✅
   - `ReportStudy()` fails ❌ (line 549)
   - `exitCode = Constant.FAILURE` (line 548)
   - Calls `continue` (line 549) ❌ **Lock NOT released, streams NOT closed**
4. Processes PROJ2_RUN2:
   - Acquires lock: `FCSA_PROJ2_RUN2_LOCK` ✅
   - Processes successfully ✅
   - Releases lock ✅
5. Processes PROJ3_RUN3:
   - Acquires lock: `FCSA_PROJ3_RUN3_LOCK` ✅
   - Processes successfully ✅
   - Releases lock ✅
6. Process exits with `exitCode = FAILURE` (because PROJ1_RUN1 failed)
7. **Windows releases mutex** for PROJ1_RUN1 (process exited)

**Run 2** (Immediately after Run 1):
1. **Scheduler/retry mechanism sees FAILURE exit code**
2. **Immediately restarts TSIP process**
3. TSIP process starts
4. Loads same parameter records: `[PROJ1_RUN1, PROJ2_RUN2, PROJ3_RUN3]`
5. Processes PROJ1_RUN1:
   - Tries to acquire lock: `FCSA_PROJ1_RUN1_LOCK`
   - **Lock is available** (Windows released it when Run 1 exited) ✅
   - Acquires lock ✅
   - Opens report streams ✅
   - Calculations succeed ✅
   - `ReportStudy()` fails again ❌ (same error)
   - `exitCode = Constant.FAILURE`
   - Calls `continue` ❌ **Lock NOT released, streams NOT closed**
6. Processes PROJ2_RUN2, PROJ3_RUN3 (successfully)
7. Process exits with `exitCode = FAILURE`
8. **Windows releases mutex** for PROJ1_RUN1

**Run 3, 4, 5...**: **Same cycle repeats indefinitely**

---

## Why This Causes "Endless Error Streams"

### Error Stream Accumulation

**Each Run**:
1. Opens error stream (`mTW_ERR`) at line 277
2. Re-opens error stream for each parameter record at line 350
3. **Error stream is NEVER closed on error paths**
4. Error stream only closed at line 648 (normal exit)

**What Happens**:
- Run 1: Error stream opened, errors logged, stream NOT closed (if error occurs)
- Run 2: Error stream opened again (may create duplicate or append)
- Run 3: More errors logged
- **Error stream accumulates errors from all runs**

**Result**: **Endless error streams** - Errors from all failed runs accumulate

---

## Why Results Never Written

### Report Stream Buffering

**Each Run**:
1. Opens report streams at line 330
2. Calculations succeed (data in memory buffers)
3. `ReportStudy()` or `ReportNew()` fails
4. Calls `continue` (line 549 or 587)
5. **Streams NOT closed** - Buffered data never flushed
6. Process exits - **Windows may or may not flush buffers**

**Result**: 
- Calculations complete (data in buffers)
- Reports never written (buffers never flushed)
- Files appear empty or don't exist

---

## The Probable Cause: Exit Code + Retry Mechanism

### Most Likely Scenario

**The Bug Chain**:

1. **TSIP processes parameter records in a loop** (`foreach`)
2. **One record fails** (e.g., ReportStudy fails)
3. **`exitCode = FAILURE`** is set
4. **Lock and streams NOT released** (bug)
5. **Process continues**, processes other records
6. **Process exits with `exitCode = FAILURE`**
7. **External mechanism (scheduler/tsipInitiator) sees FAILURE**
8. **Immediately restarts TSIP** (retry on failure)
9. **New process starts**, tries same records
10. **Same error occurs** (e.g., ReportStudy still fails)
11. **Cycle repeats indefinitely**

**Evidence for Retry Mechanism**:
- Comment mentions "tsipInitiator" (line 170)
- Exit code is carefully tracked (`exitCode` variable)
- Exit code is passed to `Application.Exit()` (line 650)
- This suggests something monitors exit codes

---

## Why Lock Bug Enables This

### Without Lock Bug

**If lock was properly released**:
1. Run 1 fails, releases lock
2. Run 2 starts, acquires lock
3. Run 2 fails, releases lock
4. **But**: Run 2 would still fail (same error)
5. **Cycle would still repeat** (but at least lock is released)

**Lock bug makes it worse**:
- Lock not released means if process continues (doesn't exit), lock stays held
- But if process exits, Windows releases lock anyway
- **So lock bug enables the cycle, but doesn't cause it**

---

## The Real Root Cause

### Primary Cause: **Retry Mechanism + Exit Code**

**The retry mechanism** (scheduler/tsipInitiator) sees FAILURE exit code and immediately restarts TSIP.

**Why it retries**:
- Exit code indicates failure
- Retry mechanism assumes transient error
- Restarts process to retry
- **But error is NOT transient** - same error occurs every time

**Why it's endless**:
- Same error occurs every run
- Exit code is always FAILURE
- Retry mechanism keeps retrying
- **No backoff or failure limit**

---

## Secondary Causes

### 1. Lock Not Released (Amplifies Problem)

**Impact**: 
- If process continues (doesn't exit), lock stays held
- Blocks other processes from running same project/run
- But if process exits, Windows releases lock anyway
- **Main impact**: If multiple processes try to run, lock bug causes blocking

---

### 2. Streams Not Closed (Causes Data Loss)

**Impact**:
- Buffered data never flushed
- Results never written to files
- File handles accumulate
- Error streams accumulate

---

### 3. Exit Code Set But Process Continues

**Impact**:
- `exitCode = FAILURE` is set on error
- But process continues processing other records
- Process exits with FAILURE even if other records succeeded
- **Retry mechanism retries ALL records**, not just the failed one

---

## Recommended Investigation

### Check These

1. **Is there a scheduler/tsipInitiator?**
   - Look for process that invokes TSIP
   - Check if it monitors exit codes
   - Check if it has retry logic

2. **What triggers TSIP execution?**
   - Scheduled task?
   - Service?
   - Manual invocation?
   - Database trigger?

3. **Is there retry logic?**
   - Does something retry on FAILURE exit code?
   - Is there a backoff mechanism?
   - Is there a failure limit?

4. **Why does ReportStudy/ReportNew fail?**
   - What's the actual error?
   - Is it a transient error or permanent?
   - Does it fail every time or intermittently?

---

## Recommended Fixes

### Fix 1: Don't Set Exit Code on Continue (IMMEDIATE)

**Problem**: Setting `exitCode = FAILURE` causes retry mechanism to retry

**Fix**: Only set exit code on fatal errors that cause process exit

```csharp
// DON'T set exitCode on continue paths
if ((rc = ReportStudy(...)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    // exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    CloseReportStreams();
    GenUtil.FileGateClose(cLockFile);
    continue;  // Skip this run, but don't fail entire process
}
```

**Result**: Process exits with SUCCESS even if some records fail, preventing retry

---

### Fix 2: Release Lock and Close Streams (CRITICAL)

**Problem**: Lock and streams not released on error paths

**Fix**: Use try-finally to always release

```csharp
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    continue;
}

try
{
    // All processing
}
finally
{
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    GenUtil.FileGateClose(cLockFile);
}
```

---

### Fix 3: Investigate Retry Mechanism

**Action**: Find and examine the scheduler/tsipInitiator

**Questions**:
- Does it retry on FAILURE exit code?
- Can retry logic be disabled or modified?
- Is there a backoff mechanism?
- Is there a failure limit?

---

## Summary

### Root Cause

**Primary**: **Retry mechanism sees FAILURE exit code and immediately restarts TSIP**

**Secondary**:
- Lock not released (enables blocking)
- Streams not closed (causes data loss)
- Exit code set on non-fatal errors (triggers retry)

### The Cycle

1. TSIP fails → `exitCode = FAILURE`
2. Process exits with FAILURE
3. Retry mechanism restarts TSIP
4. Same error occurs
5. **Cycle repeats indefinitely**

### Why "Endless Error Streams"

- Error stream opened each run
- Errors accumulate
- Stream never closed on error paths
- **Errors from all runs accumulate**

### Why "No Results Written"

- Report streams opened
- Data buffered in memory
- Streams never closed on error
- Buffers never flushed
- **Results never written to disk**

---

*Last Updated: January 2026*

