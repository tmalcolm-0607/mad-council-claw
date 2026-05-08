#!/usr/bin/env node
'use strict';

/**
 * handoff-generator.js
 *
 * Shared library for generating session handoff documents before context
 * compaction or at HALT threshold (Context Guardian).
 *
 * Writes a minimal Markdown handoff to .claude/work-items/{WI-ID}/ (if a
 * work item is active) or .mad/scratch/ (fallback), then writes a
 * PENDING_HANDOFF pointer so /resume-handoff can locate it.
 *
 * Exports:
 *   generateHandoff({ reason, tier }) → { success, handoffPath, workItemId }
 *
 * Called by:
 *   - pre-compact.js (tier: 'minimal', reason: 'pre_compact_safety')
 *   - context-warning.js (tier: 'minimal', reason: 'halt_threshold')
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Resolve the project root by walking up from cwd looking for .claude/.
 * Falls back to cwd if not found.
 * @returns {string}
 */
function resolveProjectRoot() {
  try {
    let dir = process.cwd();
    for (let i = 0; i < 6; i++) {
      if (fs.existsSync(path.join(dir, '.claude'))) return dir;
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
    return process.cwd();
  } catch {
    return process.cwd();
  }
}

/**
 * Read the active work item ID from .claude/work-items/ACTIVE.
 * @param {string} projectRoot
 * @returns {string|null}
 */
function readActiveWI(projectRoot) {
  try {
    const activePath = path.join(projectRoot, '.claude', 'work-items', 'ACTIVE');
    if (!fs.existsSync(activePath)) return null;
    const content = fs.readFileSync(activePath, 'utf8').trim();
    return content || null;
  } catch {
    return null;
  }
}

/**
 * Ensure a directory exists. Never throws.
 * @param {string} dir
 */
function ensureDir(dir) {
  try {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  } catch {
    // Non-fatal
  }
}

/**
 * Read a file as a string, returning '' on any error.
 * @param {string} filePath
 * @returns {string}
 */
function safeRead(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
}

/**
 * Extract a brief resume summary from plan.md (last checked item + next unchecked).
 * @param {string} projectRoot
 * @returns {string}
 */
function extractPlanSummary(projectRoot) {
  try {
    // Check both common plan file locations
    const candidates = [
      path.join(projectRoot, 'plan.md'),
      path.join(projectRoot, '.claude', 'work-items', 'plan.md'),
    ];

    // Also check active work item directory
    const wiId = readActiveWI(projectRoot);
    if (wiId) {
      candidates.push(path.join(projectRoot, '.claude', 'work-items', wiId, 'plan.md'));
      candidates.push(path.join(projectRoot, 'specs', wiId, 'plan.md'));
    }

    for (const candidate of candidates) {
      if (!fs.existsSync(candidate)) continue;
      const content = fs.readFileSync(candidate, 'utf8');
      const lines = content.split('\n');

      let lastChecked = null;
      let firstUnchecked = null;

      for (const line of lines) {
        if (/^\s*-\s*\[x\]/i.test(line)) {
          lastChecked = line.trim();
        } else if (/^\s*-\s*\[\s*\]/i.test(line) && !firstUnchecked) {
          firstUnchecked = line.trim();
        }
      }

      if (lastChecked || firstUnchecked) {
        const parts = [];
        if (lastChecked) parts.push(`Last completed: ${lastChecked}`);
        if (firstUnchecked) parts.push(`Next task: ${firstUnchecked}`);
        return parts.join('\n');
      }
    }
    return 'No plan.md found or no checkboxes detected.';
  } catch {
    return 'Could not read plan.md.';
  }
}

/**
 * Build the Markdown content for a minimal handoff document.
 * @param {object} opts
 * @param {string} opts.reason
 * @param {string|null} opts.workItemId
 * @param {string} opts.timestamp
 * @param {string} opts.planSummary
 * @returns {string}
 */
function buildMinimalHandoff({ reason, workItemId, timestamp, planSummary }) {
  return [
    `# Session Handoff`,
    ``,
    `**Generated**: ${timestamp}`,
    `**Reason**: ${reason}`,
    `**Work Item**: ${workItemId || 'none'}`,
    ``,
    `## Resume Instructions`,
    ``,
    `1. Run \`/resume-handoff\` in a new session`,
    `2. Check the plan.md for the last \`[x]\` checkbox`,
    `3. Continue from the next unchecked item`,
    ``,
    `## Plan State`,
    ``,
    planSummary,
    ``,
    `## Notes`,
    ``,
    `This handoff was auto-generated (${reason}). For a full handoff with`,
    `blockers, decisions, and modified files, generate one manually before`,
    `context approaches the HALT threshold.`,
    ``,
    `See: .claude/rules/context-guardian.md`,
  ].join('\n');
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Generate a handoff document and write the PENDING_HANDOFF pointer.
 *
 * @param {object} opts
 * @param {string} [opts.reason='manual']       - Why the handoff was triggered
 * @param {string} [opts.tier='minimal']        - 'minimal' (auto) or 'full' (manual)
 * @returns {{ success: boolean, handoffPath: string|null, workItemId: string|null }}
 */
function generateHandoff({ reason = 'manual', tier = 'minimal' } = {}) {
  try {
    const projectRoot = resolveProjectRoot();
    const wiId = readActiveWI(projectRoot);
    const timestamp = new Date().toISOString();
    const datestamp = timestamp.replace(/[:.]/g, '-').slice(0, 19);

    // Determine output directory
    let outDir;
    if (wiId) {
      outDir = path.join(projectRoot, '.claude', 'work-items', wiId);
    } else {
      outDir = path.join(projectRoot, '.mad', 'scratch');
    }
    ensureDir(outDir);

    // Build and write handoff document
    const planSummary = extractPlanSummary(projectRoot);
    const content = buildMinimalHandoff({ reason, workItemId: wiId, timestamp, planSummary });
    const handoffFileName = `HANDOFF-${datestamp}.md`;
    const handoffPath = path.join(outDir, handoffFileName);

    fs.writeFileSync(handoffPath, content, 'utf8');

    // Write PENDING_HANDOFF pointer (plain text, just the path)
    const pointerPath = path.join(outDir, 'PENDING_HANDOFF');
    fs.writeFileSync(pointerPath, handoffPath, 'utf8');

    // Also write to ~/.mad/scratch/PENDING_HANDOFF as a fallback
    // so resume-handoff can find it even if project root detection differs
    try {
      const globalScratch = path.join(os.homedir(), '.mad', 'scratch');
      ensureDir(globalScratch);
      fs.writeFileSync(path.join(globalScratch, 'PENDING_HANDOFF'), handoffPath, 'utf8');
    } catch {
      // Non-fatal - local pointer is sufficient
    }

    return { success: true, handoffPath, workItemId: wiId };
  } catch (err) {
    return { success: false, handoffPath: null, workItemId: null };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

module.exports = { generateHandoff };
