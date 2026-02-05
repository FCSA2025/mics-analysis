-- ============================================================================
-- QUICK FIX SCRIPT: Missing Variable Declarations
-- File: FCSA_BACKEND_SQL/TprunTsip.sql
-- ============================================================================
-- 
-- INSTRUCTIONS:
-- 1. Open TprunTsip.sql
-- 2. Find line 159 (after "@mOrbit smallint")
-- 3. Insert the DECLARE block below
-- 4. Find line 865 (GenUtil.UtGetDateTime call)
-- 5. Replace with the corrected call
-- 6. Find line 778 (before "if @protype='E'")
-- 7. Add @isTS initialization
--
-- ============================================================================

-- ============================================================================
-- FIX #1: INSERT AFTER LINE 159
-- ============================================================================
-- Location: After "declare @mOrbit smallint" (line 159)
-- Insert the following block:

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
SET @Constant_FAILURE = -1  -- Verify matches C# Constant.FAILURE
SET @Constant_FT = 0        -- Verify matches C# Constant.FT
SET @isTS = 0               -- Initialize before conditional assignment

-- ============================================================================
-- FIX #2: REPLACE LINE 865
-- ============================================================================
-- Location: Line 865
-- Current: GenUtil.UtGetDateTime(out endDate, out endTime);
-- Replace with:

exec [tpruntsip].[GenUtil_UtGetDateTime] @endDate out, @endTime out

-- ============================================================================
-- FIX #3: INSERT AFTER LINE 778
-- ============================================================================
-- Location: After "set @Constant_TE_ANTE = 407" (line 778), before "if @protype='E'"
-- Insert:

set @isTS = 0  -- Initialize before conditional

-- ============================================================================
-- FIX #4: ADD AFTER LINE 865 (OPTIONAL - May need implementation)
-- ============================================================================
-- Location: After the UtGetDateTime call (line 865)
-- Add time calculation (verify logic matches C#):

-- Calculate clockTime and timeDiff for reports
SET @clockTime = @endTime  -- Or calculate elapsed time - verify C# logic
-- SET @timeDiff = DATEDIFF(SECOND, CAST(@startTime AS TIME), CAST(@endTime AS TIME))
SET @timeDiff = ''  -- Placeholder - needs implementation based on C# source

-- ============================================================================
-- VERIFICATION CHECKLIST
-- ============================================================================
-- After making changes, verify:
-- [ ] All 14 variables declared
-- [ ] Constants initialized (@Constant_FAILURE, @Constant_FT)
-- [ ] @isTS initialized before use
-- [ ] UtGetDateTime call syntax corrected
-- [ ] Code compiles without "undeclared variable" errors
-- [ ] Test with SET PARSEONLY ON to check syntax

