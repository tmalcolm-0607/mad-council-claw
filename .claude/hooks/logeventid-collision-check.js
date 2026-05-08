#!/usr/bin/env node
/**
 * Hook: PreToolUse (Write|Edit)
 * Purpose: Detect LogEventId collisions when editing log-related files.
 *
 * Triggers on files matching *LogEventIds*.cs or *LogMessages*.cs.
 * Scans all matching files in the project for duplicate EventId values.
 *
 * Exit 0: no collisions (or scan error -- fail-open)
 * Exit 2: collision detected (blocks the edit)
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** Glob-like basename patterns that trigger a scan. */
const TRIGGER_PATTERNS = [/LogEventIds.*\.cs$/i, /LogMessages.*\.cs$/i];

/** Same patterns used to find ALL files to scan across the project. */
const SCAN_PATTERNS = TRIGGER_PATTERNS;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalize(p) {
  return p.replace(/\\/g, '/');
}

/**
 * Walk a directory tree synchronously, yielding file paths.
 * Skips common non-source directories for speed.
 */
function walkSync(dir, results) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return results;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // Skip directories that cannot contain C# source
      const lower = entry.name.toLowerCase();
      if (lower === 'node_modules' || lower === 'bin' || lower === 'obj' ||
          lower === '.git' || lower === '.vs' || lower === 'packages' ||
          lower === 'testresults') {
        continue;
      }
      walkSync(full, results);
    } else if (entry.isFile()) {
      const name = entry.name;
      for (const pat of SCAN_PATTERNS) {
        if (pat.test(name)) {
          results.push(normalize(full));
          break;
        }
      }
    }
  }
  return results;
}

/**
 * Read a file, stripping a leading UTF-8 BOM if present.
 */
function readFileSafe(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  if (content.charCodeAt(0) === 0xFEFF) {
    content = content.slice(1);
  }
  return content;
}

/**
 * Extract all EventId numeric values from a file.
 *
 * Matches two patterns:
 *   1. public const int <Name> = <N>;          (LogEventIds.cs)
 *   2. [LoggerMessage(EventId = <N>,            (LogMessages files with inline literals)
 *
 * Returns: Array<{ value: number, name: string, file: string, line: number }>
 */
function extractEventIds(filePath) {
  const content = readFileSafe(filePath);
  const lines = content.split(/\r?\n/);
  const results = [];
  const normalized = normalize(filePath);

  // Pattern 1: public const int SomeName = 1234;
  const constRegex = /public\s+const\s+int\s+(\w+)\s*=\s*(\d+)\s*;/;

  // Pattern 2: [LoggerMessage(EventId = 1234
  // Captures inline numeric literals only (not LogEventIds.Foo references)
  const attrRegex = /\[\s*LoggerMessage\s*\(\s*EventId\s*=\s*(\d+)/;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNum = i + 1;

    const constMatch = constRegex.exec(line);
    if (constMatch) {
      results.push({
        value: parseInt(constMatch[2], 10),
        name: constMatch[1],
        file: normalized,
        line: lineNum,
      });
      continue;
    }

    const attrMatch = attrRegex.exec(line);
    if (attrMatch) {
      // Extract a label from the method name on the next non-empty line,
      // or fall back to a generic label.
      let label = `[LoggerMessage(EventId = ${attrMatch[1]})`;
      for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {
        const methodMatch = /partial\s+void\s+(\w+)/.exec(lines[j]);
        if (methodMatch) {
          label = methodMatch[1];
          break;
        }
      }
      results.push({
        value: parseInt(attrMatch[1], 10),
        name: label,
        file: normalized,
        line: lineNum,
      });
    }
  }

  return results;
}

/**
 * Find the git repo root for a given file path by walking up looking for .git/.
 * Falls back to the directory containing the file.
 */
function findRepoRoot(filePath) {
  let dir = path.dirname(filePath);
  while (dir !== path.dirname(dir)) {
    // Check for .git file (worktree) or .git directory (main repo)
    if (fs.existsSync(path.join(dir, '.git'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return path.dirname(filePath);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  // Read stdin
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  const input = Buffer.concat(chunks).toString();

  if (!input.trim()) {
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }

  // Extract file path from tool input
  const toolInput = data.tool_input || data.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';

  if (!filePath) {
    process.exit(0);
  }

  // Check if the file being edited matches our trigger patterns
  const baseName = path.basename(filePath);
  const isTriggered = TRIGGER_PATTERNS.some((pat) => pat.test(baseName));
  if (!isTriggered) {
    process.exit(0);
  }

  // Find all LogEventIds/LogMessages files within the repo containing the edited file
  try {
    const repoRoot = findRepoRoot(normalize(filePath));

    const allFiles = [];
    walkSync(repoRoot, allFiles);

    // Deduplicate file paths
    const uniqueFiles = [...new Set(allFiles)];

    // Extract all EventIds from all files
    const allEventIds = [];
    for (const f of uniqueFiles) {
      try {
        const ids = extractEventIds(f);
        allEventIds.push(...ids);
      } catch (err) {
        // Skip files that can't be read -- fail-open
        console.error(`[LogEventId Check] Warning: could not read ${f}: ${err.message}`);
      }
    }

    // Group by numeric value to find collisions
    const byValue = new Map();
    for (const entry of allEventIds) {
      if (!byValue.has(entry.value)) {
        byValue.set(entry.value, []);
      }
      byValue.get(entry.value).push(entry);
    }

    // Find collisions: same numeric value used by different constant names.
    // Same name at different lines in the same file is NOT a collision
    // (just the same constant). Same name in different files is also not a
    // collision (e.g., const definition in LogEventIds.cs referenced in
    // LogMessages.cs via inline literal with the same value).
    const collisions = [];
    for (const [value, entries] of byValue) {
      if (entries.length < 2) continue;

      // Deduplicate by constant name (case-sensitive). If all entries share
      // the same name, they represent the same logical constant -- no collision.
      const byName = new Map();
      for (const e of entries) {
        if (!byName.has(e.name)) {
          byName.set(e.name, e);
        }
      }

      // A collision exists when 2+ distinct constant names share one value.
      if (byName.size >= 2) {
        collisions.push({ value, entries: [...byName.values()] });
      }
    }

    if (collisions.length === 0) {
      process.exit(0);
    }

    // Format collision report
    const lines = [];
    for (const collision of collisions) {
      lines.push(`[LogEventId Collision] Duplicate EventId ${collision.value} found:`);
      for (const entry of collision.entries) {
        // Make paths relative for readability
        const relFile = path.basename(entry.file);
        lines.push(`  - ${relFile}:${entry.line}  ${entry.name} = ${entry.value}`);
      }
    }

    const message = lines.join('\n');
    console.error(message);
    process.exit(2);

  } catch (err) {
    // Fail-open: scanning errors should not block the edit
    console.error(`[LogEventId Check] Warning: scan failed (${err.message}). Proceeding without collision check.`);
    process.exit(0);
  }
}

main().catch((err) => {
  // Fail-open on unexpected errors
  console.error(`[LogEventId Check] Error: ${err.message}`);
  process.exit(0);
});
