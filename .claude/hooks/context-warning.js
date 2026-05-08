#!/usr/bin/env node
/**
 * context-warning.js
 *
 * Purpose: Three-tier context usage warning system (Context Guardian).
 *
 * Event: UserPromptSubmit
 * Behavior:
 *   - ADVISORY (50%): One-line stderr reminder (non-blocking)
 *   - PREPARE  (70%): Multi-line stderr warning block (non-blocking)
 *   - HALT     (85%): Hard gate - blocks the prompt (exit code 2)
 *
 * Also detects keywords suggesting heavy operations and warns accordingly.
 *
 * Uses shared library: .mad/lib/context-metrics.js
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Import shared metrics library
let metrics;
try {
  metrics = require('../../.mad/lib/context-metrics.js');
} catch (err) {
  // If the library is missing, exit gracefully - cannot function without it
  process.stderr.write(`context-warning.js: context-metrics.js not found, skipping.\n`);
  process.exit(0);
}

// Import handoff generator for HALT-level safety net
let handoffGenerator;
try {
  handoffGenerator = require('../../.mad/lib/handoff-generator.js');
} catch {
  // Non-fatal - HALT will still block but won't generate handoff
}

// Keywords that suggest context-heavy operations
const HEAVY_OPERATION_KEYWORDS = [
  'read all',
  'read every',
  'analyze entire',
  'review all files',
  'search entire',
  'full codebase',
  'whole project',
  'everything in',
  'all the files',
  'complete analysis'
];

/**
 * Clean up orphan metrics files older than 24 hours from temp dir.
 * Best effort - never throws.
 */
function cleanupOrphanFiles() {
  try {
    const tmpDir = os.tmpdir();
    const files = fs.readdirSync(tmpDir);
    const now = Date.now();
    const DAY_MS = 24 * 60 * 60 * 1000;

    for (const f of files) {
      if (f.startsWith('claude-context-metrics-') && f.endsWith('.json')) {
        try {
          const fp = path.join(tmpDir, f);
          const stat = fs.statSync(fp);
          if (now - stat.mtimeMs > DAY_MS) {
            fs.unlinkSync(fp);
          }
        } catch {
          // Skip individual file errors
        }
      }
    }
  } catch {
    // Non-fatal
  }
}

/**
 * Check if prompt suggests a heavy context operation.
 * @param {string} prompt
 * @returns {string|false} matched keyword or false
 */
function detectHeavyOperation(prompt) {
  if (!prompt) return false;
  const lower = prompt.toLowerCase();
  for (const keyword of HEAVY_OPERATION_KEYWORDS) {
    if (lower.includes(keyword)) {
      return keyword;
    }
  }
  return false;
}

/**
 * Count how many turns have occurred past the first 85% hit.
 * Tracks by looking at entries where cumulativeTokens >= 85% of effective capacity.
 * Uses getEffectiveCapacity() from the shared library (no inline duplication).
 * @param {object} m - metrics object
 * @returns {number}
 */
function turnsPastHalt(m) {
  if (!m || !m.entries || m.entries.length === 0) return 0;
  const haltThreshold = metrics.getEffectiveCapacity() * metrics.THRESHOLDS.HALT;
  let count = 0;
  for (const entry of m.entries) {
    if (entry.cumulativeTokens >= haltThreshold) {
      count++;
    }
  }
  return count;
}

/**
 * Main hook execution.
 */
async function main() {
  let input = '';

  // Read JSON input from stdin
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }

  // Only check UserPromptSubmit events
  if (data.hook_event_name !== 'UserPromptSubmit') {
    process.exit(0);
  }

  const sessionId = metrics.getSessionId(data);
  const prompt = data.prompt || '';

  // Update metrics with this prompt
  const updated = metrics.updateMetrics(sessionId, prompt.length);

  // Get threshold status
  const status = metrics.getThresholdStatus(updated);
  const pct = Math.round(status.percentage * 100);
  const rawPct = Math.round(status.rawPercentage * 100);
  const growthRate = metrics.getGrowthRate(updated);

  // Clean up old orphan files (best effort, on every prompt - cheap operation)
  cleanupOrphanFiles();

  // --- HALT (85%+) ---
  if (status.level === 'HALT') {
    const pastHalt = turnsPastHalt(updated);
    const rateStr = growthRate !== null ? `${growthRate} tokens/turn` : 'unknown';
    let escalation = '';
    if (pastHalt >= 5) {
      escalation = `\nCRITICAL: You have continued ${pastHalt}+ turns past the safety threshold.`;
    }

    // Generate minimal handoff before blocking
    let handoffInfo = '';
    if (handoffGenerator) {
      try {
        const result = handoffGenerator.generateHandoff({ reason: 'halt_threshold', tier: 'minimal' });
        if (result.success && result.handoffPath) {
          handoffInfo = `\nHandoff saved: ${result.handoffPath}\n`;
        }
      } catch {
        // Non-fatal - still block even if handoff fails
      }
    }

    process.stderr.write(
      `[Context Guardian] HALT - ~${rawPct}% raw (~${pct}% effective) estimated context usage\n` +
      `=======================================================\n` +
      `Context capacity critically low. Further work risks compaction.\n` +
      `\n` +
      `Action Required:\n` +
      `1. Start a new session\n` +
      `2. Run /resume-handoff to continue from where you left off\n` +
      `\n` +
      `Growth rate: ${rateStr} | Turns since 85%: ${pastHalt}\n` +
      `Note: All thresholds are heuristic estimates (~15% error margin).\n` +
      `See: ${metrics.GUARDIAN_RULE_PATH}${escalation}${handoffInfo}\n`
    );

    process.exit(2);
  }

  // --- PREPARE (70%+) ---
  if (status.level === 'PREPARE') {
    // Check heavy operation keywords for stronger supplementary warning
    const heavyOp = detectHeavyOperation(prompt);
    let heavyWarning = '';
    if (heavyOp) {
      heavyWarning =
        `\nWARNING: Detected context-heavy request: "${heavyOp}"\n` +
        `At 70%+ usage, this operation could push you into HALT territory.\n` +
        `Strongly consider using agents to offload this work.\n`;
    }

    process.stderr.write(
      `[Context Guardian] ~${rawPct}% raw (~${pct}% effective) estimated context usage\n` +
      `================================================\n` +
      `Complete current task and avoid spawning new agents.\n` +
      `Checkpoint your progress (update plan.md, commit completed work).\n` +
      `Consider generating a handoff document if this is a long workflow.\n` +
      `See: ${metrics.GUARDIAN_RULE_PATH} for full guidelines.${heavyWarning}\n`
    );

    process.exit(0);
  }

  // --- ADVISORY (50%+) ---
  if (status.level === 'ADVISORY') {
    // Throttle: only emit once every 5 prompts to reduce warning fatigue
    const lastAdvisory = updated.lastAdvisoryTurn || 0;
    if (updated.promptCount - lastAdvisory >= 5) {
      // Check heavy operation keywords for supplementary warning
      const heavyOp = detectHeavyOperation(prompt);
      if (heavyOp) {
        process.stderr.write(
          `[Context Guardian] ~${rawPct}% raw (~${pct}% effective) estimated - detected context-heavy request: "${heavyOp}". Consider using agents to offload this work.\n`
        );
      } else {
        process.stderr.write(
          `[Context Guardian] ~${rawPct}% raw (~${pct}% effective) estimated - consider completing current phase before spawning new agents.\n`
        );
      }

      // Update lastAdvisoryTurn in metrics
      updated.lastAdvisoryTurn = updated.promptCount;
      metrics.saveMetrics(sessionId, updated);
    }

    process.exit(0);
  }

  process.exit(0);
}

main().catch(() => process.exit(0));
