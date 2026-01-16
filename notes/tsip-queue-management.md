# TSIP Queue Management and Concurrency Control

This document explains how the TSIP code manages queueing and prevents multiple runs from executing simultaneously.

---

## Overview

The TSIP system uses a **two-level locking mechanism** to prevent concurrent execution:

1. **Database-Level Queue** (`Qutils.EnterQueue`/`ExitQueue`) - Prevents multiple processes from accessing the database simultaneously
2. **Run-Level Lock** (`GenUtil.FileGate`/`FileGateClose`) - Prevents multiple TSIP runs for the same project/run combination

---

## Level 1: Database-Level Queue (`Qutils`)

### Purpose

Prevents multiple processes from accessing the database simultaneously, with different rules for READ vs. WRITE access.

### Implementation

**Location**: `_Utillib/Qutils.cs`

**Key Methods**:
- `EnterQueue(dBase, cQName, writeQueueWaitTimeSeconds)` - Enter the queue
- `ExitQueue(dBase, cQName)` - Exit the queue
- `ExplainQueue(dBase, cQName, nErr, fOut)` - Explain queue errors

### Queue Types

#### 1. HOLD Mutex (`Global\{DB}HOLD`)

**Purpose**: Administrative lock - FCSA admin can block ALL MICS program access

**Behavior**:
- If HOLD mutex is locked → **All access blocked** (returns error 100)
- If HOLD mutex is available → Proceed to WRITE mutex check
- **Always released immediately** after check (not held during processing)

**Mutex Name**: `Global\{DB}HOLD` (e.g., `Global\FCSAHOLD`)

#### 2. WRITE Mutex (`Global\{DB}WRITE`)

**Purpose**: Ensures only one process has WRITE access, or coordinates READ access

**Behavior**:
- **WRITE mode**: Holds mutex during entire processing (exclusive access)
- **READ mode**: Acquires mutex briefly to create marker file, then releases

**Mutex Name**: `Global\{DB}WRITE` (e.g., `Global\FCSAWRITE`)

**Wait Time**: Configurable (TSIP uses 30 seconds)

---

### READ Mode Access

**How It Works**:

1. **Acquire WRITE mutex** (briefly, to coordinate)
2. **Check HOLD mutex** - If locked, abort (error 100)
3. **Create marker file** in `{MICS_ROOT}\files\read\{ProcessID}`
4. **Release WRITE mutex** (other READ processes can proceed)
5. **Process runs** (multiple READ processes can run simultaneously)
6. **Delete marker file** on exit

**Marker File Location**: `{MICS_ROOT}\files\read\{ProcessID}`

**Example**: Process ID 12345 creates file `d:\mics\files\read\12345`

**Key Point**: **Multiple READ processes can run simultaneously** - they just create marker files

---

### WRITE Mode Access

**How It Works**:

1. **Acquire WRITE mutex** (exclusive - blocks other WRITE requests)
2. **Check HOLD mutex** - If locked, abort (error 100)
3. **Poll for READ marker files** - Wait until no READ processes are running
4. **Hold WRITE mutex** during entire processing (exclusive access)
5. **Release WRITE mutex** on exit

**Polling Behavior**:
- Checks every **5 seconds** for READ marker files
- **Timeouts** after `writeQueueWaitTimeSeconds` (30 seconds for TSIP)
- **Validates marker files** - Only blocks if process is still running
- **Cleans up orphaned files** - Deletes marker files for dead processes

**Key Point**: **Only one WRITE process can run at a time**, and it waits for all READ processes to finish

---

### Error Codes

| Code | Meaning |
|------|---------|
| **0** | Success |
| **100** | HOLD mutex locked (admin blocking) |
| **110** | WRITE mutex timeout (another WRITE process running) |
| **120** | Read marker file directory doesn't exist |
| **130** | Failed to get process list |
| **140** | READ processes still running (timeout waiting) |
| **150** | Failed to create READ marker file |

---

## Level 2: Run-Level Lock (`FileGate`)

### Purpose

Prevents multiple TSIP runs for the **same project/run combination** from executing simultaneously.

### Implementation

**Location**: `_Utillib/GenUtil.cs`

**Key Methods**:
- `FileGate(cFileName)` - Acquire lock
- `FileGateClose(cFileName)` - Release lock

### How It Works

**Lock File Name**: `{DB}_{Project}_{Run}_LOCK`

**Example**: `FCSA_PROJECT1_RUN1_LOCK`

**Process**:

1. **Create named mutex** with lock file name
2. **Try to acquire mutex** with **0-second timeout** (non-blocking)
3. **If acquired**: Lock successful, proceed
4. **If not acquired**: Another process has the lock, abort with warning

**Key Point**: **Non-blocking** - If lock is held, TSIP exits immediately (doesn't wait)

---

## TSIP Usage in `TpRunTsip.cs`

### Entry Sequence

```csharp
// 1. Enter database queue (READ mode)
nRet = Qutils.EnterQueue(Info.DbName, "READ", 30);
if (nRet != Constant.SUCCESS)
{
    Qutils.ExplainQueue(Info.DbName, "READ", nRet, null);
    Application.Exit(Error.UNABLE_TO_ENTER_QUEUE);
}

// ... database connection, initialization ...

// 2. For each parameter record (run)
foreach (ParmTableWN currParm in parmTables)
{
    // 3. Acquire run-level lock
    cLockFile = String.Format("{0}_{1}_{2}_LOCK", 
        Info.DbName, 
        cProNameTrimmed, 
        cRunNameTrimmed);
    
    if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
    {
        // Another TSIP is running this project/run combination
        Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
        // Skip this run, continue to next
        continue;
    }
    
    // ... process run ...
    
    // 4. Release run-level lock
    GenUtil.FileGateClose(cLockFile);
}

// 5. Exit database queue
Qutils.ExitQueue(Info.DbName, "READ");
```

### Exit Sequence

**Normal Exit**:
```csharp
GenUtil.FileGateClose(cLockFile);  // Release run lock
Qutils.ExitQueue(Info.DbName, "READ");  // Exit database queue
```

**Error Exit**:
```csharp
Qutils.ExitQueue(Info.DbName, "READ");  // Always exit queue on error
Application.Exit(ErrorCode);
```

---

## Concurrency Scenarios

### Scenario 1: Multiple TSIP Runs (Different Projects/Runs)

**Allowed**: ✅ **YES**

- Each run creates different lock file: `FCSA_PROJ1_RUN1_LOCK`, `FCSA_PROJ2_RUN2_LOCK`
- All runs enter READ queue (multiple READ processes allowed)
- **Result**: All runs execute simultaneously

---

### Scenario 2: Multiple TSIP Runs (Same Project/Run)

**Allowed**: ❌ **NO**

- Both runs try to create same lock file: `FCSA_PROJ1_RUN1_LOCK`
- First run acquires lock, second run fails `FileGate()` check
- Second run **skips that run** and continues (doesn't abort entire program)
- **Result**: Only one run processes that project/run combination

---

### Scenario 3: TSIP + WRITE Process

**Allowed**: ❌ **NO** (TSIP waits or times out)

- WRITE process holds `Global\FCSAWRITE` mutex
- TSIP (READ mode) tries to enter queue
- TSIP **waits up to 30 seconds** for WRITE mutex
- If timeout: TSIP exits with error 110
- **Result**: TSIP waits for WRITE process to finish, or times out

---

### Scenario 4: TSIP + Multiple READ Processes

**Allowed**: ✅ **YES**

- Multiple TSIP processes can all enter READ queue
- Each creates marker file: `files\read\{ProcessID}`
- All processes run simultaneously
- **Result**: Multiple TSIP runs execute concurrently

---

### Scenario 5: TSIP + HOLD Lock (Admin)

**Allowed**: ❌ **NO**

- Admin holds `Global\FCSAHOLD` mutex
- TSIP tries to enter queue
- TSIP **immediately fails** with error 100
- **Result**: TSIP cannot run (admin blocking all access)

---

## Potential Issues

### Issue 1: Orphaned Marker Files

**Problem**: If a READ process crashes, marker file remains

**Solution**: `Qutils.NoReadModeMarkerFiles()` validates marker files:
- Checks if process ID is still running
- Deletes orphaned files automatically
- Only blocks if process is actually running

**Status**: ✅ **HANDLED**

---

### Issue 2: Orphaned Lock Files

**Problem**: If TSIP crashes, `FileGate` mutex may remain locked

**Solution**: **NOT AUTOMATICALLY HANDLED**

**Current Behavior**:
- Mutex is process-scoped
- If process crashes, Windows should release mutex
- **But**: If process hangs (doesn't crash), mutex remains locked

**Manual Recovery**: 
- Kill hung process
- Or wait for process to complete/release

**Status**: ⚠️ **PARTIALLY HANDLED** (Windows releases on crash, but not on hang)

---

### Issue 3: FileGate Non-Blocking

**Problem**: If lock is held, TSIP **skips the run** (doesn't wait)

**Current Behavior**:
```csharp
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
    continue;  // Skip this run, continue to next
}
```

**Impact**: 
- If another TSIP is running the same project/run, this run is **skipped**
- No error reported to user (just warning log)
- Run may appear to complete successfully but didn't process that run

**Status**: ⚠️ **POTENTIAL ISSUE** - May cause confusion if run is silently skipped

---

## Summary

### Queue Management

| Level | Mechanism | Purpose | Scope |
|-------|-----------|---------|-------|
| **Level 1** | `Qutils.EnterQueue` | Database access coordination | Database-wide |
| **Level 2** | `GenUtil.FileGate` | Run-level locking | Project/Run specific |

### Access Modes

| Mode | Mutex Held | Marker File | Concurrent Access |
|------|------------|-------------|-------------------|
| **READ** | Brief (coordination) | Yes (`files\read\{PID}`) | ✅ Multiple allowed |
| **WRITE** | Entire processing | No | ❌ Exclusive only |

### Key Behaviors

1. ✅ **Multiple READ processes** can run simultaneously
2. ❌ **Only one WRITE process** can run at a time
3. ❌ **Same project/run** cannot run twice simultaneously (skipped)
4. ⚠️ **FileGate is non-blocking** - Skips run if lock held (potential issue)

---

## Recommendations for T-SQL Port

### Option 1: Replicate Current Behavior

**Use SQL Server Application Locks**:
```sql
-- Database-level queue (READ mode)
EXEC sp_getapplock @Resource = 'FCSA_READ_QUEUE', @LockMode = 'Shared', @LockTimeout = 30000;

-- Run-level lock
EXEC sp_getapplock @Resource = 'FCSA_PROJ1_RUN1_LOCK', @LockMode = 'Exclusive', @LockTimeout = 0;

-- Release locks
EXEC sp_releaseapplock @Resource = 'FCSA_PROJ1_RUN1_LOCK';
EXEC sp_releaseapplock @Resource = 'FCSA_READ_QUEUE';
```

### Option 2: Improve Current Behavior

**Add blocking option to FileGate**:
- Allow TSIP to wait for run lock (with timeout)
- Or queue runs instead of skipping them

---

## References

- **Queue Implementation**: `_Utillib/Qutils.cs`
- **FileGate Implementation**: `_Utillib/GenUtil.cs` (lines 207-267)
- **TSIP Usage**: `TpRunTsip/TpRunTsip.cs` (lines 174, 318, 627)

