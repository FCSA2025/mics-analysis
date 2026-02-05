# Error Recovery Implementation Decision

**Date**: January 2026  
**Status**: ✅ **DECIDED**  
**Approach**: **Transactional with Explicit Cleanup**

---

## Decision Summary

**We will implement error recovery using a transactional approach with explicit cleanup of artifacts from prior failed runs.**

---

## Key Decisions

### 1. ✅ Transactional Approach

**Decision**: Use SQL Server transactions (`BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`)

**Rationale**:
- ✅ Provides atomicity (all or nothing)
- ✅ Better than C# (C# can't rollback)
- ✅ Simple, standard T-SQL pattern
- ✅ Automatic cleanup of data on error

**Implementation**:
```sql
BEGIN TRANSACTION;
BEGIN TRY
    -- Process all sites/links/antennas/channels
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;  -- Removes all data
    -- Explicit cleanup (see below)
    THROW;
END CATCH;
```

---

### 2. ✅ Artifact Detection at Start

**Decision**: Check for and clean up any tables from prior failed runs before starting new run

**Rationale**:
- ✅ Ensures clean state
- ✅ Prevents orphaned tables
- ✅ Matches C# behavior (`UtCleanupTables`)

**Implementation**:
```sql
-- At start of procedure, check for and drop:
IF OBJECT_ID('tt_{proj}_{run}_parm', 'U') IS NOT NULL
    DROP TABLE tt_{proj}_{run}_parm;
-- ... (repeat for all tables)
```

**Tables to Check**:
- `tt_{proj}_{run}_parm`, `tt_{proj}_{run}_site`, `tt_{proj}_{run}_ante`, `tt_{proj}_{run}_chan`
- `tt_{proj}_{run}_temp1`, `tt_{proj}_{run}_temp2`
- `te_{proj}_{run}_*` (if ES analysis)

---

### 3. ✅ Explicit Cleanup After Error

**Decision**: Explicitly drop tables in CATCH block even after ROLLBACK

**Rationale**:
- ✅ ROLLBACK removes data but may not drop tables
- ✅ Ensures clean state on error
- ✅ Prevents orphaned empty tables

**Implementation**:
```sql
BEGIN CATCH
    ROLLBACK TRANSACTION;  -- Removes all data
    
    -- Explicitly drop tables (even though ROLLBACK removed data)
    IF OBJECT_ID('tt_{proj}_{run}_parm', 'U') IS NOT NULL
        DROP TABLE tt_{proj}_{run}_parm;
    -- ... (repeat for all tables)
    
    THROW;  -- Re-raise error
END CATCH;
```

---

### 4. ✅ Error Logging

**Decision**: Log error details for debugging and monitoring

**Rationale**:
- ✅ Need to know what went wrong
- ✅ Helps with troubleshooting
- ✅ Better than C# (C# only logs to file)

**Implementation**:
```sql
DECLARE @errorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
DECLARE @errorLine INT = ERROR_LINE();
DECLARE @errorNumber INT = ERROR_NUMBER();

PRINT 'ERROR: ' + @errorMsg;
PRINT 'Line: ' + CAST(@errorLine AS VARCHAR(10));
-- Optionally: INSERT INTO tsip.error_log (...)
```

---

## Implementation Pattern

### Complete Pattern

```sql
CREATE PROCEDURE tsip.ProcessInterferenceAnalysis
    @projName VARCHAR(50),
    @runName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- STEP 1: Artifact Detection and Cleanup
    -- Check for and drop tables from prior failed runs
    IF OBJECT_ID('tt_' + @projName + '_' + @runName + '_parm', 'U') IS NOT NULL
        DROP TABLE tt_...;
    -- ... (repeat for all tables)
    
    -- STEP 2: Transaction-Based Processing
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Create tables
        -- Process all sites/links/antennas/channels
        -- Insert results
        
        COMMIT TRANSACTION;
        SELECT 'SUCCESS' AS status;
    END TRY
    BEGIN CATCH
        -- STEP 3: Error Handling
        ROLLBACK TRANSACTION;
        
        -- STEP 4: Explicit Cleanup
        -- Drop all tables (even after ROLLBACK)
        IF OBJECT_ID('tt_' + @projName + '_' + @runName + '_parm', 'U') IS NOT NULL
            DROP TABLE tt_...;
        -- ... (repeat for all tables)
        
        -- Log error
        PRINT 'ERROR: ' + ERROR_MESSAGE();
        
        -- Re-raise
        THROW;
    END CATCH;
END;
```

---

## Tables to Clean Up

### TS-TS Tables (Always)
- `tt_{proj}_{run}_parm`
- `tt_{proj}_{run}_site`
- `tt_{proj}_{run}_ante`
- `tt_{proj}_{run}_chan`
- `tt_{proj}_{run}_temp1`
- `tt_{proj}_{run}_temp2`

### TS-ES Tables (If ES Analysis)
- `te_{proj}_{run}_parm`
- `te_{proj}_{run}_site`
- `te_{proj}_{run}_ante`
- `te_{proj}_{run}_chan`
- `te_{proj}_{run}_temp1`

---

## Implementation Checklist

### ✅ At Start of Procedure
- [x] Build table names from `@projName` and `@runName`
- [x] Check for and drop all `tt_*` tables (if exist)
- [x] Check for and drop all `te_*` tables (if ES analysis, if exist)
- [x] Check for and drop temporary tables (if exist)

### ✅ During Processing
- [x] `BEGIN TRANSACTION` before any DDL/DML
- [x] Create tables within transaction
- [x] Process all sites/links/antennas/channels
- [x] `COMMIT TRANSACTION` on success

### ✅ On Error (CATCH Block)
- [x] `ROLLBACK TRANSACTION` (removes all data)
- [x] Log error details (message, line, number, severity)
- [x] Explicitly drop all `tt_*` tables (if exist)
- [x] Explicitly drop all `te_*` tables (if ES analysis, if exist)
- [x] Explicitly drop temporary tables (if exist)
- [x] `THROW` to re-raise error

---

## Benefits

### vs Current C# Code
- ✅ **Atomicity** - All or nothing (C# can't rollback)
- ✅ **Clean state** - No partial results (C# leaves partial results)
- ✅ **Artifact detection** - Explicit check at start (C# has `UtCleanupTables` but less explicit)
- ✅ **Better error handling** - Transaction rollback + explicit cleanup (C# only has explicit cleanup)

### vs Other Options
- ✅ **Simpler than resume capability** - No state tracking needed
- ✅ **Better than no recovery** - Provides atomicity and cleanup
- ✅ **Standard pattern** - Uses standard T-SQL transactions

---

## Related Documents

- `../historical/error-recovery-analysis.md` - Complete analysis of error recovery options
- `state-management-tsql-analysis.md` - State management analysis (progress tracking not needed)
- `../../shared/database-tables.md` - Table naming conventions and cleanup functions

---

## Status

✅ **DECIDED** - Ready for implementation

**Next Steps**:
1. Implement artifact detection at start of procedure
2. Implement transaction-based processing
3. Implement explicit cleanup in CATCH block
4. Implement error logging
5. Test with various failure scenarios

