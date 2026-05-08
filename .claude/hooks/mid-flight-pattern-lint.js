#!/usr/bin/env node
/**
 * Hook: mid-flight-pattern-lint
 * Event: PostToolUse (Write|Edit)
 * Purpose: Regex-based C# pattern checking at zero LLM cost.
 *
 * Fires after Write/Edit on .cs files and warns about common pattern
 * violations. Non-blocking (always exits 0, warnings go to stderr).
 *
 * Checks:
 *   1. using-placement     - using directives must precede namespace
 *   2. async-void          - async void methods (except event handlers)
 *   3. throw-ex            - throw ex; instead of throw;
 *   4. sync-over-async     - .Result or .Wait() on tasks
 *   5. configure-await     - ConfigureAwait(false) not needed in ASP.NET Core
 *   6. block-scoped-ns     - block-scoped namespace instead of file-scoped
 *   7. hardcoded-connstr   - hardcoded connection strings
 *   8. missing-cancel-token - async Task methods without CancellationToken
 */

const fs = require('fs');
const path = require('path');

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

// --- Individual check functions ---

/**
 * Check 1: using directives must come before namespace declaration.
 * Flags any `using` line that appears after the first `namespace` line.
 */
function checkUsingPlacement(lines) {
  const warnings = [];
  let firstNamespaceLine = -1;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    // Skip comments and blank lines
    if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*') || trimmed === '') continue;

    if (firstNamespaceLine === -1 && /^namespace\s+/.test(trimmed)) {
      firstNamespaceLine = i;
    }

    if (firstNamespaceLine !== -1 && /^using\s+[\w.]+\s*[;=]/.test(trimmed)) {
      warnings.push({
        rule: 'using-placement',
        line: i + 1,
        message: '`using` directive after `namespace` declaration -- move usings above namespace',
      });
    }
  }

  return warnings;
}

/**
 * Check 2: async void methods.
 * Detects `async void MethodName` patterns.
 */
function checkAsyncVoid(lines) {
  const warnings = [];
  const pattern = /async\s+void\s+(\w+)/;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    const match = trimmed.match(pattern);
    if (match) {
      warnings.push({
        rule: 'async-void',
        line: i + 1,
        message: `async void method '${match[1]}' -- use async Task instead (async void is fire-and-forget)`,
      });
    }
  }

  return warnings;
}

/**
 * Check 3: throw ex; instead of bare throw;
 * Detects throw with a variable name that matches common catch variable names.
 */
function checkThrowEx(lines) {
  const warnings = [];
  const throwPattern = /\bthrow\s+(ex|e|err|error|exception)\s*;/;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    const match = trimmed.match(throwPattern);
    if (match) {
      warnings.push({
        rule: 'throw-ex',
        line: i + 1,
        message: `'throw ${match[1]};' resets stack trace -- use 'throw;' to preserve it`,
      });
    }
  }

  return warnings;
}

/**
 * Check 4: Sync-over-async (.Result or .Wait()).
 * Detects .Result property access or .Wait() calls on task-like objects.
 */
function checkSyncOverAsync(lines) {
  const warnings = [];
  const resultPattern = /\.Result[\s;,)}\]]/;
  const waitPattern = /\.Wait\(\)/;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    if (resultPattern.test(trimmed)) {
      warnings.push({
        rule: 'sync-over-async',
        line: i + 1,
        message: '.Result blocks the thread -- use await instead',
      });
    }

    if (waitPattern.test(trimmed)) {
      warnings.push({
        rule: 'sync-over-async',
        line: i + 1,
        message: '.Wait() blocks the thread -- use await instead',
      });
    }
  }

  return warnings;
}

/**
 * Check 5: ConfigureAwait(false).
 * Not needed in ASP.NET Core applications.
 */
function checkConfigureAwait(lines) {
  const warnings = [];
  const pattern = /\.ConfigureAwait\(\s*false\s*\)/;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    if (pattern.test(trimmed)) {
      warnings.push({
        rule: 'configure-await',
        line: i + 1,
        message: 'ConfigureAwait(false) is unnecessary in ASP.NET Core',
      });
    }
  }

  return warnings;
}

/**
 * Check 6: Block-scoped namespace.
 * Detects `namespace X.Y {` instead of file-scoped `namespace X.Y;`
 */
function checkBlockScopedNamespace(lines) {
  const warnings = [];
  // Match namespace followed by identifier(s) and an opening brace (possibly on the same line)
  // But NOT file-scoped (which ends with ;)
  const nsPattern = /^namespace\s+[\w.]+\s*\{?\s*$/;
  const fileScopedPattern = /^namespace\s+[\w.]+\s*;\s*$/;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    // Skip file-scoped namespaces (correct pattern)
    if (fileScopedPattern.test(trimmed)) continue;

    // Detect block-scoped: namespace Foo.Bar {
    if (/^namespace\s+[\w.]+\s*\{/.test(trimmed)) {
      warnings.push({
        rule: 'block-scoped-ns',
        line: i + 1,
        message: 'Block-scoped namespace -- use file-scoped namespace (namespace X.Y;)',
      });
      continue;
    }

    // Detect namespace declaration without semicolon where next non-empty line has {
    if (/^namespace\s+[\w.]+\s*$/.test(trimmed)) {
      // Look ahead for opening brace
      for (let j = i + 1; j < lines.length && j <= i + 2; j++) {
        const nextTrimmed = lines[j].trim();
        if (nextTrimmed === '') continue;
        if (nextTrimmed === '{') {
          warnings.push({
            rule: 'block-scoped-ns',
            line: i + 1,
            message: 'Block-scoped namespace -- use file-scoped namespace (namespace X.Y;)',
          });
        }
        break;
      }
    }
  }

  return warnings;
}

/**
 * Check 7: Hardcoded connection strings.
 * Detects patterns like "Server=", "Data Source=", "mongodb://", "AccountEndpoint=".
 */
function checkHardcodedConnectionStrings(lines) {
  const warnings = [];
  const patterns = [
    { regex: /"[^"]*Server\s*=/, label: 'SQL Server connection string' },
    { regex: /"[^"]*Data Source\s*=/, label: 'Data Source connection string' },
    { regex: /"[^"]*mongodb:\/\//, label: 'MongoDB connection string' },
    { regex: /"[^"]*AccountEndpoint\s*=/, label: 'Cosmos DB connection string' },
    { regex: /"[^"]*Initial Catalog\s*=/, label: 'SQL connection string' },
    { regex: /"[^"]*Password\s*=/, label: 'connection string with password' },
  ];

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    for (const { regex, label } of patterns) {
      if (regex.test(lines[i])) {
        warnings.push({
          rule: 'hardcoded-connstr',
          line: i + 1,
          message: `Hardcoded ${label} detected -- use IConfiguration or IConfigOptions pattern`,
        });
        break; // One warning per line is sufficient
      }
    }
  }

  return warnings;
}

/**
 * Check 8: Missing CancellationToken in async Task methods.
 * Detects async Task/Task<T> method signatures without a CancellationToken parameter.
 * Uses a simple heuristic: looks for lines containing both `async Task` and a parenthesized
 * parameter list, then checks if CancellationToken appears in the signature.
 */
function checkMissingCancellationToken(lines) {
  const warnings = [];
  // Match method signatures: access-modifier? async Task<...>? MethodName(...)
  const asyncMethodPattern = /async\s+Task\b/;
  const cancelTokenPattern = /CancellationToken/;
  const lambdaOrLocalPattern = /[=(]\s*async/; // skip lambdas and local functions assigned inline

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    if (!asyncMethodPattern.test(trimmed)) continue;

    // Skip lambdas and arrow functions
    if (lambdaOrLocalPattern.test(trimmed)) continue;

    // Build the full signature by collecting continuation lines (for multi-line signatures)
    let signature = trimmed;
    if (!signature.includes('(')) continue; // no parameter list on this line

    // If signature doesn't close the param list, extend to next lines (up to 5)
    if (!signature.includes(')')) {
      for (let j = i + 1; j < lines.length && j <= i + 5; j++) {
        signature += ' ' + lines[j].trim();
        if (lines[j].includes(')')) break;
      }
    }

    // Extract parameter list
    const paramMatch = signature.match(/\(([^)]*)\)/);
    if (!paramMatch) continue;

    const params = paramMatch[1];

    // Empty parameter list: async Task DoSomething() -- might be legitimate (no params to pass)
    // Still flag it since CancellationToken should generally be passed
    if (params.trim() === '') {
      // Don't flag parameterless methods -- CancellationToken can be obtained from HttpContext
      continue;
    }

    // Check if CancellationToken is in the parameter list
    if (!cancelTokenPattern.test(params)) {
      // Extract method name for the message
      const methodMatch = signature.match(/async\s+Task(?:<[^>]+>)?\s+(\w+)\s*\(/);
      const methodName = methodMatch ? methodMatch[1] : '(unknown)';

      warnings.push({
        rule: 'missing-cancel-token',
        line: i + 1,
        message: `async method '${methodName}' lacks CancellationToken parameter`,
      });
    }
  }

  return warnings;
}

// --- Main ---

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Extract file path from tool input
    const filePath = data.tool_input?.file_path || '';

    // Only process .cs files
    if (!filePath || !filePath.toLowerCase().endsWith('.cs')) {
      process.exit(0);
    }

    // Normalize path for display
    const displayPath = filePath.replace(/\\/g, '/');

    // Read the file content after the write/edit
    let content;
    try {
      content = fs.readFileSync(filePath, 'utf-8');
    } catch (readError) {
      // File might not exist (edge case), skip silently
      process.exit(0);
    }

    // Skip empty or binary-looking files
    if (!content || content.length === 0) {
      process.exit(0);
    }

    // Quick binary check: if file has null bytes in first 512 chars, skip
    if (content.slice(0, 512).includes('\0')) {
      process.exit(0);
    }

    const lines = content.split('\n');

    // Run all checks
    const allWarnings = [
      ...checkUsingPlacement(lines),
      ...checkAsyncVoid(lines),
      ...checkThrowEx(lines),
      ...checkSyncOverAsync(lines),
      ...checkConfigureAwait(lines),
      ...checkBlockScopedNamespace(lines),
      ...checkHardcodedConnectionStrings(lines),
      ...checkMissingCancellationToken(lines),
    ];

    if (allWarnings.length === 0) {
      process.exit(0);
    }

    // Sort warnings by line number
    allWarnings.sort((a, b) => a.line - b.line);

    // Format warnings for stderr
    const fileName = path.basename(filePath);
    const header = `[pattern-lint] ${allWarnings.length} warning(s) in ${fileName}:`;
    const details = allWarnings
      .map(w => `  line ${w.line}: [${w.rule}] ${w.message}`)
      .join('\n');

    console.error(`${header}\n${details}`);

    // Also output as additionalContext so it appears in the conversation
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: `Pattern lint for ${displayPath}:\n${allWarnings.map(w => `- Line ${w.line} [${w.rule}]: ${w.message}`).join('\n')}`,
      },
    }));

    // Always exit 0 (non-blocking)
    process.exit(0);
  } catch (err) {
    // Hook error - fail-open (advisory hook)
    console.error('[mid-flight-pattern-lint] FATAL ERROR:', err.message);
    console.error('[mid-flight-pattern-lint] Hook failed - continuing (advisory).');
    process.exit(0);
  }
}

main();
