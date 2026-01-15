/**
 * MICS# Analyzer Configuration
 * 
 * READ-ONLY ANALYSIS WORKSPACE
 * ============================
 * This workspace is configured for READ-ONLY analysis of the MICS# codebase.
 * DO NOT modify any files in the MICS_PATH directory.
 */

const path = require('path');

module.exports = {
    // Path to the MICS# solution (relative to this workspace)
    // IMPORTANT: This path should ONLY be used for READING files
    MICS_PATH: path.resolve(__dirname, '../../CloudMICS# 20230116/MICS#'),
    
    // Solution file name
    SOLUTION_FILE: 'MICS#.sln',
    
    // Output directory for reports (within THIS workspace, not in MICS# source)
    OUTPUT_DIR: path.resolve(__dirname, '../reports'),
    
    // Analysis options
    options: {
        // Include bin/obj directories in analysis
        includeBuildDirs: false,
        
        // Maximum file size to analyze (in bytes)
        maxFileSize: 1024 * 1024, // 1MB
        
        // File patterns to analyze
        filePatterns: ['*.cs'],
        
        // Directories to skip
        skipDirs: ['bin', 'obj', 'packages', 'node_modules', '.git', '_bin'],
        
        // Calculate cyclomatic complexity
        calculateComplexity: true,
        
        // Track TODO/FIXME comments
        trackTodos: true,
        
        // Analyze P/Invoke declarations
        analyzePInvoke: true,
        
        // READ-ONLY MODE: Never write to MICS_PATH
        readOnlyMode: true
    },
    
    // Safety check function
    isPathSafeForWrite: function(targetPath) {
        const resolved = path.resolve(targetPath);
        const micsResolved = path.resolve(this.MICS_PATH);
        
        // Never allow writing to MICS# source
        if (resolved.startsWith(micsResolved)) {
            console.error('ERROR: Attempted to write to MICS# source directory!');
            console.error('Path:', resolved);
            return false;
        }
        return true;
    }
};

