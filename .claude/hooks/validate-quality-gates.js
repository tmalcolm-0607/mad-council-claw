#!/usr/bin/env node
/**
 * Validates that quality gate failures are properly addressed.
 *
 * Purpose: Enforce test-failure-protocol.md by detecting dismissive language
 * Trigger: SubagentStop after code-implementer completes
 *
 * This hook analyzes agent output files to detect when failures are dismissed
 * as "pre-existing" or "not our problem" without proper action.
 *
 * Redesigned for file-based detection (stdin protocol compatible).
 */

const fs = require('fs');
const path = require('path');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

const REPO_ROOT = path.resolve(__dirname, '..', '..');

/**
 * MAD-artifact-presence gate (iter1-F2):
 * Block phase commits when specs/<M>-lens-dcs-p<N>/{spec,plan,tasks,test-plan}.md
 * is missing on any LENS-DCS phase worktree branch.
 *
 * Trigger shape: PreToolUse Bash event with a `git commit` command, executed
 * inside (or with cwd at) a phase worktree, OR a command that explicitly cd's
 * to a LENS-DCS phase worktree.
 *
 * Returns { block: bool, reason: string|null }.
 */
function checkMadArtifactPresence(toolUse) {
  // Feature flag (default ON)
  const flag = process.env.MAD_ARTIFACT_GATE_ENABLED;
  if (flag === 'false' || flag === '0') {
    return { block: false, reason: null };
  }

  // Only PreToolUse Bash with a `git commit` is relevant here. SubagentStop
  // events don't carry a tool_input.command; bail out for those.
  const command = toolUse?.tool_input?.command || '';
  if (!command) {
    return { block: false, reason: null };
  }
  // Match `git commit ...`, including `git -C <path> commit ...` and
  // `git -c <key>=<val> commit ...` forms.
  // Avoid matching `git commit --dry-run` and `git commit -h`/`--help`.
  const gitCommitRe = /^\s*git(?:\s+-[Cc]\s+\S+)*\s+commit\b/;
  if (!gitCommitRe.test(command)) {
    return { block: false, reason: null };
  }
  if (/\bcommit\b[^|;&]*?(--dry-run|--help|\s-h(?:\s|$))/.test(command)) {
    return { block: false, reason: null };
  }

  // Determine the phase number. Prefer cwd-based detection; fall back to a
  // phase token in the command string.
  // Path patterns: references/LENS-DCS-p1 .. p6 (forward or backslashes).
  const cwd = (toolUse?.cwd || process.cwd()).replace(/\\/g, '/');
  const cmdNorm = command.replace(/\\/g, '/');

  let phaseN = null;
  const cwdMatch = cwd.match(/references\/LENS-DCS-p([1-6])(?:\/|$)/);
  if (cwdMatch) {
    phaseN = parseInt(cwdMatch[1], 10);
  }
  if (phaseN === null) {
    const cmdMatch = cmdNorm.match(/references\/LENS-DCS-p([1-6])(?:\/|\s|$)/);
    if (cmdMatch) phaseN = parseInt(cmdMatch[1], 10);
  }
  if (phaseN === null) {
    // Phase branch name pattern (e.g., commits made via git -C from elsewhere).
    const branchMatch = cmdNorm.match(/users\/tonym\/lens-standardization-p([1-6])\b/);
    if (branchMatch) phaseN = parseInt(branchMatch[1], 10);
  }

  if (phaseN === null) {
    // Not a LENS-DCS phase commit — no-op.
    return { block: false, reason: null };
  }

  // Locate specs/<M>-lens-dcs-p<N>/ for some integer M.
  const specsDir = path.join(REPO_ROOT, 'specs');
  const required = ['spec.md', 'plan.md', 'tasks.md', 'test-plan.md'];
  const phaseSlug = `lens-dcs-p${phaseN}`;

  let phaseDir = null;
  if (fs.existsSync(specsDir)) {
    const entries = fs.readdirSync(specsDir, { withFileTypes: true });
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      // Match `<M>-lens-dcs-p<N>` where M is one or more digits.
      const m = e.name.match(/^(\d+)-lens-dcs-p([1-6])$/);
      if (m && parseInt(m[2], 10) === phaseN) {
        phaseDir = path.join(specsDir, e.name);
        break;
      }
    }
  }

  if (!phaseDir) {
    return {
      block: true,
      reason: `Phase P${phaseN} commit blocked - missing MAD artifact(s): ${required.join(', ')} (no specs/<M>-${phaseSlug}/ directory exists). Run /mad-spec -> /mad-plan -> /mad-tasks -> /testplan first.`
    };
  }

  const missing = required.filter(f => !fs.existsSync(path.join(phaseDir, f)));
  if (missing.length > 0) {
    return {
      block: true,
      reason: `Phase P${phaseN} commit blocked - missing MAD artifact(s): ${missing.join(', ')} (in ${path.relative(REPO_ROOT, phaseDir).replace(/\\/g, '/')}). Run /mad-spec -> /mad-plan -> /mad-tasks -> /testplan first.`
    };
  }

  return { block: false, reason: null };
}

/**
 * Read JSON input from stdin
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Dismissive patterns that violate test failure protocol
 */
const DISMISSIVE_PATTERNS = [
  /pre-existing.*failures?.*unrelated to our changes/i,
  /not related to our changes/i,
  /these are all pre-existing/i,
  /not our problem/i,
  /failures?.*existed before we started/i,
  /\d+\s+failures?.*pre-existing.*unrelated/i,
  /our \d+ (new )?tests? (all )?passed/i, // Only reporting new tests passing
];

/**
 * Patterns indicating proper failure handling (should NOT warn)
 */
const PROPER_HANDLING_PATTERNS = [
  /created tracking (bug|spec):/i,
  /fixed in commit/i,
  /added skip (attributes?|logic)/i,
  /all regressions fixed/i,
  /analysis:/i, // Detailed analysis section
];

/**
 * Check agent output files for dismissive patterns
 */
function checkAgentOutput(workItemId) {
  const artifactsDir = path.join(process.cwd(), '.claude', 'work-items', workItemId, 'artifacts');

  if (!fs.existsSync(artifactsDir)) {
    return { hasDismissive: false };
  }

  // Check implementation log
  const logPath = path.join(artifactsDir, 'implementation-log.md');
  const gateResultsPath = path.join(artifactsDir, 'gate-results.txt');

  const filesToCheck = [logPath, gateResultsPath].filter(p => fs.existsSync(p));

  if (filesToCheck.length === 0) {
    return { hasDismissive: false };
  }

  for (const filePath of filesToCheck) {
    const content = fs.readFileSync(filePath, 'utf8');

    // Check if failures are mentioned
    const hasFailures = /failed:\s+\d+|failures?:\s+\d+|\d+\s+failed/i.test(content);

    if (!hasFailures) {
      continue; // No failures mentioned, skip this file
    }

    // Check for proper handling first
    const hasProperHandling = PROPER_HANDLING_PATTERNS.some(p => p.test(content));

    if (hasProperHandling) {
      continue; // Proper protocol followed, no warning needed
    }

    // Check for dismissive patterns
    const hasDismissive = DISMISSIVE_PATTERNS.some(p => p.test(content));

    if (hasDismissive) {
      return {
        hasDismissive: true,
        file: filePath,
        content: content.substring(0, 500) // First 500 chars for context
      };
    }
  }

  return { hasDismissive: false };
}

/**
 * Main hook logic
 */
async function main() {
  try {
    // Self-check mode: smoke-test the hook without stdin (used by Lane 4 verification).
    if (process.argv.includes('--self-check')) {
      // Exercise checkMadArtifactPresence with a synthetic event that should NOT block
      // (no git-commit command).
      const r1 = checkMadArtifactPresence({ tool_input: { command: 'echo hello' } });
      if (r1.block) {
        console.error('[self-check] FAIL: non-commit command unexpectedly blocked');
        process.exit(1);
      }
      // Synthetic phase-commit event that SHOULD block when specs/ is empty.
      const r2 = checkMadArtifactPresence({
        tool_input: { command: 'git -C references/LENS-DCS-p2 commit -m "test"' }
      });
      // Block result depends on whether specs/2-lens-dcs-p2/ exists; both
      // outcomes are valid for a smoke test, but the function must return a shape.
      if (typeof r2.block !== 'boolean') {
        console.error('[self-check] FAIL: checkMadArtifactPresence returned invalid shape');
        process.exit(1);
      }
      console.log('[self-check] OK');
      process.exit(0);
    }

    const input = await readStdin();
    const data = JSON.parse(input);

    // (iter1-F2) MAD-artifact-presence gate: short-circuit on PreToolUse Bash
    // events for `git commit` against a LENS-DCS phase worktree.
    const madGate = checkMadArtifactPresence(data);
    if (madGate.block) {
      console.error('');
      console.error('[MAD-ARTIFACT-GATE] ' + madGate.reason);
      console.error('');
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason: madGate.reason
        }
      }));
      process.exit(0);
    }

    // This hook runs on SubagentStop events
    // We don't need to validate the event type - just check the work item

    // Get active work item (session-aware resolution for worktree support)
    const { wiId: workItemId } = resolveActiveWI(data, process.cwd());

    if (!workItemId) {
      // No active work item, nothing to check
      process.exit(0);
    }

    // Check for dismissive patterns in agent output
    const result = checkAgentOutput(workItemId);

    if (result.hasDismissive) {
      // Emit warning to stderr
      console.error('');
      console.error('❌ TEST FAILURE PROTOCOL VIOLATION');
      console.error('');
      console.error('Found test failures dismissed as "pre-existing" or "not our problem".');
      console.error('');
      console.error('ALL test failures discovered during your work are YOUR responsibility.');
      console.error('');
      console.error('Required actions:');
      console.error('1. Categorize failures (regression vs pre-existing)');
      console.error('2. For regressions: Fix immediately');
      console.error('3. For pre-existing: Fix, track via spec, or add skip logic');
      console.error('4. Report what action was taken');
      console.error('');
      console.error('See .claude/rules/test-failure-protocol.md for details.');
      console.error('');
      console.error(`Detected in: ${result.file}`);
      console.error('');

      // Currently fail-open (allow operation to continue)
      // Will be converted to fail-closed in Phase 1 Task 1.6
      process.exit(0);
    }

    // No violations found
    process.exit(0);

  } catch (error) {
    // Hook error - fail-open (currently, will be fail-closed in Phase 1 Task 1.6)
    console.error('[validate-quality-gates] Hook error (non-blocking):', error.message);
    process.exit(0);
  }
}

main().catch(() => process.exit(0));
