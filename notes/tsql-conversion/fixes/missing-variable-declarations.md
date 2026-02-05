# Missing Variable Declarations - T-SQL Port Fix Guide

**File**: `FCSA_BACKEND_SQL/TprunTsip.sql`  
**Issue**: Multiple variables are used but never declared, causing compilation errors  
**Priority**: **CRITICAL** - Code will not compile without these fixes

---

## Summary

**14 missing variable declarations** need to be added to `TprunTsip.sql`. All should be declared in the variable declaration section (around lines 135-160).

---

## Fix Location: Variable Declaration Section

**Insert location**: After line 159 (after `@mOrbit smallint` declaration), before line 160 (before the `SET` statements)

**Current code structure** (lines 135-160):
```sql
@numTeIntCases int

DECLARE @TmpRet int
DECLARE @nCount int,
  @res int,
  @Constant_SUCCESS int,
  @Constant_MAX_CTX_PTS int,
  @Constant_MAX_SAVED_CTX int,
  @idxPts int, @idx int

DECLARE @CvtTab CURSOR
DECLARE @ParTab CURSOR

DECLARE @Constant_TT_ANTE int,
	@Constant_TT_CHAN int,
	@Constant_TE_PARM int,
	@Constant_TE_SITE int,
	@Constant_TE_ANTE int,
	@Constant_TE_CHAN int

declare @mSELECT nvarchar(255),
		@ParmDefinition nvarchar(50)

declare @mExport smallint,
	@mOrbit smallint

-- ⬇️ INSERT NEW DECLARATIONS HERE ⬇️

SET @ProjectCode = 'compa4_0'
```

---

## Required Variable Declarations

Add the following declarations after line 159:

```sql
-- Error handling and status tracking
DECLARE @exitCode int
DECLARE @Constant_FAILURE int
DECLARE @isTS smallint

-- Report generation variables
DECLARE @chanName varchar(255)
DECLARE @clockTime varchar(50)
DECLARE @timeDiff varchar(50)
DECLARE @endDate varchar(50)
DECLARE @endTime varchar(50)

-- Interference group tracking
DECLARE @TsEsStnGroups int
DECLARE @EsTsStnGroups int
DECLARE @numStnGroups int

-- Report table names
DECLARE @cUnique varchar(255)
DECLARE @cUniqueEnv varchar(255)

-- Utility variables
DECLARE @cBuf nvarchar(255)
DECLARE @Constant_FT int
```

---

## Variable Usage Locations (For Reference)

### 1. `@exitCode` (int)
- **Line 797**: `set @exitCode = @Constant_FAILURE;` (ES error path)
- **Line 839**: `set @exitCode = @Constant_FAILURE;` (TS error path)
- **Line 860**: `set @exitCode = @Constant_FAILURE;` (UpdateParmRec error)
- **Line 880**: `set @exitCode = @Constant_FAILURE;` (ReportStudy error)
- **Line 921**: `set @exitCode = @Constant_FAILURE` (ReportNew error)
- **Note**: Variable is set but never actually used to exit. May need to add exit logic.

### 2. `@Constant_FAILURE` (int)
- **Line 786**: `if @rc = @Constant_FAILURE` (ES error check)
- **Should be set to**: `-1` (typical failure code, verify against C# `Constant.FAILURE`)

### 3. `@isTS` (smallint)
- **Line 815**: `set @isTS = 1` (TS processing branch)
- **Line 888**: `if @isTS=1` (report generation branch selection)
- **Line 916**: `@isTS, @rc out` (ReportNew parameter)
- **Line 943**: `@isTS, @numStnGroups` (TpExecRpt parameter)
- **Note**: Should be initialized to `0` or `NULL` before the `if @protype='E'` check

### 4. `@chanName` (varchar(255))
- **Line 875**: `@chanName, @clockTime` (ReportStudy parameter)
- **Line 892**: `@chanName out` (TS channel table name)
- **Line 905**: `@chanName out` (ES channel table name)
- **Note**: Set via `GenUtil_UtCvtName` calls, but needs declaration

### 5. `@clockTime` (varchar(50))
- **Line 875**: `@chanName, @clockTime, @timeDiff` (ReportStudy parameter)
- **Note**: Should be calculated from `@startTime` and `@endTime`

### 6. `@timeDiff` (varchar(50))
- **Line 875**: `@clockTime, @timeDiff, @numStnGroups` (ReportStudy parameter)
- **Note**: Should be calculated as difference between `@startTime` and `@endTime`

### 7. `@TsEsStnGroups` (int)
- **Line 809**: `@TsEsStnGroups out` (UtGetInterferenceGroups output)
- **Line 811**: `set @numStnGroups = @TsEsStnGroups + @EsTsStnGroups;`
- **Line 875**: `@TsEsStnGroups,` (ReportStudy parameter)
- **Line 944**: `@TsEsStnGroups,` (TpExecRpt parameter)

### 8. `@EsTsStnGroups` (int)
- **Line 810**: `@EsTsStnGroups out` (UtGetInterferenceGroups output)
- **Line 811**: `set @numStnGroups = @TsEsStnGroups + @EsTsStnGroups;`
- **Line 876**: `@EsTsStnGroups, @DestName` (ReportStudy parameter)
- **Line 945**: `@EsTsStnGroups, @numIntCases` (TpExecRpt parameter)

### 9. `@numStnGroups` (int)
- **Line 811**: `set @numStnGroups = @TsEsStnGroups + @EsTsStnGroups;` (ES path)
- **Line 844**: `@numStnGroups out` (TS path - DbCountRows)
- **Line 875**: `@numStnGroups, @TsEsStnGroups` (ReportStudy parameter)
- **Line 915**: `@numStnGroups, @viewName` (ReportNew parameter)
- **Line 944**: `@numStnGroups, @TsEsStnGroups` (TpExecRpt parameter)

### 10. `@cUnique` (varchar(255))
- **Line 896**: `@cUnique out` (CreateTTStatRep output - TS path)
- **Line 909**: `@cUnique out, @cUniqueEnv out` (CreateETStatRep output - ES path)
- **Line 916**: `@cUnique, @cUniqueEnv, @isTS` (ReportNew parameter)
- **Line 962**: `FormatMessage(N'drop table %s ', @cUnique);` (Cleanup)

### 11. `@cUniqueEnv` (varchar(255))
- **Line 897**: `set @cUniqueEnv = '';` (TS path - set to empty)
- **Line 909**: `@cUnique out, @cUniqueEnv out` (ES path - from CreateETStatRep)
- **Line 916**: `@cUnique, @cUniqueEnv, @isTS` (ReportNew parameter)

### 12. `@endDate` (varchar(50))
- **Line 865**: `GenUtil.UtGetDateTime(out endDate, out endTime);` - **NEEDS FIX** (see below)
- **Line 944**: `@endTime, @endDate, @isTS` (TpExecRpt parameter)

### 13. `@endTime` (varchar(50))
- **Line 865**: `GenUtil.UtGetDateTime(out endDate, out endTime);` - **NEEDS FIX** (see below)
- **Line 943**: `@mTW_EXEC, @PdfName, @startTime, @startDate, @endTime, @endDate` (TpExecRpt parameter)

### 14. `@cBuf` (nvarchar(255))
- **Line 962**: `set @cBuf = FormatMessage(N'drop table %s ', @cUnique);`
- **Line 963**: `exec sp_executesql @cBuf`

### 15. `@Constant_FT` (int)
- **Line 753**: `@Constant_FT` (UtUpdateCentralTable parameter)
- **Line 754**: `@Constant_FT` (UtUpdateCentralTable parameter)
- **Line 851**: `@Constant_FT, @proname` (UtDropTable parameter)
- **Should be set to**: `0` (typical value for FT table type constant)

---

## Additional Fix Required: UtGetDateTime Call

**Location**: Line 865

**Current (INCORRECT)**:
```sql
GenUtil.UtGetDateTime(out endDate, out endTime);
```

**Should be**:
```sql
exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out
```

**Note**: The stored procedure `[tpruntsip].[GenUtil_UtGetDateTime]` exists (confirmed in `StoredProcedure.sql` line 32162), but the call syntax is wrong. It's using C# syntax instead of T-SQL.

---

## Complete Fix Block

Insert the following code block **after line 159** (after `@mOrbit smallint`):

```sql
-- Error handling and status tracking
DECLARE @exitCode int
DECLARE @Constant_FAILURE int
DECLARE @isTS smallint

-- Report generation variables
DECLARE @chanName varchar(255)
DECLARE @clockTime varchar(50)
DECLARE @timeDiff varchar(50)
DECLARE @endDate varchar(50)
DECLARE @endTime varchar(50)

-- Interference group tracking
DECLARE @TsEsStnGroups int
DECLARE @EsTsStnGroups int
DECLARE @numStnGroups int

-- Report table names
DECLARE @cUnique varchar(255)
DECLARE @cUniqueEnv varchar(255)

-- Utility variables
DECLARE @cBuf nvarchar(255)
DECLARE @Constant_FT int

-- Initialize constants
SET @Constant_FAILURE = -1  -- Verify this matches C# Constant.FAILURE
SET @Constant_FT = 0        -- Verify this matches C# Constant.FT
SET @isTS = 0               -- Initialize before conditional assignment
```

---

## Additional Initialization Needed

After the variable declarations, add initialization in the appropriate places:

1. **Line ~815** (before `set @isTS = 1`): Initialize `@isTS = 0` earlier (already handled above)

2. **Line 865** (fix the UtGetDateTime call):
   ```sql
   -- BEFORE (line 865):
   GenUtil.UtGetDateTime(out endDate, out endTime);
   
   -- AFTER:
   exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out
   ```

3. **Calculate `@clockTime` and `@timeDiff`** (after line 865):
   ```sql
   -- After getting endDate and endTime, calculate clockTime and timeDiff
   -- This logic needs to be implemented based on C# equivalent
   -- Example (needs verification):
   SET @clockTime = @endTime  -- Or calculate elapsed time
   SET @timeDiff = DATEDIFF(SECOND, @startTime, @endTime)  -- Verify format
   ```

---

## Verification Checklist

After making these changes, verify:

- [ ] All 14 variables declared
- [ ] `@Constant_FAILURE` and `@Constant_FT` initialized with correct values
- [ ] `@isTS` initialized to 0 before conditional assignment
- [ ] `UtGetDateTime` call fixed at line 865
- [ ] `@clockTime` and `@timeDiff` calculated (may need additional logic)
- [ ] Code compiles without "undeclared variable" errors

---

## Estimated Effort

- **Time**: 30-60 minutes
- **Risk**: Low (straightforward additions)
- **Testing**: Compile and run basic syntax check

---

## Next Steps After This Fix

1. Fix the `UtGetDateTime` call syntax
2. Implement `@clockTime` and `@timeDiff` calculation logic
3. Verify constant values match C# definitions
4. Test compilation
5. Address Part 2 (Over-Horizon Path Loss) if needed

