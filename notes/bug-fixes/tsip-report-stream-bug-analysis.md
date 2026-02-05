# TSIP Report Stream Bug Analysis

**Symptoms**:
- TSIP runs multiple times
- Outputs endless streams to error log
- Never outputs results to output files
- Successfully calculates several individual interference cases

**Analysis Date**: January 2026

---

## Root Cause Hypothesis

**Primary Issue**: **Report streams are opened but not closed on error paths**, causing:
1. File handles to remain open
2. Buffered data not being flushed to disk
3. Subsequent runs to fail when trying to open already-open files
4. Error logging to continue indefinitely as streams remain open

---

## Code Flow Analysis

### Stream Opening

**Line 330**: `OpenReportStreams()` is called
```csharp
// AH: New
// The following method assigns a TextWriter stream for every report type.
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);
```

**What This Does**: Opens multiple `TextWriter` streams for:
- `mTW_AGGINTCSV`, `mTW_AGGINTREP`
- `mTW_CASEDET`, `mTW_CASEOHL`
- `mTW_CASESUM`, `mTW_EXEC`
- `mTW_EXPORT`, `mTW_HILO`
- `mTW_ORBIT`, `mTW_STATSUM`
- `mTW_STUDY`

---

### Stream Closing (Success Path)

**Line 631**: `CloseReportStreams()` is called **ONLY on success**
```csharp
// Report sets are 'per-record' so we need to close the TextWriter
// streams and tidy-up.
CloseReportStreams();
DeleteUnwantedReportFiles();
```

**Location**: After all processing completes successfully, just before `FileGateClose()`

---

## Critical Bug: Streams Not Closed on Error Paths

### Error Paths That DON'T Close Streams

#### 1. Line 373: PLAN PDF Generation Fails
```csharp
if (TpPlanChan.GenChan(currParm.parmStruct) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(Error.NOPLANPDF);
    exitCode = Constant.FAILURE;
    continue;  // ❌ BUG - Streams opened but NOT closed!
}
```

**Impact**: 
- Streams remain open
- File handles locked
- Next run may fail to open files
- Buffered data never flushed

---

#### 2. Line 463: TeBuildSH Fails
```csharp
if (rc == Constant.FAILURE)
{
    mTW_ERR.Write("FATAL ES ERROR({0}): PROCESSING TERMINATED\r\n", rc);
    // ... error logging ...
    exitCode = Constant.FAILURE;
    continue;  // ❌ BUG - Streams opened but NOT closed!
}
```

**Impact**: Same as above - streams remain open

---

#### 3. Line 505: TtBuildSH Fails
```csharp
if (rc != Constant.SUCCESS)
{
    Log2.e("\nTpRunTsip.Main(): ERROR: TtBuildSH.TtBuildSHTable() returned " + rc);
    mTW_ERR.Write("FATAL TS ERROR({0}): PROCESSING TERMINATED\r\n", rc);
    // ... error logging ...
    exitCode = Constant.FAILURE;
    continue;  // ❌ BUG - Streams opened but NOT closed!
}
```

**Impact**: Same as above - streams remain open

---

#### 4. Line 523: UpdateParmRec Fails
```csharp
if ((rc = UpdateParmRec(numIntCases, numTeIntCases, parmName, currParm)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;
    continue;  // ❌ BUG - Streams opened but NOT closed!
}
```

**Impact**: Same as above - streams remain open

---

#### 5. Line 549: ReportStudy Fails
```csharp
if ((rc = ReportStudy(...)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;
    continue;  // ❌ BUG - Streams opened but NOT closed!
}
```

**Impact**: 
- **CRITICAL** - This is AFTER calculations complete but BEFORE reports are written
- Streams are open but reports never written
- Matches symptom: "calculates cases but never outputs results"

---

#### 6. Line 587: ReportNew Fails
```csharp
rc = ReportNew(...);
if (rc != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;
    continue;  // ❌ BUG - Streams opened but NOT closed!
}
```

**Impact**: 
- **CRITICAL** - This is AFTER ReportStudy, also before final reports
- Streams remain open, reports not written
- Matches symptom: "calculates cases but never outputs results"

---

### Error Path That DOES Close Streams

**Line 428**: ParmRecInit Fails (CORRECT)
```csharp
if ((rc = ParmRecInit(currParm)) != Constant.SUCCESS)
{
    // ... error handling ...
    CloseReportStreams();  // ✅ CORRECT - Streams are closed
    DeleteUnwantedReportFiles();
    exitCode = Constant.FAILURE;
    continue;
}
```

**Why This One is Different**: This error occurs **BEFORE** calculations, so cleanup is easier.

---

## Secondary Issues

### 1. FileGate Lock Not Released

**Already Documented**: See `tsip-lock-bug-analysis.md`

**Impact**: Causes multiple runs to be attempted
- Lock not released on error paths
- Process exits, Windows releases mutex
- Next process starts immediately
- Same error occurs, cycle repeats

**Combined with Stream Bug**: 
- Each run opens streams
- Streams never closed
- File handles accumulate
- Eventually all file handles exhausted
- Error logging continues (error stream still open)

---

### 2. Error File Re-creation

**Line 350**: `CreateErrorFile()` is called **AFTER** `OpenReportStreams()`
```csharp
// Re-open the Error file for this Tsip parameter record.
// This is necessary for multiple records since the output is
// redirected for reports after each Tsip parameter record is
// processed.
CreateErrorFile(Info.DestName, Info.PdfName, currParm.parmStruct.runname);
```

**Potential Issue**: If error file is already open from previous run, this might:
- Fail silently
- Create duplicate error streams
- Cause endless error logging

---

### 3. Report Writing After Streams Opened

**Timeline**:
1. Line 330: `OpenReportStreams()` - Streams opened
2. Lines 440-506: Calculations performed (TtBuildSH/TeBuildSH)
3. Line 549: `ReportStudy()` - **First report writing**
4. Line 587: `ReportNew()` - **Second report writing**
5. Line 631: `CloseReportStreams()` - Streams closed (ONLY on success)

**If ReportStudy or ReportNew Fail**:
- Streams are still open
- Data may be buffered but not flushed
- Files may be locked
- Next run can't open files

---

## Why This Causes "Endless Error Streams"

### Scenario: ReportStudy Fails

1. **Run 1**:
   - Opens report streams (line 330)
   - Calculates interference cases (successful)
   - `ReportStudy()` fails (line 549)
   - Calls `continue` (line 567)
   - **Streams NOT closed** ❌
   - Process exits (completes other parameter records)
   - **Windows releases file handles** (but data not flushed)

2. **Run 2** (immediately after):
   - Tries to open report streams
   - **May fail** if files still locked or handles not fully released
   - Error logged to `mTW_ERR`
   - Error stream remains open
   - Process continues, more errors logged
   - **Error stream never closed** (only closed at line 648 on normal exit)

3. **Run 3, 4, 5...**:
   - Same cycle repeats
   - Error stream accumulates more errors
   - Report streams never successfully opened/closed
   - **Endless error logging**

---

## Why Results Never Written

### Buffering Issue

**TextWriter streams are buffered**:
- Data written to streams is buffered in memory
- `Flush()` must be called to write to disk
- `Close()` calls `Flush()` automatically
- **If streams are never closed, data never flushed**

**Result**: 
- Calculations complete (data in memory buffers)
- Reports never written to disk (buffers never flushed)
- Files appear empty or don't exist

---

## Likely Bug Locations (Priority Order)

### 🔴 CRITICAL: Report Stream Management

**Location 1**: Lines 549-567 (ReportStudy failure)
- **Most Likely** - This is where report writing starts
- If this fails, all subsequent reports fail
- Streams remain open, data buffered but not flushed

**Location 2**: Lines 587-606 (ReportNew failure)
- **Second Most Likely** - Final report writing
- If this fails, reports incomplete
- Streams remain open

**Location 3**: Lines 463, 505 (Calculation failures after streams opened)
- **Less Likely** - Failures occur before report writing
- But streams still not closed

---

### 🟡 HIGH: FileGate Lock Management

**Location**: Lines 338-627 (entire processing block)
- Lock not released on error paths
- Causes multiple runs
- Combined with stream bug, amplifies the problem

**See**: `tsip-lock-bug-analysis.md` for details

---

### 🟡 HIGH: Error File Management

**Location**: Line 350 (CreateErrorFile after OpenReportStreams)
- Error file re-created after report streams opened
- May cause file handle conflicts
- May create duplicate error streams

---

### 🟢 MEDIUM: Stream Opening Before Lock

**Location**: Line 330 (OpenReportStreams before FileGate)
- Streams opened before lock acquired
- If lock fails, streams opened but never used
- Should streams be opened after lock?

---

## Recommended Fixes

### Fix 1: Close Streams on All Error Paths (CRITICAL)

**Pattern**: Add `CloseReportStreams()` and `DeleteUnwantedReportFiles()` to ALL error paths

**Example**:
```csharp
if ((rc = ReportStudy(...)) != Constant.SUCCESS)
{
    ErrMsg.UtPrintMessage(rc);
    exitCode = Constant.FAILURE;
    
    // FIX: Close streams before continue
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    GenUtil.FileGateClose(cLockFile);  // Also release lock
    
    continue;
}
```

**Apply to**:
- Line 373 (PLAN PDF failure)
- Line 463 (TeBuildSH failure)
- Line 505 (TtBuildSH failure)
- Line 523 (UpdateParmRec failure)
- Line 549 (ReportStudy failure) ⭐ **MOST CRITICAL**
- Line 587 (ReportNew failure) ⭐ **MOST CRITICAL**

---

### Fix 2: Use Try-Finally for Stream Management (BETTER)

**Pattern**: Wrap processing in try-finally to ensure streams always closed

```csharp
OpenReportStreams(Info.PdfName, currParm.parmStruct.runname, currParm.parmStruct.protype);

if (GenUtil.FileGate(cLockFile) != Constant.SUCCESS)
{
    CloseReportStreams();  // Close if lock fails
    continue;
}

try
{
    // All processing code here
    // ... calculations ...
    // ... report writing ...
}
finally
{
    // Always close streams, even on error
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    GenUtil.FileGateClose(cLockFile);  // Also release lock
}
```

**Benefits**:
- Guarantees streams are always closed
- Guarantees lock is always released
- Single point of cleanup
- No risk of missing an error path

---

### Fix 3: Flush Streams Before Error Paths

**Pattern**: Explicitly flush streams before calling `continue`

```csharp
if ((rc = ReportStudy(...)) != Constant.SUCCESS)
{
    // Flush any buffered data before closing
    mTW_ERR.Flush();
    // ... flush other streams if needed ...
    
    CloseReportStreams();
    DeleteUnwantedReportFiles();
    GenUtil.FileGateClose(cLockFile);
    
    continue;
}
```

---

## Testing Scenarios

### Test 1: ReportStudy Failure
1. Force `ReportStudy()` to fail
2. Verify streams are closed
3. Verify lock is released
4. Verify next run can proceed

### Test 2: ReportNew Failure
1. Force `ReportNew()` to fail
2. Verify streams are closed
3. Verify partial reports are written (if any)
4. Verify next run can proceed

### Test 3: Multiple Consecutive Failures
1. Run TSIP multiple times with same error
2. Verify error log doesn't grow indefinitely
3. Verify file handles don't accumulate
4. Verify process can eventually succeed

---

## Summary

**Primary Bug**: **Report streams not closed on error paths**

**Most Likely Locations**:
1. **Line 549** (ReportStudy failure) - ⭐ **MOST LIKELY**
2. **Line 587** (ReportNew failure) - ⭐ **MOST LIKELY**
3. Lines 373, 463, 505, 523 (other error paths)

**Secondary Bug**: FileGate lock not released (already documented)

**Combined Effect**:
- Multiple runs attempted (lock bug)
- Streams never closed (stream bug)
- File handles accumulate
- Error logging continues indefinitely
- Results never written (buffered but not flushed)

**Recommended Fix**: Use try-finally block to ensure streams and locks are always released

---

*Last Updated: January 2026*

