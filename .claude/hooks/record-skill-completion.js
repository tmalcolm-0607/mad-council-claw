#!/usr/bin/env node
/**
 * Hook: PostToolUse (Skill)
 * Purpose: Record skill completion timing for kit-wide performance metrics.
 *          Companion to track-mad-skill-invocation.js (PreToolUse:Skill) which
 *          records started_at_ms; this hook records completed_at_ms and
 *          appends a structured entry to .mad/scratch/skill-timing.jsonl.
 *
 * Why: Phase 3 of cheeky-leaping-kahn.md ran 3 canonical skills in ~2h 13m of
 *      wall-clock time (mad-spec 52m, testplan 42m, mad-plan 40m). The user
 *      flagged: "it shouldn't take AI hours to spec/plan." We need a per-skill
 *      timing record to make slow runs visible immediately, not requiring
 *      post-hoc forensics.
 *
 * Output schema (one JSONL line per skill completion):
 *   {
 *     "skill": "mad-plan",
 *     "session_id": "abc...",
 *     "started_at_ms": 1746252900000,
 *     "completed_at_ms": 1746255300000,
 *     "duration_ms": 2400000,
 *     "duration_min": 40.0,
 *     "completed_at_iso": "2026-05-03T08:55:00.000Z"
 *   }
 *
 * Override:
 *   - Set SKILL_TIMING_DISABLED=true in .claude/settings.local.json env block.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const STATE_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'mad-pipeline-active.json');
const TIMING_LOG = path.join(REPO_ROOT, '.mad', 'scratch', 'skill-timing.jsonl');
const SLOW_THRESHOLD_MS = 600000; // 10 minutes — emit warning when exceeded

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
    const flag = env.SKILL_TIMING_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function readState() {
  try {
    const raw = fs.readFileSync(STATE_FILE, 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
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
  if (toolName && toolName !== 'Skill') process.exit(0);

  if (isHookDisabled()) process.exit(0);

  const toolInput = payload.tool_input || payload.toolInput || {};
  const skillName = toolInput.skill || toolInput.skillName;
  if (!skillName) process.exit(0);

  const state = readState();
  if (!state || state.current_skill !== skillName) {
    // No matching pre-event recorded; skip silently.
    process.exit(0);
  }

  const startedAtMs = state.started_at_ms;
  if (typeof startedAtMs !== 'number') process.exit(0);

  const completedAtMs = Date.now();
  const durationMs = completedAtMs - startedAtMs;

  // Capture tokens + outcome (same shape as record-task-completion.js)
  const toolResponse = payload.tool_response || payload.toolResponse || payload.response || null;
  const usage = (toolResponse && (toolResponse.usage || toolResponse.token_usage)) || payload.usage || null;
  const responseText = (typeof toolResponse === 'string')
    ? toolResponse
    : (toolResponse && (toolResponse.content || toolResponse.text || toolResponse.output)) || '';

  const tokens = {
    input: usage ? (usage.input_tokens || usage.input || null) : null,
    output: usage ? (usage.output_tokens || usage.output || null) : null,
    cache_read: usage ? (usage.cache_read_input_tokens || usage.cache_read_tokens || usage.cache_read || null) : null,
    cache_creation: usage ? (usage.cache_creation_input_tokens || usage.cache_creation_tokens || usage.cache_creation || null) : null,
  };

  let outcome = 'unknown';
  if (toolResponse && (toolResponse.is_error === true || toolResponse.isError === true)) {
    outcome = 'failure';
  } else if (toolResponse && toolResponse.error) {
    outcome = 'failure';
  } else if (typeof responseText === 'string' && responseText.length > 0) {
    const text = String(responseText).slice(0, 5000);
    if (/\b(?:failed|error|unable\s+to|cannot\s+complete|crashed|aborted|denied)\b/i.test(text)) {
      outcome = 'failure-likely';
    } else if (/\b(?:complete|completed|success|all\s+(?:tests|checks)\s+passed|\[OK\]|done|finished)\b/i.test(text)) {
      outcome = 'success';
    } else {
      outcome = 'success-no-marker';
    }
  } else {
    outcome = 'success-empty-response';
  }

  const entry = {
    skill: skillName,
    session_id: state.session_id || payload.session_id || null,
    started_at_ms: startedAtMs,
    completed_at_ms: completedAtMs,
    duration_ms: durationMs,
    duration_min: Math.round((durationMs / 60000) * 10) / 10,
    completed_at_iso: new Date(completedAtMs).toISOString(),
    tokens,
    outcome,
    response_preview: typeof responseText === 'string' ? responseText.slice(0, 500) : null,
  };

  try {
    fs.mkdirSync(path.dirname(TIMING_LOG), { recursive: true });
    fs.appendFileSync(TIMING_LOG, JSON.stringify(entry) + '\n');
  } catch {
    // best-effort
  }

  if (durationMs > SLOW_THRESHOLD_MS) {
    process.stderr.write(
      `[skill-timing] /${skillName} took ${entry.duration_min} min — exceeds the 10-minute slow-run threshold.\n` +
        `  See .mad/scratch/skill-timing.jsonl for history. Profile with .claude/scripts/Track-SkillMetrics.ps1.\n`
    );
  }

  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[record-skill-completion] internal error: ${err && err.message}\n`);
  process.exit(0);
});
