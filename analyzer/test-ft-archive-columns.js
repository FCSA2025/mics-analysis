#!/usr/bin/env node
/**
 * test-ft-archive-columns.js
 * 
 * Tests that our FT archive table definitions match the actual FT table columns
 * by comparing against a real FT table set (e.g., bmce.ft_f3268_*)
 * 
 * Usage: node test-ft-archive-columns.js [schema.prefix]
 *        Default: bmce.ft_f3268
 */

const sql = require('mssql');
const { sqlConfig } = require('./db-config');

// Expected columns for each archive table (verified from micsprod)
// These should match what we INSERT in the trigger
const EXPECTED_FT_COLUMNS = {
    titl: ['validated', 'namef', 'source', 'descr', 'mdate', 'mtime'],
    shrl: ['userid', 'mdate', 'mtime'],
    site: [
        'cmd', 'recstat', 'call1', 'name', 'prov', 'oper', 'latit', 'longit', 'grnd',
        'stats', 'sdate', 'loc', 'icaccount', 'reg', 'spoint', 'nots', 'oprtyp', 'snumb',
        'notwr', 'bandwd1', 'bandwd2', 'bandwd3', 'bandwd4', 'bandwd5', 'bandwd6', 'bandwd7', 'bandwd8',
        'mdate', 'mtime'
    ],
    ante: [
        'cmd', 'recstat', 'call1', 'call2', 'bndcde', 'anum', 'ause', 'acode',
        'aht', 'azmth', 'elvtn', 'dist', 'offazm', 'tazmth', 'telvtn', 'tgain',
        'txfdlnth', 'txfdlnlh', 'txfdlntv', 'txfdlnlv', 'rxfdlnth', 'rxfdlnlh', 'rxfdlntv', 'rxfdlnlv',
        'txpadpam', 'rxpadlna', 'txcompl', 'rxcompl', 'obsloss', 'kvalue', 'atwrno', 'nota', 'apoint',
        'sdate', 'mdate', 'mtime', 'licence'
    ],
    chan: [
        'cmd', 'recstat', 'call1', 'call2', 'bndcde', 'splan', 'hl', 'vh', 'chid',
        'freqtx', 'poltx', 'antnumbtx1', 'antnumbtx2', 'eqpttx', 'eqptutx', 'pwrtx', 'atpccde',
        'afsltx1', 'afsltx2', 'traftx', 'srvctx', 'stattx',
        'freqrx', 'polrx', 'antnumbrx1', 'antnumbrx2', 'antnumbrx3', 'eqptrx', 'eqpturx',
        'afslrx1', 'afslrx2', 'afslrx3', 'pwrrx1', 'pwrrx2', 'pwrrx3', 'trafrx', 'esint', 'tsint',
        'srvcrx', 'statrx', 'routnumb', 'stnnumb', 'hopnumb', 'sdate',
        'notetx', 'noterx', 'notegnl', 'cpoint', 'feetx', 'feerx', 'mdate', 'mtime'
    ],
    chng_call: ['newcall1', 'oldcall1', 'name']
};

async function getTableColumns(tableName) {
    const request = new sql.Request();
    request.input('tableName', sql.NVarChar, tableName);
    const result = await request.query(`
        SELECT c.name AS ColumnName
        FROM sys.columns c
        WHERE c.object_id = OBJECT_ID(@tableName)
        ORDER BY c.column_id
    `);
    return result.recordset.map(r => r.ColumnName.toLowerCase());
}

async function testTable(schema, prefix, suffix) {
    const tableName = `${schema}.${prefix}_${suffix}`;
    const expectedCols = EXPECTED_FT_COLUMNS[suffix];
    
    if (!expectedCols) {
        console.log(`  [SKIP] ${suffix} - no expected columns defined`);
        return { status: 'skip', table: suffix };
    }
    
    try {
        const actualCols = await getTableColumns(tableName);
        
        if (actualCols.length === 0) {
            console.log(`  [SKIP] ${tableName} - table not found`);
            return { status: 'skip', table: suffix };
        }
        
        // Check if all expected columns exist in actual table
        const missing = expectedCols.filter(c => !actualCols.includes(c.toLowerCase()));
        const extra = actualCols.filter(c => !expectedCols.map(e => e.toLowerCase()).includes(c));
        
        if (missing.length === 0) {
            console.log(`  [PASS] ${suffix} - all ${expectedCols.length} archive columns found in source`);
            if (extra.length > 0) {
                console.log(`         (${extra.length} extra cols in source not archived: ${extra.slice(0, 5).join(', ')}${extra.length > 5 ? '...' : ''})`);
            }
            return { status: 'pass', table: suffix, extra: extra.length };
        } else {
            console.log(`  [FAIL] ${suffix} - MISSING columns: ${missing.join(', ')}`);
            return { status: 'fail', table: suffix, missing };
        }
    } catch (err) {
        console.log(`  [ERROR] ${suffix} - ${err.message}`);
        return { status: 'error', table: suffix, error: err.message };
    }
}

async function main() {
    const arg = process.argv[2] || 'bmce.ft_f3268';
    const parts = arg.split('.');
    const schema = parts[0];
    const prefix = parts[1] || 'ft_f3268';
    
    console.log('='.repeat(70));
    console.log('FT Archive Column Validation Test');
    console.log('='.repeat(70));
    console.log(`Testing against: ${schema}.${prefix}_*`);
    console.log(`Database: ${sqlConfig.database}`);
    console.log('');
    
    try {
        await sql.connect(sqlConfig);
        console.log('Connected to database.\n');
        
        const suffixes = ['titl', 'shrl', 'site', 'ante', 'chan', 'chng_call'];
        const results = [];
        
        for (const suffix of suffixes) {
            const result = await testTable(schema, prefix, suffix);
            results.push(result);
        }
        
        console.log('\n' + '='.repeat(70));
        console.log('SUMMARY');
        console.log('='.repeat(70));
        
        const passed = results.filter(r => r.status === 'pass').length;
        const failed = results.filter(r => r.status === 'fail').length;
        const skipped = results.filter(r => r.status === 'skip').length;
        const errors = results.filter(r => r.status === 'error').length;
        
        console.log(`Passed:  ${passed}`);
        console.log(`Failed:  ${failed}`);
        console.log(`Skipped: ${skipped}`);
        console.log(`Errors:  ${errors}`);
        console.log('');
        
        if (failed === 0 && errors === 0) {
            console.log('SUCCESS: All archive column definitions match the source tables!');
            console.log('The trigger INSERT statements should work correctly.');
        } else {
            console.log('ISSUES FOUND: Some archive definitions do not match source tables.');
            console.log('Review the failures above and update the archive definitions.');
        }
        
    } catch (err) {
        console.error('Fatal error:', err.message);
        process.exit(1);
    } finally {
        await sql.close();
    }
}

main();
