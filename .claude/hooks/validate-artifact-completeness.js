#!/usr/bin/env node
/**
 * Hook: SubagentStop / Stop
 * Purpose: Block subagent completion when any of the antipattern flag files
 *          contain unresolved entries, OR when a spec.md was written this
 *          session without a sibling test-plan.md.
 *
 * Why: PostToolUse hooks (content-scan-deferrals, enforce-skill-canonical-marker,
 *      detect-top-n-capping) record violations to flag files but cannot block
 *      the original Write/Edit/Task call. SubagentStop is the choke point —
 *      a subagent claiming "done" must clear all flags first OR mark them
 *      acknowledged. Otherwise the iter1-41 pattern repeats: violations land
 *      on disk, subagent reports success, user has to flag manually.
 *
 * Flag files watched:
 *   - .mad/scratch/deferral-flags.json
 *   - .mad/scratch/canonical-marker-flags.json
 *   - .mad/scratch/top-n-cap-flags.json
 *   - .mad/scratch/missing-testplan-flags.json   (computed here)
 *   - .mad/scratch/missing-autofire-flags.json   (written by track-mad-skill-invocation)
 *
 * Mechanism:
 *   1. On SubagentStop, read every flag file.
 *   2. For each flag entry, check if record has acknowledged: true OR
 *      acknowledged_by_user: true. If not, count as live violation.
 *   3. Compute test-plan presence: for each new spec.md modified this session
 *      (via stop_hook payload session_state.modified_files if available, or
 *      git ls-files listing), check whether the sibling test-plan.md exists.
 *   4. If any live violations: emit { decision: "block", reason: "..." }.
 *
 * Acknowledging a flag (clearing it for completion):
 *   - The orchestrator persists the flag with `acknowledged: true` after user
 *     discussion, OR removes it entirely. The hook accepts either.
 *
 * Override:
 *   - Set ARTIFACT_COMPLETENESS_HOOK_DISABLED=true in settings.local.json.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const SCRATCH_DIR = path.join(REPO_ROOT, '.mad', 'scratch');

const FLAG_FILES = [
  { name: 'deferrals',          file: 'deferral-flags.json' },
  { name: 'canonical-markers',  file: 'canonical-marker-flags.json' },
  { name: 'top-n-caps',         file: 'top-n-cap-flags.json' },
  { name: 'missing-autofires',  file: 'missing-autofire-flags.json' },
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
    const flag = env.ARTIFACT_COMPLETENESS_HOOK_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function readFlagFile(fileName) {
  const p = path.join(SCRATCH_DIR, fileName);
  try {
    const raw = fs.readFileSync(p, 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function unacknowledgedCount(flags, currentSessionId) {
  // Only count flags from the CURRENT session as blocking. Flags from other
  // sessions (or legacy flags without a session_id stamp) belong to a
  // different work-item context and must not block this session's Stop.
  // Producer-side stamping was added in `content-scan-deferrals.js` after
  // user feedback: "We should not be stopped by flags from other sessions.
  // unrelated to the current workitem. it should flag in those sessions"
  return flags.filter(
    (f) =>
      !f.acknowledged &&
      !f.acknowledged_by_user &&
      currentSessionId &&
      f.session_id === currentSessionId
  ).length;
}

function getSessionStartMs(payload) {
  // Derive session start time so the orphan-spec scan only fires on specs
  // THIS session modified. Without this scoping, any session within 24h of
  // an orphan spec from a different work-item gets blocked (disrupted iter 5
  // multi-model verification per loop retros).
  //
  // Source: transcript file's birthtime = session start. Stop / SubagentStop
  // hooks receive `transcript_path` in their payload per Claude Code docs.
  // Fail-open (return null) if unavailable — better to miss an orphan than
  // to block on cross-session state.
  const transcriptPath = payload && (payload.transcript_path || payload.transcriptPath);
  if (!transcriptPath) return null;
  try {
    const stats = fs.statSync(transcriptPath);
    // birthtimeMs is reliable on NTFS (Windows) and APFS (macOS); on some
    // ext4 setups birthtime is 0. Treat 0 / NaN as "unknown".
    const start = stats.birthtimeMs || 0;
    return start > 0 ? start : null;
  } catch {
    return null;
  }
}

function readSpecSessionId(specPath) {
  // Read the spec.md's frontmatter `skill-state-file-id` (set by /mad-spec at
  // canonical-frontmatter write time). Returns null if frontmatter absent or
  // field missing. Cheap: reads first 1KB only.
  try {
    const fd = fs.openSync(specPath, 'r');
    const buf = Buffer.alloc(1024);
    const n = fs.readSync(fd, buf, 0, 1024, 0);
    fs.closeSync(fd);
    const head = buf.slice(0, n).toString('utf8');
    const m = head.match(/^skill-state-file-id:\s*(\S+)/m);
    return m ? m[1].trim() : null;
  } catch {
    return null;
  }
}

function findOrphanSpecs(sessionStartMs, currentSessionId) {
  // Scan specs/<N>-<feature>/ dirs for spec.md without sibling test-plan.md.
  // SESSION-SCOPED via TWO filters (both must be satisfied to flag):
  //   1. spec.md mtime > sessionStartMs (the file was touched during this session)
  //   2. spec.md frontmatter `skill-state-file-id` matches currentSessionId
  //      (the spec was AUTHORED by this session's /mad-spec invocation,
  //      not by a parallel session whose write happened to overlap).
  //
  // Why both: mtime alone catches cross-session bleedover when a parallel
  // /mad-spec session writes a new spec while this session is running. Wave-20
  // hit this — specs/022-sha256-util was authored by session 967a44fb at the
  // same wall-clock time as our session 176dd866, both passed the mtime filter,
  // and our session got blocked on completing because of an orphan it didn't
  // create. The skill-state-file-id filter resolves it.
  //
  // Fail-open semantics:
  //   - If sessionStartMs is null (no transcript birthtime) → return [] (no flag)
  //   - If currentSessionId is null → fall back to mtime-only (legacy behavior;
  //     better to over-flag than under-flag when session-id is unknown)
  //   - If spec.md has no skill-state-file-id frontmatter → flag (legacy specs
  //     pre-canonical-frontmatter; can't tell which session wrote them, so
  //     conservative-flag is safer than skip)
  if (!sessionStartMs) return []; // fail-open per docstring above
  const specsRoot = path.join(REPO_ROOT, 'specs');
  if (!fs.existsSync(specsRoot)) return [];
  const orphans = [];
  let dirs = [];
  try {
    dirs = fs.readdirSync(specsRoot, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);
  } catch {
    return [];
  }
  for (const dir of dirs) {
    const specPath = path.join(specsRoot, dir, 'spec.md');
    const testPlanPath = path.join(specsRoot, dir, 'test-plan.md');
    if (!fs.existsSync(specPath)) continue;
    let mtime = 0;
    try { mtime = fs.statSync(specPath).mtimeMs; } catch { continue; }
    if (mtime < sessionStartMs) continue; // modified before this session — not our concern
    if (fs.existsSync(testPlanPath)) continue;
    // Skill-state-file-id filter: skip if spec was authored by a different session.
    if (currentSessionId) {
      const specSessionId = readSpecSessionId(specPath);
      if (specSessionId && specSessionId !== currentSessionId) continue;
    }
    orphans.push({ spec_dir: dir, spec_path: specPath, mtime: new Date(mtime).toISOString() });
  }
  return orphans;
}

async function main() {
  let raw = '';
  try {
    raw = await readStdin();
  } catch {
    process.exit(0);
  }

  let payload;
  try {
    payload = raw && raw.trim() ? JSON.parse(raw) : {};
  } catch {
    payload = {};
  }

  if (isHookDisabled()) process.exit(0);

  // Pull current session_id from Stop hook payload; fall back to env. If we
  // can't resolve a session_id at all, the safest behaviour is to NOT block
  // (otherwise hooks fire on every session forever on stale flags).
  const currentSessionId =
    payload.session_id ||
    payload.sessionId ||
    process.env.CLAUDE_SESSION_ID ||
    null;

  const violations = [];

  for (const ff of FLAG_FILES) {
    const flags = readFlagFile(ff.file);
    const liveCount = unacknowledgedCount(flags, currentSessionId);
    if (liveCount > 0) {
      violations.push({
        category: ff.name,
        flag_file: ff.file,
        unacknowledged: liveCount,
        sample:
          flags.find(
            (f) =>
              !f.acknowledged &&
              !f.acknowledged_by_user &&
              currentSessionId &&
              f.session_id === currentSessionId
          ) || null,
      });
    }
  }

  // Recently-modified spec.md without sibling test-plan.md (session-scoped).
  // findOrphanSpecs returns [] if session start can't be determined; that's
  // intentional fail-open behavior — see getSessionStartMs() comment.
  // Pass currentSessionId for skill-state-file-id filtering — prevents
  // cross-session bleedover when a parallel /mad-spec writes during our session.
  const sessionStartMs = getSessionStartMs(payload);
  const orphans = findOrphanSpecs(sessionStartMs, currentSessionId);
  if (orphans.length > 0) {
    violations.push({
      category: 'missing-test-plan',
      flag_file: 'computed-from-disk',
      unacknowledged: orphans.length,
      orphan_specs: orphans,
    });
  }

  if (violations.length === 0) process.exit(0);

  const summary = violations
    .map(
      (v) =>
        `  - [${v.category}] ${v.unacknowledged} unacknowledged flag(s) (file: .mad/scratch/${v.flag_file})`
    )
    .join('\n');

  const message =
    `Artifact-completeness violations detected — completion blocked.\n\n` +
    `${summary}\n\n` +
    `To resolve, choose one for each category:\n` +
    `  (a) Fix the underlying violation (e.g., re-author via canonical skill).\n` +
    `  (b) Acknowledge each flag entry by setting "acknowledged": true after\n` +
    `      explicit user discussion of why the deferral/cap/missing-marker is\n` +
    `      acceptable in this case (per .claude/rules/no-silent-deferrals.md).\n` +
    `  (c) Delete the flag file entries that no longer apply.\n\n` +
    `For missing test plans: run /testplan --source spec on the orphan spec dir.\n\n` +
    `Override (NOT RECOMMENDED — defeats the antipattern detector):\n` +
    `  Set ARTIFACT_COMPLETENESS_HOOK_DISABLED=true in .claude/settings.local.json env.`;

  // SubagentStop / Stop hooks use { decision: "block", reason } shape per CC docs
  const decision = { decision: 'block', reason: message };
  process.stdout.write(JSON.stringify(decision));
  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[validate-artifact-completeness] internal error: ${err && err.message}\n`);
  process.exit(0);
});
