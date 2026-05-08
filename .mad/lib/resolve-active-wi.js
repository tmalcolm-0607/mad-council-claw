#!/usr/bin/env node
'use strict';

/**
 * Resolve the active work item ID for the current session.
 *
 * Reads .claude/work-items/ACTIVE (a plain-text file containing the work item ID)
 * and returns { wiId: string | null }.
 *
 * Per .claude/rules/artifact-placement.md, runtime libraries live under .mad/lib/.
 * The 9 hooks under .claude/hooks/ require this module via `../../.mad/lib/resolve-active-wi`.
 *
 * This module is imported by multiple hooks at module scope, so it MUST:
 * - Never throw (always return a safe default)
 * - Only use built-in Node.js modules (fs, path)
 * - Be self-contained (no local requires)
 * - Fail-open: return { wiId: null } on any error
 *
 * @param {object|null} data - Hook event data (may contain session_id/sessionId).
 *                             Currently unused; reserved for future per-session resolution
 *                             (e.g. .claude/work-items/sessions/<session_id>) so worktree
 *                             isolation can be supported without breaking the contract.
 * @param {string} projectDir - Absolute path to the project root (containing .claude/).
 *                              Falls back to process.cwd() if absent.
 * @returns {{ wiId: string | null }}
 */
function resolveActiveWI(data, projectDir) {
  try {
    const fs = require('fs');
    const path = require('path');

    const dir = projectDir || process.cwd();
    const activePath = path.join(dir, '.claude', 'work-items', 'ACTIVE');

    if (!fs.existsSync(activePath)) {
      return { wiId: null };
    }

    const content = fs.readFileSync(activePath, 'utf8').trim();

    if (!content) {
      return { wiId: null };
    }

    return { wiId: content };
  } catch {
    return { wiId: null };
  }
}

module.exports = { resolveActiveWI };
