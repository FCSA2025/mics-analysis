/**
 * MICS Database Configuration
 * 
 * Connection settings for SQL Server access to verify table structures.
 * Uses CursorAiAccess login for read-only schema inspection.
 * 
 * Target: micsprod (production database with extensive FT/FE tables)
 */

const sqlConfig = {
    user: 'CursorAiAccess',
    password: 'Cack31415',
    database: 'micsprod',
    server: 'DESKTOP-EEUSAQH',
    options: {
        encrypt: true,
        trustServerCertificate: true,
        requestTimeout: 30000  // 30 second timeout for large queries
    }
};

module.exports = { sqlConfig };
