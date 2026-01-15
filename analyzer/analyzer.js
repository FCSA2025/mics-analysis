/**
 * MICS# Code Analyzer
 * 
 * READ-ONLY ANALYSIS TOOL
 * =======================
 * This tool ONLY reads from the MICS# source directory.
 * All output is written to the reports/ directory in THIS workspace.
 * 
 * Analyzes the MICS# codebase to extract:
 * - Project structure and dependencies
 * - Class and method information
 * - Code metrics (lines, complexity)
 * - P/Invoke declarations
 * - TODO/FIXME comments
 */

const fs = require('fs');
const path = require('path');
const config = require('./config');

// Analysis results
const results = {
    timestamp: new Date().toISOString(),
    micsPath: config.MICS_PATH,
    solution: null,
    projects: [],
    files: [],
    classes: [],
    methods: [],
    pInvokes: [],
    todos: [],
    metrics: {
        totalProjects: 0,
        totalFiles: 0,
        totalLines: 0,
        totalClasses: 0,
        totalMethods: 0,
        totalPInvokes: 0,
        totalTodos: 0
    },
    errors: []
};

/**
 * Parse the solution file to extract project references
 */
function parseSolutionFile(slnPath) {
    console.log(`\nParsing solution: ${slnPath}`);
    
    try {
        const content = fs.readFileSync(slnPath, 'utf8');
        const projects = [];
        
        // Match project definitions: Project("{GUID}") = "Name", "Path", "{GUID}"
        const projectRegex = /Project\("\{[^}]+\}"\)\s*=\s*"([^"]+)",\s*"([^"]+)",\s*"\{([^}]+)\}"/g;
        let match;
        
        while ((match = projectRegex.exec(content)) !== null) {
            const [_, name, relativePath, guid] = match;
            
            // Skip solution folders
            if (relativePath.endsWith('.csproj')) {
                projects.push({
                    name,
                    relativePath,
                    guid,
                    fullPath: path.join(path.dirname(slnPath), relativePath),
                    type: 'csproj'
                });
            }
        }
        
        results.solution = {
            path: slnPath,
            projectCount: projects.length
        };
        
        console.log(`  Found ${projects.length} C# projects`);
        return projects;
        
    } catch (err) {
        results.errors.push({ type: 'solution', path: slnPath, error: err.message });
        return [];
    }
}

/**
 * Parse a .csproj file to extract dependencies and source files
 */
function parseProjectFile(project) {
    console.log(`  Parsing project: ${project.name}`);
    
    try {
        const content = fs.readFileSync(project.fullPath, 'utf8');
        const projectDir = path.dirname(project.fullPath);
        
        // Extract target framework
        const frameworkMatch = content.match(/<TargetFrameworkVersion>([^<]+)<\/TargetFrameworkVersion>/);
        const framework = frameworkMatch ? frameworkMatch[1] : 'Unknown';
        
        // Extract output type
        const outputMatch = content.match(/<OutputType>([^<]+)<\/OutputType>/);
        const outputType = outputMatch ? outputMatch[1] : 'Library';
        
        // Extract project references
        const dependencies = [];
        const projRefRegex = /<ProjectReference Include="([^"]+)">/g;
        let match;
        while ((match = projRefRegex.exec(content)) !== null) {
            const depPath = match[1];
            const depName = path.basename(depPath, '.csproj');
            dependencies.push(depName);
        }
        
        // Extract compile items (source files)
        const sourceFiles = [];
        const compileRegex = /<Compile Include="([^"]+)"/g;
        while ((match = compileRegex.exec(content)) !== null) {
            sourceFiles.push(match[1]);
        }
        
        // Extract define constants
        const definesMatch = content.match(/<DefineConstants>([^<]+)<\/DefineConstants>/);
        const defines = definesMatch ? definesMatch[1].split(';') : [];
        
        return {
            ...project,
            framework,
            outputType,
            dependencies,
            sourceFiles,
            defines,
            sourceFileCount: sourceFiles.length
        };
        
    } catch (err) {
        results.errors.push({ type: 'project', path: project.fullPath, error: err.message });
        return { ...project, error: err.message };
    }
}

/**
 * Analyze a C# source file
 */
function analyzeCSharpFile(filePath, projectName) {
    try {
        const stats = fs.statSync(filePath);
        if (stats.size > config.options.maxFileSize) {
            return null;
        }
        
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n');
        const lineCount = lines.length;
        
        const fileResult = {
            path: filePath,
            relativePath: path.relative(config.MICS_PATH, filePath),
            project: projectName,
            lines: lineCount,
            classes: [],
            methods: [],
            pInvokes: [],
            todos: []
        };
        
        // Extract namespaces
        const namespaceMatch = content.match(/namespace\s+([\w.]+)/);
        fileResult.namespace = namespaceMatch ? namespaceMatch[1] : null;
        
        // Extract using statements
        const usings = [];
        const usingRegex = /using\s+([\w.]+);/g;
        let match;
        while ((match = usingRegex.exec(content)) !== null) {
            usings.push(match[1]);
        }
        fileResult.usings = usings;
        
        // Extract classes/structs
        const classRegex = /(?:public|private|internal|protected)?\s*(?:static|abstract|sealed|partial)?\s*(class|struct|interface|enum)\s+(\w+)(?:<[^>]+>)?(?:\s*:\s*([^\{]+))?/g;
        while ((match = classRegex.exec(content)) !== null) {
            const [_, type, name, inheritance] = match;
            const classInfo = {
                type,
                name,
                inheritance: inheritance ? inheritance.trim() : null,
                file: fileResult.relativePath,
                project: projectName
            };
            fileResult.classes.push(classInfo);
            results.classes.push(classInfo);
        }
        
        // Extract methods
        const methodRegex = /(?:public|private|internal|protected)\s+(?:static\s+)?(?:virtual\s+|override\s+|abstract\s+|async\s+)?(?:[\w<>\[\],\s]+)\s+(\w+)\s*\(([^)]*)\)/g;
        while ((match = methodRegex.exec(content)) !== null) {
            const [fullMatch, name, params] = match;
            
            // Skip constructors and property accessors
            if (name === 'get' || name === 'set' || name === 'if' || name === 'while' || name === 'for') continue;
            
            const methodInfo = {
                name,
                parameters: params.trim(),
                file: fileResult.relativePath,
                project: projectName
            };
            fileResult.methods.push(methodInfo);
            results.methods.push(methodInfo);
        }
        
        // Extract P/Invoke declarations
        if (config.options.analyzePInvoke) {
            const pInvokeRegex = /\[DllImport\s*\(\s*"([^"]+)"[^\]]*\)\s*\][^;]*(?:extern\s+)?(?:static\s+)?(?:\w+\s+)+(\w+)\s*\([^)]*\)/g;
            while ((match = pInvokeRegex.exec(content)) !== null) {
                const [_, dllName, funcName] = match;
                const pInvokeInfo = {
                    dll: dllName,
                    function: funcName,
                    file: fileResult.relativePath,
                    project: projectName
                };
                fileResult.pInvokes.push(pInvokeInfo);
                results.pInvokes.push(pInvokeInfo);
            }
        }
        
        // Extract TODO/FIXME comments
        if (config.options.trackTodos) {
            const todoRegex = /\/\/\s*(TODO|FIXME|HACK|XXX|BUG)[\s:]*(.+)/gi;
            let lineNum = 0;
            for (const line of lines) {
                lineNum++;
                const todoMatch = todoRegex.exec(line);
                if (todoMatch) {
                    const todoInfo = {
                        type: todoMatch[1].toUpperCase(),
                        text: todoMatch[2].trim(),
                        file: fileResult.relativePath,
                        line: lineNum,
                        project: projectName
                    };
                    fileResult.todos.push(todoInfo);
                    results.todos.push(todoInfo);
                }
                todoRegex.lastIndex = 0; // Reset regex for next line
            }
        }
        
        return fileResult;
        
    } catch (err) {
        results.errors.push({ type: 'file', path: filePath, error: err.message });
        return null;
    }
}

/**
 * Recursively find all .cs files in a directory
 */
function findCSharpFiles(dir, files = []) {
    try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            
            if (entry.isDirectory()) {
                // Skip configured directories
                if (!config.options.skipDirs.includes(entry.name)) {
                    findCSharpFiles(fullPath, files);
                }
            } else if (entry.isFile() && entry.name.endsWith('.cs')) {
                files.push(fullPath);
            }
        }
    } catch (err) {
        // Skip directories we can't read
    }
    
    return files;
}

/**
 * Safely write output (only to OUTPUT_DIR, never to MICS_PATH)
 */
function safeWriteFile(outputPath, content) {
    if (!config.isPathSafeForWrite(outputPath)) {
        throw new Error(`Refusing to write to unsafe path: ${outputPath}`);
    }
    
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    
    fs.writeFileSync(outputPath, content);
}

/**
 * Main analysis function
 */
async function analyze() {
    console.log('='.repeat(60));
    console.log('MICS# Code Analyzer (READ-ONLY MODE)');
    console.log('='.repeat(60));
    console.log(`\nSource (READ-ONLY): ${config.MICS_PATH}`);
    console.log(`Output Directory:   ${config.OUTPUT_DIR}`);
    
    // Check if path exists
    if (!fs.existsSync(config.MICS_PATH)) {
        console.error(`\nERROR: Path not found: ${config.MICS_PATH}`);
        console.error('Please update the MICS_PATH in config.js');
        process.exit(1);
    }
    
    // Parse solution file
    const slnPath = path.join(config.MICS_PATH, config.SOLUTION_FILE);
    const projects = parseSolutionFile(slnPath);
    
    // Parse each project
    console.log('\nAnalyzing projects...');
    for (const project of projects) {
        const projectInfo = parseProjectFile(project);
        results.projects.push(projectInfo);
    }
    
    // Find and analyze all .cs files
    console.log('\nAnalyzing source files...');
    const allCsFiles = findCSharpFiles(config.MICS_PATH);
    console.log(`  Found ${allCsFiles.length} C# files`);
    
    let processed = 0;
    for (const filePath of allCsFiles) {
        // Determine which project this file belongs to
        let projectName = 'Unknown';
        for (const proj of results.projects) {
            if (filePath.startsWith(path.dirname(proj.fullPath))) {
                projectName = proj.name;
                break;
            }
        }
        
        const fileResult = analyzeCSharpFile(filePath, projectName);
        if (fileResult) {
            results.files.push(fileResult);
            results.metrics.totalLines += fileResult.lines;
        }
        
        processed++;
        if (processed % 50 === 0) {
            process.stdout.write(`  Processed ${processed}/${allCsFiles.length} files\r`);
        }
    }
    console.log(`  Processed ${processed}/${allCsFiles.length} files`);
    
    // Calculate final metrics
    results.metrics.totalProjects = results.projects.length;
    results.metrics.totalFiles = results.files.length;
    results.metrics.totalClasses = results.classes.length;
    results.metrics.totalMethods = results.methods.length;
    results.metrics.totalPInvokes = results.pInvokes.length;
    results.metrics.totalTodos = results.todos.length;
    
    // Save results (safely, only to OUTPUT_DIR)
    const outputPath = path.join(config.OUTPUT_DIR, 'analysis-results.json');
    safeWriteFile(outputPath, JSON.stringify(results, null, 2));
    
    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('Analysis Summary');
    console.log('='.repeat(60));
    console.log(`  Projects:     ${results.metrics.totalProjects}`);
    console.log(`  Source Files: ${results.metrics.totalFiles}`);
    console.log(`  Total Lines:  ${results.metrics.totalLines.toLocaleString()}`);
    console.log(`  Classes:      ${results.metrics.totalClasses}`);
    console.log(`  Methods:      ${results.metrics.totalMethods}`);
    console.log(`  P/Invokes:    ${results.metrics.totalPInvokes}`);
    console.log(`  TODOs:        ${results.metrics.totalTodos}`);
    console.log(`  Errors:       ${results.errors.length}`);
    console.log('='.repeat(60));
    console.log(`\nResults saved to: ${outputPath}`);
    
    return results;
}

// Run analyzer
analyze().catch(err => {
    console.error('Analysis failed:', err);
    process.exit(1);
});

