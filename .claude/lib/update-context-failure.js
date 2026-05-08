#!/usr/bin/env node
/**
 * Helper: Update Context Failure Log
 * Purpose: Add failure entries to a feature's context.md
 *
 * This module provides functions to:
 * - Read context.md from a feature directory
 * - Add new failure entries to the Failure Log table
 * - Detect and increment pattern counts for similar failures
 * - Write updated context.md back
 *
 * Usage:
 *   const { addFailure } = require('./update-context-failure.js');
 *   await addFailure({
 *     featureDir: 'specs/1-example-feature',
 *     gate: 'BUILD',
 *     taskId: 'T123',
 *     errorOutput: 'Error: Cannot find module...',
 *     rootCause: 'Missing dependency',
 *     fixApplied: 'npm install'
 *   });
 */

const fs = require('fs');
const path = require('path');

// Gate categories matching context.md spec
const CATEGORIES = [
  'BUILD', 'TEST', 'GATE', 'TYPE', 'LINT',
  'DOCKER', 'E2E', 'API', 'DB', 'CONFIG', 'LOGIC', 'OTHER'
];

// Known failure patterns for matching
// Order matters: more specific patterns should come before general ones
const KNOWN_PATTERNS = [
  // Specific mocking patterns (check before general API patterns)
  { regex: /vi\.mock\s*\(|jest\.mock\s*\(/i, pattern: 'Mocking entire API in integration tests', category: 'TEST' },
  { regex: /page\.route\s*\(/i, pattern: 'Mocking API in E2E tests', category: 'E2E' },
  // API URL mismatch (fetch/axios with /api/ but not /api/v1/)
  { regex: /fetch\s*\(\s*["'`][^"'`]*\/api\/(?!v1)/i, pattern: 'API URL prefix mismatch', category: 'API' },
  { regex: /axios\.[a-z]+\s*\(\s*["'`][^"'`]*\/api\/(?!v1)/i, pattern: 'API URL prefix mismatch', category: 'API' },
  // CORS and auth
  { regex: /CORS|Access-Control-Allow-Origin/i, pattern: 'CORS hardcoded to dev server', category: 'DOCKER' },
  { regex: /relation.*does not exist|no such table/i, pattern: 'Database migration not run', category: 'DB' },
  { regex: /401.*Unauthorized|Unauthorized.*401|missing.*Authorization/i, pattern: 'Auth header not sent from frontend', category: 'API' },
  // Code quality
  { regex: /mock.*data.*production|placeholder.*data|demo.*data/i, pattern: 'Mock data in production code', category: 'LOGIC' },
  { regex: /pass.*locally.*fail.*docker|docker.*fail/i, pattern: 'Tests pass locally, fail in Docker', category: 'DOCKER' },
  // Build/type errors
  { regex: /Cannot find module|Module not found/i, pattern: 'Missing dependency or import', category: 'BUILD' },
  { regex: /Type.*not assignable|TS\d{4}/i, pattern: 'TypeScript type error', category: 'TYPE' },
  { regex: /eslint|lint.*error/i, pattern: 'Linting error', category: 'LINT' },
  // Runtime/infra errors
  { regex: /timeout|ETIMEDOUT/i, pattern: 'Test/operation timeout', category: 'TEST' },
  { regex: /ECONNREFUSED|connection refused/i, pattern: 'Service connection refused', category: 'DOCKER' },
  { regex: /health.*check.*fail|unhealthy/i, pattern: 'Docker health check failure', category: 'DOCKER' },
];

/**
 * Generate a unique failure ID
 * @returns {string} Failure ID (e.g., F001)
 */
function generateFailureId(existingIds) {
  let maxNum = 0;
  for (const id of existingIds) {
    const match = id.match(/F(\d+)/);
    if (match) {
      maxNum = Math.max(maxNum, parseInt(match[1], 10));
    }
  }
  return `F${String(maxNum + 1).padStart(3, '0')}`;
}

/**
 * Extract error summary from full error output
 * @param {string} errorOutput - Full error output
 * @returns {string} Summarized error (first meaningful line, max 60 chars)
 */
function summarizeError(errorOutput) {
  if (!errorOutput) return 'Unknown error';

  const lines = errorOutput.split('\n').filter(l => l.trim());

  // Find first line that looks like an error message
  for (const line of lines) {
    const trimmed = line.trim();
    // Skip common noise lines
    if (trimmed.startsWith('>') || trimmed.startsWith('npm') ||
        trimmed.startsWith('at ') || trimmed === '') continue;

    // Look for error-like patterns
    if (/error|fail|cannot|unable|invalid|missing/i.test(trimmed)) {
      // Truncate and return
      return trimmed.length > 60 ? trimmed.substring(0, 57) + '...' : trimmed;
    }
  }

  // Fallback: first non-empty line
  const firstLine = lines[0] || 'Unknown error';
  return firstLine.length > 60 ? firstLine.substring(0, 57) + '...' : firstLine;
}

/**
 * Detect if error matches a known pattern
 * @param {string} errorOutput - Full error output
 * @returns {{pattern: string, category: string} | null} Matched pattern or null
 */
function detectPattern(errorOutput) {
  if (!errorOutput) return null;

  for (const { regex, pattern, category } of KNOWN_PATTERNS) {
    if (regex.test(errorOutput)) {
      return { pattern, category };
    }
  }
  return null;
}

/**
 * Parse the Failure Log section from context.md
 * @param {string} content - context.md content
 * @returns {{failures: Array, patternsSection: string, startLine: number, endLine: number}}
 */
function parseFailureLog(content) {
  const lines = content.split('\n');
  const failures = [];
  let inTable = false;
  let tableStartLine = -1;
  let tableEndLine = -1;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Find the Failure Log section
    if (line.includes('## Failure Log')) {
      // Look for table header
      for (let j = i + 1; j < lines.length && j < i + 10; j++) {
        if (lines[j].startsWith('| ID')) {
          tableStartLine = j;
          inTable = true;
          break;
        }
      }
      continue;
    }

    // Parse table rows
    if (inTable && line.startsWith('|')) {
      // Skip header and separator rows
      if (line.includes('| ID') || line.includes('|---')) continue;

      // End of table
      if (!line.includes('|')) {
        tableEndLine = i - 1;
        inTable = false;
        continue;
      }

      // Parse failure row
      const cells = line.split('|').map(c => c.trim()).filter(c => c);
      if (cells.length >= 7 && cells[0] !== '-') {
        failures.push({
          id: cells[0],
          date: cells[1],
          category: cells[2],
          task: cells[3],
          summary: cells[4],
          rootCause: cells[5],
          fixApplied: cells[6]
        });
      }

      tableEndLine = i;
    }

    // Stop at next section
    if (inTable && line.startsWith('##')) {
      tableEndLine = i - 1;
      break;
    }
  }

  return { failures, tableStartLine, tableEndLine };
}

/**
 * Parse the Failure Patterns Detected section
 * @param {string} content - context.md content
 * @returns {{patterns: Map<string, {count: number, category: string, suggestion: string}>, startLine: number, endLine: number}}
 */
function parsePatterns(content) {
  const lines = content.split('\n');
  const patterns = new Map();
  let inTable = false;
  let tableStartLine = -1;
  let tableEndLine = -1;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Find the Failure Patterns section
    if (line.includes('### Failure Patterns Detected')) {
      for (let j = i + 1; j < lines.length && j < i + 10; j++) {
        if (lines[j].startsWith('| Pattern')) {
          tableStartLine = j;
          inTable = true;
          break;
        }
      }
      continue;
    }

    // Parse table rows
    if (inTable && line.startsWith('|')) {
      if (line.includes('| Pattern') || line.includes('|---')) continue;

      if (!line.includes('|') || line.startsWith('###')) {
        tableEndLine = i - 1;
        inTable = false;
        continue;
      }

      const cells = line.split('|').map(c => c.trim()).filter(c => c);
      if (cells.length >= 4) {
        const countMatch = cells[1].match(/(\d+)/);
        const count = countMatch ? parseInt(countMatch[1], 10) : 1;
        patterns.set(cells[0], {
          count,
          category: cells[2],
          suggestion: cells[3]
        });
      }

      tableEndLine = i;
    }

    // Stop at next section
    if (inTable && line.startsWith('###') && !line.includes('Failure Patterns')) {
      tableEndLine = i - 1;
      break;
    }
  }

  return { patterns, tableStartLine, tableEndLine };
}

/**
 * Add a failure entry to context.md
 * @param {Object} options - Failure details
 * @param {string} options.featureDir - Path to feature directory (relative to project root)
 * @param {string} options.gate - Gate name (BUILD, TEST, LINT, DOCKER, E2E)
 * @param {string} options.taskId - Task ID (e.g., T123)
 * @param {string} options.errorOutput - Full error output
 * @param {string} [options.rootCause] - Root cause analysis
 * @param {string} [options.fixApplied] - Fix that was applied
 * @returns {{success: boolean, failureId: string, patternMatch: string|null, message: string}}
 */
function addFailure(options) {
  const {
    featureDir,
    gate,
    taskId,
    errorOutput,
    rootCause = 'Investigating',
    fixApplied = 'Pending'
  } = options;

  // Resolve context.md path
  const contextPath = path.resolve(featureDir, 'context.md');

  if (!fs.existsSync(contextPath)) {
    return {
      success: false,
      failureId: null,
      patternMatch: null,
      message: `context.md not found at ${contextPath}`
    };
  }

  let content = fs.readFileSync(contextPath, 'utf8');

  // Parse existing failures
  const { failures, tableStartLine, tableEndLine } = parseFailureLog(content);

  // Parse existing patterns
  const { patterns, tableStartLine: patternStart, tableEndLine: patternEnd } = parsePatterns(content);

  // Generate failure ID
  const existingIds = failures.map(f => f.id);
  const failureId = generateFailureId(existingIds);

  // Summarize error
  const errorSummary = summarizeError(errorOutput);

  // Detect pattern match
  const detectedPattern = detectPattern(errorOutput);
  let patternMatch = null;

  // Map gate to category
  const category = CATEGORIES.includes(gate.toUpperCase()) ? gate.toUpperCase() : 'OTHER';

  // Create new failure entry
  const today = new Date().toISOString().split('T')[0];
  const newFailure = {
    id: failureId,
    date: today,
    category: detectedPattern?.category || category,
    task: taskId || '-',
    summary: errorSummary,
    rootCause: rootCause,
    fixApplied: fixApplied
  };

  // Update content
  const lines = content.split('\n');

  // Find and update the failure log table
  let updated = false;
  for (let i = 0; i < lines.length; i++) {
    // Find the "No failures logged yet" row and replace it
    if (lines[i].includes('No failures logged yet')) {
      lines[i] = `| ${newFailure.id} | ${newFailure.date} | ${newFailure.category} | ${newFailure.task} | ${newFailure.summary} | ${newFailure.rootCause} | ${newFailure.fixApplied} |`;
      updated = true;
      break;
    }
  }

  // If no placeholder found, insert after the table header separator
  if (!updated && tableStartLine > 0) {
    // Find the separator row (|---|---| etc)
    for (let i = tableStartLine; i < tableStartLine + 3 && i < lines.length; i++) {
      if (lines[i].includes('|---')) {
        // Insert new row after separator
        const newRow = `| ${newFailure.id} | ${newFailure.date} | ${newFailure.category} | ${newFailure.task} | ${newFailure.summary} | ${newFailure.rootCause} | ${newFailure.fixApplied} |`;
        lines.splice(i + 1, 0, newRow);
        updated = true;
        break;
      }
    }
  }

  // Update pattern counts if matched
  if (detectedPattern) {
    patternMatch = detectedPattern.pattern;

    // Find and update pattern count
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes(detectedPattern.pattern)) {
        // Extract current count and increment
        const countMatch = lines[i].match(/\|\s*(\d+)\+?\s*\|/);
        if (countMatch) {
          const currentCount = parseInt(countMatch[1], 10);
          const newCount = currentCount + 1;
          lines[i] = lines[i].replace(/\|\s*\d+\+?\s*\|/, `| ${newCount}+ |`);
        }
        break;
      }
    }
  }

  // Write updated content
  content = lines.join('\n');
  fs.writeFileSync(contextPath, content, 'utf8');

  return {
    success: true,
    failureId,
    patternMatch,
    message: `Added failure ${failureId} to ${contextPath}${patternMatch ? ` (pattern: ${patternMatch})` : ''}`
  };
}

/**
 * Update the fix applied for an existing failure
 * @param {Object} options - Update details
 * @param {string} options.featureDir - Path to feature directory
 * @param {string} options.failureId - Failure ID to update
 * @param {string} options.fixApplied - Fix description
 * @param {string} [options.rootCause] - Updated root cause
 * @returns {{success: boolean, message: string}}
 */
function updateFailureFix(options) {
  const { featureDir, failureId, fixApplied, rootCause } = options;

  const contextPath = path.resolve(featureDir, 'context.md');

  if (!fs.existsSync(contextPath)) {
    return { success: false, message: `context.md not found at ${contextPath}` };
  }

  let content = fs.readFileSync(contextPath, 'utf8');
  const lines = content.split('\n');

  let updated = false;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes(`| ${failureId} |`)) {
      const cells = lines[i].split('|').map(c => c.trim());
      // cells: ['', id, date, category, task, summary, rootCause, fixApplied, '']
      if (cells.length >= 8) {
        if (rootCause) cells[6] = rootCause;
        cells[7] = fixApplied;
        lines[i] = '| ' + cells.slice(1, -1).join(' | ') + ' |';
        updated = true;
      }
      break;
    }
  }

  if (!updated) {
    return { success: false, message: `Failure ${failureId} not found` };
  }

  content = lines.join('\n');
  fs.writeFileSync(contextPath, content, 'utf8');

  return { success: true, message: `Updated fix for ${failureId}` };
}

// Export for use by other hooks
module.exports = {
  addFailure,
  updateFailureFix,
  summarizeError,
  detectPattern,
  CATEGORIES,
  KNOWN_PATTERNS
};

// CLI usage when run directly
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.length < 3) {
    console.error('Usage: node update-context-failure.js <featureDir> <gate> <taskId> [errorFile]');
    console.error('  featureDir: Path to feature directory (e.g., specs/1-example-feature)');
    console.error('  gate: Gate name (BUILD, TEST, LINT, DOCKER, E2E)');
    console.error('  taskId: Task ID (e.g., T123)');
    console.error('  errorFile: (optional) File containing error output');
    process.exit(1);
  }

  const [featureDir, gate, taskId, errorFile] = args;

  let errorOutput = 'Gate failure (no details provided)';
  if (errorFile && fs.existsSync(errorFile)) {
    errorOutput = fs.readFileSync(errorFile, 'utf8');
  }

  const result = addFailure({
    featureDir,
    gate,
    taskId,
    errorOutput
  });

  console.log(JSON.stringify(result, null, 2));
  process.exit(result.success ? 0 : 1);
}
