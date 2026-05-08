#!/usr/bin/env node
/**
 * Hook: PostToolUse (Task)
 * Purpose: Record per-Task-subagent timing for kit-wide performance metrics.
 *          Companion to record-skill-completion.js (which captures Skill body
 *          duration). Task subagents are where most wall-clock lives in
 *          parallel-fan-out skills (e.g. /mad-plan's 3 domain reviewers).
 *
 * Why: Phase 3 (B) timing investigation showed the Skill-tool record only
 *      captures one number per skill invocation, not the per-subagent
 *      durations that drive parallel-vs-serial speedup analysis. With Task
 *      timing logged we can answer "did these 3 lanes really run in
 *      parallel?" mechanically — see record-task-parallel-miss.js for the
 *      detector that uses this log.
 *
 * Output schema (one JSONL line per Task completion):
 *   {
 *     "subagent_type": "code-investigator",
 *     "description": "Lane A: Coverage + Scope Drift",
 *     "session_id": "abc...",
 *     "started_at_ms": null,           // PreToolUse timing not captured here;
 *                                      // PostToolUse only sees completion
 *     "completed_at_ms": 1746255300000,
 *     "completed_at_iso": "2026-05-03T08:55:00.000Z",
 *     "prompt_preview": "Phase 3 (C) /mad-analyze — Lane A...",
 *     "prompt_hash": "abc123..."       // for parallel-miss correlation
 *   }
 *
 * Why no started_at_ms: PostToolUse alone can't tell you the start time.
 * For a true duration, pair with a PreToolUse:Task hook that records
 * started_at_ms keyed by the prompt hash. v1 (this file) records the
 * completion event only; v2 (future) adds the PreToolUse twin.
 *
 * Override:
 *   - Set TASK_TIMING_DISABLED=true in .claude/settings.local.json env block.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const TASK_TIMING_LOG = path.join(REPO_ROOT, '.mad', 'scratch', 'task-timing.jsonl');
const PENDING_LOG = path.join(REPO_ROOT, '.mad', 'scratch', 'task-start-pending.jsonl');

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
    const flag = env.TASK_TIMING_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function hashPrompt(prompt) {
  if (!prompt) return null;
  return crypto.createHash('sha256').update(String(prompt)).digest('hex').slice(0, 16);
}

function correlationKey(prompt, description, sessionId) {
  const data = `${sessionId || ''}|${description || ''}|${prompt || ''}`;
  return crypto.createHash('sha256').update(data).digest('hex').slice(0, 16);
}

function popPendingByKey(key) {
  // Read pending log; remove and return the matching entry (if any).
  let entries = [];
  try {
    const raw = fs.readFileSync(PENDING_LOG, 'utf8');
    entries = raw.split('\n').filter((l) => l.trim()).map((l) => {
      try { return JSON.parse(l); } catch { return null; }
    }).filter(Boolean);
  } catch {
    return null;
  }
  const idx = entries.findIndex((e) => e.correlation_key === key);
  if (idx === -1) return null;
  const match = entries[idx];
  entries.splice(idx, 1);
  try {
    fs.writeFileSync(PENDING_LOG, entries.map((e) => JSON.stringify(e)).join('\n') + (entries.length ? '\n' : ''));
  } catch {
    // best-effort
  }
  return match;
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
  const subagentType = toolInput.subagent_type || toolInput.subagentType || 'general-purpose';
  const description = toolInput.description || '';
  const prompt = toolInput.prompt || '';
  const sessionId = payload.session_id || null;

  const completedAtMs = Date.now();
  const key = correlationKey(prompt, description, sessionId);
  const startEntry = popPendingByKey(key);
  const startedAtMs = startEntry ? startEntry.started_at_ms : null;
  const durationMs = startedAtMs ? (completedAtMs - startedAtMs) : null;

  // Capture tokens + outcome from tool_response. Claude Code's PostToolUse
  // payload shape may include any of: tool_response (text), tool_response.usage
  // (input/output/cache token counts), tool_response.error, tool_response.is_error.
  // We capture defensively — fields may be absent depending on the host.
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

  // Outcome heuristic: error fields take precedence; otherwise scan response text.
  let outcome = 'unknown';
  if (toolResponse && (toolResponse.is_error === true || toolResponse.isError === true)) {
    outcome = 'failure';
  } else if (toolResponse && toolResponse.error) {
    outcome = 'failure';
  } else if (typeof responseText === 'string' && responseText.length > 0) {
    const text = String(responseText).slice(0, 5000);
    // Failure markers
    if (/\b(?:failed|error|unable\s+to|cannot\s+complete|crashed|aborted|denied)\b/i.test(text) &&
        !/\bsmoke\s+test\s+passed\b/i.test(text)) {
      outcome = 'failure-likely';
    } else if (/\b(?:complete|completed|success|all\s+(?:tests|checks)\s+passed|\[OK\]|done|finished)\b/i.test(text)) {
      outcome = 'success';
    } else {
      outcome = 'success-no-marker';
    }
  } else if (durationMs !== null) {
    // No response text but PostToolUse fired — assume completion was clean
    outcome = 'success-empty-response';
  }

  // Archive full prompt to a content-addressable store so later analysis can
  // retrieve it without bloating the timing log itself.
  const promptArchiveDir = path.join(REPO_ROOT, '.mad', 'scratch', 'prompt-archive');
  const promptHash = hashPrompt(prompt);
  if (promptHash && prompt) {
    try {
      fs.mkdirSync(promptArchiveDir, { recursive: true });
      const archivePath = path.join(promptArchiveDir, `${promptHash}.txt`);
      if (!fs.existsSync(archivePath)) {
        fs.writeFileSync(archivePath, prompt);
      }
    } catch {
      // best-effort
    }
  }

  const entry = {
    subagent_type: subagentType,
    description: description.slice(0, 200),
    session_id: sessionId,
    started_at_ms: startedAtMs,
    completed_at_ms: completedAtMs,
    completed_at_iso: new Date(completedAtMs).toISOString(),
    duration_ms: durationMs,
    duration_min: durationMs ? Math.round((durationMs / 60000) * 10) / 10 : null,
    prompt_preview: prompt.slice(0, 500),
    prompt_hash: promptHash,
    prompt_archive_path: promptHash ? `.mad/scratch/prompt-archive/${promptHash}.txt` : null,
    correlation_key: key,
    correlation_status: startEntry ? 'paired' : 'orphan-completion-no-start',
    tokens,
    outcome,
    response_preview: typeof responseText === 'string' ? responseText.slice(0, 500) : null,
  };

  try {
    fs.mkdirSync(path.dirname(TASK_TIMING_LOG), { recursive: true });
    fs.appendFileSync(TASK_TIMING_LOG, JSON.stringify(entry) + '\n');
  } catch {
    // best-effort
  }

  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[record-task-completion] internal error: ${err && err.message}\n`);
  process.exit(0);
});
