# EndJob() Analysis - Does It Exclude Current Job?

**Question**: Does `EndJob()` explicitly check against the current job's job number when signaling waiting jobs?

**Analysis Date**: January 2026

---

## Code Analysis

### EndJob() Method Flow

**Location**: `_Utillib\TsipQ.cs`, lines 613-735

```csharp
public static int EndJob(int nJob, string cStatus, int nRet)
{
    // ... initialization ...
    
    // Step 1: Update current job status to 'F' (Finished)
    cSQL = String.Format("update web.tsip_queue set TQ_Status = '{0}', TQ_Finish={1}, TQ_TimeEnd = CURRENT_TIMESTAMP where TQ_Job = {2} ",
                         cStatus, nRet, nJob);  // nJob is the current job number
    IsOK = Ssutil.DbExecute(cSQL);
    
    // ... guard logic ...
    
    // Step 2: Query for waiting jobs
    if (nToStart > 0)
    {
        // Identify any tsip jobs that are currently marked as waiting (W).
        cSQL = "Select TQ_Job, TQ_EventName from web.tsip_queue where TQ_Status = 'W' order by TQ_Job ";
        
        // ... execute query and signal waiting jobs ...
        for (nInd = 0; nInd < nToStart; nInd++)
        {
            ODBC.SQLFetch(hStmt);
            Ssutil.DbGetInt(hStmt, 1, "TQ_Job", out targetJob, out nNull);
            SignalEvent(targetJob);  // Signal the waiting job
        }
    }
}
```

---

## Critical Finding: NO Explicit Exclusion

### The SQL Query

**Line 678**: 
```sql
Select TQ_Job, TQ_EventName from web.tsip_queue where TQ_Status = 'W' order by TQ_Job
```

**Key Observation**: 
- ❌ **NO explicit exclusion** of current job: `TQ_Job != {nJob}` is **NOT** in the WHERE clause
- ✅ **Relies on status change**: The query assumes the current job's status was changed to `'F'` (Finished) in Step 1

---

## How It's Supposed to Work

### Expected Behavior

1. **Line 636**: Current job status updated to `'F'` (Finished)
   ```sql
   UPDATE web.tsip_queue SET TQ_Status = 'F', TQ_Finish={exitCode}, TQ_TimeEnd = CURRENT_TIMESTAMP 
   WHERE TQ_Job = {nJob}
   ```

2. **Line 678**: Query for waiting jobs
   ```sql
   SELECT TQ_Job, TQ_EventName FROM web.tsip_queue WHERE TQ_Status = 'W' ORDER BY TQ_Job
   ```

3. **Expected Result**: Current job should **NOT** be in results because:
   - Its status was just changed to `'F'` (Finished)
   - Query only selects jobs with status `'W'` (Waiting)
   - Current job no longer matches `TQ_Status = 'W'`

---

## Potential Issues

### Issue 1: Transaction Isolation

**Problem**: If the UPDATE and SELECT are in different transactions or have different isolation levels, the SELECT might see the old status.

**Scenario**:
1. UPDATE executes, changes status to `'F'`
2. Transaction not yet committed
3. SELECT executes in different transaction/isolation level
4. SELECT might see old status `'X'` (Running) or even `'W'` (Waiting) if there's a race condition

**Likelihood**: ⚠️ **LOW** - Both operations use the same connection (`hConn`), so they should be in the same transaction context.

---

### Issue 2: Race Condition with Status Change

**Problem**: If the job's status is somehow still `'W'` when the SELECT runs, it could signal itself.

**Scenario**:
1. Job somehow has status `'W'` (Waiting) instead of `'X'` (Running)
2. UPDATE changes it to `'F'` (Finished)
3. But if UPDATE fails or doesn't commit, status might still be `'W'`
4. SELECT finds the job with status `'W'`
5. **Job signals itself!**

**Likelihood**: ⚠️ **MEDIUM** - Unlikely but possible if:
- UPDATE fails silently
- Database connection issue
- Job was never properly set to `'X'` (Running)

---

### Issue 3: Job Re-Queued Before EndJob() Completes

**Problem**: If something re-queues the job (changes status back to `'W'`) between the UPDATE and SELECT, the job could signal itself.

**Scenario**:
1. Job finishes, `EndJob(nJob, "F", exitCode)` called
2. UPDATE changes status to `'F'` (Finished)
3. **Something external re-queues the job** (changes status back to `'W'`)
4. SELECT runs, finds job with status `'W'`
5. **Job signals itself!**

**Likelihood**: ⚠️ **MEDIUM** - This could happen if:
- WebMICS or another process monitors the queue
- Sees `TQ_Finish != 0` (failure)
- Immediately re-queues the job (status = `'W'`)
- This happens **before** `EndJob()` completes the SELECT

**This Could Be The Bug!**

---

## The Potential Infinite Loop Scenario

### How EndJob() Could Signal the Same Job

**Timeline**:

**T0**: TpRunTsip fails, exits with FAILURE
- `tpRunTsipExitCode = FAILURE`

**T1**: TsipInitiator calls `EndJob(nJob, "F", FAILURE)`
- Line 636: UPDATE sets `TQ_Status = 'F'`, `TQ_Finish = FAILURE`

**T2**: **WebMICS (or monitoring process) detects failure**
- Polls `web.tsip_queue` table
- Sees `TQ_Finish = FAILURE` (non-zero)
- **Immediately re-queues job**: `UPDATE TQ_Status = 'W'` (Waiting)
- **OR inserts new job** with same parameters: `INSERT ... TQ_Status = 'W'`

**T3**: `EndJob()` continues execution
- Line 664: Counts running jobs: `nTsipsRunning = 4` (one just finished)
- Line 667: Calculates: `nToStart = 5 - 4 = 1` (one slot available)
- Line 678: **SELECT for waiting jobs**
  - **Finds the re-queued job** (status = `'W'`)
  - **OR finds a new job with same parameters** (status = `'W'`)
- Line 716: **Signals the job** (`SignalEvent(targetJob)`)

**T4**: Waiting TsipInitiator instance receives signal
- `WaitForEvent()` returns
- Calls `TestAndFlag()` again
- Slot available, spawns TpRunTsip again
- **Same error occurs**
- **Cycle repeats**

---

## Why This Could Cause Infinite Loop

### If WebMICS Re-Queues Immediately

**The Race Condition**:

```
Time    | Action
--------|--------------------------------------------------------
T0      | TpRunTsip fails, exits with FAILURE
T1      | TsipInitiator calls EndJob(nJob, "F", FAILURE)
T1.1    | UPDATE: TQ_Status = 'F', TQ_Finish = FAILURE
T1.2    | [WebMICS polls queue, sees TQ_Finish = FAILURE]
T1.3    | [WebMICS re-queues: UPDATE TQ_Status = 'W' OR INSERT new job]
T1.4    | EndJob() continues: SELECT WHERE TQ_Status = 'W'
T1.5    | [Finds re-queued/new job with status 'W']
T1.6    | SignalEvent(targetJob) - Signals the re-queued job!
T2      | Waiting TsipInitiator receives signal, spawns TpRunTsip
T3      | Same error occurs, cycle repeats
```

**Key Point**: If WebMICS re-queues the job **before** `EndJob()` completes the SELECT, the job could signal itself (or a duplicate job).

---

## Recommended Fix: Explicit Exclusion

### Add Explicit Check in SQL Query

**Current Code** (Line 678):
```csharp
cSQL = "Select TQ_Job, TQ_EventName from web.tsip_queue where TQ_Status = 'W' order by TQ_Job ";
```

**Recommended Fix**:
```csharp
cSQL = String.Format("Select TQ_Job, TQ_EventName from web.tsip_queue where TQ_Status = 'W' and TQ_Job != {0} order by TQ_Job ", nJob);
```

**Benefits**:
- ✅ **Explicitly excludes current job** - No reliance on status change
- ✅ **Prevents self-signaling** - Even if status is wrong, won't signal itself
- ✅ **Defensive programming** - Handles edge cases and race conditions
- ✅ **Clear intent** - Code explicitly shows we don't want to signal the current job

---

## Alternative: Check Before Signaling

### Add Check in Loop

**Current Code** (Lines 710-716):
```csharp
try
{
    int targetJob;
    Ssutil.DbGetInt(hStmt, 1, "TQ_Job", out targetJob, out nNull);
    Ssutil.DbGetString(hStmt, 2, "TQ_EventName", out cEventName, Constant.MAX_EVENT_NAME_SZ, out nNull);
    
    SignalEvent(targetJob);
}
```

**Recommended Fix**:
```csharp
try
{
    int targetJob;
    Ssutil.DbGetInt(hStmt, 1, "TQ_Job", out targetJob, out nNull);
    Ssutil.DbGetString(hStmt, 2, "TQ_EventName", out cEventName, Constant.MAX_EVENT_NAME_SZ, out nNull);
    
    // Explicitly check: don't signal the current job
    if (targetJob != nJob)
    {
        SignalEvent(targetJob);
    }
    else
    {
        Log2.w("\nTsipQ.EndJob(): WARNING: Attempted to signal current job {0}, skipping.", nJob);
    }
}
```

**Benefits**:
- ✅ **Double protection** - Even if SQL doesn't exclude it, code checks
- ✅ **Logging** - Warns if this edge case occurs
- ✅ **Safe** - Prevents self-signaling even in race conditions

---

## Summary

### Key Finding

**`EndJob()` does NOT explicitly exclude the current job number** in the SQL query that selects waiting jobs.

**Current Implementation**:
- ✅ Updates current job status to `'F'` (Finished) first
- ❌ **Does NOT explicitly exclude** `TQ_Job != {nJob}` in WHERE clause
- ⚠️ **Relies on status change** to prevent self-signaling

**Potential Issue**:
- If job is re-queued (status changed back to `'W'`) **before** SELECT executes
- Or if UPDATE doesn't commit before SELECT
- **Job could signal itself** (or a duplicate job)

### Recommended Fix

**Add explicit exclusion** in SQL query:
```sql
WHERE TQ_Status = 'W' AND TQ_Job != {nJob}
```

**OR add check before signaling**:
```csharp
if (targetJob != nJob)
{
    SignalEvent(targetJob);
}
```

---

*Last Updated: January 2026*

