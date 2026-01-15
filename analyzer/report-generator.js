/**
 * MICS# Report Generator
 * 
 * READ-ONLY ANALYSIS TOOL
 * =======================
 * Generates readable reports from the analysis results.
 * All output is written to the reports/ directory in THIS workspace.
 */

const fs = require('fs');
const path = require('path');
const config = require('./config');

const outputDir = config.OUTPUT_DIR;

/**
 * Safely write to output directory only
 */
function safeWriteFile(outputPath, content) {
    if (!config.isPathSafeForWrite(outputPath)) {
        throw new Error(`Refusing to write to unsafe path: ${outputPath}`);
    }
    fs.writeFileSync(outputPath, content);
}

/**
 * Load analysis results
 */
function loadResults() {
    const resultsPath = path.join(outputDir, 'analysis-results.json');
    if (!fs.existsSync(resultsPath)) {
        console.error('Analysis results not found. Run "npm run analyze" first.');
        process.exit(1);
    }
    return JSON.parse(fs.readFileSync(resultsPath, 'utf8'));
}

/**
 * Generate project dependency report
 */
function generateDependencyReport(results) {
    let report = `# MICS# Project Dependencies\n\n`;
    report += `Generated: ${new Date().toISOString()}\n\n`;
    
    // Create dependency matrix
    report += `## Project Overview\n\n`;
    report += `| Project | Type | Framework | Dependencies | Source Files |\n`;
    report += `|---------|------|-----------|--------------|-------------|\n`;
    
    // Sort projects by name
    const sortedProjects = [...results.projects].sort((a, b) => a.name.localeCompare(b.name));
    
    for (const proj of sortedProjects) {
        const deps = proj.dependencies ? proj.dependencies.join(', ') : '-';
        report += `| ${proj.name} | ${proj.outputType || 'Unknown'} | ${proj.framework || '?'} | ${deps} | ${proj.sourceFileCount || 0} |\n`;
    }
    
    // Dependency graph (text-based)
    report += `\n## Dependency Graph\n\n`;
    report += `\`\`\`\n`;
    
    for (const proj of sortedProjects) {
        if (proj.dependencies && proj.dependencies.length > 0) {
            report += `${proj.name}\n`;
            for (const dep of proj.dependencies) {
                report += `  └── ${dep}\n`;
            }
            report += `\n`;
        }
    }
    report += `\`\`\`\n`;
    
    // Core libraries (most depended upon)
    report += `\n## Core Libraries (Most Depended Upon)\n\n`;
    const dependencyCounts = {};
    for (const proj of results.projects) {
        if (proj.dependencies) {
            for (const dep of proj.dependencies) {
                dependencyCounts[dep] = (dependencyCounts[dep] || 0) + 1;
            }
        }
    }
    
    const sortedDeps = Object.entries(dependencyCounts)
        .sort((a, b) => b[1] - a[1]);
    
    report += `| Library | Dependents |\n`;
    report += `|---------|------------|\n`;
    for (const [lib, count] of sortedDeps) {
        report += `| ${lib} | ${count} |\n`;
    }
    
    return report;
}

/**
 * Generate class/method report
 */
function generateClassReport(results) {
    let report = `# MICS# Classes and Methods\n\n`;
    report += `Generated: ${new Date().toISOString()}\n\n`;
    
    // Summary
    report += `## Summary\n\n`;
    report += `- Total Classes: ${results.metrics.totalClasses}\n`;
    report += `- Total Methods: ${results.metrics.totalMethods}\n`;
    report += `- Total Lines: ${results.metrics.totalLines.toLocaleString()}\n\n`;
    
    // Classes by project
    report += `## Classes by Project\n\n`;
    
    const classesByProject = {};
    for (const cls of results.classes) {
        if (!classesByProject[cls.project]) {
            classesByProject[cls.project] = [];
        }
        classesByProject[cls.project].push(cls);
    }
    
    for (const [project, classes] of Object.entries(classesByProject).sort()) {
        report += `### ${project} (${classes.length} classes)\n\n`;
        report += `| Type | Name | Inheritance |\n`;
        report += `|------|------|-------------|\n`;
        for (const cls of classes.slice(0, 50)) { // Limit for readability
            const inherit = cls.inheritance || '-';
            report += `| ${cls.type} | ${cls.name} | ${inherit.substring(0, 50)} |\n`;
        }
        if (classes.length > 50) {
            report += `| ... | *${classes.length - 50} more* | ... |\n`;
        }
        report += `\n`;
    }
    
    // Large files (by method count)
    report += `## Largest Files (by method count)\n\n`;
    const filesByMethods = [...results.files]
        .filter(f => f.methods && f.methods.length > 0)
        .sort((a, b) => b.methods.length - a.methods.length)
        .slice(0, 20);
    
    report += `| File | Methods | Classes | Lines |\n`;
    report += `|------|---------|---------|-------|\n`;
    for (const file of filesByMethods) {
        report += `| ${file.relativePath} | ${file.methods.length} | ${file.classes.length} | ${file.lines} |\n`;
    }
    
    return report;
}

/**
 * Generate P/Invoke report
 */
function generatePInvokeReport(results) {
    let report = `# MICS# P/Invoke Declarations\n\n`;
    report += `Generated: ${new Date().toISOString()}\n\n`;
    
    report += `Total P/Invoke declarations: ${results.pInvokes.length}\n\n`;
    
    // Group by DLL
    const byDll = {};
    for (const pInvoke of results.pInvokes) {
        if (!byDll[pInvoke.dll]) {
            byDll[pInvoke.dll] = [];
        }
        byDll[pInvoke.dll].push(pInvoke);
    }
    
    report += `## P/Invokes by DLL\n\n`;
    
    for (const [dll, funcs] of Object.entries(byDll).sort()) {
        report += `### ${dll} (${funcs.length} functions)\n\n`;
        report += `| Function | Project | File |\n`;
        report += `|----------|---------|------|\n`;
        for (const func of funcs) {
            report += `| ${func.function} | ${func.project} | ${func.file} |\n`;
        }
        report += `\n`;
    }
    
    return report;
}

/**
 * Generate TODO/FIXME report
 */
function generateTodoReport(results) {
    let report = `# MICS# TODO/FIXME Comments\n\n`;
    report += `Generated: ${new Date().toISOString()}\n\n`;
    
    report += `Total TODO comments: ${results.todos.length}\n\n`;
    
    // Group by type
    const byType = {};
    for (const todo of results.todos) {
        if (!byType[todo.type]) {
            byType[todo.type] = [];
        }
        byType[todo.type].push(todo);
    }
    
    for (const [type, todos] of Object.entries(byType).sort()) {
        report += `## ${type} (${todos.length})\n\n`;
        report += `| File | Line | Comment |\n`;
        report += `|------|------|--------|\n`;
        for (const todo of todos.slice(0, 100)) {
            const text = todo.text.substring(0, 60).replace(/\|/g, '\\|');
            report += `| ${todo.file} | ${todo.line} | ${text} |\n`;
        }
        if (todos.length > 100) {
            report += `| ... | ... | *${todos.length - 100} more* |\n`;
        }
        report += `\n`;
    }
    
    return report;
}

/**
 * Generate namespace report
 */
function generateNamespaceReport(results) {
    let report = `# MICS# Namespace Analysis\n\n`;
    report += `Generated: ${new Date().toISOString()}\n\n`;
    
    // Group files by namespace
    const byNamespace = {};
    for (const file of results.files) {
        const ns = file.namespace || '(No namespace)';
        if (!byNamespace[ns]) {
            byNamespace[ns] = { files: [], lines: 0, classes: 0 };
        }
        byNamespace[ns].files.push(file);
        byNamespace[ns].lines += file.lines;
        byNamespace[ns].classes += file.classes.length;
    }
    
    report += `## Namespaces\n\n`;
    report += `| Namespace | Files | Classes | Lines |\n`;
    report += `|-----------|-------|---------|-------|\n`;
    
    for (const [ns, data] of Object.entries(byNamespace).sort()) {
        report += `| ${ns} | ${data.files.length} | ${data.classes} | ${data.lines.toLocaleString()} |\n`;
    }
    
    // Using statement analysis
    report += `\n## Most Used External Dependencies\n\n`;
    const usingCounts = {};
    for (const file of results.files) {
        if (file.usings) {
            for (const using of file.usings) {
                // Filter to external namespaces
                if (!using.startsWith('_') && !using.startsWith('TpRunTsip')) {
                    usingCounts[using] = (usingCounts[using] || 0) + 1;
                }
            }
        }
    }
    
    const sortedUsings = Object.entries(usingCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 30);
    
    report += `| Namespace | Usage Count |\n`;
    report += `|-----------|-------------|\n`;
    for (const [ns, count] of sortedUsings) {
        report += `| ${ns} | ${count} |\n`;
    }
    
    return report;
}

/**
 * Generate executive summary
 */
function generateSummary(results) {
    let report = `# MICS# Codebase Analysis Summary\n\n`;
    report += `Generated: ${new Date().toISOString()}\n\n`;
    report += `Source: ${results.micsPath || config.MICS_PATH}\n\n`;
    
    report += `## Overview\n\n`;
    report += `| Metric | Value |\n`;
    report += `|--------|-------|\n`;
    report += `| Total Projects | ${results.metrics.totalProjects} |\n`;
    report += `| Source Files | ${results.metrics.totalFiles} |\n`;
    report += `| Total Lines of Code | ${results.metrics.totalLines.toLocaleString()} |\n`;
    report += `| Classes/Structs/Interfaces | ${results.metrics.totalClasses} |\n`;
    report += `| Methods | ${results.metrics.totalMethods} |\n`;
    report += `| P/Invoke Declarations | ${results.metrics.totalPInvokes} |\n`;
    report += `| TODO/FIXME Comments | ${results.metrics.totalTodos} |\n`;
    report += `| Analysis Errors | ${results.errors.length} |\n`;
    
    // Project types
    report += `\n## Project Types\n\n`;
    const projectTypes = {};
    for (const proj of results.projects) {
        const type = proj.outputType || 'Unknown';
        projectTypes[type] = (projectTypes[type] || 0) + 1;
    }
    
    report += `| Type | Count |\n`;
    report += `|------|-------|\n`;
    for (const [type, count] of Object.entries(projectTypes)) {
        report += `| ${type} | ${count} |\n`;
    }
    
    // Top 10 largest files
    report += `\n## Top 10 Largest Files\n\n`;
    const largestFiles = [...results.files]
        .sort((a, b) => b.lines - a.lines)
        .slice(0, 10);
    
    report += `| File | Lines | Project |\n`;
    report += `|------|-------|--------|\n`;
    for (const file of largestFiles) {
        report += `| ${path.basename(file.path)} | ${file.lines.toLocaleString()} | ${file.project} |\n`;
    }
    
    // Architecture overview
    report += `\n## Architecture\n\n`;
    report += `The MICS# solution consists of the following project categories:\n\n`;
    
    report += `### Core Libraries\n`;
    report += `- **_Configuration**: Constants and error definitions\n`;
    report += `- **_DataStructures**: Data models (Sites, Antennas, Channels, etc.)\n`;
    report += `- **_NewLib**: Modern utility classes\n`;
    report += `- **_Utillib**: Business logic utilities\n`;
    report += `- **_Auxlib**: Mathematical calculations\n`;
    report += `- **_OHloss**: Over-horizon loss calculations\n\n`;
    
    report += `### Applications\n`;
    const apps = results.projects.filter(p => p.outputType === 'Exe');
    for (const app of apps.slice(0, 15)) {
        report += `- **${app.name}**\n`;
    }
    if (apps.length > 15) {
        report += `- ... and ${apps.length - 15} more\n`;
    }
    
    return report;
}

/**
 * Main function
 */
function main() {
    console.log('='.repeat(60));
    console.log('MICS# Report Generator (READ-ONLY MODE)');
    console.log('='.repeat(60));
    console.log(`\nOutput Directory: ${outputDir}`);
    
    // Load results
    const results = loadResults();
    console.log(`Loaded analysis from: ${results.timestamp}`);
    
    // Generate reports
    console.log('\nGenerating reports...');
    
    const reports = [
        { name: 'summary.md', generator: generateSummary },
        { name: 'dependencies.md', generator: generateDependencyReport },
        { name: 'classes.md', generator: generateClassReport },
        { name: 'pinvokes.md', generator: generatePInvokeReport },
        { name: 'todos.md', generator: generateTodoReport },
        { name: 'namespaces.md', generator: generateNamespaceReport }
    ];
    
    for (const { name, generator } of reports) {
        try {
            const content = generator(results);
            const outputPath = path.join(outputDir, name);
            safeWriteFile(outputPath, content);
            console.log(`  Created: ${name}`);
        } catch (err) {
            console.error(`  Error generating ${name}: ${err.message}`);
        }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log(`Reports saved to: ${outputDir}/`);
    console.log('='.repeat(60));
}

main();

