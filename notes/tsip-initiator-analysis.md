# TsipInitiator Analysis - How It Manages TSIP Runs

**Purpose**: Understand how TsipInitiator works and how it might cause the infinite retry loop.

**Analysis Date**: January 2026

---

## Overview

**TsipInitiator** is a supervisory framework that:
- Manages a queue of TSIP jobs
- Spawns and supervises multiple concurrent instances of `TpRunTsip.exe`
- Sends TSIP output reports to users as email attachments
- Is launched by **WebMICS** whenever a user requests a TSIP run

**Key Concept**: Each instance of `TpRunTsip.exe` occupies one TSIP "slot". TsipInitiator limits the number of available slots (default: 5 as of 30-Jul-2018).

---

## TsipInitiator Main Flow

### Entry Point

**File**: `TsipInitiator\TsipInitiator.cs`  
**Method**: `Main(string[] args)`

### Command-Line Arguments

```
TsipInitiator <dbName> <project> <paramTableName> [-o<prefix>] [-p<binDirPath>]
```

**Example**:
```
TsipInitiator fcsa hulme1_0 -otsip myParamFileName
```

---

## Step-by-Step Execution Flow

### Step 1: Initialization (Lines 104-179)

```csharp
// Parse command-line arguments
ParseCommandLineArgs(ref args, out dbName, out projectCode, out paramFileName, out reportPrefix);

// Get current date/time
GenUtil.UtGetDateTime(out curDate, out curTime);

// Initialize TSIP log file access
nRet = TsipQ.InitTsipLogFileAccess(dbName);

// Connect to database
nRet = Ssutil.UtConnect(dbName, userSessionID);

// Get next job number
nJob = Ssutil.GetNextNum(cTsipJob);  // cTsipJob = "TSIPJOB" + dbName

// Get user info
UserInfo.UtGetUserInfo(out userInfo);
```

**Key Point**: Each TSIP run gets a **unique job number** (`nJob`).

---

### Step 2: Insert Job into Queue (Lines 213-234)

```csharp
// Create event name for signaling
cEventName = String.Format("Global\\TSIPJOB{0}{1}", dbName, nJob);

// Insert into queue as "waiting" (status = 'W')
nRet = TsipQ.InsertTsipQ(nJob, dbName, projectCode, reportPrefix, paramFileName, cEventName, userInfo.micsUser.micsid);
```

**What This Does**:
- Inserts a record into `web.tsip_queue` table
- Status set to `'W'` (Waiting)
- Process ID set to `0`
- Creates a unique event name for inter-process signaling

**Queue Table Schema** (`web.tsip_queue`):
- `TQ_Job` - Unique job number
- `TQ_Status` - Status: 'W' (Waiting), 'X' (Running), 'F' (Finished), 'D' (Deleted)
- `TQ_Finish` - Exit code from TpRunTsip
- `TQ_ArgDB`, `TQ_ArgPC`, `TQ_ArgDest`, `TQ_ArgFile` - Job parameters
- `TQ_ProcID` - Windows process ID of TpRunTsip.exe
- `TQ_EventName` - Event name for signaling
- `TQ_MicsID` - User ID
- `TQ_TimeIn`, `TQ_TimeStart`, `TQ_TimeEnd` - Timestamps

---

### Step 3: Wait for Available Slot (Lines 275-414)

```csharp
nRet = 0;
nTime = 0;
while (nRet == 0)
{
    nTime++;
    
    // Try to enter database queue (READ mode)
    if ((nQRet = Qutils.EnterQueue(dbName, "READ", 30)) != Constant.SUCCESS)
    {
        // Wait 30 seconds and try again
        Thread.Sleep(30 * 1000);
        continue;
    }
    
    // Check if slot is available
    if ((nRet = TsipQ.TestAndFlag(dbName, nJob, "X")) == 0)
    {
        // Slot available! Break out of loop to start TSIP
        break;
    }
    else if (nRet == Error.JOB_HAS_NO_ROOM_TO_RUN)
    {
        // No slot available - wait for event signal
        if (TsipQ.CheckRunningProgs() == Constant.SUCCESS)
        {
            nRet = TsipQ.WaitForEvent(nJob);  // Blocks until signaled
        }
        else
        {
            continue;  // Some slots weren't running, try again
        }
    }
    else if (nRet == Error.JOB_IN_QUEUE_HAS_BEEN_DELETED)
    {
        // Job was deleted - exit
        IsDeleted = true;
        break;
    }
    else
    {
        // Error - exit
        break;
    }
}
```

**Key Points**:
- **`TestAndFlag()`** checks if there's an available slot (less than `MaxTsips` running)
- If slot available, updates job status to `'X'` (Running) and breaks
- If no slot, **waits for event signal** from another TsipInitiator that's finishing
- **`CheckRunningProgs()`** cleans up "zombie" jobs (marked as running but process doesn't exist)

---

### Step 4: Start TpRunTsip Process (Lines 312-369)

```csharp
// Open console file for output
twConsoleFile = new StreamWriter(consoleFilePath);

// Redirect stdout/stderr to console file
Console.SetOut(twConsoleFile);
Console.SetError(twConsoleFile);

// Spawn TpRunTsip.exe as independent process
tsipProcessID = TsipQ.StartTsip(dbName, args, destPath, nJob, out tsipProcess);

if (tsipProcessID > 0)
{
    // Wait for TpRunTsip to finish
    tsipProcess.WaitForExit();
    
    // Capture exit code
    tpRunTsipExitCode = nRet = tsipProcess.ExitCode;
    
    Console.Write("\n\nTpRunTsip.exe:      exit code = {0}", tsipProcess.ExitCode);
}

// Restore stdout/stderr
Console.SetOut(twOldStdOut);
Console.SetError(twOldStdErr);

Qutils.ExitQueue(dbName, "READ");
```

**Key Points**:
- **Spawns `TpRunTsip.exe` as a separate Windows process**
- **Waits for process to finish** (`WaitForExit()`)
- **Captures exit code** (`tsipProcess.ExitCode`)
- **Does NOT retry** - TsipInitiator itself does not restart TpRunTsip on failure

---

### Step 5: End Job and Signal Next Jobs (Lines 417-425)

```csharp
if (IsDeleted)
{
    TsipQ.EndJob(nJob, "D", nRet);  // Deleted
}
else
{
    TsipQ.EndJob(nJob, "F", nRet);  // Finished
}
```

**What `EndJob()` Does** (`TsipQ.cs`, lines 613-735):
1. Updates job status to `'F'` (Finished) or `'D'` (Deleted)
2. Sets `TQ_Finish` to the exit code (`nRet`)
3. Sets `TQ_TimeEnd` to current timestamp
4. **Signals waiting jobs** to start (if slots available)

**Key Method**: `EndJob()` calls `SignalEvent()` for each waiting job that can now run.

---

### Step 6: Send Email Reports (Lines 427-472)

```csharp
// Get email address
nRet = Ssutil.EmailAddr(userid, userInfo.micsUser.micsid, out cEmail, nMaxLen, out tsip_email, out cDelFlag);

if (!IsDeleted && (nRet == 0) && (tpRunTsipExitCode == 0))
{
    // Only send email if exit code is 0 (SUCCESS)
    if (userWantsEmail)
    {
        sendEmailRetVal = EmailReportsToUser(paramFileName, cDelFlag, dbName, destPath, cFileRoot, cEmail, IsDeleted);
    }
}
else if (tpRunTsipExitCode != 0)
{
    // Log error - exit code was not 0
    TsipQ.WriteToTsipLog(String.Format("\nERROR: TpRunTsip.exe failed, returned exitCode = {0}", tpRunTsipExitCode));
    Log2.e("\nTsipInitiator.Main(): ERROR: TpRunTsip.exe failed, returned exitCode = " + tpRunTsipExitCode);
}
```

**Key Point**: Email is **only sent if exit code is 0** (SUCCESS). If exit code is non-zero, error is logged but **no email sent**.

---

### Step 7: Exit (Lines 474-481)

```csharp
// Close console file
twConsoleFile.Close();

// Disconnect from database
Ssutil.UtDisconnect(userSessionID);

// Exit with email send result
Application.Exit(sendEmailRetVal);
```

**Key Point**: TsipInitiator exits with the email send result, **NOT** the TpRunTsip exit code.

---

## Critical Finding: TsipInitiator Does NOT Retry

### No Retry Logic in TsipInitiator

**Analysis of `TsipInitiator.cs`**:
- ✅ Spawns TpRunTsip process
- ✅ Waits for it to finish
- ✅ Captures exit code
- ✅ Logs error if exit code != 0
- ❌ **Does NOT retry** - No code that restarts TpRunTsip on failure
- ❌ **Does NOT check exit code** to decide whether to retry
- ❌ **Exits immediately** after TpRunTsip finishes

**Conclusion**: **TsipInitiator itself does NOT cause the infinite loop.**

---

## So What Causes the Infinite Loop?

### Hypothesis 1: WebMICS Retries on Failure (MOST LIKELY)

**Scenario**: WebMICS monitors TsipInitiator exit codes or TSIP queue status and automatically retries failed jobs.

**How It Might Work**:
1. User initiates TSIP run via WebMICS
2. WebMICS calls `TsipInitiator.exe` with job parameters
3. TsipInitiator spawns TpRunTsip, waits, captures exit code
4. TsipInitiator exits (with email send result, not TpRunTsip exit code)
5. **WebMICS checks `web.tsip_queue` table** - sees `TQ_Finish != 0` (failure)
6. **WebMICS automatically calls TsipInitiator again** with same parameters
7. Cycle repeats indefinitely

**Evidence Needed**:
- Check WebMICS code for retry logic
- Check if WebMICS monitors `TQ_Finish` column
- Check if WebMICS has a scheduled task or polling mechanism

---

### Hypothesis 2: Database Trigger or Stored Procedure

**Scenario**: A database trigger or stored procedure monitors `web.tsip_queue` and automatically re-queues failed jobs.

**How It Might Work**:
1. TpRunTsip fails, exits with FAILURE
2. TsipInitiator calls `EndJob(nJob, "F", FAILURE)`
3. `EndJob()` updates `TQ_Finish = FAILURE` in database
4. **Database trigger fires** on `TQ_Finish != 0`
5. **Trigger inserts new job** into queue with same parameters
6. New TsipInitiator instance picks up job
7. Cycle repeats

**Evidence Needed**:
- Check for triggers on `web.tsip_queue` table
- Check for stored procedures that monitor queue status
- Check for scheduled SQL Server jobs

---

### Hypothesis 3: Scheduled Task or Service

**Scenario**: A Windows scheduled task or service monitors the queue and automatically retries failed jobs.

**How It Might Work**:
1. Scheduled task runs periodically (e.g., every minute)
2. Queries `web.tsip_queue` for jobs with `TQ_Finish != 0` and `TQ_Status = 'F'`
3. For each failed job, **calls TsipInitiator again** with same parameters
4. Cycle repeats

**Evidence Needed**:
- Check Windows Task Scheduler for tasks related to TSIP
- Check for Windows services that monitor the queue
- Check for PowerShell scripts or batch files that retry jobs

---

### Hypothesis 4: Multiple TsipInitiator Instances (UNLIKELY)

**Scenario**: Multiple TsipInitiator instances are running, and one of them keeps picking up the same job.

**Why This Is Unlikely**:
- `InsertTsipQ()` checks for duplicates (lines 126-156)
- If job already in queue with status 'W' or 'X', returns `Error.ALREADY_IN_QUEUE`
- Jobs are processed once and marked as 'F' (Finished)

---

## The Real Question: What Monitors TQ_Finish?

### Key Database Column: `TQ_Finish`

**Location**: `web.tsip_queue` table, `TQ_Finish` column

**Values**:
- `0` = Success
- `!= 0` = Failure (exit code from TpRunTsip)

**Who Checks This?**:
- ❌ **Not TsipInitiator** - It logs the error but doesn't retry
- ❌ **Not TpRunTsip** - It just exits with a code
- ✅ **Likely WebMICS** - Probably monitors this to decide whether to retry
- ✅ **Possibly database trigger/stored procedure** - Could automatically re-queue
- ✅ **Possibly scheduled task/service** - Could poll and retry

---

## How the Infinite Loop Actually Works

### The Complete Flow

**Initial User Action**:
1. User clicks "Run TSIP" in WebMICS (one-time action)

**First Iteration**:
2. WebMICS calls `TsipInitiator.exe` with job parameters
3. TsipInitiator inserts job into `web.tsip_queue` (status='W')
4. TsipInitiator waits for slot, then spawns `TpRunTsip.exe`
5. TpRunTsip processes parameter records
6. One record fails (e.g., ReportStudy fails)
7. `exitCode = Constant.FAILURE` is set
8. TpRunTsip exits with FAILURE
9. TsipInitiator captures exit code (`tpRunTsipExitCode = FAILURE`)
10. TsipInitiator calls `EndJob(nJob, "F", FAILURE)`
11. `EndJob()` updates `TQ_Finish = FAILURE` in database
12. TsipInitiator exits (does NOT retry)

**Second Iteration (AUTOMATED)**:
13. **Something (WebMICS/trigger/task) monitors `TQ_Finish`**
14. **Sees `TQ_Finish != 0` (failure)**
15. **Automatically calls `TsipInitiator.exe` again** with same parameters
16. **OR automatically inserts new job** into queue with same parameters
17. New TsipInitiator instance picks up job
18. Spawns TpRunTsip again
19. **Same error occurs** (e.g., ReportStudy still fails)
20. **Cycle repeats indefinitely**

---

## Evidence from Code

### TsipInitiator Does NOT Retry

**Line 348**: Captures exit code but doesn't use it for retry
```csharp
tpRunTsipExitCode = nRet = tsipProcess.ExitCode;
```

**Line 465**: Logs error but doesn't retry
```csharp
else if (tpRunTsipExitCode != 0)
{
    TsipQ.WriteToTsipLog(String.Format("\nERROR: TpRunTsip.exe failed, returned exitCode = {0}", tpRunTsipExitCode));
    Log2.e("\nTsipInitiator.Main(): ERROR: TpRunTsip.exe failed, returned exitCode = " + tpRunTsipExitCode);
}
```

**Line 481**: Exits immediately (no retry loop)
```csharp
Application.Exit(sendEmailRetVal);
```

---

### EndJob() Signals Next Jobs, But Doesn't Retry Same Job

**Line 636**: Updates `TQ_Finish` with exit code
```csharp
cSQL = String.Format("update web.tsip_queue set TQ_Status = '{0}', TQ_Finish={1}, TQ_TimeEnd = CURRENT_TIMESTAMP where TQ_Job = {2} ",
                     cStatus, nRet, nJob);
```

**Lines 674-728**: Signals **waiting jobs** (different jobs), not the same job
```csharp
// Start the maximum number of new tsips that we are allowed.
if (nToStart > 0)
{
    // Identify any tsip jobs that are currently marked as waiting (W).
    cSQL = "Select TQ_Job, TQ_EventName from web.tsip_queue where TQ_Status = 'W' order by TQ_Job ";
    // ... signals waiting jobs to start ...
}
```

**Key Point**: `EndJob()` only signals **other waiting jobs**, not the same job that just failed.

---

## Recommended Investigation

### 1. Check WebMICS Code

**Look for**:
- Code that calls `TsipInitiator.exe`
- Code that monitors `web.tsip_queue` table
- Code that checks `TQ_Finish` column
- Retry logic based on exit codes
- Scheduled tasks or polling mechanisms

**Questions**:
- Does WebMICS have a background service that monitors the queue?
- Does WebMICS poll `web.tsip_queue` periodically?
- Does WebMICS automatically retry failed jobs?

---

### 2. Check Database

**Look for**:
- Triggers on `web.tsip_queue` table
- Stored procedures that monitor queue status
- SQL Server Agent jobs that query the queue
- Views or functions that automatically re-queue failed jobs

**SQL to Check**:
```sql
-- Check for triggers
SELECT * FROM sys.triggers WHERE parent_id = OBJECT_ID('web.tsip_queue');

-- Check for stored procedures that reference tsip_queue
SELECT * FROM sys.procedures WHERE OBJECT_DEFINITION(object_id) LIKE '%tsip_queue%';

-- Check SQL Server Agent jobs
SELECT * FROM msdb.dbo.sysjobs WHERE command LIKE '%tsip%' OR command LIKE '%TSIP%';
```

---

### 3. Check Windows Scheduled Tasks

**Look for**:
- Tasks that run `TsipInitiator.exe`
- Tasks that monitor the TSIP queue
- Tasks that retry failed jobs
- PowerShell scripts or batch files that query the database

**Commands**:
```powershell
# List all scheduled tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like '*tsip*' -or $_.TaskName -like '*TSIP*'}

# Check task actions
Get-ScheduledTask | Get-ScheduledTaskInfo
```

---

### 4. Check for Monitoring Services

**Look for**:
- Windows services related to MICS/TSIP
- Background processes that monitor the queue
- Log files that show retry attempts

---

## Job Status System and Signaling Mechanism

### Job Status Values

**Location**: `web.tsip_queue` table, `TQ_Status` column

**Status Values**:
- **`'W'`** = **Waiting** - Job is in queue, waiting for an available slot
- **`'X'`** = **Running** - Job is currently executing (TpRunTsip process is running)
- **`'F'`** = **Finished** - Job has completed (successfully or with failure)
- **`'D'`** = **Deleted** - Job was deleted before completion

---

### How a Job Becomes "Waiting"

#### Step 1: Job Insertion (Status = 'W')

**Location**: `TsipQ.InsertTsipQ()` (`TsipQ.cs`, lines 108-163)

```csharp
// Insert into queue with status 'W' (Waiting)
cSQL = String.Format("INSERT INTO [web].[tsip_queue] ([TQ_Job],[TQ_Status],[TQ_ArgDB],[TQ_ArgPC],[TQ_ArgDest], [TQ_ArgFile],[TQ_ProcID],[TQ_EventName],[TQ_MicsID],  [TQ_TimeIn]) VALUES ({0}, 'W', '{1}', '{2}', '{3}', '{4}', 0, '{5}', '{6}', CURRENT_TIMESTAMP)",
                     nJob, dbName, pcode, destarg, cFileName, cEventName, cMicsID);
```

**What Happens**:
1. **Unique job number** is allocated (`nJob = Ssutil.GetNextNum("TSIPJOB" + dbName)`)
2. **Event name is created**: `"Global\\TSIPJOB{dbName}{nJob}"` (e.g., `"Global\\TSIPJOBFCSA677"`)
3. **Job is inserted** into `web.tsip_queue` with:
   - `TQ_Status = 'W'` (Waiting)
   - `TQ_ProcID = 0` (No process yet)
   - `TQ_EventName = "Global\\TSIPJOB{dbName}{nJob}"` (Unique event name for signaling)

**Key Point**: **All jobs start with status 'W' (Waiting)** when first inserted into the queue.

---

#### Step 2: Checking for Available Slot

**Location**: `TsipInitiator.Main()` (`TsipInitiator.cs`, lines 275-414)

```csharp
while (nRet == 0)
{
    // Try to enter database queue
    if ((nQRet = Qutils.EnterQueue(dbName, "READ", 30)) != Constant.SUCCESS)
    {
        Thread.Sleep(30 * 1000);
        continue;
    }
    
    // Check if slot is available
    if ((nRet = TsipQ.TestAndFlag(dbName, nJob, "X")) == 0)
    {
        // Slot available! Status changed from 'W' to 'X'
        break;  // Exit loop, proceed to start TSIP
    }
    else if (nRet == Error.JOB_HAS_NO_ROOM_TO_RUN)
    {
        // No slot available - must wait
        nRet = TsipQ.WaitForEvent(nJob);  // Blocks here until signaled
    }
}
```

**What `TestAndFlag()` Does** (`TsipQ.cs`, lines 177-236):

```csharp
public static int TestAndFlag(string cDatabase, int nJob, string cFlag)
{
    // Get maximum number of concurrent TSIP runs (default: 5)
    int nMax = GetMaxTsips();
    
    // Count how many are currently running (status = 'X')
    int nRunning = Ssutil.DbCountRows("web.tsip_queue", "TQ_Status = 'X' ");
    
    if (nRunning < nMax)
    {
        // Slot available! Change status from 'W' to 'X' (Running)
        cSQL = String.Format("Update web.tsip_queue set TQ_Status = '{0}', TQ_TimeIn = CURRENT_TIMESTAMP, TQ_ProcID = -1 where TQ_Job = {1}",
                            cFlag, nJob);  // cFlag = "X"
        nRet = Ssutil.DbExecute(cSQL) ? 0 : -2;
    }
    else
    {
        // No slot available
        nRet = Error.JOB_HAS_NO_ROOM_TO_RUN;
    }
    
    return nRet;
}
```

**Key Points**:
- **Checks if `nRunning < nMax`** (default max = 5)
- **If slot available**: Updates status from `'W'` to `'X'` (Running)
- **If no slot**: Returns `Error.JOB_HAS_NO_ROOM_TO_RUN`
- **Job remains with status 'W'** (Waiting) until a slot becomes available

---

### How Waiting Jobs Are Signaled

#### The Signaling Mechanism: UDP-Based Inter-Process Communication

**Key Methods**:
- `SignalEvent(nJob)` - Sends signal to a waiting job
- `WaitForEvent(nJob)` - Waits for signal (blocks until received)

---

#### Step 1: Job Finishes and Signals Next Jobs

**Location**: `TsipQ.EndJob()` (`TsipQ.cs`, lines 613-735)

**When Called**: After TpRunTsip finishes (success or failure)

```csharp
public static int EndJob(int nJob, string cStatus, int nRet)
{
    // 1. Update finished job status to 'F' (Finished)
    cSQL = String.Format("update web.tsip_queue set TQ_Status = '{0}', TQ_Finish={1}, TQ_TimeEnd = CURRENT_TIMESTAMP where TQ_Job = {2} ",
                         cStatus, nRet, nJob);  // cStatus = "F", nRet = exit code
    Ssutil.DbExecute(cSQL);
    
    // 2. Calculate how many slots are now available
    int nMaxTsips = GetMaxTsips();  // e.g., 5
    int nTsipsRunning = Ssutil.DbCountRows("web.tsip_queue", "TQ_Status = 'X' ");  // e.g., 4 (one just finished)
    int nToStart = nMaxTsips - nTsipsRunning;  // e.g., 5 - 4 = 1 slot available
    
    // 3. Find waiting jobs and signal them
    if (nToStart > 0)
    {
        // Query for jobs with status 'W' (Waiting), ordered by job number (FIFO)
        cSQL = "Select TQ_Job, TQ_EventName from web.tsip_queue where TQ_Status = 'W' order by TQ_Job ";
        
        // Signal up to nToStart waiting jobs
        for (nInd = 0; nInd < nToStart; nInd++)
        {
            // Fetch next waiting job
            ODBC.SQLFetch(hStmt);
            Ssutil.DbGetInt(hStmt, 1, "TQ_Job", out targetJob, out nNull);
            Ssutil.DbGetString(hStmt, 2, "TQ_EventName", out cEventName, ...);
            
            // Signal this waiting job
            SignalEvent(targetJob);
        }
    }
}
```

**Key Points**:
- **Only signals jobs with status 'W' (Waiting)**
- **Signals jobs in FIFO order** (`order by TQ_Job`)
- **Signals up to `nToStart` jobs** (number of available slots)
- **Does NOT signal the same job that just finished** - only other waiting jobs

---

#### Step 2: SignalEvent() - Sends UDP Message

**Location**: `TsipQ.SignalEvent()` (`TsipQ.cs`, lines 744-761)

```csharp
public static int SignalEvent(int nJob)
{
    // Convert job number to UDP port number
    int port = SimpleUDP.HashToDynamicPortNumber(nJob);
    
    // Send UDP message "brocolli" to that port
    SimpleUDP.Send(port, "brocolli");
    
    return Constant.SUCCESS;
}
```

**How It Works**:
1. **Job number is hashed to a UDP port number** (e.g., job 677 → port 12345)
2. **UDP message "brocolli" is sent** to `localhost:port`
3. **The waiting TsipInitiator instance** is listening on that port

**Key Point**: Each job has a **unique UDP port** based on its job number, allowing multiple TsipInitiator instances to wait on different ports simultaneously.

---

#### Step 3: WaitForEvent() - Receives UDP Message

**Location**: `TsipQ.WaitForEvent()` (`TsipQ.cs`, lines 771-786)

```csharp
public static int WaitForEvent(int nJob)
{
    string message;
    
    // Convert job number to UDP port number (same hash function)
    int port = SimpleUDP.HashToDynamicPortNumber(nJob);
    
    // Block until UDP message is received on this port
    SimpleUDP.Receive(port, out message);
    
    return Constant.SUCCESS;
}
```

**How It Works**:
1. **Job number is hashed to UDP port number** (same hash as SignalEvent)
2. **Blocks waiting for UDP message** on that port
3. **When message received**, returns SUCCESS
4. **TsipInitiator continues** and calls `TestAndFlag()` again

**Key Point**: **`WaitForEvent()` blocks indefinitely** until a UDP message is received. This allows multiple TsipInitiator instances to wait simultaneously without polling the database.

---

### Complete Job Lifecycle

#### State Transition Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    TSIP JOB LIFECYCLE                        │
└─────────────────────────────────────────────────────────────┘

1. INSERT (Status = 'W')
   └─> TsipInitiator.InsertTsipQ()
       └─> Job inserted with TQ_Status = 'W' (Waiting)
           └─> TQ_EventName = "Global\\TSIPJOB{dbName}{nJob}"

2. CHECK FOR SLOT
   └─> TsipInitiator calls TestAndFlag()
       ├─> If slot available (nRunning < nMax):
       │   └─> UPDATE Status = 'X' (Running) ✅
       │       └─> Proceed to start TpRunTsip
       │
       └─> If no slot (nRunning >= nMax):
           └─> Status remains 'W' (Waiting) ⏳
               └─> Call WaitForEvent(nJob)
                   └─> Blocks waiting for UDP message

3. WAITING FOR SIGNAL
   └─> WaitForEvent(nJob) blocks on UDP port
       └─> Another job finishes
           └─> EndJob() calls SignalEvent(targetJob)
               └─> UDP message sent to waiting job's port
                   └─> WaitForEvent() receives message
                       └─> Returns SUCCESS
                           └─> Loop back to Step 2 (CHECK FOR SLOT)

4. RUNNING (Status = 'X')
   └─> TpRunTsip.exe spawned and running
       └─> TQ_ProcID = process ID
       └─> TQ_TimeStart = current timestamp

5. FINISHED (Status = 'F')
   └─> TpRunTsip.exe exits
       └─> TsipInitiator calls EndJob(nJob, "F", exitCode)
           ├─> UPDATE Status = 'F' (Finished)
           ├─> UPDATE TQ_Finish = exitCode
           ├─> UPDATE TQ_TimeEnd = current timestamp
           └─> SignalEvent() called for waiting jobs
               └─> Waiting jobs wake up and check for slots
```

---

### Example: Multiple Jobs in Queue

**Scenario**: 7 jobs submitted, max slots = 5

**Initial State**:
```
Job 100: Status='W' (Waiting) - No slot available
Job 101: Status='W' (Waiting) - No slot available
Job 102: Status='X' (Running) - Process ID 1234
Job 103: Status='X' (Running) - Process ID 1235
Job 104: Status='X' (Running) - Process ID 1236
Job 105: Status='X' (Running) - Process ID 1237
Job 106: Status='X' (Running) - Process ID 1238
```

**What Happens**:
1. **Jobs 100, 101**: Status='W', call `WaitForEvent()` and block
2. **Jobs 102-106**: Status='X', running TpRunTsip
3. **Job 102 finishes**: Calls `EndJob(102, "F", exitCode)`
   - Updates Job 102: Status='F', TQ_Finish=exitCode
   - Calculates: `nToStart = 5 - 4 = 1` (one slot available)
   - Queries: `SELECT TQ_Job FROM web.tsip_queue WHERE TQ_Status = 'W' ORDER BY TQ_Job`
   - Finds: Job 100 (first in queue)
   - Calls: `SignalEvent(100)`
   - Sends UDP message to Job 100's port
4. **Job 100 receives signal**: `WaitForEvent(100)` returns
   - Calls `TestAndFlag(100, "X")` again
   - Slot available! Updates Status='X'
   - Spawns TpRunTsip for Job 100
5. **Job 101**: Still waiting, still blocked in `WaitForEvent(101)`

---

## Key Insights

### 1. Jobs Are Designated as "Waiting" at Insertion

**When**: Immediately when `InsertTsipQ()` is called

**Status**: `TQ_Status = 'W'` (Waiting)

**Remains Waiting Until**:
- A slot becomes available (`nRunning < nMax`)
- `TestAndFlag()` successfully changes status to `'X'` (Running)

---

### 2. Signaling Uses UDP, Not Database Polling

**Why UDP?**:
- **Efficient**: No database polling required
- **Scalable**: Multiple instances can wait simultaneously
- **Low latency**: Immediate wake-up when slot available
- **No polling overhead**: Waiting jobs don't consume CPU/database resources

**How It Works**:
- Each job has a **unique UDP port** (hashed from job number)
- Waiting job **blocks on UDP receive** (no CPU usage)
- Finishing job **sends UDP message** to wake up waiting job
- **One-to-one signaling**: Each waiting job has its own port

---

### 3. EndJob() Only Signals Other Jobs, Not Same Job

**Critical Point**: When a job finishes:
- ✅ Updates its own status to `'F'` (Finished)
- ✅ Signals **other waiting jobs** (status='W')
- ❌ **Does NOT signal itself**
- ❌ **Does NOT re-queue the same job**

**This Confirms**: **TsipInitiator does NOT cause the infinite loop** - it only signals different jobs.

---

### 4. No Database Triggers or Scheduled Jobs

**Confirmed**: User stated there are no database triggers or scheduled jobs.

**Implication**: The retry mechanism must be:
- ✅ **WebMICS** - Monitors queue and retries failed jobs
- ✅ **Application-level logic** - Some code that checks `TQ_Finish` and re-queues
- ❌ **NOT database triggers**
- ❌ **NOT SQL Server Agent jobs**

---

## Updated Root Cause Hypothesis

### Most Likely: WebMICS Retry Logic

**Since there are no database triggers or scheduled jobs**, the retry must be in **WebMICS application code**:

**How It Might Work**:
1. User initiates TSIP run via WebMICS
2. WebMICS calls `TsipInitiator.exe` with job parameters
3. TsipInitiator processes job, TpRunTsip fails
4. `EndJob()` updates `TQ_Finish = FAILURE` in database
5. **WebMICS has background thread/service** that:
   - Polls `web.tsip_queue` table periodically
   - Checks for jobs with `TQ_Finish != 0` and `TQ_Status = 'F'`
   - **Automatically calls TsipInitiator again** with same parameters
   - **OR automatically inserts new job** into queue
6. New TsipInitiator instance picks up job
7. Cycle repeats

**Evidence Needed**:
- Check WebMICS code for queue monitoring
- Check WebMICS for retry logic
- Check WebMICS for background services/threads
- Check WebMICS logs for retry attempts

---

## Summary

### Key Findings

1. **Jobs start as 'W' (Waiting)** when inserted into queue
2. **TestAndFlag() changes status to 'X' (Running)** when slot available
3. **EndJob() signals other waiting jobs** via UDP when a job finishes
4. **UDP-based signaling** allows efficient inter-process communication
5. **TsipInitiator does NOT retry** - only signals different jobs
6. **No database triggers or scheduled jobs** - retry must be in application code (likely WebMICS)

### Most Likely Cause

**WebMICS application code** that:
- Monitors `web.tsip_queue` table
- Checks `TQ_Finish` column for failures
- Automatically calls `TsipInitiator.exe` again with same parameters
- Creates infinite retry loop

### Next Steps

1. **Examine WebMICS code** for retry logic
2. **Check WebMICS** for background services/threads that monitor the queue
3. **Add logging** to track who is calling TsipInitiator
4. **Check WebMICS logs** for retry attempts

---

*Last Updated: January 2026*

