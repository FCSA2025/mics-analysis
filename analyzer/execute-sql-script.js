#!/usr/bin/env node
/**
 * execute-sql-script.js
 * 
 * Executes a SQL script file against the configured database.
 * Handles GO batch separators properly.
 * 
 * Usage: node execute-sql-script.js <script-path>
 */

const sql = require('mssql');
const fs = require('fs');
const path = require('path');
const { sqlConfig } = require('./db-config');

async function executeSqlScript(scriptPath) {
    const fullPath = path.resolve(scriptPath);
    
    console.log('='.repeat(70));
    console.log('SQL Script Executor');
    console.log('='.repeat(70));
    console.log(`Script: ${fullPath}`);
    console.log(`Database: ${sqlConfig.database}`);
    console.log(`Server: ${sqlConfig.server}`);
    console.log('');
    
    if (!fs.existsSync(fullPath)) {
        console.error(`Error: File not found: ${fullPath}`);
        process.exit(1);
    }
    
    const scriptContent = fs.readFileSync(fullPath, 'utf8');
    
    // Split by GO statements (case insensitive, on its own line)
    // Replace the USE statement placeholder
    const modifiedContent = scriptContent.replace(
        /USE \[YourDatabase\];/gi, 
        `USE [${sqlConfig.database}];`
    );
    
    // Split into batches by GO
    const batches = modifiedContent
        .split(/^\s*GO\s*$/gim)
        .map(b => b.trim())
        .filter(b => b.length > 0 && !/^--[^\n]*$/.test(b));  // Remove empty and pure single-line comment batches
    
    console.log(`Found ${batches.length} batches to execute.\n`);
    
    try {
        await sql.connect(sqlConfig);
        console.log('Connected to database.\n');
        
        let successCount = 0;
        let errorCount = 0;
        
        for (let i = 0; i < batches.length; i++) {
            const batch = batches[i];
            const preview = batch.substring(0, 80).replace(/\n/g, ' ').trim();
            
            process.stdout.write(`[${i + 1}/${batches.length}] ${preview}...`);
            
            try {
                const request = new sql.Request();
                await request.batch(batch);
                console.log(' OK');
                successCount++;
            } catch (err) {
                console.log(` ERROR: ${err.message}`);
                errorCount++;
                // Continue with next batch
            }
        }
        
        console.log('\n' + '='.repeat(70));
        console.log('SUMMARY');
        console.log('='.repeat(70));
        console.log(`Successful: ${successCount}`);
        console.log(`Errors: ${errorCount}`);
        console.log(`Total: ${batches.length}`);
        
        if (errorCount === 0) {
            console.log('\nScript executed successfully!');
        } else {
            console.log('\nScript completed with errors. Review output above.');
        }
        
    } catch (err) {
        console.error('Fatal error:', err.message);
        process.exit(1);
    } finally {
        await sql.close();
    }
}

// Main
const scriptPath = process.argv[2];
if (!scriptPath) {
    console.log('Usage: node execute-sql-script.js <script-path>');
    console.log('');
    console.log('Example:');
    console.log('  node execute-sql-script.js ../notes/shared/scripts/tt-archive-capture/00_create_schema_and_archive_tables.sql');
    process.exit(1);
}

executeSqlScript(scriptPath);
