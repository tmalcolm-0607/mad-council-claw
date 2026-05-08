#!/usr/bin/env node
/**
 * Hook: SubagentStop (command type)
 * Purpose: Enforce 200-line cap on baseline extraction files.
 *
 * When a subagent stops, scans for recently-written baseline files in
 * .mad/scratch/review-*/baselines/*.md. If any exceed 200 lines,
 * emits a stderr warning for the orchestrator to handle.
 *
 * Protocol: SubagentStop is advisory — exits 0 always. Emits console.error
 *   warning when baseline exceeded. Cannot block or retry via SubagentStop.
 *   Retry count tracked via .mad/scratch/.retry-{agentId}.count
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const MAX_BASELINE_LINES = 200;
const MAX_RETRIES = 2;
const RECENT_THRESHOLD_MS = 120 * 1000; // 2 minutes

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

function getProjectDir() {
  let dir = process.cwd();
  const root = path.parse(dir).root;
  while (dir !== root) {
    if (fs.existsSync(path.join(dir, '.claude'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

/**
 * Find all review scratch directories
 */
function findReviewDirs(projectDir) {
  const scratchDir = path.join(projectDir, '.mad', 'scratch');
  if (!fs.existsSync(scratchDir)) return [];

  try {
    return fs.readdirSync(scratchDir, { withFileTypes: true })
      .filter(d => d.isDirectory() && d.name.startsWith('review-'))
      .map(d => path.join(scratchDir, d.name));
  } catch {
    return [];
  }
}

/**
 * Find recently-written baseline files across all review directories
 */
function findRecentBaselines(reviewDirs) {
  const now = Date.now();
  const results = [];

  for (const reviewDir of reviewDirs) {
    // Check baselines/ subdirectory
    const baselinesDir = path.join(reviewDir, 'baselines');
    if (fs.existsSync(baselinesDir)) {
      try {
        const files = fs.readdirSync(baselinesDir)
          .filter(f => f.endsWith('.md'));
        for (const file of files) {
          const filePath = path.join(baselinesDir, file);
          try {
            const stats = fs.statSync(filePath);
            if (now - stats.mtimeMs < RECENT_THRESHOLD_MS) {
              results.push(filePath);
            }
          } catch { /* skip */ }
        }
      } catch { /* skip */ }
    }

    // Also check root-level baseline-*.md (legacy pattern)
    try {
      const files = fs.readdirSync(reviewDir)
        .filter(f => f.startsWith('baseline-') && f.endsWith('.md'));
      for (const file of files) {
        const filePath = path.join(reviewDir, file);
        try {
          const stats = fs.statSync(filePath);
          if (now - stats.mtimeMs < RECENT_THRESHOLD_MS) {
            results.push(filePath);
          }
        } catch { /* skip */ }
      }
    } catch { /* skip */ }
  }

  return results;
}

/**
 * Count lines in a file
 */
function countLines(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    // Don't count trailing empty lines
    const trimmed = content.replace(/\n+$/, '');
    return trimmed.split('\n').length;
  } catch {
    return 0;
  }
}

/**
 * Get retry count for an agent
 */
function getRetryCount(projectDir, agentId) {
  const retryFile = path.join(projectDir, '.mad', 'scratch', `.retry-${agentId}.count`);
  try {
    if (fs.existsSync(retryFile)) {
      return parseInt(fs.readFileSync(retryFile, 'utf8').trim(), 10) || 0;
    }
  } catch { /* default to 0 */ }
  return 0;
}

/**
 * Increment retry count for an agent
 */
function incrementRetryCount(projectDir, agentId) {
  const scratchDir = path.join(projectDir, '.mad', 'scratch');
  try {
    if (!fs.existsSync(scratchDir)) {
      fs.mkdirSync(scratchDir, { recursive: true });
    }
    const retryFile = path.join(scratchDir, `.retry-${agentId}.count`);
    const current = getRetryCount(projectDir, agentId);
    fs.writeFileSync(retryFile, String(current + 1));
  } catch { /* ignore */ }
}

/**
 * Clean up retry counter for an agent
 */
function cleanupRetryCount(projectDir, agentId) {
  const retryFile = path.join(projectDir, '.mad', 'scratch', `.retry-${agentId}.count`);
  try {
    if (fs.existsSync(retryFile)) {
      fs.unlinkSync(retryFile);
    }
  } catch { /* ignore */ }
}

async function main() {
  try {
    const input = await readStdin();
    let data = {};

    try {
      data = JSON.parse(input);
    } catch {
      // Not JSON, allow stop
      process.exit(0);
    }

    const agentId = data.subagentId || data.agent_id || data.agentId || 'unknown';
    const projectDir = getProjectDir();

    // Find review directories and recent baselines
    const reviewDirs = findReviewDirs(projectDir);
    if (reviewDirs.length === 0) {
      // No review in progress — not relevant, allow stop
      process.exit(0);
    }

    const recentBaselines = findRecentBaselines(reviewDirs);
    if (recentBaselines.length === 0) {
      // No recent baselines — this agent wasn't doing baseline extraction
      cleanupRetryCount(projectDir, agentId);
      process.exit(0);
    }

    // Check each recent baseline for line count violations
    const violations = [];
    for (const file of recentBaselines) {
      const lineCount = countLines(file);
      if (lineCount > MAX_BASELINE_LINES) {
        violations.push({ file: path.relative(projectDir, file), lines: lineCount });
      }
    }

    if (violations.length === 0) {
      // All baselines within limits — success
      cleanupRetryCount(projectDir, agentId);
      process.exit(0);
    }

    // Violations found — check retry count
    const retries = getRetryCount(projectDir, agentId);

    if (retries >= MAX_RETRIES) {
      // Max retries exceeded — allow stop but warn
      cleanupRetryCount(projectDir, agentId);
      const warning = violations.map(v =>
        `${v.file}: ${v.lines} lines (exceeds ${MAX_BASELINE_LINES})`
      ).join('; ');
      console.error(`WARNING: Baseline size cap exceeded after ${MAX_RETRIES} retries. Orchestrator should truncate. ${warning}`);
      // Allow stop — orchestrator will handle truncation
      process.exit(0);
    }

    // Advisory warning — SubagentStop cannot block or retry
    incrementRetryCount(projectDir, agentId);
    const violationDetails = violations.map(v =>
      `${v.file}: ${v.lines} lines`
    ).join(', ');

    console.error(
      `WARNING: Baseline exceeds ${MAX_BASELINE_LINES}-line cap (${violationDetails}). ` +
      `SUMMARIZE (do not truncate) to under ${MAX_BASELINE_LINES} lines. ` +
      `Retry ${retries + 1}/${MAX_RETRIES}. Orchestrator should truncate.`
    );
    process.exit(0);
  } catch (err) {
    // fail-open: advisory hook should not crash session
    console.error('[validate-baseline-size] ERROR:', err.message);
    process.exit(0);
  }
}

main();
