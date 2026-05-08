#!/usr/bin/env node
/**
 * Hook: PreToolUse (Task)
 * Purpose: BLOCK Task spawns whose prompt contains a "top-N cap" phrase
 *          (top 5, top 10, first 10, most important 5, etc.) UNLESS the
 *          prompt also explicitly opts into exhaustive enumeration.
 *
 * Why: Iter1-41 of the collab-engine session, every audit/review/inventory
 *      task spawned with caps like "Top 5 issues", "first 10 violations",
 *      "most important 3 findings". The user had to flag this manually each
 *      time. The cap silently truncates findings — a Top-5 inventory of 25
 *      LENS-* repos hides 20 repos. NO existing rule permits Top-N capping;
 *      multiple memory rules mandate the opposite (feedback_pr_comment_triage,
 *      feedback_nothing_out_of_scope, skill-standards Dimension 2).
 *
 * Mechanism:
 *   1. On PreToolUse:Task, scan tool_input.prompt for cap regex.
 *   2. If a cap phrase matches, check whether the prompt also contains the
 *      literal opt-in: "Enumerate exhaustively" (case-insensitive).
 *   3. If cap present AND opt-in absent: BLOCK with permissionDecision: deny.
 *
 * Allowed (does NOT block):
 *   - Tasks with no cap phrase
 *   - Tasks that contain a cap phrase AND "Enumerate exhaustively" (the
 *     subagent prompt explicitly requested both an upper bound for display
 *     AND exhaustive analysis — usually means "rank top N but list all")
 *   - Tasks where cap appears inside a quoted user message being relayed
 *     (heuristic: cap surrounded by quote chars)
 *
 * Override:
 *   - Set TOP_N_HOOK_DISABLED=true in .claude/settings.local.json env block.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const FLAG_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'top-n-cap-flags.json');

// Cap phrases — case-insensitive, deliberately conservative (false-positive-tolerant)
const CAP_PATTERNS = [
  /\btop[-\s]+\d+\b/i,                          // "top 5", "top-10"
  /\bfirst\s+\d+\b/i,                           // "first 10"
  /\b(?:most|least)\s+(?:important|critical|severe|relevant)\s+\d+\b/i,
  /\b(?:limit|cap|bound)\s+(?:to|at)\s+\d+\b/i, // "limit to 5"
  /\bonly\s+(?:the\s+)?(?:top|first)\s+\d+\b/i,
  /\b(?:list|enumerate|return|show|report)\s+(?:up\s+to\s+|at\s+most\s+)?\d{1,2}\s+(?:issues|findings|items|results|files|repos|services)\b/i,
  /\bmaximum\s+(?:of\s+)?\d+\s+(?:issues|findings|items)\b/i,
];

const OPT_IN_PHRASE = /enumerate\s+exhaustively/i;

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => (data += chunk));
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', () => resolve(''));
  });
}

function isHookDisabled() {
  try {
    const raw = fs.readFileSync(SETTINGS_LOCAL, 'utf8');
    const parsed = JSON.parse(raw);
    const env = (parsed && parsed.env) || {};
    const flag = env.TOP_N_HOOK_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function appendFlag(record) {
  try {
    fs.mkdirSync(path.dirname(FLAG_FILE), { recursive: true });
    let existing = [];
    try {
      existing = JSON.parse(fs.readFileSync(FLAG_FILE, 'utf8'));
      if (!Array.isArray(existing)) existing = [];
    } catch {
      existing = [];
    }
    existing.push(record);
    fs.writeFileSync(FLAG_FILE, JSON.stringify(existing, null, 2));
  } catch {
    // Best-effort; never crash the hook on flag-file write failure.
  }
}

async function main() {
  let raw = '';
  try {
    raw = await readStdin();
  } catch {
    process.exit(0);
  }
  if (!raw || !raw.trim()) process.exit(0);

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  const toolName = payload.tool_name || payload.toolName;
  if (toolName && toolName !== 'Task') process.exit(0);

  if (isHookDisabled()) process.exit(0);

  const toolInput = payload.tool_input || payload.toolInput || {};
  const prompt = toolInput.prompt || '';
  if (typeof prompt !== 'string' || !prompt.trim()) process.exit(0);

  // Find cap phrase matches
  const matches = [];
  for (const pattern of CAP_PATTERNS) {
    const m = prompt.match(pattern);
    if (m) matches.push({ pattern: pattern.source, match: m[0] });
  }

  if (matches.length === 0) process.exit(0);

  // Cap phrase present — check for opt-in
  if (OPT_IN_PHRASE.test(prompt)) {
    // Caller acknowledged the cap is for display only; full enumeration still required
    process.exit(0);
  }

  // BLOCK
  const message =
    `BLOCKED: Task prompt contains a Top-N cap phrase without explicit exhaustive-enumeration opt-in.\n\n` +
    `Matched cap phrase(s): ${matches.map((m) => `"${m.match}"`).join(', ')}\n\n` +
    `Top-N capping silently truncates findings. NO rule in this kit permits it.\n` +
    `Multiple memory rules mandate the opposite:\n` +
    `  - .claude/rules/no-top-n-capping.md\n` +
    `  - .claude/rules/pr-comment-triage.md ("TRIAGE EACH COMMENT")\n` +
    `  - .claude/rules/scope-discipline.md ("every item classify and act")\n` +
    `  - .claude/rules/skill-standards.md Dimension 2 (anti-hallucination)\n\n` +
    `Required action: rewrite the prompt to include the literal phrase\n` +
    `"Enumerate exhaustively" AND remove any cap that hides items. Acceptable shape:\n` +
    `  "Enumerate exhaustively. No Top-N capping. Every item classified and acted\n` +
    `   upon. State 'no findings' explicitly when a category is empty."\n\n` +
    `If you genuinely need a top-ranked DISPLAY of N items but full enumeration\n` +
    `internally, include both the cap phrase AND "Enumerate exhaustively" in the\n` +
    `prompt — the hook treats that as a valid intent declaration.\n\n` +
    `Override (not recommended): set TOP_N_HOOK_DISABLED=true in\n` +
    `.claude/settings.local.json env block.`;

  appendFlag({
    timestamp: new Date().toISOString(),
    matches: matches.map((m) => m.match),
    prompt_preview: prompt.slice(0, 500),
    blocked: true,
  });

  const decision = {
    permissionDecision: 'deny',
    permissionDecisionReason: message,
  };
  process.stdout.write(JSON.stringify(decision));
  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[detect-top-n-capping] internal error: ${err && err.message}\n`);
  process.exit(0);
});
