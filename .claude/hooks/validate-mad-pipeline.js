#!/usr/bin/env node
/**
 * Hook: PreToolUse (Write|Edit)
 * Purpose: BLOCK direct Writes AND Edits to MAD artifacts (spec.md / plan.md /
 *          tasks.md / analysis-report.md / test-plan.md) unless the corresponding
 *          /mad-* skill is currently being invoked.
 *
 * Why: Authoring MAD artifacts inline (without invoking the skill that
 *      enforces gates around them) bypasses critical discipline:
 *      - implementability checks
 *      - agent-team review
 *      - completeness oracle
 *      - dependency analysis
 *      - parallel-task ordering
 *
 *      Each session that writes MAD artifacts directly produces a degraded
 *      version of what the skill would produce, and the user has flagged
 *      this as a recurring anti-pattern.
 *
 *      Iter1-41 of the collab-engine session, the Edit-loophole was the escape
 *      hatch every cascade took (iter 15/19/21/23 plan.md edits, iter 16/19/21/23
 *      tasks.md edits, iter 17/25 analysis-report.md edits — all via Edit). The
 *      "for typo fixes etc." rationale doesn't survive contact with subagents
 *      that frame multi-page rewrites as "edits". This hook now blocks Edit too.
 *
 * Mechanism:
 *   1. Companion hook (track-mad-skill-invocation.js, PreToolUse:Skill) writes
 *      .mad/scratch/mad-pipeline-active.json when /mad-* is invoked.
 *   2. This hook checks: when Write OR Edit targets a MAD artifact, is the
 *      matching /mad-* skill currently active? If yes, allow. If no, BLOCK with
 *      a message pointing at the right /mad-* skill.
 *
 * Allowed (does NOT block):
 *   - Write or Edit to non-MAD-artifact paths
 *   - Write or Edit while the matching /mad-* skill is active (TTL 30 min)
 *   - Write or Edit while /mad-implement, /mad-validate, /mad-full,
 *     /mad-decompose, or /mad-parallel is active (those legitimately write
 *     multiple MAD artifacts)
 *
 * Blocked (decision: deny):
 *   - Write OR Edit to specs/<N>-<feature>/spec.md without /mad-spec active
 *   - Write OR Edit to specs/<N>-<feature>/plan.md without /mad-plan active
 *   - Write OR Edit to specs/<N>-<feature>/tasks.md without /mad-tasks active
 *   - Write OR Edit to specs/<N>-<feature>/analysis-report.md without /mad-analyze active
 *   - Write OR Edit to specs/<N>-<feature>/test-plan.md without /testplan active
 *
 * Override (escape hatches):
 *   - Set MAD_PIPELINE_HOOK_DISABLED=true in .claude/settings.local.json
 *     env block — bypasses this hook entirely (not recommended).
 *   - Invoke the matching /mad-* skill first, which sets the state file and
 *     allows subsequent Writes/Edits during the skill's lifetime.
 *   - Single-line typo fixes: there is no exemption — invoke the skill. The
 *     "Edit-allowed-for-typos" loophole was the source of iter1-41 failures.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const STATE_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'mad-pipeline-active.json');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');

// MAD-artifact path pattern → required skill name
// Pattern: any path ending with /specs/<N>-<feature>/<artifact>.md
const ARTIFACT_PATTERNS = [
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]spec\.md$/i,             skill: 'mad-spec'    },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]plan\.md$/i,             skill: 'mad-plan'    },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]tasks\.md$/i,            skill: 'mad-tasks'   },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]analysis-report\.md$/i,  skill: 'mad-analyze' },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]test-plan\.md$/i,        skill: 'testplan'    },
];

// Skills that legitimately write any artifact under specs/<N>/ during their body
const MULTI_ARTIFACT_SKILLS = new Set([
  'mad-implement',
  'mad-validate',
  'mad-full',
  'mad-decompose',
  'mad-parallel',
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

function isHookDisabled() {
  try {
    const raw = fs.readFileSync(SETTINGS_LOCAL, 'utf8');
    const parsed = JSON.parse(raw);
    const env = (parsed && parsed.env) || {};
    const flag = env.MAD_PIPELINE_HOOK_DISABLED;
    if (typeof flag === 'string') {
      return flag === 'true' || flag === '1';
    }
    return flag === true;
  } catch {
    return false;
  }
}

function readActiveState() {
  try {
    const raw = fs.readFileSync(STATE_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return null;
    if (!parsed.current_skill) return null;
    if (typeof parsed.started_at_ms !== 'number') return null;
    const ttl = typeof parsed.ttl_ms === 'number' ? parsed.ttl_ms : 30 * 60 * 1000;
    if (Date.now() - parsed.started_at_ms > ttl) return null; // expired
    return parsed;
  } catch {
    return null;
  }
}

function matchArtifact(filePath) {
  if (!filePath || typeof filePath !== 'string') return null;
  for (const entry of ARTIFACT_PATTERNS) {
    if (entry.regex.test(filePath)) return entry;
  }
  return null;
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

  // This hook is registered for Write|Edit. Act on both — Edit was the loophole
  // every cascade in iter1-41 took (claiming "typo fix" while rewriting multi-page artifacts).
  const toolName = payload.tool_name || payload.toolName;
  if (toolName && toolName !== 'Write' && toolName !== 'Edit') {
    process.exit(0);
  }

  if (isHookDisabled()) {
    process.exit(0);
  }

  const toolInput = payload.tool_input || payload.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';
  const artifactMatch = matchArtifact(filePath);
  if (!artifactMatch) {
    process.exit(0); // Not a MAD artifact — allow.
  }

  const active = readActiveState();
  if (active) {
    if (active.current_skill === artifactMatch.skill) {
      process.exit(0); // Right skill is running.
    }
    if (MULTI_ARTIFACT_SKILLS.has(active.current_skill)) {
      process.exit(0); // Implement / validate / full / decompose can write any artifact.
    }
  }

  // BLOCK
  const message =
    `BLOCKED: Direct Write to MAD artifact ${path.basename(filePath)} ` +
    `without /${artifactMatch.skill} skill being invoked.\n\n` +
    `MAD artifacts must be authored via their corresponding skill so the gates\n` +
    `around them (implementability checks, agent-team review, completeness\n` +
    `oracle, dependency analysis) actually run. Authoring inline produces a\n` +
    `degraded version of what the skill would produce.\n\n` +
    `Required action: invoke /${artifactMatch.skill} via the Skill tool.\n` +
    `The skill body will write the artifact correctly during its execution.\n\n` +
    `Other allowed paths:\n` +
    `  - Use Edit (not Write) for incremental updates / typo fixes.\n` +
    `  - Invoke /mad-implement, /mad-validate, /mad-full, /mad-decompose, or\n` +
    `    /mad-parallel — those skills legitimately write multiple artifacts.\n` +
    `  - In an emergency, set MAD_PIPELINE_HOOK_DISABLED=true in\n` +
    `    .claude/settings.local.json env block (NOT recommended).\n\n` +
    `Why this hook exists: see .claude/rules/canonical-skill-only.md and\n` +
    `.claude/rules/non-negotiable-rules.md (MAD-pipeline enforcement rule).`;

  // Hook protocol: writing JSON to stdout with permissionDecision: 'deny' blocks the tool.
  const decision = {
    permissionDecision: 'deny',
    permissionDecisionReason: message,
  };
  process.stdout.write(JSON.stringify(decision));
  process.exit(0);
}

main().catch((err) => {
  // Never block on hook crash — fail open.
  process.stderr.write(`[validate-mad-pipeline] internal error: ${err && err.message}\n`);
  process.exit(0);
});
