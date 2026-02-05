# Variable Declaration Fix Locations - Visual Guide

**File**: `FCSA_BACKEND_SQL/TprunTsip.sql`

---

## Fix #1: Add Variable Declarations (CRITICAL)

### Location: After Line 159

**Current Code** (lines 155-165):
```sql
155|declare @mSELECT nvarchar(255),
156|		@ParmDefinition nvarchar(50)
157|
158|declare @mExport smallint,
159|	@mOrbit smallint
160|
161|SET @ProjectCode = 'compa4_0'
```

**Action**: Insert new variable declarations between lines 159 and 161

**Insert this code**:
```sql
declare @mExport smallint,
	@mOrbit smallint

-- ============================================
-- ADD MISSING VARIABLE DECLARATIONS HERE
-- ============================================
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
SET @Constant_FAILURE = -1
SET @Constant_FT = 0
SET @isTS = 0

SET @ProjectCode = 'compa4_0'
```

---

## Fix #2: Fix UtGetDateTime Call (CRITICAL)

### Location: Line 865

**Current Code** (lines 863-867):
```sql
863|    end
864|
865|	/*// Get the end date and time.*/
865|	GenUtil.UtGetDateTime(out endDate, out endTime);
866|/*
867|	//================================
```

**Action**: Replace line 865

**Replace**:
```sql
	GenUtil.UtGetDateTime(out endDate, out endTime);
```

**With**:
```sql
	exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out
```

**Result** (lines 863-870):
```sql
863|    end
864|
865|	/*// Get the end date and time.*/
865|	exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out
866|/*
867|	//================================
868|	// Start of report production.   =
869|	//================================
870|*/
```

---

## Fix #3: Initialize @isTS Before Conditional (RECOMMENDED)

### Location: Before Line 815

**Current Code** (lines 812-816):
```sql
812|	end
813|	else
814|	begin
815|	  set @isTS = 1
816|      exec [tpruntsip].[GenUtil_UtCvtName] @Constant_TT_PARM, @Schema, @viewName, @parmName out
```

**Action**: Add initialization before the `if @protype='E'` block (around line 779)

**Current Code** (lines 776-780):
```sql
776|	set @Constant_TE_PARM = 405
777|	set @Constant_TE_SITE = 406
778|	set @Constant_TE_ANTE = 407
779|	if @protype='E' or @protype='PDF_ES' or @protype='MDB_ES'
```

**Add after line 778**:
```sql
	set @Constant_TE_PARM = 405
	set @Constant_TE_SITE = 406
	set @Constant_TE_ANTE = 407
	set @isTS = 0  -- Initialize before conditional
	if @protype='E' or @protype='PDF_ES' or @protype='MDB_ES'
```

---

## Fix #4: Calculate @clockTime and @timeDiff (MAY BE NEEDED)

### Location: After Line 865 (after UtGetDateTime call)

**Current Code** (lines 865-870):
```sql
865|	exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out
866|/*
867|	//================================
868|	// Start of report production.   =
869|	//================================
870|*/
871|	/*if ((rc = ReportStudy(Info.DbName, Info.PdfName, Info.ProjectCode, currParm,
```

**Action**: Add calculation after line 865

**Add after line 865**:
```sql
	exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out
	
	-- Calculate clockTime and timeDiff for reports
	-- Note: Verify this logic matches C# implementation
	SET @clockTime = @endTime  -- Or calculate elapsed time from startTime
	-- Calculate time difference (verify format needed)
	-- SET @timeDiff = DATEDIFF(SECOND, CAST(@startTime AS TIME), CAST(@endTime AS TIME))
	-- Or simpler if they're already formatted strings:
	SET @timeDiff = ''  -- Placeholder - needs implementation
```

**Note**: The exact calculation for `@clockTime` and `@timeDiff` needs to be verified against the C# source code to ensure correct format and calculation method.

---

## Summary of All Fix Locations

| Fix # | Line(s) | Type | Priority | Description |
|-------|---------|------|----------|-------------|
| **1** | **159-160** | **Insert** | **CRITICAL** | Add 14 variable declarations |
| **2** | **865** | **Replace** | **CRITICAL** | Fix UtGetDateTime call syntax |
| **3** | **778-779** | **Insert** | **RECOMMENDED** | Initialize @isTS = 0 |
| **4** | **865-866** | **Insert** | **MAY BE NEEDED** | Calculate @clockTime and @timeDiff |

---

## Quick Reference: Variable Usage Map

```
Line 753:  @Constant_FT          (UtUpdateCentralTable)
Line 754:  @Constant_FT          (UtUpdateCentralTable)
Line 786:  @Constant_FAILURE     (if @rc = @Constant_FAILURE)
Line 797:  @exitCode             (set @exitCode = @Constant_FAILURE)
Line 809:  @TsEsStnGroups out    (UtGetInterferenceGroups)
Line 810:  @EsTsStnGroups out    (UtGetInterferenceGroups)
Line 811:  @numStnGroups         (set @numStnGroups = ...)
Line 815:  @isTS                 (set @isTS = 1)
Line 839:  @exitCode             (set @exitCode = @Constant_FAILURE)
Line 844:  @numStnGroups out     (DbCountRows)
Line 851:  @Constant_FT          (UtDropTable)
Line 860:  @exitCode             (set @exitCode = @Constant_FAILURE)
Line 865:  @endDate, @endTime    (UtGetDateTime - NEEDS FIX)
Line 875:  @chanName, @clockTime, @timeDiff, @numStnGroups, @TsEsStnGroups (ReportStudy)
Line 876:  @EsTsStnGroups         (ReportStudy)
Line 880:  @exitCode             (set @exitCode = @Constant_FAILURE)
Line 888:  @isTS                 (if @isTS=1)
Line 892:  @chanName out         (GenUtil_UtCvtName)
Line 896:  @cUnique out          (CreateTTStatRep)
Line 897:  @cUniqueEnv            (set @cUniqueEnv = '')
Line 905:  @chanName out         (GenUtil_UtCvtName)
Line 909:  @cUnique, @cUniqueEnv out (CreateETStatRep)
Line 915:  @numStnGroups, @cUnique, @cUniqueEnv, @isTS (ReportNew)
Line 921:  @exitCode             (set @exitCode = @Constant_FAILURE)
Line 943:  @endTime, @endDate, @isTS, @numStnGroups, @TsEsStnGroups (TpExecRpt)
Line 944:  @EsTsStnGroups        (TpExecRpt)
Line 962:  @cBuf, @cUnique        (FormatMessage, sp_executesql)
```

---

## Testing After Fixes

1. **Syntax Check**: Run `SET PARSEONLY ON` and execute the script
2. **Compilation**: Attempt to create/alter the stored procedure
3. **Variable Scope**: Verify all variables are accessible where used
4. **Initialization**: Verify constants are set before use

---

## Notes

- **Constant Values**: Verify `@Constant_FAILURE = -1` and `@Constant_FT = 0` match the C# definitions
- **Time Calculations**: The `@clockTime` and `@timeDiff` calculation may need additional research into the C# implementation
- **Error Handling**: The `@exitCode` variable is set but never used to actually exit - this may be intentional or may need additional logic

