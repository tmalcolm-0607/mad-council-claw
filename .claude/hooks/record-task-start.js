#!/usr/bin/env node
/**
 * Hook: PreToolUse (Task)
 * Purpose: Record Task subagent start time so PostToolUse:Task can compute
 *          true wall-clock duration. Companion to record-task-completion.js.
 *
 * Why: Without a paired start-time hook, PostToolUse only sees the completion
 *      moment. duration_ms = NULL. Phase 3 (C) demonstrated the cost: we
 *      could not numerically compare parallel-vs-serial Task dispatch
 *      without manual stopwatch.
 *
 * Mechanism:
 *   1. Hash the prompt+description into a correlation key.
 *   2. Append { correlation_key, started_at_ms, session_id } to
 *      .mad/scratch/task-start-pending.jsonl.
 *   3. record-task-completion.js (PostToolUse:Task) hashes the same way,
 *      finds the matching start entry, computes duration_ms, removes the
 *      pending entry, writes the joined record.
 *
 * Override:
 *   - Set TASK_TIMING_DISABLED=true in .claude/settings.local.json env block.
 *     (Same flag as record-task-completion.js — turn both off together.)
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const PENDING_LOG = path.join(REPO_ROOT, '.mad', 'scratch', 'task-start-pending.jsonl');
const PENDING_MAX_AGE_MS = 60 * 60 * 1000; // 1h — orphans get swept

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

function correlationKey(prompt, description, sessionId) {
  const data = `${sessionId || ''}|${description || ''}|${prompt || ''}`;
  return crypto.createHash('sha256').update(data).digest('hex').slice(0, 16);
}

function readPending() {
  try {
    const raw = fs.readFileSync(PENDING_LOG, 'utf8');
    const lines = raw.split('\n').filter((l) => l.trim());
    return lines.map((l) => {
      try { return JSON.parse(l); } catch { return null; }
    }).filter(Boolean);
  } catch {
    return [];
  }
}

function writePending(entries) {
  try {
    fs.mkdirSync(path.dirname(PENDING_LOG), { recursive: true });
    fs.writeFileSync(PENDING_LOG, entries.map((e) => JSON.stringify(e)).join('\n') + (entries.length ? '\n' : ''));
  } catch {
    // best-effort
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
  const description = toolInput.description || '';
  const sessionId = payload.session_id || null;
  const startedAtMs = Date.now();
  const key = correlationKey(prompt, description, sessionId);

  // Sweep pending entries older than PENDING_MAX_AGE_MS (orphans from agents
  // that never produced a PostToolUse event, e.g. session crash).
  const fresh = readPending().filter((e) => (startedAtMs - (e.started_at_ms || 0)) <= PENDING_MAX_AGE_MS);
  fresh.push({
    correlation_key: key,
    started_at_ms: startedAtMs,
    started_at_iso: new Date(startedAtMs).toISOString(),
    session_id: sessionId,
    description: description.slice(0, 200),
    subagent_type: toolInput.subagent_type || toolInput.subagentType || 'general-purpose',
  });
  writePending(fresh);

  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[record-task-start] internal error: ${err && err.message}\n`);
  process.exit(0);
});
