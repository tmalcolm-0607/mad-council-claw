#!/usr/bin/env node
/**
 * Hook: Stop (advisory)
 * Purpose: Warn when session ends with unchecked plan items in the active work item.
 *          Suggests generating a handoff for the next session.
 *
 * This is the Stop-event advisory hook. It provides work-item awareness at session end.
 *
 * Exit codes:
 *   0 - Always (advisory only, never blocks session ending)
 *
 * Feature flag:
 *   STOP_GUARD_ENABLED=false|0  -> disables this hook entirely
 *
 * Performance target: <20ms (2-3 synchronous file reads)
 */

'use strict';

const fs = require('fs');
const path = require('path');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const MAX_UNCHECKED_DISPLAY = 5; // Show at most N unchecked items in the warning

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Find the project root by walking up from cwd looking for .claude/
 */
function getProjectDir() {
  let dir = process.cwd();
  const root = path.parse(dir).root;

  while (dir !== root) {
    if (fs.existsSync(path.join(dir, '.claude'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

/**
 * Safely read a file, returning null on any error.
 */
function safeReadFile(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

/**
 * Parse the slug from a work item ID.
 * Format: WI-YYYYMMDD-HHMM-slug
 * Returns the slug portion or null if the format is invalid.
 */
function parseWorkItemSlug(workItemId) {
  if (!workItemId || typeof workItemId !== 'string') return null;

  const match = workItemId.match(/^WI-\d{8}-\d{4}-(.+)$/);
  return match ? match[1] : null;
}

/**
 * Find the spec directory matching a work item slug.
 * Spec directories follow the pattern: specs/{N}-{slug}/
 * where N is one or more digits (typically 3, e.g. 001, 020).
 */
function findSpecDir(projectDir, slug) {
  const specsDir = path.join(projectDir, 'specs');

  let entries;
  try {
    entries = fs.readdirSync(specsDir, { withFileTypes: true });
  } catch {
    return null;
  }

  // Build regex: digits followed by dash and the slug
  const pattern = new RegExp(`^\\d+-${escapeRegex(slug)}$`);

  for (const entry of entries) {
    if (entry.isDirectory() && pattern.test(entry.name)) {
      return path.join(specsDir, entry.name);
    }
  }
  return null;
}

/**
 * Escape special regex characters in a string.
 */
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Extract unchecked plan items from plan.md content.
 * Returns an array of { line: string } objects for unchecked checkboxes.
 */
function getUncheckedItems(planContent) {
  const items = [];
  const lines = planContent.split('\n');

  for (const line of lines) {
    // Match lines like "- [ ] Task description" (with possible leading whitespace)
    if (/^\s*-\s*\[\s*\]/.test(line)) {
      // Clean up the line for display: trim and remove the checkbox prefix
      const text = line.replace(/^\s*-\s*\[\s*\]\s*/, '').trim();
      if (text) {
        items.push({ line: text });
      }
    }
  }
  return items;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  // Feature flag check (first thing, before any I/O)
  const enabled = process.env.STOP_GUARD_ENABLED;
  if (enabled !== undefined) {
    const lower = String(enabled).toLowerCase();
    if (lower === 'false' || lower === '0') {
      process.exit(0);
    }
  }

  const projectDir = getProjectDir();

  // Step 1: Read current work item
  // Stop hooks do not receive tool-use session_id in payload;
  // resolveActiveWI falls back to CLAUDE_SESSION_ID env var or 'default'
  const { wiId: workItemId } = resolveActiveWI(null, projectDir);
  if (!workItemId) {
    // No active work item -- nothing to warn about
    process.exit(0);
  }

  // Step 2: Validate work item ID format and extract slug
  const slug = parseWorkItemSlug(workItemId);
  if (!slug) {
    // Malformed work item ID -- exit silently
    process.stderr.write(`[stop-guard] Skipping: invalid work item ID format "${workItemId}"\n`);
    process.exit(0);
  }

  // Step 3: Check for existing handoff
  const handoffPath = path.join(projectDir, '.claude', 'work-items', workItemId, 'PENDING_HANDOFF');
  try {
    if (fs.existsSync(handoffPath)) {
      // Handoff already generated -- no warning needed
      process.exit(0);
    }
  } catch {
    // Ignore existence-check errors
  }

  // Step 4: Find spec directory and read plan.md
  const specDir = findSpecDir(projectDir, slug);
  if (!specDir) {
    // No matching spec directory -- exit silently
    process.stderr.write(`[stop-guard] Skipping: no spec directory found for slug "${slug}"\n`);
    process.exit(0);
  }

  const planPath = path.join(specDir, 'plan.md');
  const planContent = safeReadFile(planPath);
  if (!planContent) {
    // No plan.md -- exit silently
    process.stderr.write(`[stop-guard] Skipping: plan.md not found at "${planPath}"\n`);
    process.exit(0);
  }

  // Step 5: Count unchecked items
  const uncheckedItems = getUncheckedItems(planContent);
  if (uncheckedItems.length === 0) {
    // All items checked -- nothing to warn about
    process.exit(0);
  }

  // Step 6: Build and emit warning
  const count = uncheckedItems.length;
  const displayItems = uncheckedItems.slice(0, MAX_UNCHECKED_DISPLAY);
  const remainingCount = count - displayItems.length;

  let message = `[Stop Guard] Work item ${workItemId} has ${count} unchecked plan item${count !== 1 ? 's' : ''}.\n`;
  message += '\n';
  message += 'Consider generating a handoff for the next session:\n';
  message += '  /resume-handoff\n';
  message += '\n';
  message += 'Unchecked items:\n';

  for (const item of displayItems) {
    message += `  - [ ] ${item.line}\n`;
  }

  if (remainingCount > 0) {
    message += `  ... and ${remainingCount} more\n`;
  }

  message += '\n';
  message += 'To disable this warning: STOP_GUARD_ENABLED=false\n';

  // Write warning to stderr (advisory)
  process.stderr.write(message);

  // Always exit 0 -- advisory only
  process.exit(0);
}

try {
  main();
} catch (err) {
  console.error('[stop-guard] Error:', err.message);
  process.exit(0);
}
