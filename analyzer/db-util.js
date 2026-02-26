/**
 * MICS SQL Server Database Toolkit
 * 
 * Comprehensive CLI tool for SQL Server database inspection, validation,
 * and schema comparison. Designed for repeated use across MICS projects.
 * 
 * Usage: node db-util.js <command> [options]
 * 
 * Commands:
 *   test                    - Test database connection
 *   databases               - List accessible databases
 *   schemas                 - List all schemas in current database
 *   tables [--schema X]     - List tables (optionally filter by schema)
 *   sample <suffix>         - Find ONE table matching suffix pattern
 *   count <pattern>         - Count tables by schema matching pattern
 *   describe <table>        - Full table structure (columns, PKs, FKs)
 *   columns <table>         - Column list only
 *   keys <table>            - Primary and foreign keys
 *   procs [--schema X]      - List stored procedures
 *   proc <name>             - Show procedure definition
 *   compare <type>          - Compare archive def vs actual (e.g., FT_SITE)
 *   query "<sql>"           - Execute ad-hoc query
 *   interactive             - Interactive query mode
 *   help                    - Show this help message
 */

const sql = require('mssql');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { sqlConfig } = require('./db-config');

const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    white: '\x1b[37m',
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    dim: '\x1b[2m'
};

function log(color, message) {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function logTable(data) {
    if (data.length === 0) {
        log('yellow', 'No results found.');
        return;
    }
    console.table(data);
    log('dim', `(${data.length} rows)`);
}

async function connect() {
    try {
        await sql.connect(sqlConfig);
        return true;
    } catch (err) {
        log('red', `Connection failed: ${err.message}`);
        return false;
    }
}

async function disconnect() {
    try {
        await sql.close();
    } catch (err) {
        // Ignore close errors
    }
}

// =============================================================================
// CONNECTION COMMANDS
// =============================================================================

async function cmdTest() {
    log('cyan', 'Testing database connection...');
    log('dim', `Server: ${sqlConfig.server}`);
    log('dim', `Database: ${sqlConfig.database}`);
    log('dim', `User: ${sqlConfig.user}`);
    
    if (await connect()) {
        const result = await sql.query`SELECT @@VERSION AS Version, DB_NAME() AS CurrentDB`;
        log('green', 'Connection successful!');
        log('dim', `Database: ${result.recordset[0].CurrentDB}`);
        log('dim', `Version: ${result.recordset[0].Version.split('\n')[0]}`);
        await disconnect();
        return true;
    }
    return false;
}

async function cmdDatabases() {
    if (!await connect()) return;
    
    log('cyan', 'Listing accessible databases...');
    const result = await sql.query`
        SELECT name AS DatabaseName, 
               state_desc AS State,
               create_date AS Created
        FROM sys.databases 
        WHERE HAS_DBACCESS(name) = 1
        ORDER BY name
    `;
    logTable(result.recordset);
    await disconnect();
}

// =============================================================================
// SCHEMA DISCOVERY COMMANDS
// =============================================================================

async function cmdSchemas() {
    if (!await connect()) return;
    
    log('cyan', 'Listing schemas...');
    const result = await sql.query`
        SELECT s.name AS SchemaName,
               p.name AS Owner,
               COUNT(t.object_id) AS TableCount
        FROM sys.schemas s
        LEFT JOIN sys.database_principals p ON s.principal_id = p.principal_id
        LEFT JOIN sys.tables t ON s.schema_id = t.schema_id
        GROUP BY s.name, p.name
        HAVING COUNT(t.object_id) > 0
        ORDER BY TableCount DESC, s.name
    `;
    logTable(result.recordset);
    await disconnect();
}

async function cmdTables(schemaFilter = null) {
    if (!await connect()) return;
    
    log('cyan', schemaFilter ? `Listing tables in schema '${schemaFilter}'...` : 'Listing tables...');
    
    let query;
    if (schemaFilter) {
        query = sql.query`
            SELECT TOP 100
                SCHEMA_NAME(t.schema_id) AS SchemaName,
                t.name AS TableName,
                SUM(p.rows) AS [RowCount]
            FROM sys.tables t
            LEFT JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
            WHERE SCHEMA_NAME(t.schema_id) = ${schemaFilter}
            GROUP BY t.schema_id, t.name
            ORDER BY t.name
        `;
    } else {
        query = sql.query`
            SELECT TOP 100
                SCHEMA_NAME(t.schema_id) AS SchemaName,
                t.name AS TableName,
                SUM(p.rows) AS [RowCount]
            FROM sys.tables t
            LEFT JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
            GROUP BY t.schema_id, t.name
            ORDER BY SchemaName, t.name
        `;
    }
    
    const result = await query;
    logTable(result.recordset);
    log('dim', '(Limited to 100 results. Use --schema to filter.)');
    await disconnect();
}

async function cmdSample(suffix) {
    if (!suffix) {
        log('red', 'Usage: db-util.js sample <suffix>');
        log('dim', 'Example: db-util.js sample _site');
        return;
    }
    
    if (!await connect()) return;
    
    const pattern = `%${suffix}`;
    log('cyan', `Finding ONE table matching '*${suffix}'...`);
    
    const findTable = await sql.query`
        SELECT TOP 1 
            SCHEMA_NAME(schema_id) AS SchemaName,
            name AS TableName
        FROM sys.tables 
        WHERE name LIKE ${pattern}
        ORDER BY name
    `;
    
    if (findTable.recordset.length === 0) {
        log('yellow', `No tables found matching pattern '*${suffix}'`);
        await disconnect();
        return;
    }
    
    const table = findTable.recordset[0];
    const fullName = `${table.SchemaName}.${table.TableName}`;
    log('green', `Found: ${fullName}`);
    
    await showTableStructure(fullName);
    await disconnect();
}

async function cmdCount(pattern) {
    if (!pattern) {
        log('red', 'Usage: db-util.js count <pattern>');
        log('dim', 'Example: db-util.js count ft_');
        return;
    }
    
    if (!await connect()) return;
    
    const likePattern = `${pattern}%`;
    log('cyan', `Counting tables matching '${pattern}*' by schema...`);
    
    const result = await sql.query`
        SELECT 
            SCHEMA_NAME(schema_id) AS SchemaName,
            COUNT(*) AS TableCount
        FROM sys.tables 
        WHERE name LIKE ${likePattern}
        GROUP BY schema_id
        ORDER BY TableCount DESC
    `;
    
    logTable(result.recordset);
    
    const total = result.recordset.reduce((sum, r) => sum + r.TableCount, 0);
    log('bright', `Total: ${total} tables`);
    await disconnect();
}

// =============================================================================
// TABLE INSPECTION COMMANDS
// =============================================================================

async function showTableStructure(tableName) {
    const request = new sql.Request();
    request.input('tableName', sql.NVarChar, tableName);
    const result = await request.query(`
        SELECT 
            c.name AS ColumnName,
            t.name AS DataType,
            CASE 
                WHEN t.name IN ('nvarchar', 'nchar') THEN c.max_length / 2
                WHEN t.name IN ('varchar', 'char', 'varbinary') THEN c.max_length
                ELSE NULL
            END AS MaxLength,
            c.precision AS [Precision],
            c.scale AS Scale,
            CASE WHEN c.is_nullable = 1 THEN 'YES' ELSE 'NO' END AS Nullable,
            CASE WHEN c.is_identity = 1 THEN 'YES' ELSE 'NO' END AS [Identity],
            CASE WHEN pkc.column_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS PrimaryKey
        FROM sys.columns c
        INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
        LEFT JOIN (
            SELECT ic.column_id, ic.object_id
            FROM sys.index_columns ic
            INNER JOIN sys.indexes i ON ic.object_id = i.object_id 
                AND ic.index_id = i.index_id
            WHERE i.is_primary_key = 1
        ) pkc ON c.object_id = pkc.object_id AND c.column_id = pkc.column_id
        WHERE c.object_id = OBJECT_ID(@tableName)
        ORDER BY c.column_id
    `);
    
    if (result.recordset.length === 0) {
        log('yellow', `Table '${tableName}' not found or has no columns.`);
        return null;
    }
    
    log('cyan', `\nColumns for ${tableName}:`);
    logTable(result.recordset);
    return result.recordset;
}

async function cmdDescribe(tableName) {
    if (!tableName) {
        log('red', 'Usage: db-util.js describe <schema.tablename>');
        return;
    }
    
    if (!await connect()) return;
    
    await showTableStructure(tableName);
    
    // Also show foreign keys
    log('cyan', '\nForeign Keys:');
    const fkResult = await sql.query`
        SELECT
            fk.name AS FKName,
            COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ColumnName,
            OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
            COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ReferencedColumn
        FROM sys.foreign_keys fk
        INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        WHERE fk.parent_object_id = OBJECT_ID(${tableName})
    `;
    
    if (fkResult.recordset.length === 0) {
        log('dim', '(No foreign keys)');
    } else {
        logTable(fkResult.recordset);
    }
    
    await disconnect();
}

async function cmdColumns(tableName) {
    if (!tableName) {
        log('red', 'Usage: db-util.js columns <schema.tablename>');
        return;
    }
    
    if (!await connect()) return;
    await showTableStructure(tableName);
    await disconnect();
}

async function cmdKeys(tableName) {
    if (!tableName) {
        log('red', 'Usage: db-util.js keys <schema.tablename>');
        return;
    }
    
    if (!await connect()) return;
    
    log('cyan', `Primary Key for ${tableName}:`);
    const pkResult = await sql.query`
        SELECT 
            i.name AS IndexName,
            COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
            ic.key_ordinal AS KeyOrder
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.object_id = OBJECT_ID(${tableName}) AND i.is_primary_key = 1
        ORDER BY ic.key_ordinal
    `;
    
    if (pkResult.recordset.length === 0) {
        log('dim', '(No primary key)');
    } else {
        logTable(pkResult.recordset);
    }
    
    log('cyan', `\nForeign Keys for ${tableName}:`);
    const fkResult = await sql.query`
        SELECT
            fk.name AS FKName,
            COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ColumnName,
            OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
            COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ReferencedColumn
        FROM sys.foreign_keys fk
        INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        WHERE fk.parent_object_id = OBJECT_ID(${tableName})
    `;
    
    if (fkResult.recordset.length === 0) {
        log('dim', '(No foreign keys)');
    } else {
        logTable(fkResult.recordset);
    }
    
    await disconnect();
}

// =============================================================================
// STORED PROCEDURE COMMANDS
// =============================================================================

async function cmdProcs(schemaFilter = null) {
    if (!await connect()) return;
    
    log('cyan', schemaFilter ? `Listing procedures in schema '${schemaFilter}'...` : 'Listing stored procedures...');
    
    let result;
    if (schemaFilter) {
        result = await sql.query`
            SELECT TOP 50
                SCHEMA_NAME(schema_id) AS SchemaName,
                name AS ProcedureName,
                create_date AS Created,
                modify_date AS Modified
            FROM sys.procedures
            WHERE SCHEMA_NAME(schema_id) = ${schemaFilter}
            ORDER BY name
        `;
    } else {
        result = await sql.query`
            SELECT TOP 50
                SCHEMA_NAME(schema_id) AS SchemaName,
                name AS ProcedureName,
                create_date AS Created,
                modify_date AS Modified
            FROM sys.procedures
            ORDER BY SchemaName, name
        `;
    }
    
    logTable(result.recordset);
    await disconnect();
}

async function cmdProc(procName) {
    if (!procName) {
        log('red', 'Usage: db-util.js proc <procedure_name>');
        return;
    }
    
    if (!await connect()) return;
    
    log('cyan', `Definition for ${procName}:`);
    const result = await sql.query`
        SELECT OBJECT_DEFINITION(OBJECT_ID(${procName})) AS Definition
    `;
    
    if (result.recordset[0].Definition) {
        console.log(result.recordset[0].Definition);
    } else {
        log('yellow', `Procedure '${procName}' not found.`);
    }
    
    await disconnect();
}

// =============================================================================
// COMPARISON COMMANDS
// =============================================================================

function parseArchiveDefinition(tableType) {
    const archivePath = path.join(__dirname, '../notes/shared/scripts/tt-archive-capture/00_create_schema_and_archive_tables.sql');
    
    if (!fs.existsSync(archivePath)) {
        log('red', `Archive definition file not found: ${archivePath}`);
        return null;
    }
    
    const content = fs.readFileSync(archivePath, 'utf8');
    const archiveTableName = `Archive${tableType}`;
    
    // Find the CREATE TABLE statement for this archive table
    const regex = new RegExp(
        `CREATE TABLE tsip_archive\\.${archiveTableName}\\s*\\(([^;]+?)\\s*CONSTRAINT`,
        's'
    );
    
    const match = content.match(regex);
    if (!match) {
        log('yellow', `Could not find definition for ${archiveTableName} in archive file.`);
        return null;
    }
    
    const columnDefs = match[1];
    const columns = [];
    
    // Parse column definitions (skip ArchiveId, RunKey, PdfName, ArchivedAt - these are archive-specific)
    const lines = columnDefs.split('\n');
    for (const line of lines) {
        const colMatch = line.trim().match(/^(\w+)\s+([\w()]+)/);
        if (colMatch) {
            const colName = colMatch[1];
            // Skip archive-specific columns
            if (!['ArchiveId', 'RunKey', 'PdfName', 'ArchivedAt'].includes(colName)) {
                columns.push({
                    name: colName,
                    type: colMatch[2].toUpperCase()
                });
            }
        }
    }
    
    return columns;
}

async function cmdCompare(tableType) {
    if (!tableType) {
        log('red', 'Usage: db-util.js compare <type>');
        log('dim', 'Example: db-util.js compare FT_SITE');
        log('dim', 'Available types: FT_TITL, FT_SHRL, FT_SITE, FT_ANTE, FT_CHAN, FT_CHNG_CALL');
        log('dim', '                 FE_TITL, FE_SHRL, FE_SITE, FE_AZIM, FE_ANTE, FE_CHAN, FE_CLOC, FE_CCAL');
        return;
    }
    
    tableType = tableType.toUpperCase();
    log('cyan', `Comparing Archive${tableType} definition vs actual ${tableType.toLowerCase()} tables...`);
    
    // Parse archive definition
    const archiveColumns = parseArchiveDefinition(tableType);
    if (!archiveColumns) return;
    
    log('dim', `Archive definition has ${archiveColumns.length} source columns (excluding archive metadata)`);
    
    if (!await connect()) return;
    
    // Determine search pattern based on type
    const prefix = tableType.startsWith('FT_') ? 'ft_' : 'fe_';
    const suffix = '_' + tableType.split('_')[1].toLowerCase();
    const pattern = `${prefix}%${suffix}`;
    
    log('dim', `Searching for tables matching '${pattern}'...`);
    
    // Find one actual table
    const findTable = await sql.query`
        SELECT TOP 1 
            SCHEMA_NAME(schema_id) AS SchemaName,
            name AS TableName
        FROM sys.tables 
        WHERE name LIKE ${pattern}
        ORDER BY name
    `;
    
    if (findTable.recordset.length === 0) {
        log('yellow', `No tables found matching pattern '${pattern}'`);
        await disconnect();
        return;
    }
    
    const table = findTable.recordset[0];
    const fullName = `${table.SchemaName}.${table.TableName}`;
    log('green', `Found sample table: ${fullName}`);
    
    // Get actual columns
    const actualResult = await sql.query`
        SELECT 
            c.name AS ColumnName,
            UPPER(t.name) AS DataType
        FROM sys.columns c
        INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
        WHERE c.object_id = OBJECT_ID(${fullName})
        ORDER BY c.column_id
    `;
    
    const actualColumns = actualResult.recordset.map(r => ({
        name: r.ColumnName,
        type: r.DataType
    }));
    
    log('dim', `Actual table has ${actualColumns.length} columns`);
    
    // Compare
    console.log('\n');
    log('bright', '=== COMPARISON RESULTS ===');
    
    const archiveColNames = archiveColumns.map(c => c.name);
    const actualColNames = actualColumns.map(c => c.name);
    
    // Columns in archive but not in actual (ERRORS - will cause INSERT to fail)
    const missingInActual = archiveColumns.filter(c => !actualColNames.includes(c.name));
    if (missingInActual.length > 0) {
        log('red', '\nERROR: Columns in archive definition but NOT in actual table:');
        missingInActual.forEach(c => {
            log('red', `  - ${c.name} (${c.type})`);
        });
    }
    
    // Columns in actual but not in archive (WARNINGS - data not being captured)
    const missingInArchive = actualColumns.filter(c => !archiveColNames.includes(c.name));
    if (missingInArchive.length > 0) {
        log('yellow', '\nWARNING: Columns in actual table but NOT in archive definition:');
        missingInArchive.forEach(c => {
            log('yellow', `  - ${c.name} (${c.type})`);
        });
    }
    
    // Matching columns
    const matching = archiveColumns.filter(c => actualColNames.includes(c.name));
    log('green', `\nMatching columns: ${matching.length}/${archiveColumns.length}`);
    
    if (missingInActual.length === 0 && missingInArchive.length === 0) {
        log('green', '\nPERFECT MATCH! Archive definition matches actual table structure.');
    } else if (missingInActual.length > 0) {
        log('red', '\nACTION REQUIRED: Remove non-existent columns from archive definition and trigger.');
    }
    
    await disconnect();
}

// =============================================================================
// QUERY COMMANDS
// =============================================================================

async function cmdQuery(sqlText) {
    if (!sqlText) {
        log('red', 'Usage: db-util.js query "<sql statement>"');
        return;
    }
    
    if (!await connect()) return;
    
    log('cyan', 'Executing query...');
    try {
        const startTime = Date.now();
        const result = await sql.query(sqlText);
        const elapsed = Date.now() - startTime;
        
        if (result.recordset && result.recordset.length > 0) {
            logTable(result.recordset);
        } else {
            log('green', `Query executed successfully. Rows affected: ${result.rowsAffected || 0}`);
        }
        log('dim', `Time: ${elapsed}ms`);
    } catch (err) {
        log('red', `Query error: ${err.message}`);
    }
    
    await disconnect();
}

async function cmdInteractive() {
    if (!await connect()) return;
    
    log('cyan', 'MICS SQL Server Interactive Mode');
    log('dim', `Connected to: ${sqlConfig.database}@${sqlConfig.server}`);
    log('dim', 'Type SQL queries ending with ; or use commands:');
    log('dim', '  \\q       - Quit');
    log('dim', '  \\d       - List tables');
    log('dim', '  \\d <tbl> - Describe table');
    console.log('');
    
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        prompt: `${sqlConfig.database}> `
    });
    
    let currentQuery = '';
    
    rl.on('line', async (input) => {
        const line = input.trim();
        
        if (line === '\\q') {
            await disconnect();
            rl.close();
            return;
        }
        
        if (line === '\\d') {
            const result = await sql.query`
                SELECT TOP 50 SCHEMA_NAME(schema_id) + '.' + name AS TableName
                FROM sys.tables ORDER BY name
            `;
            result.recordset.forEach(r => console.log(r.TableName));
            rl.prompt();
            return;
        }
        
        if (line.startsWith('\\d ')) {
            const tableName = line.substring(3).trim();
            await showTableStructure(tableName);
            rl.prompt();
            return;
        }
        
        if (line.endsWith(';')) {
            currentQuery += ' ' + line;
            try {
                const result = await sql.query(currentQuery);
                if (result.recordset && result.recordset.length > 0) {
                    console.table(result.recordset);
                } else {
                    console.log(`OK (${result.rowsAffected || 0} rows affected)`);
                }
            } catch (err) {
                log('red', `Error: ${err.message}`);
            }
            currentQuery = '';
            rl.prompt();
        } else {
            currentQuery += ' ' + line;
            rl.setPrompt('... ');
            rl.prompt();
        }
    });
    
    rl.on('close', async () => {
        await disconnect();
        console.log('\nGoodbye!');
        process.exit(0);
    });
    
    rl.prompt();
}

// =============================================================================
// HELP
// =============================================================================

function showHelp() {
    console.log(`
${colors.cyan}MICS SQL Server Database Toolkit${colors.reset}

${colors.bright}Usage:${colors.reset} node db-util.js <command> [options]

${colors.bright}Connection Commands:${colors.reset}
  test                    Test database connection
  databases               List accessible databases

${colors.bright}Schema Discovery:${colors.reset}
  schemas                 List all schemas with table counts
  tables [--schema X]     List tables (optionally filter by schema)
  sample <suffix>         Find ONE table matching suffix (e.g., _site)
  count <pattern>         Count tables by schema matching pattern (e.g., ft_)

${colors.bright}Table Inspection:${colors.reset}
  describe <table>        Full table structure (columns, PKs, FKs)
  columns <table>         Column list only
  keys <table>            Primary and foreign keys

${colors.bright}Stored Procedures:${colors.reset}
  procs [--schema X]      List stored procedures
  proc <name>             Show procedure definition

${colors.bright}Comparison:${colors.reset}
  compare <type>          Compare archive def vs actual table
                          Types: FT_SITE, FT_ANTE, FE_SITE, etc.

${colors.bright}Query:${colors.reset}
  query "<sql>"           Execute ad-hoc SQL query
  interactive             Interactive query mode (psql-like)

${colors.bright}Examples:${colors.reset}
  node db-util.js test
  node db-util.js sample _site
  node db-util.js describe dbo.ft_myproj_site
  node db-util.js compare FT_SITE
  node db-util.js count fe_
`);
}

// =============================================================================
// MAIN
// =============================================================================

async function main() {
    const args = process.argv.slice(2);
    const command = args[0];
    
    if (!command || command === 'help' || command === '--help' || command === '-h') {
        showHelp();
        return;
    }
    
    switch (command) {
        case 'test':
            await cmdTest();
            break;
        case 'databases':
            await cmdDatabases();
            break;
        case 'schemas':
            await cmdSchemas();
            break;
        case 'tables':
            const schemaArg = args.indexOf('--schema');
            const schemaFilter = schemaArg !== -1 ? args[schemaArg + 1] : null;
            await cmdTables(schemaFilter);
            break;
        case 'sample':
            await cmdSample(args[1]);
            break;
        case 'count':
            await cmdCount(args[1]);
            break;
        case 'describe':
            await cmdDescribe(args[1]);
            break;
        case 'columns':
            await cmdColumns(args[1]);
            break;
        case 'keys':
            await cmdKeys(args[1]);
            break;
        case 'procs':
            const procSchemaArg = args.indexOf('--schema');
            const procSchemaFilter = procSchemaArg !== -1 ? args[procSchemaArg + 1] : null;
            await cmdProcs(procSchemaFilter);
            break;
        case 'proc':
            await cmdProc(args[1]);
            break;
        case 'compare':
            await cmdCompare(args[1]);
            break;
        case 'query':
            await cmdQuery(args.slice(1).join(' '));
            break;
        case 'interactive':
            await cmdInteractive();
            break;
        default:
            log('red', `Unknown command: ${command}`);
            log('dim', 'Use "node db-util.js help" to see available commands.');
    }
}

main().catch(err => {
    log('red', `Fatal error: ${err.message}`);
    process.exit(1);
});
