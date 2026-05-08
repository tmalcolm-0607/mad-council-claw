#!/usr/bin/env node
/**
 * Hook: PreToolUse (Skill)
 * Purpose: Records when a /mad-* skill is invoked, so the companion
 *          validate-mad-pipeline.js hook can verify that direct Writes to
 *          MAD artifacts (plan.md, tasks.md, analysis-report.md, test-plan.md)
 *          only happen as part of an active /mad-* skill invocation.
 *
 *          ALSO: detects missing auto-fire skills. /mad-spec is supposed to
 *          auto-fire /testplan on completion; iter1-41 it never did. Each new
 *          skill invocation checks history for /mad-spec runs that lack a
 *          subsequent /testplan invocation in the same session — appends to
 *          .mad/scratch/missing-autofire-flags.json so the SubagentStop hook
 *          (validate-artifact-completeness.js) can block on unanswered flags.
 *
 * State file: .mad/scratch/mad-pipeline-active.json
 *   {
 *     "current_skill": "mad-plan",
 *     "started_at_ms": 1746230400000,
 *     "ttl_ms": 1800000,
 *     "session_id": "abc...",
 *     "history": [
 *       { "skill": "mad-spec", "started_at_ms": ..., "session_id": "abc..." },
 *       ...
 *     ]
 *   }
 *
 * Trigger: PreToolUse on the Skill tool. If the skill is one of the tracked
 *          MAD skills, append to history and write the state file. Always
 *          run the auto-fire check.
 *
 * Auto-fire contract (read by this hook):
 *   /mad-spec  -> /testplan   (within AUTOFIRE_GRACE_MS of mad-spec start;
 *                              same session; before any conflicting MAD
 *                              skill like /mad-plan starts)
 *
 * This hook does NOT block. It always exits 0. Its sole job is to maintain
 * pipeline-state metadata + missing-autofire detection for the companion
 * blocking hooks (validate-mad-pipeline.js, validate-artifact-completeness.js).
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const STATE_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'mad-pipeline-active.json');
const AUTOFIRE_FLAG_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'missing-autofire-flags.json');

const TRACKED_SKILLS = new Set([
  'mad-spec',
  'mad-plan',
  'mad-tasks',
  'mad-analyze',
  'testplan',
  'mad-implement',
  'mad-validate',
  'mad-decompose',
  'mad-parallel',
  'mad-full',
]);

const STATE_TTL_MS = 30 * 60 * 1000; // 30 minutes
const HISTORY_MAX = 100;
const AUTOFIRE_GRACE_MS = 30 * 60 * 1000;

// Auto-fire contract: skill X must be followed by skill Y within grace window.
// /mad-spec MUST be followed by /testplan per CLAUDE.md mad-workflow.md.
const AUTOFIRE_RULES = [
  {
    initiator: 'mad-spec',
    expected_follow_up: 'testplan',
    note: '/mad-spec is documented to auto-fire /testplan --source spec on completion. Iter1-41 of collab-engine session, this never fired — 45 FRs ended up with no test plan.',
  },
];

// Skills that, if invoked between initiator and expected_follow_up, "consume"
// the auto-fire window (the workflow has moved on). Currently the canonical
// MAD pipeline never has this — /mad-plan/tasks/analyze are valid follow-ups
// AFTER /testplan, not in place of it. So we treat any other /mad-* invocation
// as evidence the auto-fire was missed.
const AUTOFIRE_TERMINATING_SKILLS = new Set([
  'mad-plan',
  'mad-tasks',
  'mad-analyze',
  'mad-implement',
  'mad-validate',
  'mad-decompose',
  'mad-parallel',
  'mad-full',
]);

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => (data += chunk));
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', () => resolve(''));
  });
}

function readState() {
  try {
    const raw = fs.readFileSync(STATE_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return null;
    return parsed;
  } catch {
    return null;
  }
}

function appendAutofireFlag(record) {
  try {
    fs.mkdirSync(path.dirname(AUTOFIRE_FLAG_FILE), { recursive: true });
    let existing = [];
    try {
      const raw = fs.readFileSync(AUTOFIRE_FLAG_FILE, 'utf8');
      existing = JSON.parse(raw);
      if (!Array.isArray(existing)) existing = [];
    } catch {
      existing = [];
    }
    existing.push(record);
    fs.writeFileSync(AUTOFIRE_FLAG_FILE, JSON.stringify(existing, null, 2));
  } catch {
    // best-effort
  }
}

function checkAutofire(history, currentSkill, currentSessionId) {
  // For each autofire rule: scan history for unfulfilled initiator entries.
  // An initiator is unfulfilled if NO entry of `expected_follow_up` appears
  // after it in the same session within AUTOFIRE_GRACE_MS, AND a terminating
  // skill (or the current invocation if it's terminating) appears after it.
  const now = Date.now();
  const flags = [];
  for (const rule of AUTOFIRE_RULES) {
    for (let i = 0; i < history.length; i++) {
      const entry = history[i];
      if (entry.skill !== rule.initiator) continue;
      if (entry.autofire_resolved) continue; // already fulfilled or already flagged

      // Look for fulfillment: the expected follow-up in same session within grace
      const fulfilled = history.slice(i + 1).some((e) =>
        e.skill === rule.expected_follow_up &&
        e.session_id === entry.session_id &&
        e.started_at_ms - entry.started_at_ms <= AUTOFIRE_GRACE_MS
      );
      if (fulfilled) {
        entry.autofire_resolved = true;
        continue;
      }

      // Check if the current invocation (or a prior history entry) is a terminating
      // skill that closes the window unfulfilled
      const terminatingPrior = history.slice(i + 1).some((e) =>
        e.session_id === entry.session_id && AUTOFIRE_TERMINATING_SKILLS.has(e.skill)
      );
      const terminatingNow =
        entry.session_id === currentSessionId &&
        AUTOFIRE_TERMINATING_SKILLS.has(currentSkill);

      const expired = now - entry.started_at_ms > AUTOFIRE_GRACE_MS;

      if (terminatingPrior || terminatingNow || expired) {
        flags.push({
          timestamp: new Date().toISOString(),
          initiator: rule.initiator,
          expected_follow_up: rule.expected_follow_up,
          initiator_started_at_ms: entry.started_at_ms,
          initiator_session_id: entry.session_id,
          terminating_skill: terminatingNow ? currentSkill : 'prior-or-expired',
          note: rule.note,
        });
        entry.autofire_resolved = 'flagged';
      }
    }
  }
  return flags;
}

async function main() {
  let raw = '';
  try {
    raw = await readStdin();
  } catch {
    process.exit(0);
  }

  if (!raw || !raw.trim()) {
    process.exit(0);
  }

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  const toolInput = payload.tool_input || payload.toolInput || {};
  const skillName = toolInput.skill || toolInput.skillName;
  if (!skillName) {
    process.exit(0);
  }

  if (!TRACKED_SKILLS.has(skillName)) {
    process.exit(0);
  }

  // Ensure scratch dir exists
  try {
    fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  } catch {
    // best-effort
  }

  const sessionId = payload.session_id || null;
  const startedAtMs = Date.now();

  // Read prior state to preserve history
  const priorState = readState();
  const history = Array.isArray(priorState && priorState.history) ? priorState.history : [];

  // Auto-fire check BEFORE we append the new entry — current invocation may
  // be the terminating skill that closes a prior /mad-spec auto-fire window.
  const newFlags = checkAutofire(history, skillName, sessionId);
  for (const flag of newFlags) {
    appendAutofireFlag(flag);
  }

  // Append the current invocation to history
  history.push({
    skill: skillName,
    started_at_ms: startedAtMs,
    session_id: sessionId,
    autofire_resolved: false,
  });
  // Cap history to last HISTORY_MAX entries
  while (history.length > HISTORY_MAX) history.shift();

  const state = {
    current_skill: skillName,
    started_at_ms: startedAtMs,
    ttl_ms: STATE_TTL_MS,
    session_id: sessionId,
    history,
  };

  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf8');
  } catch {
    // best-effort — never block on tracking-state failure
  }

  process.exit(0);
}

main().catch(() => process.exit(0));
