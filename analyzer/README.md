# MICS Database Analyzer Tools

This directory contains Node.js utilities for analyzing the MICS SQL Server database schemas, validating archive table definitions, and performing ad-hoc queries.

## Prerequisites

- Node.js (v16 or higher)
- SQL Server access via `CursorAiAccess` login (configured in `db-config.js`)

## Installation

```bash
cd analyzer
npm install
```

## Database Utilities (db-util.js)

A comprehensive CLI tool for SQL Server database inspection and schema comparison.

### Usage

```bash
node db-util.js <command> [options]
```

### Commands

#### Connection
| Command | Description |
|---------|-------------|
| `test` | Test database connection and show server info |
| `databases` | List all accessible databases |

#### Schema Discovery
| Command | Description |
|---------|-------------|
| `schemas` | List all schemas with table counts |
| `tables [--schema X]` | List tables (optionally filter by schema) |
| `sample <suffix>` | Find ONE table matching suffix pattern (e.g., `_site`) |
| `count <pattern>` | Count tables by schema matching pattern (e.g., `ft_`) |

#### Table Inspection
| Command | Description |
|---------|-------------|
| `describe <table>` | Full table structure (columns, types, PKs, FKs) |
| `columns <table>` | Column list with data types |
| `keys <table>` | Primary and foreign key information |

#### Stored Procedures
| Command | Description |
|---------|-------------|
| `procs [--schema X]` | List stored procedures |
| `proc <name>` | Show procedure definition |

#### Comparison
| Command | Description |
|---------|-------------|
| `compare <type>` | Compare archive definition vs actual table structure |

Available types: `FT_TITL`, `FT_SHRL`, `FT_SITE`, `FT_ANTE`, `FT_CHAN`, `FT_CHNG_CALL`, `FE_TITL`, `FE_SHRL`, `FE_SITE`, `FE_AZIM`, `FE_ANTE`, `FE_CHAN`, `FE_CLOC`, `FE_CCAL`

#### Query
| Command | Description |
|---------|-------------|
| `query "<sql>"` | Execute ad-hoc SQL query |
| `interactive` | Interactive query mode (psql-like) |

### Examples

```bash
# Test connection
node db-util.js test

# Count FT tables by schema
node db-util.js count ft_

# Describe a specific table
node db-util.js describe rctl.ft_0_site

# Compare archive definition vs actual
node db-util.js compare FT_SITE

# Run ad-hoc query
node db-util.js query "SELECT TOP 5 * FROM sys.tables"

# Interactive mode
node db-util.js interactive
```

### Interactive Mode Commands

When in interactive mode:
- `\q` - Quit
- `\d` - List tables
- `\d <table>` - Describe table
- Type SQL ending with `;` to execute

## Configuration

Database connection settings are in `db-config.js`:

```javascript
const sqlConfig = {
    user: 'CursorAiAccess',
    password: '***',
    database: 'micsprod',
    server: 'DESKTOP-EEUSAQH',
    options: {
        encrypt: true,
        trustServerCertificate: true,
        requestTimeout: 30000  // 30 second timeout
    }
};
```

To change the target database, edit the `database` field.

## Timeout Safety

The tool is designed with timeout protection for large production databases:
- Uses `TOP 1` for sample queries
- Limits table listings to 100 results
- 30-second query timeout configured
- Count-only queries for large table sets

## Files

| File | Purpose |
|------|---------|
| `db-util.js` | Main CLI tool |
| `db-config.js` | Database connection configuration |
| `package.json` | Node.js dependencies |
| `analyzer.js` | Code analysis utilities (separate tool) |
| `config.js` | Code analyzer configuration |
| `report-generator.js` | Code analysis report generator |

## Related Documentation

- [FT/FE Table Schema Findings](../notes/shared/FT-FE-TABLE-SCHEMA-FINDINGS.md) - Results of schema verification
- [SQL Server Access Notes](../notes/shared/sql-server-cursorai-access.md) - Connection details
- [Database Tables Reference](../notes/shared/database-tables.md) - Table structure documentation
