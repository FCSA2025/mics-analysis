# TSIP Bug Fixes - Detailed Implementation Guide

**File**: `TpRunTsip.cs`  
**Purpose**: Fix lock release, stream closure, and exit code management bugs  
**Date**: January 2026

---

## Fix Overview

Three critical bugs need to be fixed:

1. **Lock Not Released on Error Paths** (lines 318-627)
2. **Streams Not Closed on Error Paths** (lines 330-631)
3. **Exit Code Set on Non-Fatal Errors** (multiple locations)

**Recommended Approach**: Wrap processing in `try-finally` block to ensure cleanup always happens.

---

## Fix 1: Wrap Processing in Try-Finally (PRIMARY FIX)

### Current Code Structure (Lines 310-634)

```csharp
// Line 310: Open report streams
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);

// Line 318: Acquire lock
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    mTW_ERR.Write("*ERROR* - TSIP is currently being run on this combination. Try again later.\r\n");
    Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
    continue; // Process the next parameter table.
}

// ... processing with many error paths that call continue ...

// Line 627: Release lock (ONLY on success)
GenUtil.FileGateClose(cLockFile);

// Line 631: Close streams (ONLY on success)
CloseReportStreams();
DeleteUnwantedReportFiles();
```

### Recommended Fix: Try-Finally Block

**Location**: Replace lines 310-634 with:

```csharp
// Line 310: Open report streams
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);

// Line 318: Acquire lock
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    /*	We have a locking situation.  Tell the user to come back later */
    mTW_ERR.Write("*ERROR* - TSIP is currently being run on this combination. Try again later.\r\n");
    Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
    
    // Close streams before continue (lock wasn't acquired, so no lock to release)
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    
    continue; // Process the next parameter table.
}

// Wrap all processing in try-finally to ensure cleanup
try
{
    // Re-open the Error file for this Tsip parameter record.
    // This is necessary for multiple records since the output is
    // redirected for reports after each Tsip parameter record is
    // processed.
    CreateErrorFile(Info.DestName, Info.PdfName, currParm.parmStruct.runname);

    // ... ALL EXISTING PROCESSING CODE FROM LINE 330 TO LINE 625 GOES HERE ...
    // This includes:
    // - Line 338-360: Spherecalc conversion, ohloss directories
    // - Line 366-378: PLAN PDF generation
    // - Line 400-413: ParmRecInit
    // - Line 440-506: TeBuildSH / TtBuildSH
    // - Line 519-524: UpdateParmRec
    // - Line 542-550: ReportStudy
    // - Line 579-588: ReportNew
    // - Line 598-617: TpExecRpt, TpExportRpt
    // - Line 625: KillTable(cUnique)
    
    // Success path - release lock and close streams
    GenUtil.FileGateClose(cLockFile);  /* Allow others to run this combo */
    CloseReportStreams();
    DeleteUnwantedReportFiles();
}
catch (Exception e)
{
    // Log unexpected exceptions
    Log2.e("\nTpRunTsip.Main(): Unexpected exception in parameter record processing: " + e.Message);
    Log2.e("\nTpRunTsip.Main(): Stack trace: " + e.StackTrace);
    mTW_ERR.Write("*ERROR* - Unexpected exception: {0}\r\n", e.Message);
    
    // Cleanup will happen in finally block
    throw; // Re-throw to preserve exception
}
finally
{
    // Always release lock and close streams, even on error
    try
    {
        // Check if lock was acquired (mFileGateMutex might be null if FileGate failed)
        // FileGateClose will handle null check internally if we fix it, but for safety:
        if (GenUtil.FileGateClose != null) // This won't compile - FileGateClose is static
        {
            GenUtil.FileGateClose(cLockFile);
        }
    }
    catch (Exception e)
    {
        Log2.e("\nTpRunTsip.Main(): Error releasing lock in finally: " + e.Message);
    }
    
    try
    {
        CloseReportStreams();
        DeleteUnwantedReportFiles();
    }
    catch (Exception e)
    {
        Log2.e("\nTpRunTsip.Main(): Error closing streams in finally: " + e.Message);
    }
}
```

**Note**: The `finally` block approach above has a syntax issue. Better approach below.

---

## Fix 1 (Revised): Simpler Try-Finally Without Exception Handling

**Better Approach**: Use a flag to track if lock was acquired, then cleanup in finally:

```csharp
// Line 310: Open report streams
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);

// Line 318: Acquire lock
bool lockAcquired = false;
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    /*	We have a locking situation.  Tell the user to come back later */
    mTW_ERR.Write("*ERROR* - TSIP is currently being run on this combination. Try again later.\r\n");
    Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
    
    // Close streams before continue (lock wasn't acquired, so no lock to release)
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    
    continue; // Process the next parameter table.
}
lockAcquired = true; // Mark that lock was successfully acquired

// Wrap all processing in try-finally to ensure cleanup
try
{
    // Re-open the Error file for this Tsip parameter record.
    CreateErrorFile(Info.DestName, Info.PdfName, currParm.parmStruct.runname);

    // The following code is here to provide compatability between the
    // old TSIP parameter files with Propogation Loss Method selection
    // for the ES side only, and the new files which permit up to 5
    // propogation loss methods for the TS side. Old TSIP parameter
    // files may have NULL spherecalc fields--this must be caught and
    // converted here.
    if (currParm.parmNulls[TpParm.SPHERECALC] == Constant.DB_NULL)
    {
        currParm.parmStruct.spherecalc = "3";
        currParm.parmNulls[TpParm.SPHERECALC] = Constant.DB_NOT_NULL;
    }
    else
    {
        if (Strings.FirstCharIs(currParm.parmStruct.spherecalc, 'N'))
        {
            currParm.parmStruct.spherecalc = "1";
        }
        if (Strings.FirstCharIs(currParm.parmStruct.spherecalc, 'Y'))
        {
            currParm.parmStruct.spherecalc = "2";
        }
    }

    //	If this is an ohloss calculation, print the directories...
    if (currParm.parmStruct.spherecalc[0] == '5')
    {
        string str = String.Format("\r\nOver Horizon Loss Calculation Directories:-\r\n1:250K - {0}\r\n1:50K  - {1}\r\n", dir250k, dir50k);
        mTW_ERR.Write(str);
    }

    // Check whether this is a PLAN mode analysis. If it is,
    // generate a temporaray PDF with all the PLAN channels in it. The
    // name of this new PDF becomes the PDf name in the parmStruct. The
    // PDF will be deleted at the end of the tsip run.
    if ((currParm.parmStruct.analopt.Equals("PLAN")) &&
                                         (currParm.parmStruct.protype.Equals("T")))
    {
        if (TpPlanChan.GenChan(currParm.parmStruct) != Constant.SUCCESS)
        {
            ErrMsg.UtPrintMessage(Error.NOPLANPDF);
            // REMOVED: exitCode = Constant.FAILURE;  // Fix 3: Don't set exit code on continue
            // REMOVED: continue;  // Will fall through to finally block
            // Instead, break out of try block to go to finally
            return; // Actually, we want to continue to next record, so use a different approach
        }

        UserInfo.UtUpdateCentralTable("A", currParm.parmStruct.proname, Constant.FT, "T", "N");
        UserInfo.UtUpdateCentralTable("U", currParm.parmStruct.proname, Constant.FT, "T", "N");
    }


    // Initialize the number of interference cases found for this tsip run.
    numIntCases = 0;
    numTeIntCases = 0;

    // Start a stop watch to calculate elapsed real-time.
    Stopwatch stopWatch = Stopwatch.StartNew();

    // Get the startDate and startTime to include in the exec report.
    GenUtil.UtGetDateTime(out startDate, out startTime);

    // ParmRecInit() write the current parm rec to mTW_ERR.
    // Also, check the validation status of the PDFs.
    if ((rc = ParmRecInit(currParm)) != Constant.SUCCESS)
    {
        if (rc != Constant.FAILURE)
        {
            ErrMsg.UtPrintMessage(rc);
            ErrMsg.UtPrintMessage(Error.DYN_MS_SQL_SERVER_ERR);
        }

        // REMOVED: CloseReportStreams();  // Will be done in finally
        // REMOVED: DeleteUnwantedReportFiles();  // Will be done in finally
        // REMOVED: exitCode = Constant.FAILURE;  // Fix 3: Don't set exit code
        // REMOVED: continue;  // Will fall through to finally block
        // Instead, we need to skip to next record, so we'll use a flag or break
    }
    else
    {
        // Continue with processing only if ParmRecInit succeeded
        // ... rest of processing code ...
    }
}
finally
{
    // Always release lock and close streams, even on error
    if (lockAcquired)
    {
        try
        {
            GenUtil.FileGateClose(cLockFile);
        }
        catch (Exception e)
        {
            Log2.e("\nTpRunTsip.Main(): Error releasing lock in finally: " + e.Message);
        }
    }
    
    try
    {
        CloseReportStreams();
        DeleteUnwantedReportFiles();
    }
    catch (Exception e)
    {
        Log2.e("\nTpRunTsip.Main(): Error closing streams in finally: " + e.Message);
    }
}
```

**Problem**: Using `continue` inside a `try` block doesn't work the way we want - it will skip the `finally` block.

---

## Fix 1 (Final): Proper Try-Finally with Continue Handling

**Best Approach**: Use a flag to indicate success, then check it after the try-finally:

```csharp
// Line 310: Open report streams
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);

// Line 318: Acquire lock
bool lockAcquired = false;
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    /*	We have a locking situation.  Tell the user to come back later */
    mTW_ERR.Write("*ERROR* - TSIP is currently being run on this combination. Try again later.\r\n");
    Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
    
    // Close streams before continue (lock wasn't acquired, so no lock to release)
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    
    continue; // Process the next parameter table.
}
lockAcquired = true; // Mark that lock was successfully acquired

bool processingSucceeded = false;

// Wrap all processing in try-finally to ensure cleanup
try
{
    // Re-open the Error file for this Tsip parameter record.
    CreateErrorFile(Info.DestName, Info.PdfName, currParm.parmStruct.runname);

    // ... ALL EXISTING PROCESSING CODE FROM LINE 330 TO LINE 625 ...
    // BUT: Replace all "continue;" statements with "processingSucceeded = false; goto cleanup;"
    
    // If we reach here, processing succeeded
    processingSucceeded = true;
}
finally
{
    // Always release lock and close streams, even on error
    if (lockAcquired)
    {
        try
        {
            GenUtil.FileGateClose(cLockFile);
        }
        catch (Exception e)
        {
            Log2.e("\nTpRunTsip.Main(): Error releasing lock in finally: " + e.Message);
        }
    }
    
    try
    {
        CloseReportStreams();
        DeleteUnwantedReportFiles();
    }
    catch (Exception e)
    {
        Log2.e("\nTpRunTsip.Main(): Error closing streams in finally: " + e.Message);
    }
}

// After finally, check if we should continue to next record
if (!processingSucceeded)
{
    continue; // Skip to next parameter record
}
```

**Problem**: Using `goto` is generally discouraged in C#.

---

## Fix 1 (Simplest): Refactor Error Handling to Use Return Pattern

**Simplest Approach**: Extract processing into a separate method that returns success/failure:

```csharp
// Line 310: Open report streams
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);

// Line 318: Acquire lock
if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    /*	We have a locking situation.  Tell the user to come back later */
    mTW_ERR.Write("*ERROR* - TSIP is currently being run on this combination. Try again later.\r\n");
    Log2.w("\nTpRunTsip.Main(): FileGate(): WARNING: call failed.");
    
    // Close streams before continue (lock wasn't acquired, so no lock to release)
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    
    continue; // Process the next parameter table.
}

// Process this parameter record with guaranteed cleanup
bool success = ProcessParameterRecord(currParm, cLockFile, ...);

// Cleanup is handled inside ProcessParameterRecord, but we can also do it here for safety
if (!success)
{
    // Lock and streams should already be closed in ProcessParameterRecord
    continue;
}
```

**Then create a new method**:

```csharp
private static bool ProcessParameterRecord(
    ParmTableWN currParm, 
    string cLockFile,
    // ... other parameters ...
)
{
    bool lockAcquired = true; // We know it was acquired before calling this method
    
    try
    {
        // Re-open the Error file for this Tsip parameter record.
        CreateErrorFile(Info.DestName, Info.PdfName, currParm.parmStruct.runname);

        // ... ALL PROCESSING CODE ...
        // Replace all "continue;" with "return false;"
        // Replace all "exitCode = Constant.FAILURE; continue;" with "return false;"
        
        // Success path
        GenUtil.FileGateClose(cLockFile);
        CloseReportStreams();
        DeleteUnwantedReportFiles();
        return true;
    }
    catch (Exception e)
    {
        Log2.e("\nTpRunTsip.Main(): Unexpected exception: " + e.Message);
        mTW_ERR.Write("*ERROR* - Unexpected exception: {0}\r\n", e.Message);
        return false;
    }
    finally
    {
        // Always release lock and close streams, even on error
        if (lockAcquired)
        {
            try
            {
                GenUtil.FileGateClose(cLockFile);
            }
            catch (Exception e)
            {
                Log2.e("\nTpRunTsip.Main(): Error releasing lock in finally: " + e.Message);
            }
        }
        
        try
        {
            CloseReportStreams();
            DeleteUnwantedReportFiles();
        }
        catch (Exception e)
        {
            Log2.e("\nTpRunTsip.Main(): Error closing streams in finally: " + e.Message);
        }
    }
}
```

**This is the cleanest approach**, but requires refactoring.

---

## Fix 2: Remove Exit Code Setting on Non-Fatal Errors

### Current Problem Locations

**Line 372**: PLAN PDF generation fails
```csharp
// CURRENT CODE:
if (TpPlanChan.GenChan(currParm.parmStruct) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(Error.NOPLANPDF);
    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;
}
```

**FIXED CODE**:
```csharp
if (TpPlanChan.GenChan(currParm.parmStruct) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(Error.NOPLANPDF);
    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process for one record
    continue;  // Cleanup will happen in finally block (if using try-finally)
}
```

---

**Line 411**: ParmRecInit fails
```csharp
// CURRENT CODE:
if ((rc = ParmRecInit(currParm)) != Constant.SUCCESS)
{
    if (rc != Constant.FAILURE)
    {
        ErrMsg.UtPrintMessage(rc);
        ErrMsg.UtPrintMessage(Error.DYN_MS_SQL_SERVER_ERR);
    }

    CloseReportStreams();
    DeleteUnwantedReportFiles();

    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;  // skip to the next run.
}
```

**FIXED CODE**:
```csharp
if ((rc = ParmRecInit(currParm)) != Constant.SUCCESS)
{
    if (rc != Constant.FAILURE)
    {
        ErrMsg.UtPrintMessage(rc);
        ErrMsg.UtPrintMessage(Error.DYN_MS_SQL_SERVER_ERR);
    }

    // REMOVED: CloseReportStreams();  // Will be done in finally
    // REMOVED: DeleteUnwantedReportFiles();  // Will be done in finally
    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process
    continue;  // Cleanup will happen in finally block
}
```

---

**Line 462**: TeBuildSH fails
```csharp
// CURRENT CODE:
if (rc == Constant.FAILURE)
{
    mTW_ERR.Write("FATAL ES ERROR({0}): PROCESSING TERMINATED\r\n", rc);
    GenUtil.UtGetDateTime(out endDate, out endTime);
    sqlCommand = String.Format("Time: {0}\n", endTime.PadRight(12));
    ErrMsg.UtPrintMessage(Error.GENERROR, sqlCommand);
    if (!String.IsNullOrWhiteSpace(GenUtil.GetUserMess()))
    {
        mTW_ERR.Write("*ERROR : {0}\r\n", GenUtil.GetUserMess());
    }

    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;
}
```

**FIXED CODE**:
```csharp
if (rc == Constant.FAILURE)
{
    mTW_ERR.Write("FATAL ES ERROR({0}): PROCESSING TERMINATED\r\n", rc);
    GenUtil.UtGetDateTime(out endDate, out endTime);
    sqlCommand = String.Format("Time: {0}\n", endTime.PadRight(12));
    ErrMsg.UtPrintMessage(Error.GENERROR, sqlCommand);
    if (!String.IsNullOrWhiteSpace(GenUtil.GetUserMess()))
    {
        mTW_ERR.Write("*ERROR : {0}\r\n", GenUtil.GetUserMess());
    }

    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process
    continue;  // Cleanup will happen in finally block
}
```

---

**Line 504**: TtBuildSH fails
```csharp
// CURRENT CODE:
if (rc != Constant.SUCCESS)
{
    Log2.e("\nTpRunTsip.Main(): ERROR: TtBuildSH.TtBuildSHTable() returned " + rc);

    mTW_ERR.Write("FATAL TS ERROR({0}): PROCESSING TERMINATED\r\n", rc);
    GenUtil.UtGetDateTime(out endDate, out endTime);
    sqlCommand = String.Format(" Time: {0}\n", endTime.PadRight(12));
    ErrMsg.UtPrintMessage(Error.GENERROR, sqlCommand);
    if (!String.IsNullOrWhiteSpace(GenUtil.GetUserMess()))
    {
        mTW_ERR.Write("*ERROR : {0}\r\n", GenUtil.GetUserMess());
    }

    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;
}
```

**FIXED CODE**:
```csharp
if (rc != Constant.SUCCESS)
{
    Log2.e("\nTpRunTsip.Main(): ERROR: TtBuildSH.TtBuildSHTable() returned " + rc);

    mTW_ERR.Write("FATAL TS ERROR({0}): PROCESSING TERMINATED\r\n", rc);
    GenUtil.UtGetDateTime(out endDate, out endTime);
    sqlCommand = String.Format(" Time: {0}\n", endTime.PadRight(12));
    ErrMsg.UtPrintMessage(Error.GENERROR, sqlCommand);
    if (!String.IsNullOrWhiteSpace(GenUtil.GetUserMess()))
    {
        mTW_ERR.Write("*ERROR : {0}\r\n", GenUtil.GetUserMess());
    }

    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process
    continue;  // Cleanup will happen in finally block
}
```

---

**Line 522**: UpdateParmRec fails
```csharp
// CURRENT CODE:
if ((rc = UpdateParmRec(numIntCases, numTeIntCases, parmName, currParm)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;
}
```

**FIXED CODE**:
```csharp
if ((rc = UpdateParmRec(numIntCases, numTeIntCases, parmName, currParm)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process
    continue;  // Cleanup will happen in finally block
}
```

---

**Line 548**: ReportStudy fails
```csharp
// CURRENT CODE:
if ((rc = ReportStudy(Info.DbName, Info.PdfName, Info.ProjectCode, currParm,
                                            parmName, siteName, anteName, chanName,
                      clockTime, timeDiff, numStnGroups, TsEsStnGroups,
                      EsTsStnGroups, Info.DestName)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;
}
```

**FIXED CODE**:
```csharp
if ((rc = ReportStudy(Info.DbName, Info.PdfName, Info.ProjectCode, currParm,
                                            parmName, siteName, anteName, chanName,
                      clockTime, timeDiff, numStnGroups, TsEsStnGroups,
                      EsTsStnGroups, Info.DestName)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process
    continue;  // Cleanup will happen in finally block
}
```

---

**Line 586**: ReportNew fails
```csharp
// CURRENT CODE:
rc = ReportNew(Info.DbName, Info.PdfName, currParm, numIntCases,
    numTeIntCases, numStnGroups, viewName, Info.DestName,
    cUnique, cUniqueEnv, isTS);

if (rc != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;  // ❌ REMOVE THIS
    continue;
}
```

**FIXED CODE**:
```csharp
rc = ReportNew(Info.DbName, Info.PdfName, currParm, numIntCases,
    numTeIntCases, numStnGroups, viewName, Info.DestName,
    cUnique, cUniqueEnv, isTS);

if (rc != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    // REMOVED: exitCode = Constant.FAILURE;  // Don't fail entire process
    continue;  // Cleanup will happen in finally block
}
```

---

## Fix 3: Track Success Per Record (Optional Enhancement)

**Enhancement**: Track which records succeeded vs failed, but don't fail entire process:

```csharp
// At start of foreach loop
int successfulRecords = 0;
int failedRecords = 0;

foreach (ParmTableWN currParm in parmTables)
{
    // ... processing ...
    
    if (success)  // After try-finally
    {
        successfulRecords++;
    }
    else
    {
        failedRecords++;
        // Log which record failed
        Log2.w("\nTpRunTsip.Main(): Parameter record failed: {0}_{1}", 
            currParm.parmStruct.proname, currParm.parmStruct.runname);
    }
}

// At end, before exit
if (failedRecords > 0)
{
    Log2.w("\nTpRunTsip.Main(): {0} records succeeded, {1} records failed", 
        successfulRecords, failedRecords);
    // Optionally set exitCode = FAILURE only if ALL records failed
    if (successfulRecords == 0)
    {
        exitCode = Constant.FAILURE;
    }
}
```

---

## Summary of Changes

### Required Changes

1. **Wrap processing in try-finally** (lines 318-634)
   - Ensures lock always released
   - Ensures streams always closed
   - Handles all error paths

2. **Remove `exitCode = Constant.FAILURE`** from these lines:
   - Line 372 (PLAN PDF failure)
   - Line 411 (ParmRecInit failure)
   - Line 462 (TeBuildSH failure)
   - Line 504 (TtBuildSH failure)
   - Line 522 (UpdateParmRec failure)
   - Line 548 (ReportStudy failure)
   - Line 586 (ReportNew failure)

3. **Remove duplicate cleanup** from these lines:
   - Line 408-409 (CloseReportStreams/DeleteUnwantedReportFiles) - will be in finally

### Optional Changes

- Extract processing into separate method for cleaner code
- Track success/failure per record for better logging
- Only set `exitCode = FAILURE` if ALL records fail

---

*Last Updated: January 2026*

