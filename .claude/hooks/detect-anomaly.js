#!/usr/bin/env node

/**
 * Anomaly Detection Hook
 *
 * Detects unusual patterns in Claude Code sessions:
 * - Excessive agent spawns (>10/hr)
 * - Repeated failures (>3 consecutive)
 * - Unusual token usage (>2x average)
 * - Long-running sessions (>2 hours)
 * - Rapid-fire prompts (<30s apart consistently)
 * - Overplanning (too many read-only tool calls without writes)
 *
 * Events: UserPromptSubmit, SubagentStop, PostToolUse (gate failures, tool tracking)
 */

const fs = require('fs');
const path = require('path');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

// Configuration (can be overridden by anomaly-thresholds.md)
const DEFAULT_THRESHOLDS = {
  spawns_per_hour: 10,
  consecutive_failures: 3,
  token_multiplier: 2.0,  // 2x average
  session_duration_hours: 2,
  rapid_prompt_seconds: 30,
  rapid_prompt_count: 5,
  planning_turns_without_write: 8,
  detect_overplanning_enabled: true,
  anomaly_cooldown_seconds: 300,
  anomaly_repeat_summary_count: 5,
  anomaly_repeat_summary_window_seconds: 900
};

const ANOMALY_LOG = '.mad/logs/anomaly.log';
const SESSION_STATE_FILE = '.mad/scratch/anomaly-state.json';

/**
 * Get project directory by walking up to find .claude folder
 */
function getProjectDir() {
  let dir = process.cwd();
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, '.claude'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

/**
 * Load thresholds from anomaly-thresholds.md if exists
 */
function loadThresholds() {
  const projectDir = getProjectDir();
  const thresholdsPath = path.join(projectDir, '.claude/rules/anomaly-thresholds.md');

  if (!fs.existsSync(thresholdsPath)) {
    return DEFAULT_THRESHOLDS;
  }

  try {
    const content = fs.readFileSync(thresholdsPath, 'utf8');
    const thresholds = { ...DEFAULT_THRESHOLDS };

    // Parse threshold values from markdown table
    const patterns = {
      spawns_per_hour: /spawns_per_hour\s*\|\s*(\d+)/i,
      consecutive_failures: /consecutive_failures\s*\|\s*(\d+)/i,
      token_multiplier: /token_multiplier\s*\|\s*([\d.]+)/i,
      session_duration_hours: /session_duration_hours\s*\|\s*(\d+)/i,
      rapid_prompt_seconds: /rapid_prompt_seconds\s*\|\s*(\d+)/i,
      rapid_prompt_count: /rapid_prompt_count\s*\|\s*(\d+)/i,
      planning_turns_without_write: /planning_turns_without_write\s*\|\s*(\d+)/i,
      anomaly_cooldown_seconds: /anomaly_cooldown_seconds\s*\|\s*(\d+)/i,
      anomaly_repeat_summary_count: /anomaly_repeat_summary_count\s*\|\s*(\d+)/i,
      anomaly_repeat_summary_window_seconds: /anomaly_repeat_summary_window_seconds\s*\|\s*(\d+)/i
    };

    // Parse boolean thresholds
    const boolPatterns = {
      detect_overplanning_enabled: /detect_overplanning_enabled\s*\|\s*(true|false)/i
    };

    for (const [key, pattern] of Object.entries(boolPatterns)) {
      const match = content.match(pattern);
      if (match) {
        thresholds[key] = match[1].toLowerCase() === 'true';
      }
    }

    for (const [key, pattern] of Object.entries(patterns)) {
      const match = content.match(pattern);
      if (match) {
        thresholds[key] = parseFloat(match[1]);
      }
    }

    return thresholds;
  } catch (e) {
    return DEFAULT_THRESHOLDS;
  }
}

/**
 * Load or initialize session state
 */
function loadSessionState(sessionId) {
  const projectDir = getProjectDir();
  const statePath = path.join(projectDir, SESSION_STATE_FILE);

  try {
    if (fs.existsSync(statePath)) {
      const data = JSON.parse(fs.readFileSync(statePath, 'utf8'));
      if (data.sessionId === sessionId) {
        return data;
      }
    }
  } catch (e) {
    // Start fresh on error
  }

  return {
    sessionId,
    startTime: Date.now(),
    promptTimes: [],
    agentSpawns: [],
    consecutiveFailures: 0,
    totalTokens: 0,
    promptCount: 0,
    anomaliesDetected: [],
    toolUses: [],   // { name, timestamp } entries for planning ratio tracking
    anomalyLedger: {}
  };
}

/**
 * Save session state
 */
function saveSessionState(state) {
  const projectDir = getProjectDir();
  const statePath = path.join(projectDir, SESSION_STATE_FILE);

  try {
    const dir = path.dirname(statePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  } catch (e) {
    // Silently fail - state is ephemeral
  }
}

/**
 * Log anomaly to file and return warning message
 */
function logAnomaly(anomaly) {
  const projectDir = getProjectDir();
  const logPath = path.join(projectDir, ANOMALY_LOG);

  const entry = {
    timestamp: new Date().toISOString(),
    ...anomaly
  };

  try {
    const dir = path.dirname(logPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.appendFileSync(logPath, JSON.stringify(entry) + '\n');
  } catch (e) {
    // Silently fail
  }

  return entry;
}

/**
 * Format anomaly as user-facing warning
 */
function formatWarning(anomaly) {
  const severityIcon = {
    alert: '[ALERT]',
    warn: '[WARN]'
  };

  return `
${severityIcon[anomaly.policySeverity] || '[WARN]'} ANOMALY DETECTED: ${anomaly.type}
${'-'.repeat(50)}
${anomaly.message}

Recommendation: ${anomaly.recommendation}
${'-'.repeat(50)}
`;
}

function getPolicySeverity(anomaly) {
  return anomaly.severity === 'high' ? 'alert' : 'warn';
}

function getFingerprint(anomaly) {
  const normalizedMessage = String(anomaly.message || '')
    .replace(/\b\d+(\.\d+)?\b/g, '#')
    .replace(/\s+/g, ' ')
    .trim();
  return `${anomaly.type}|${normalizedMessage}`;
}

function createRepeatSummaryAnomaly(original, suppressedCount, windowSeconds) {
  return {
    type: `${original.type}_REPEAT_SUMMARY`,
    severity: original.severity,
    policySeverity: getPolicySeverity(original),
    message: `${suppressedCount} duplicate ${original.type} anomalies suppressed in the last ${windowSeconds} seconds`,
    recommendation: 'Persistent repeated anomalies detected. Investigate root cause and reduce repeated failing actions.',
    __summary: true
  };
}

function shouldEmitAnomaly(state, anomaly, thresholds) {
  if (!state.anomalyLedger) {
    state.anomalyLedger = {};
  }

  const now = Date.now();
  const cooldownMs = thresholds.anomaly_cooldown_seconds * 1000;
  const summaryWindowMs = thresholds.anomaly_repeat_summary_window_seconds * 1000;
  const fingerprint = getFingerprint(anomaly);
  const ledger = state.anomalyLedger[fingerprint] || {
    lastEmittedAt: 0,
    suppressedCount: 0,
    firstSuppressedAt: 0,
    lastSuppressedAt: 0
  };

  // Always emit high severity anomalies unless it's an immediate duplicate in cooldown.
  // Unique high severity events are preserved by fingerprinting.
  if (now - ledger.lastEmittedAt >= cooldownMs) {
    ledger.lastEmittedAt = now;
    state.anomalyLedger[fingerprint] = ledger;
    return { emit: true, anomaly: { ...anomaly, policySeverity: getPolicySeverity(anomaly), fingerprint } };
  }

  ledger.suppressedCount += 1;
  ledger.lastSuppressedAt = now;
  if (!ledger.firstSuppressedAt || now - ledger.firstSuppressedAt > summaryWindowMs) {
    ledger.firstSuppressedAt = now;
    ledger.suppressedCount = 1;
  }

  let summaryAnomaly = null;
  if (ledger.suppressedCount >= thresholds.anomaly_repeat_summary_count) {
    summaryAnomaly = createRepeatSummaryAnomaly(
      anomaly,
      ledger.suppressedCount,
      thresholds.anomaly_repeat_summary_window_seconds
    );
    ledger.suppressedCount = 0;
    ledger.firstSuppressedAt = now;
    ledger.lastEmittedAt = now;
  }

  state.anomalyLedger[fingerprint] = ledger;

  if (summaryAnomaly) {
    return { emit: true, anomaly: { ...summaryAnomaly, fingerprint: `${fingerprint}|summary` } };
  }

  return { emit: false };
}

/**
 * Check for excessive agent spawns
 */
function checkExcessiveSpawns(state, thresholds) {
  const oneHourAgo = Date.now() - (60 * 60 * 1000);
  const recentSpawns = state.agentSpawns.filter(t => t > oneHourAgo);

  if (recentSpawns.length > thresholds.spawns_per_hour) {
    return {
      type: 'EXCESSIVE_SPAWNS',
      severity: 'medium',
      message: `${recentSpawns.length} agent spawns in the last hour (threshold: ${thresholds.spawns_per_hour})`,
      recommendation: 'Consider consolidating work into fewer, more focused agent tasks. Check if spawning is looping.'
    };
  }
  return null;
}

/**
 * Check for consecutive failures
 */
function checkConsecutiveFailures(state, thresholds) {
  if (state.consecutiveFailures >= thresholds.consecutive_failures) {
    return {
      type: 'REPEATED_FAILURES',
      severity: 'high',
      message: `${state.consecutiveFailures} consecutive failures detected`,
      recommendation: 'Stop and investigate the root cause. Check logs, review recent changes, or consider a different approach.'
    };
  }
  return null;
}

/**
 * Check for unusual token usage
 */
function checkTokenUsage(state, thresholds, currentTokens) {
  if (state.promptCount < 5) return null;  // Need baseline

  const avgTokens = state.totalTokens / state.promptCount;
  if (avgTokens === 0) return null;

  if (currentTokens > avgTokens * thresholds.token_multiplier) {
    return {
      type: 'UNUSUAL_TOKENS',
      severity: 'medium',
      message: `Current operation used ${currentTokens} tokens (${(currentTokens / avgTokens * 100).toFixed(0)}% of average)`,
      recommendation: 'Review the prompt for unnecessary verbosity. Consider breaking into smaller tasks.'
    };
  }
  return null;
}

/**
 * Check for long-running session
 */
function checkSessionDuration(state, thresholds) {
  const durationHours = (Date.now() - state.startTime) / (1000 * 60 * 60);

  if (durationHours > thresholds.session_duration_hours) {
    // Only warn once per session
    if (!state.anomaliesDetected.includes('LONG_SESSION')) {
      state.anomaliesDetected.push('LONG_SESSION');
      return {
        type: 'LONG_SESSION',
        severity: 'low',
        message: `Session running for ${durationHours.toFixed(1)} hours (threshold: ${thresholds.session_duration_hours}h)`,
        recommendation: 'Consider using /clear or starting a new session to free context. Long sessions may lose early context.'
      };
    }
  }
  return null;
}

/**
 * Check for rapid-fire prompts
 */
function checkRapidPrompts(state, thresholds) {
  const recentPrompts = state.promptTimes.slice(-thresholds.rapid_prompt_count);

  if (recentPrompts.length < thresholds.rapid_prompt_count) return null;

  // Check if all recent prompts were within rapid threshold
  const allRapid = recentPrompts.every((time, i, arr) => {
    if (i === 0) return true;
    return (time - arr[i-1]) < (thresholds.rapid_prompt_seconds * 1000);
  });

  if (allRapid) {
    return {
      type: 'RAPID_PROMPTS',
      severity: 'low',
      message: `${thresholds.rapid_prompt_count} prompts in rapid succession (< ${thresholds.rapid_prompt_seconds}s apart)`,
      recommendation: 'Slow down to review outputs. Rapid prompts may lead to compounding errors or wasted tokens.'
    };
  }
  return null;
}

/**
 * Read the current workflow phase from the active work item's manifest.
 * Returns the phase string or null if unavailable.
 */
function getCurrentPhase(data) {
  const projectDir = getProjectDir();
  try {
    const { wiId: activeWI } = resolveActiveWI(data, projectDir);
    if (!activeWI) return null;

    const manifestPath = path.join(projectDir, '.claude/work-items', activeWI, 'manifest.json');
    if (!fs.existsSync(manifestPath)) return null;

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    return manifest.current_phase || manifest.currentPhase || null;
  } catch (e) {
    return null;
  }
}

/**
 * Check for overplanning: too many consecutive read-only tool calls without writes.
 * Suppressed during planning-oriented phases (Setup, Plan, Research, Baseline, Investigate).
 */
function checkPlanningRatio(state, thresholds, data) {
  if (!thresholds.detect_overplanning_enabled) return null;

  const toolUses = state.toolUses || [];
  if (toolUses.length === 0) return null;

  // Count consecutive read-only tools from the end
  const readOnlyTools = new Set(['Read', 'Grep', 'Glob', 'WebSearch', 'WebFetch']);
  const writeTools = new Set(['Write', 'Edit', 'Bash', 'NotebookEdit']);

  let consecutiveReadOnly = 0;
  for (let i = toolUses.length - 1; i >= 0; i--) {
    const toolName = toolUses[i].name;
    if (writeTools.has(toolName)) break;
    if (readOnlyTools.has(toolName)) {
      consecutiveReadOnly++;
    }
    // Unknown tools don't break the streak but don't count toward it
  }

  if (consecutiveReadOnly < thresholds.planning_turns_without_write) return null;

  // Phase-aware suppression: suppress during planning-oriented phases
  const suppressPhases = new Set(['Setup', 'Plan', 'Research', 'Baseline', 'Investigate']);
  const currentPhase = getCurrentPhase(data);
  if (currentPhase && suppressPhases.has(currentPhase)) return null;

  // Only warn once per streak (avoid repeated warnings)
  const warningKey = `OVERPLANNING_${consecutiveReadOnly}`;
  if (state.anomaliesDetected.includes(warningKey)) return null;
  state.anomaliesDetected.push(warningKey);

  return {
    type: 'OVERPLANNING',
    severity: 'medium',
    message: `${consecutiveReadOnly} consecutive read-only tool calls (Read/Grep/Glob) without any Write/Edit/Bash. Current phase: ${currentPhase || 'unknown'}.`,
    recommendation: 'Start writing code or tests. If you are still investigating, consider whether this phase should be delegated to a code-investigator agent.'
  };
}

/**
 * Build/test commands whose non-zero exit is a real failure signal.
 * Conservative whitelist — additions here should be narrowly scoped to
 * commands whose non-zero exit unambiguously means "the verification failed".
 * grep, git diff --quiet, test/[, find, ls etc. are intentionally NOT here.
 */
const BUILD_TEST_COMMAND_PATTERNS = [
  /\bnpm\s+(?:run\s+)?(?:test|build|ci)\b/,
  /\byarn\s+(?:test|build)\b/,
  /\bpnpm\s+(?:test|build)\b/,
  /\bdotnet\s+(?:test|build|publish)\b/,
  /\bpytest\b/,
  /\bjest\b/,
  /\bvitest\b/,
  /\bpython\s+-m\s+(?:pytest|unittest)\b/,
  /\bmsbuild\b/,
  /\bmake\s+(?:test|check)\b/,
  /\bcargo\s+(?:test|build)\b/,
  /\bgo\s+(?:test|build)\b/,
  /\bmvn\s+(?:test|verify|package|install)\b/,
  /\bgradle\s+(?:test|build|check)\b/
];

function isBuildOrTestCommand(command) {
  if (!command || typeof command !== 'string') return false;
  return BUILD_TEST_COMMAND_PATTERNS.some((p) => p.test(command));
}

/**
 * Returns true when the PostToolUse event genuinely represents a tool failure.
 *
 * Rules (per loop-iter2-audit B1 + rules/test-failure-protocol.md):
 *   - Subagent (Task) tool with explicit failure marker -> failure.
 *   - Write/Edit/NotebookEdit returning non-zero AND emitting an error message -> failure.
 *   - Bash returning non-zero AND command matches build/test whitelist -> failure.
 *   - Bare non-zero exit from arbitrary Bash (grep no-match, git diff --quiet,
 *     test, glob-no-match, etc.) is NOT a failure.
 */
function isRealFailure(data, toolName, exitCode) {
  // Explicit failure markers from a subagent / Task tool.
  if (data && (data.is_error === true || data.isError === true)) return true;
  if (toolName === 'Task') {
    const failed = data && (data.error || data.errorMessage || data.failed);
    if (failed) return true;
    return false;
  }

  // Anything below this requires a non-zero exit code.
  if (typeof exitCode !== 'number' || exitCode === 0) return false;

  const stderr = (data && (data.stderr || data.tool_response_stderr || '')) || '';
  const errorMessage = (data && (data.error || data.errorMessage || '')) || '';
  const writeTools = new Set(['Write', 'Edit', 'NotebookEdit']);
  if (writeTools.has(toolName)) {
    // A write tool that returned non-zero AND said why -> real failure.
    if (errorMessage || stderr) return true;
    return false;
  }

  if (toolName === 'Bash') {
    const command = (data && (
      (data.tool_input && data.tool_input.command) ||
      (data.toolInput && data.toolInput.command) ||
      data.command
    )) || '';
    if (!isBuildOrTestCommand(command)) return false;
    // Real build/test command + non-zero exit -> count as failure regardless
    // of stderr content (some test runners write all output to stdout).
    return true;
  }

  // Other tools (Grep, Glob, Read, WebFetch, ...) don't signal "real failure"
  // through exit codes in this hook.
  return false;
}

/**
 * Returns true when the PostToolUse event represents a real success that
 * should reset the consecutive-failures counter. We're conservative here so
 * that a benign grep-no-match doesn't erase a genuine prior failure streak.
 */
function isRealSuccess(data, toolName, exitCode) {
  if (typeof exitCode !== 'number' || exitCode !== 0) return false;
  if (toolName === 'Task') {
    return !(data && (data.is_error || data.isError || data.error || data.errorMessage || data.failed));
  }
  const writeTools = new Set(['Write', 'Edit', 'NotebookEdit']);
  if (writeTools.has(toolName)) return true;
  if (toolName === 'Bash') {
    const command = (data && (
      (data.tool_input && data.tool_input.command) ||
      (data.toolInput && data.toolInput.command) ||
      data.command
    )) || '';
    return isBuildOrTestCommand(command);
  }
  return false;
}

/**
 * Main anomaly detection handler
 */
async function main() {
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch (e) {
    process.exit(0);
  }

  const thresholds = loadThresholds();
  const sessionId = data.session_id || data.sessionId || 'unknown';
  const state = loadSessionState(sessionId);
  const eventName = data.hook_event_name || data.hookEventName;

  let anomalies = [];

  // Update state based on event type
  if (eventName === 'UserPromptSubmit') {
    state.promptTimes.push(Date.now());
    state.promptCount++;

    // Keep only last 100 prompt times
    if (state.promptTimes.length > 100) {
      state.promptTimes = state.promptTimes.slice(-100);
    }

    // Check for rapid prompts
    const rapidAnomaly = checkRapidPrompts(state, thresholds);
    if (rapidAnomaly) anomalies.push(rapidAnomaly);

    // Check session duration
    const durationAnomaly = checkSessionDuration(state, thresholds);
    if (durationAnomaly) anomalies.push(durationAnomaly);
  }

  if (eventName === 'SubagentStop') {
    state.agentSpawns.push(Date.now());

    // Keep only last hour of spawns
    const oneHourAgo = Date.now() - (60 * 60 * 1000);
    state.agentSpawns = state.agentSpawns.filter(t => t > oneHourAgo);

    // Track success/failure
    const failed = data.error || data.errorMessage || data.failed;
    if (failed) {
      state.consecutiveFailures++;
    } else {
      state.consecutiveFailures = 0;
    }

    // Track tokens
    const tokens = data.tokens_used || data.tokens || 0;
    if (tokens > 0) {
      const tokenAnomaly = checkTokenUsage(state, thresholds, tokens);
      if (tokenAnomaly) anomalies.push(tokenAnomaly);
      state.totalTokens += tokens;
    }

    // Check for excessive spawns
    const spawnAnomaly = checkExcessiveSpawns(state, thresholds);
    if (spawnAnomaly) anomalies.push(spawnAnomaly);

    // Check for consecutive failures
    const failureAnomaly = checkConsecutiveFailures(state, thresholds);
    if (failureAnomaly) anomalies.push(failureAnomaly);
  }

  // PostToolUse for gate failures and tool tracking
  if (eventName === 'PostToolUse') {
    const exitCode = data.exit_code || data.exitCode;
    const toolName = data.tool_name || data.toolName;

    // Bug fix B1 (loop-iter2-audit): non-zero exit is NOT by itself a failure signal.
    // grep with no matches, git diff --quiet, test/[, glob-no-match all return 1 harmlessly.
    // Only count as a failure when it's a real build/test command, an explicit subagent
    // failure marker, or a Write/Edit that emitted an error message.
    // See: rules/test-failure-protocol.md, rules/anomaly-thresholds.md (consecutive_failures: 3).
    if (isRealFailure(data, toolName, exitCode)) {
      state.consecutiveFailures++;

      const failureAnomaly = checkConsecutiveFailures(state, thresholds);
      if (failureAnomaly) anomalies.push(failureAnomaly);
    } else if (isRealSuccess(data, toolName, exitCode)) {
      // Only reset on a real success — otherwise leave the counter alone.
      // A grep-no-match exit 1 must not falsely trip; equally, a successful grep
      // must not erase a genuine prior failure streak from a real build/test.
      state.consecutiveFailures = 0;
    }

    // Track tool usage for planning ratio detection
    if (toolName) {
      if (!state.toolUses) state.toolUses = [];
      state.toolUses.push({ name: toolName, timestamp: Date.now() });

      // Keep only last 100 entries
      if (state.toolUses.length > 100) {
        state.toolUses = state.toolUses.slice(-100);
      }

      // Bug fix B2 (loop-iter2-audit): OVERPLANNING_* ledger never decayed.
      // When any write tool fires, clear stale OVERPLANNING_* entries from
      // anomaliesDetected[] and resolve their anomalyLedger fingerprints so the
      // streak counter is a streak, not a cumulative monotonic value.
      // See: rules/anomaly-thresholds.md (planning_turns_without_write: 8).
      const writeTools = new Set(['Write', 'Edit', 'Bash', 'NotebookEdit']);
      if (writeTools.has(toolName)) {
        if (Array.isArray(state.anomaliesDetected)) {
          state.anomaliesDetected = state.anomaliesDetected.filter(
            (key) => !String(key).startsWith('OVERPLANNING_')
          );
        }
        if (state.anomalyLedger && typeof state.anomalyLedger === 'object') {
          for (const fingerprint of Object.keys(state.anomalyLedger)) {
            if (fingerprint.startsWith('OVERPLANNING|') ||
                fingerprint.startsWith('OVERPLANNING_REPEAT_SUMMARY|')) {
              delete state.anomalyLedger[fingerprint];
            }
          }
        }
      }

      // Check planning ratio (skip for agent-type tools like Task, SendMessage)
      const agentTools = new Set(['Task', 'SendMessage', 'TaskCreate', 'TaskUpdate', 'TaskList', 'TaskGet', 'TeamCreate', 'TeamDelete']);
      if (!agentTools.has(toolName)) {
        const planningAnomaly = checkPlanningRatio(state, thresholds, data);
        if (planningAnomaly) anomalies.push(planningAnomaly);
      }
    }
  }

  // Log and output warnings
  if (anomalies.length > 0) {
    const emitQueue = [];
    for (const anomaly of anomalies) {
      const decision = shouldEmitAnomaly(state, anomaly, thresholds);
      if (decision.emit && decision.anomaly) {
        emitQueue.push(decision.anomaly);
      }
    }

    saveSessionState(state);

    if (emitQueue.length === 0) {
      process.exit(0);
      return;
    }

    let output = '';
    for (const anomaly of emitQueue) {
      logAnomaly({ ...anomaly, sessionId, eventName });
      output += formatWarning(anomaly);
    }

    // Output warning to stderr (non-blocking)
    console.error(output);
    process.exit(0);
  } else {
    saveSessionState(state);
    process.exit(0);
  }
}

// Export helpers for unit testing without invoking main().
// require.main !== module when imported via require(); we still register the
// surface in both modes so tests can introspect, but only auto-run as a CLI.
module.exports = {
  isRealFailure,
  isRealSuccess,
  isBuildOrTestCommand,
  loadThresholds,
  loadSessionState,
  saveSessionState,
  checkPlanningRatio,
  checkConsecutiveFailures,
  DEFAULT_THRESHOLDS
};

if (require.main === module) {
  main().catch(() => process.exit(0));
}
