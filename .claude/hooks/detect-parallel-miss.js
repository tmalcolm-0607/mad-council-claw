#!/usr/bin/env node
/**
 * Hook: PreToolUse (Task)
 * Purpose: Warn when a Task dispatch appears to be part of a multi-lane
 *          fan-out that SHOULD have been a single message with multiple
 *          Task blocks (parallel dispatch) but is instead being sent as
 *          separate sequential messages (serial dispatch).
 *
 * Why: Phase 3 (C) /mad-analyze demonstrated this pathology twice in one
 *      session — Lane A returned, Lane B was dispatched alone, Lane C
 *      was dispatched alone. The user-facing wall-clock cost: instead
 *      of max(6:17, 3:37, 3:26) = ~6:17, we got 6:17 + 3:37 + 3:26 =
 *      ~13 min. Roughly 2x the wall-clock for the same work.
 *
 *      Mechanical detection lets the hook surface the mistake at the
 *      moment of the second/third Task in the fan-out, while there's
 *      still time to course-correct (or at least record the lesson).
 *
 * Detection heuristic:
 *   1. Maintain a sliding-window log at .mad/scratch/recent-task-dispatches.jsonl
 *      with one entry per Task PreToolUse: {timestamp, prompt_preview,
 *      session_id, message_index_hint}.
 *   2. On each new Task:
 *      a. Read entries within the last PARALLEL_MISS_WINDOW_MS (default 5min).
 *      b. Check if the current prompt cross-references a prior prompt
 *         (mentions Lane A/B/C, Phase X step Y, parallel lanes, parallel-fan-out,
 *         "lane", "subagent group", etc.) AND a prior prompt uses similar
 *         framing.
 *      c. Check if the current prompt's "lane label" (e.g., "Lane B") is
 *         distinct from prior prompts' lane labels in the same window.
 *      d. If both conditions match, emit a stderr warning. NEVER block.
 *
 * Output (stderr, advisory only):
 *   [PARALLEL-MISS] Task dispatch appears to be part of a multi-lane
 *                   fan-out. Prior Tasks within last Nm: {list}.
 *                   These could have run in one message with multiple
 *                   Task blocks (parallel) instead of separate messages
 *                   (serial). Predicted wall-clock cost of serial
 *                   dispatch: ~Nx the parallel cost.
 *
 * Override:
 *   - Set PARALLEL_MISS_DETECT_DISABLED=true in .claude/settings.local.json
 *     env block.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const RECENT_LOG = path.join(REPO_ROOT, '.mad', 'scratch', 'recent-task-dispatches.jsonl');

const PARALLEL_MISS_WINDOW_MS = 5 * 60 * 1000;     // 5 minutes
const RECENT_LOG_MAX_LINES = 50;                   // bound the log
const LANE_LABEL_REGEX = /\b(?:lane|step|phase)\s+([A-Za-z0-9-]+)\b/gi;
const FAN_OUT_KEYWORDS = [
  /\bparallel\s+lanes?\b/i,
  /\bmulti[\s-]lane\b/i,
  /\bfan[\s-]out\b/i,
  /\bsingle\s+message\s+(?:multiple\s+)?(?:task\s+)?blocks?\b/i,
  /\b(?:lane|subagent)\s+group\b/i,
  /\bdisjoint\s+lanes?\b/i,
  /\borchestrator[\s-]driven\s+parallel\b/i,
  /\bagent[\s-]team\b/i,
];

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
    const flag = env.PARALLEL_MISS_DETECT_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function readRecentLog() {
  try {
    const raw = fs.readFileSync(RECENT_LOG, 'utf8');
    const lines = raw.split('\n').filter((l) => l.trim());
    return lines.map((l) => {
      try { return JSON.parse(l); } catch { return null; }
    }).filter(Boolean);
  } catch {
    return [];
  }
}

function appendToRecentLog(entry) {
  try {
    fs.mkdirSync(path.dirname(RECENT_LOG), { recursive: true });
    let lines = [];
    try {
      lines = fs.readFileSync(RECENT_LOG, 'utf8').split('\n').filter((l) => l.trim());
    } catch {
      lines = [];
    }
    lines.push(JSON.stringify(entry));
    while (lines.length > RECENT_LOG_MAX_LINES) lines.shift();
    fs.writeFileSync(RECENT_LOG, lines.join('\n') + '\n');
  } catch {
    // best-effort
  }
}

function extractLaneLabels(prompt) {
  if (!prompt) return new Set();
  const labels = new Set();
  let m;
  const re = new RegExp(LANE_LABEL_REGEX.source, LANE_LABEL_REGEX.flags);
  while ((m = re.exec(prompt)) !== null) {
    labels.add(m[1].toLowerCase());
  }
  return labels;
}

function hasFanOutKeyword(prompt) {
  if (!prompt) return false;
  return FAN_OUT_KEYWORDS.some((p) => p.test(prompt));
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
  const now = Date.now();

  const currentEntry = {
    timestamp_ms: now,
    timestamp_iso: new Date(now).toISOString(),
    description: description.slice(0, 100),
    prompt_preview: prompt.slice(0, 300),
    session_id: sessionId,
    lane_labels: Array.from(extractLaneLabels(prompt)),
    has_fan_out_keyword: hasFanOutKeyword(prompt),
  };

  // Check recent log for fan-out-shaped predecessors
  const recent = readRecentLog().filter((e) =>
    e.timestamp_ms && (now - e.timestamp_ms) <= PARALLEL_MISS_WINDOW_MS &&
    e.session_id === sessionId
  );

  // Heuristic A: current and ≥1 prior both have fan-out keywords AND distinct lane labels
  const priorWithFanOutKeyword = recent.filter((e) => e.has_fan_out_keyword);
  const currentHasFanOut = currentEntry.has_fan_out_keyword;

  const currentLabels = new Set(currentEntry.lane_labels);
  const priorLabelsAllSeen = new Set();
  for (const e of recent) {
    for (const l of (e.lane_labels || [])) priorLabelsAllSeen.add(l);
  }

  const labelsDistinct = currentLabels.size > 0 && [...currentLabels].some((l) => !priorLabelsAllSeen.has(l));
  const labelsAlsoIntersect = currentLabels.size > 0 && [...currentLabels].some((l) => priorLabelsAllSeen.has(l));
  // We want the case where current has a NEW lane label (e.g. "Lane B" or "Lane C")
  // distinct from a prior "Lane A"

  const triggerCondition = (
    currentHasFanOut &&
    priorWithFanOutKeyword.length >= 1 &&
    labelsDistinct &&
    !labelsAlsoIntersect
  );

  if (triggerCondition) {
    const priorList = priorWithFanOutKeyword
      .slice(-3)
      .map((e) => `  - ${e.timestamp_iso} :: ${e.description || '(no description)'} :: lanes=[${(e.lane_labels || []).join(',')}]`)
      .join('\n');

    process.stderr.write(
      `[PARALLEL-MISS] Task dispatch appears to be part of a multi-lane fan-out being sent serially.\n` +
        `  Current: ${currentEntry.description || '(no description)'} :: lanes=[${currentEntry.lane_labels.join(',')}]\n` +
        `  Prior fan-out-shaped Tasks within last ${PARALLEL_MISS_WINDOW_MS / 60000}min:\n${priorList}\n\n` +
        `  These could have run in ONE assistant message with multiple Task blocks\n` +
        `  (synchronous parallel dispatch) instead of separate sequential messages.\n` +
        `  Wall-clock cost of serial vs parallel: ~Nx where N = number of lanes.\n\n` +
        `  See CLAUDE.md § Skill-invocation timing metrics § "Speed pathology #1" for the\n` +
        `  full pattern. To suppress this advisory, set PARALLEL_MISS_DETECT_DISABLED=true\n` +
        `  in .claude/settings.local.json env block.\n`
    );
  }

  // Always append current entry to the recent log (even if no warning fired)
  appendToRecentLog(currentEntry);

  // Never block — this is advisory only
  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[detect-parallel-miss] internal error: ${err && err.message}\n`);
  process.exit(0);
});
