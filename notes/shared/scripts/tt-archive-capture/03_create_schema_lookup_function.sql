-- =============================================================================
-- 03_create_schema_lookup_function.sql
-- Creates a function to map MicsID values to database schemas.
-- 
-- Problem: MicsID values like 'rctl1', 'rctl13', 'bchy6' need to map to
-- schemas 'rctl', 'bchy', etc. Simple digit-stripping doesn't work because
-- both 'rctl1' and 'rctl13' should map to 'rctl'.
--
-- Solution: Find the longest schema name that is a prefix of the MicsID.
-- =============================================================================

USE [YourDatabase];  -- Change to your database
GO

-- Drop existing function if it exists
IF OBJECT_ID(N'tsip_archive.fn_GetSchemaFromMicsID', N'FN') IS NOT NULL
    DROP FUNCTION tsip_archive.fn_GetSchemaFromMicsID;
GO

-- Create the schema lookup function
CREATE FUNCTION tsip_archive.fn_GetSchemaFromMicsID
(
    @MicsID NVARCHAR(32)
)
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @CleanMicsID NVARCHAR(32) = RTRIM(LTRIM(@MicsID));
    
    -- Find the longest schema name that is a prefix of the MicsID
    -- Exclude system schemas and known non-user schemas
    SELECT TOP 1 @SchemaName = s.name
    FROM sys.schemas s
    WHERE @CleanMicsID LIKE s.name + '%'
      AND s.name NOT IN (
          'dbo', 'guest', 'sys', 'INFORMATION_SCHEMA',
          'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin',
          'db_backupoperator', 'db_datareader', 'db_datawriter',
          'db_denydatareader', 'db_denydatawriter',
          'tsip_archive', 'web', 'archive', 'tsip',
          'acct', 'adm', 'dba', 'main', 'tabledef', 'techdef'
      )
      AND s.name NOT LIKE 'aspnet_%'
    ORDER BY LEN(s.name) DESC;
    
    RETURN @SchemaName;
END;
GO

-- Test the function
PRINT 'Testing fn_GetSchemaFromMicsID:';
PRINT '  rctl6  -> ' + ISNULL(tsip_archive.fn_GetSchemaFromMicsID('rctl6'), 'NULL');
PRINT '  rctl13 -> ' + ISNULL(tsip_archive.fn_GetSchemaFromMicsID('rctl13'), 'NULL');
PRINT '  bchy2  -> ' + ISNULL(tsip_archive.fn_GetSchemaFromMicsID('bchy2'), 'NULL');
PRINT '  bmce3  -> ' + ISNULL(tsip_archive.fn_GetSchemaFromMicsID('bmce3'), 'NULL');
PRINT '  glw1   -> ' + ISNULL(tsip_archive.fn_GetSchemaFromMicsID('glw1'), 'NULL');
GO
