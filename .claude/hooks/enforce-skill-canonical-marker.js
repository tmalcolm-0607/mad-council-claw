#!/usr/bin/env node
/**
 * Hook: PostToolUse (Write|Edit) on MAD artifacts
 * Purpose: Verify that every spec/plan/tasks/analysis-report/test-plan written
 *          to disk carries the canonical frontmatter signature
 *          (generated-by, generated-by-version, skill-state-file-id). When
 *          missing, append a flag to .mad/scratch/canonical-marker-flags.json.
 *
 * Why: Iter1-41, code-investigator and code-implementer subagents emulated the
 *      MAD skill bodies and wrote artifacts directly. Inline-authored artifacts
 *      lacked the canonical signature, but no detector existed to surface this
 *      —the orchestrator and downstream consumers couldn't tell a canonical
 *      /mad-plan output from a hand-rolled emulation. This hook makes the
 *      distinction visible and feeds validate-artifact-completeness.js.
 *
 * Mechanism:
 *   1. On PostToolUse:Write|Edit, check whether file_path matches a MAD
 *      artifact pattern (specs/<N>-<feature>/{spec,plan,tasks,analysis-report,
 *      test-plan}.md).
 *   2. Read the written file from disk.
 *   3. Look for YAML frontmatter with the three required keys:
 *        generated-by:        /mad-spec | /mad-plan | /mad-tasks |
 *                             /mad-analyze | /testplan
 *        generated-by-version: <semver>
 *        skill-state-file-id:  <session-id-or-state-hash>
 *   4. If any key missing or malformed, append to canonical-marker-flags.json.
 *
 * Allowed (does NOT flag):
 *   - The MAD pipeline state file showed the matching skill active when the
 *     write happened (skill body is mid-execution; signature may not be
 *     written yet — re-checked at SubagentStop).
 *   - The artifact was Edit'd minimally and signature already present.
 *
 * Override:
 *   - Set CANONICAL_MARKER_HOOK_DISABLED=true in settings.local.json env.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const FLAG_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'canonical-marker-flags.json');

const ARTIFACT_PATTERNS = [
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]spec\.md$/i,             skill: 'mad-spec' },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]plan\.md$/i,             skill: 'mad-plan' },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]tasks\.md$/i,            skill: 'mad-tasks' },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]analysis-report\.md$/i,  skill: 'mad-analyze' },
  { regex: /[\\/]specs[\\/][^\\/]+[\\/]test-plan\.md$/i,        skill: 'testplan' },
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
    const flag = env.CANONICAL_MARKER_HOOK_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function matchArtifact(filePath) {
  if (!filePath || typeof filePath !== 'string') return null;
  for (const entry of ARTIFACT_PATTERNS) {
    if (entry.regex.test(filePath)) return entry;
  }
  return null;
}

function extractFrontmatter(content) {
  if (typeof content !== 'string') return null;
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const block = m[1];
  const fields = {};
  for (const line of block.split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z0-9_-]+)\s*:\s*(.+?)\s*$/);
    if (kv) fields[kv[1].toLowerCase()] = kv[2];
  }
  return fields;
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
    // Best-effort
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
  if (toolName !== 'Write' && toolName !== 'Edit') process.exit(0);

  if (isHookDisabled()) process.exit(0);

  const toolInput = payload.tool_input || payload.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';
  const artifactMatch = matchArtifact(filePath);
  if (!artifactMatch) process.exit(0);

  // Read the file from disk (Edit: post-edit state; Write: just-written content)
  let content = '';
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch {
    // File can't be read — best-effort; skip
    process.exit(0);
  }

  const fm = extractFrontmatter(content);
  const issues = [];

  if (!fm) {
    issues.push('no YAML frontmatter');
  } else {
    const generatedBy = fm['generated-by'];
    const expectedSkill = `/${artifactMatch.skill}`;
    if (!generatedBy) {
      issues.push('missing generated-by');
    } else if (!generatedBy.includes(artifactMatch.skill)) {
      issues.push(`generated-by="${generatedBy}" does not match expected ${expectedSkill}`);
    }
    if (!fm['generated-by-version']) issues.push('missing generated-by-version');
    if (!fm['skill-state-file-id']) issues.push('missing skill-state-file-id');
  }

  if (issues.length === 0) process.exit(0);

  appendFlag({
    timestamp: new Date().toISOString(),
    file: filePath,
    expected_skill: `/${artifactMatch.skill}`,
    issues,
    tool: toolName,
  });

  process.stderr.write(
    `[enforce-skill-canonical-marker] ${path.basename(filePath)} lacks canonical signature: ` +
      issues.join(', ') +
      `\n  Expected frontmatter from /${artifactMatch.skill} skill body.\n` +
      `  Flag recorded at .mad/scratch/canonical-marker-flags.json — SubagentStop will block completion if unanswered.\n`
  );
  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[enforce-skill-canonical-marker] internal error: ${err && err.message}\n`);
  process.exit(0);
});
