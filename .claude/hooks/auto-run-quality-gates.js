#!/usr/bin/env node

/**
 * auto-run-quality-gates.js
 *
 * Purpose: Automatically execute quality gates when a phase completes in plan.md.
 *
 * Event: PostToolUse (Write|Edit) - triggers after plan.md is written/edited
 * Behavior: Non-blocking. Detects phase completion markers and runs quality gates.
 *           Reports results as conversation context (additionalContext).
 *
 * Detection:
 *   - Phase completion: /Phase \d+.*COMPLETE/i or /\[x\]\s*Phase/i
 *   - Only triggers on plan.md files (matches *plan*.md)
 *
 * Execution:
 *   - Runs: powershell -File .claude/scripts/Run-DotnetGates.ps1
 *   - Timeout: 5 minutes (300,000ms)
 *   - Captures stdout+stderr for reporting
 *
 * Cooldown:
 *   - 60-second cooldown per phase to prevent re-triggering on minor edits
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Cooldown tracking: phaseKey -> timestamp
const COOLDOWN_FILE = path.join(__dirname, '..', '..', '.mad', 'scratch', 'quality-gates-cooldown.json');
const GATES_LAST_RUN_FILE = path.join(__dirname, '..', '..', '.mad', 'scratch', 'gates-last-run.json');
const COOLDOWN_SECONDS = 60;

/**
 * Read JSON from stdin (Claude Code hook protocol)
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Get the project root directory
 */
function getProjectDir() {
  return process.env.CLAUDE_PROJECT_DIR || process.cwd();
}

/**
 * Detect whether projectDir contains any .sln or .csproj files at the root.
 * Returns true if a .NET shape is detected (a build target exists), false
 * for kit / spec-only repos where Run-DotnetGates.ps1 has nothing to build.
 *
 * Added 2026-05-02 per iter15-hook-misfire fix (plan-backlog Entry 9).
 */
function hasDotnetBuildTarget(projectDir) {
  try {
    const entries = fs.readdirSync(projectDir);
    return entries.some(name => {
      const lower = name.toLowerCase();
      return lower.endsWith('.sln') || lower.endsWith('.csproj');
    });
  } catch {
    // Unreadable projectDir -- fall through to "no build target" so we
    // skip cleanly rather than crash the runner.
    return false;
  }
}

/**
 * Doc-only file extensions. When a plan.md edit references only these
 * extensions in its diff, the gate runner has nothing to do.
 */
const DOC_ONLY_EXTENSIONS = new Set(['.md', '.json', '.yml', '.yaml', '.txt']);

/**
 * Determine if the triggering edit is doc-only based on the file_path that
 * fired this hook. Plan.md edits ARE doc-only by definition; this helper
 * exists to keep the gate from running unnecessarily on pure-prose changes
 * even on .NET-shaped repos.
 *
 * Added 2026-05-02 per iter15-hook-misfire fix (plan-backlog Entry 9).
 */
function isDocOnlyEdit(filePath) {
  if (!filePath) return false;
  const ext = path.extname(filePath).toLowerCase();
  return DOC_ONLY_EXTENSIONS.has(ext);
}

/**
 * Detect completed phases from plan.md content.
 * Returns array of phase identifiers found.
 */
function detectCompletedPhases(content) {
  const phases = [];

  // Pattern 1: "Phase N: Description ... COMPLETE" (case-insensitive)
  const completePattern = /Phase\s+(\d+(?:\.\d+)?)[^:\n]*:?[^\n]*COMPLETE/gi;
  let match;
  while ((match = completePattern.exec(content)) !== null) {
    phases.push(`phase-${match[1]}`);
  }

  // Pattern 2: "[x] Phase N" or "[x] **Phase N**" checkbox completion
  const checkboxPattern = /\[x\]\s+\*{0,2}Phase\s+(\d+(?:\.\d+)?)/gi;
  while ((match = checkboxPattern.exec(content)) !== null) {
    phases.push(`phase-${match[1]}`);
  }

  // Deduplicate
  return [...new Set(phases)];
}

/**
 * Load cooldown state from disk
 */
function loadCooldownState() {
  try {
    if (fs.existsSync(COOLDOWN_FILE)) {
      return JSON.parse(fs.readFileSync(COOLDOWN_FILE, 'utf-8'));
    }
  } catch {
    // Corrupted state, reset
  }
  return {};
}

/**
 * Save cooldown state to disk
 */
function saveCooldownState(state) {
  try {
    const dir = path.dirname(COOLDOWN_FILE);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(COOLDOWN_FILE, JSON.stringify(state, null, 2), 'utf-8');
  } catch {
    // Non-critical, ignore
  }
}

/**
 * Filter phases that are within cooldown period
 */
function filterCooldownPhases(phases) {
  const state = loadCooldownState();
  const now = Date.now();
  const newPhases = [];

  for (const phase of phases) {
    const lastRun = state[phase] || 0;
    const elapsed = (now - lastRun) / 1000;
    if (elapsed >= COOLDOWN_SECONDS) {
      newPhases.push(phase);
    }
  }

  return newPhases;
}

/**
 * Update cooldown state for phases that were processed
 */
function markPhasesProcessed(phases) {
  const state = loadCooldownState();
  const now = Date.now();
  for (const phase of phases) {
    state[phase] = now;
  }
  saveCooldownState(state);
}

/**
 * Execute quality gates and capture output
 */
function runQualityGates(projectDir) {
  const scriptPath = path.join(projectDir, '.mad', 'scripts', 'Run-DotnetGates.ps1');

  if (!fs.existsSync(scriptPath)) {
    return {
      success: false,
      output: `Quality gates script not found: ${scriptPath}`,
      exitCode: -1,
    };
  }

  try {
    const output = execSync(
      `powershell -File "${scriptPath}"`,
      {
        cwd: projectDir,
        encoding: 'utf-8',
        timeout: 300000, // 5 minutes
        stdio: ['pipe', 'pipe', 'pipe'],
        maxBuffer: 1024 * 1024, // 1MB buffer
      }
    );

    return {
      success: true,
      output: output || '(no output)',
      exitCode: 0,
    };
  } catch (error) {
    // execSync throws on non-zero exit
    const stdout = error.stdout || '';
    const stderr = error.stderr || '';
    const combined = [stdout, stderr].filter(Boolean).join('\n');

    return {
      success: false,
      output: combined || error.message,
      exitCode: error.status || 1,
    };
  }
}

/**
 * Format gate results for conversation display
 */
function formatGateOutput(phases, gateResult) {
  const status = gateResult.success ? 'PASSED' : 'FAILED';
  const icon = gateResult.success ? '[PASS]' : '[FAIL]';

  // Truncate output to avoid bloating conversation context
  const maxOutputLength = 2000;
  let output = gateResult.output;
  if (output.length > maxOutputLength) {
    output = output.slice(0, maxOutputLength) + '\n... (truncated)';
  }

  const phaseList = phases.map(p => p.replace('phase-', 'Phase ')).join(', ');

  return `${icon} Auto Quality Gates - ${status}
Triggered by: ${phaseList} completion
Exit code: ${gateResult.exitCode}

${output}`;
}

// --- Main ---

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Extract file path from tool input
    const filePath = data.tool_input?.file_path || '';
    if (!filePath) {
      process.exit(0);
    }

    // Only process plan.md files
    const baseName = path.basename(filePath).toLowerCase();
    if (!baseName.endsWith('.md') || !baseName.includes('plan')) {
      process.exit(0);
    }

    // Read the actual file content from disk
    let content;
    try {
      content = fs.readFileSync(filePath, 'utf-8');
    } catch {
      process.exit(0);
    }

    if (!content || content.length === 0) {
      process.exit(0);
    }

    // Detect completed phases
    const allPhases = detectCompletedPhases(content);
    if (allPhases.length === 0) {
      process.exit(0);
    }

    // Filter out phases still in cooldown
    const newPhases = filterCooldownPhases(allPhases);
    if (newPhases.length === 0) {
      // All detected phases are within cooldown, skip
      process.exit(0);
    }

    // Mark phases as processed before running (prevents re-entry)
    markPhasesProcessed(newPhases);

    const projectDir = getProjectDir();

    // --- Pre-gate skip checks (iter15-hook-misfire fix, 2026-05-02) ---
    // Belt-and-suspenders: Run-DotnetGates.ps1 also exits 0 with a skip
    // message when no .sln/.csproj is present. We pre-empt the spawn here
    // so the noise doesn't show up at all in the conversation context.

    // Skip 1: doc-only edits never need .NET gates.
    if (isDocOnlyEdit(filePath)) {
      console.error(
        '[auto-run-quality-gates] Skipping: implementer diff is doc-only.'
      );
      process.exit(0);
    }

    // Skip 2: kit / spec-only repos (no .sln, no .csproj at root) have no
    // .NET build target. The gate runner exits 0 with a skip message in
    // this case anyway; pre-empting saves the powershell spawn cost and
    // keeps conversation context clean.
    if (!hasDotnetBuildTarget(projectDir)) {
      console.error(
        '[auto-run-quality-gates] Skipping: kit/spec-only repo (no .sln/.csproj at root).'
      );
      process.exit(0);
    }

    // Run quality gates
    console.error(`[auto-quality-gates] Running quality gates for: ${newPhases.join(', ')}`);
    const gateResult = runQualityGates(projectDir);

    // Write gate-status timestamp on successful completion
    if (gateResult.success) {
      try {
        const dir = path.dirname(GATES_LAST_RUN_FILE);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        const now = Math.floor(Date.now() / 1000);
        fs.writeFileSync(GATES_LAST_RUN_FILE, JSON.stringify({
          timestamp: now,
          date: new Date(now * 1000).toISOString(),
        }, null, 2), 'utf-8');
      } catch {
        // Non-critical, ignore
      }
    }

    // Format output for conversation
    const formattedOutput = formatGateOutput(newPhases, gateResult);
    console.error(`[auto-quality-gates] ${gateResult.success ? 'Gates passed' : 'Gates failed'}`);

    // Output as additionalContext so Claude sees the result
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: formattedOutput,
      },
    }));

    // Always exit 0 - this hook is advisory, not blocking
    process.exit(0);
  } catch (error) {
    // Hook error - fail-open (advisory hook)
    console.error('[auto-run-quality-gates] FATAL ERROR:', error.message);
    console.error('[auto-run-quality-gates] Hook failed - continuing (advisory).');
    process.exit(0);
  }
}

// Export for testing
module.exports = {
  detectCompletedPhases,
  filterCooldownPhases,
  formatGateOutput,
  runQualityGates,
  hasDotnetBuildTarget,
  isDocOnlyEdit,
  DOC_ONLY_EXTENSIONS,
  COOLDOWN_SECONDS,
};

// Run if executed directly
if (require.main === module) {
  main();
}
