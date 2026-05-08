#!/usr/bin/env node
/**
 * Hook: PreToolUse (Write|Edit)
 * Purpose: Layer 3 of iter8-settings-mystery defense. Catch any future write
 *          to .claude/settings.json (or settings.local.json) that introduces
 *          absolute Windows hook paths in place of the kit-standard relative
 *          paths.
 *
 * Background: iter10 closed layers 1+2 of the defense (mark recurrence-source
 * backlogs OBSOLETE; demote HOOK-SEC-002 rule to report-only). This hook is
 * the belt-and-suspenders runtime guard for unknown-unknown automation that
 * might mutate hook paths from relative -> absolute.
 *
 * Detection:
 *   Match file_path ending with .claude/settings.json or .claude/settings.local.json
 *   Scan new content (Write) or new_string (Edit) for absolute Windows path
 *   patterns inside hook command strings:
 *     node "C:/...   node 'C:/...
 *     pwsh "C:/...   pwsh 'C:/...
 *     powershell.exe "C:/...
 *   etc. -- any "<command> \"<DRIVE>:" shape.
 *
 * Action: emit permissionDecision='ask' with diagnostic message.
 *
 * Feature flag: SETTINGS_GUARD_ENABLED (default true; set to 'false' or '0'
 * to disable for emergency overrides).
 *
 * Exit codes:
 *   0 - Always (permissionDecision in JSON payload carries any decision).
 *       Fail-open per .claude/hooks/hook-fail-open-policy.md.
 */

'use strict';

// Match: <command> "<DRIVE>: or <command> '<DRIVE>:
// where <command> is node, pwsh, powershell, powershell.exe (case-insensitive)
// and <DRIVE> is a single letter A-Z (case-insensitive).
//
// Anchored on a word boundary so matches are not confused with paths that
// happen to contain those substrings later in the line. The pattern matches
// the typical settings.json hook-command shape:
//   "command": "node \"C:/Users/.../hook.js\""
const ABSOLUTE_PATH_PATTERNS = [
  /\bnode\s+["']\s*[A-Za-z]:[\\/]/i,
  /\bpwsh\s+["']\s*[A-Za-z]:[\\/]/i,
  /\bpowershell(?:\.exe)?\s+["']\s*[A-Za-z]:[\\/]/i,
];

// In settings.json the path is JSON-escaped, so a literal `node "C:/...`
// shows up as `node \"C:/...`. Patch the patterns to also accept the
// backslash-escaped quote form.
const ABSOLUTE_PATH_PATTERNS_ESCAPED = [
  /\bnode\s+\\?["']\s*[A-Za-z]:[\\/]/i,
  /\bpwsh\s+\\?["']\s*[A-Za-z]:[\\/]/i,
  /\bpowershell(?:\.exe)?\s+\\?["']\s*[A-Za-z]:[\\/]/i,
];

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

function isSettingsFile(filePath) {
  if (!filePath || typeof filePath !== 'string') return false;
  const normalized = filePath.replace(/\\/g, '/').toLowerCase();
  return (
    normalized.endsWith('.claude/settings.json') ||
    normalized.endsWith('.claude/settings.local.json')
  );
}

/**
 * Find the first absolute-path match in the given content. Returns the
 * matched line (trimmed, capped at 200 chars) or null if no match.
 */
function findAbsolutePathMatch(content) {
  if (!content || typeof content !== 'string') return null;

  const lines = content.split('\n');
  for (const line of lines) {
    for (const pat of ABSOLUTE_PATH_PATTERNS_ESCAPED) {
      if (pat.test(line)) {
        const trimmed = line.trim();
        return trimmed.length > 200 ? trimmed.substring(0, 200) + '...' : trimmed;
      }
    }
    for (const pat of ABSOLUTE_PATH_PATTERNS) {
      if (pat.test(line)) {
        const trimmed = line.trim();
        return trimmed.length > 200 ? trimmed.substring(0, 200) + '...' : trimmed;
      }
    }
  }
  return null;
}

/**
 * Extract the content to scan from the tool input. For Write, this is
 * `content`. For Edit, this is `new_string`. Returns empty string if
 * neither is present.
 */
function getNewContent(toolName, toolInput) {
  if (!toolInput) return '';
  if (toolName === 'Write') return String(toolInput.content || '');
  if (toolName === 'Edit') return String(toolInput.new_string || '');
  return '';
}

function emitAskDecision(matchedLine) {
  const reason = '[pre-write-settings-validate] Detected absolute-path mutation in settings.json.';
  const additionalContext =
    `Pattern: ${matchedLine}\n\n` +
    `Kit standard: relative paths (Claude Code resolves CWD to project root). Only stop-guard.js\n` +
    `intentionally retains absolute path (legacy iter3 fix). HOOK-SEC-002 in config-lint/SKILL.md\n` +
    `is report-only and exempts settings.json from auto-fix.\n\n` +
    `Confirm intent. If accidental (e.g., from /config-lint --fix), reject and revert.\n\n` +
    `To disable this guard: SETTINGS_GUARD_ENABLED=false`;

  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'ask',
      permissionDecisionReason: reason,
      additionalContext: additionalContext,
    },
  }));
}

async function main() {
  // Feature flag check (first thing, before any I/O)
  const enabled = process.env.SETTINGS_GUARD_ENABLED;
  if (enabled !== undefined) {
    const lower = String(enabled).toLowerCase();
    if (lower === 'false' || lower === '0') {
      process.exit(0);
    }
  }

  let input;
  try {
    input = await readStdin();
  } catch {
    process.exit(0); // Fail-open: cannot read stdin
  }

  if (!input || !input.trim()) {
    process.exit(0); // No payload to scan
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0); // Malformed JSON: fail-open
  }

  const toolName = data.tool_name;
  const toolInput = data.tool_input;
  const filePath = toolInput?.file_path;

  if (!isSettingsFile(filePath)) {
    process.exit(0); // Not a settings file: out of scope
  }

  if (toolName !== 'Write' && toolName !== 'Edit') {
    process.exit(0); // Only Write/Edit relevant
  }

  const content = getNewContent(toolName, toolInput);
  const matchedLine = findAbsolutePathMatch(content);

  if (matchedLine) {
    emitAskDecision(matchedLine);
  }

  process.exit(0);
}

main().catch((err) => {
  // Advisory hook: fail-open on unexpected error.
  console.error('[pre-write-settings-validate] Error:', err && err.message ? err.message : err);
  process.exit(0);
});
