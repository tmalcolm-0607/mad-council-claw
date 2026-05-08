#!/usr/bin/env node
/**
 * Hook: SessionEnd
 * Purpose: Auto-capture session metrics, sync to context.md, detect patterns
 *
 * This hook replaces manual /session-improve review by automatically:
 * 1. Logging session metrics (duration, gate results, errors)
 * 2. Detecting failure patterns from gate-fail logs
 * 3. Updating context.md with new findings
 * 4. Flagging when /session-improve apply should be run
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

function ensureDir(dir) {
  try {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  } catch {
    // Ignore
  }
}

function findContextFile(cwd) {
  // Look for context.md in specs/*/
  try {
    const specsDir = path.join(cwd, 'specs');
    if (fs.existsSync(specsDir)) {
      const entries = fs.readdirSync(specsDir, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.isDirectory()) {
          const contextPath = path.join(specsDir, entry.name, 'context.md');
          if (fs.existsSync(contextPath)) {
            return contextPath;
          }
        }
      }
    }
  } catch {
    // Ignore
  }
  return null;
}

function parseGateFailures(claudeDir, sessionId) {
  const failures = [];
  const gateFailLog = path.join(claudeDir, 'gate-failures.log');

  if (fs.existsSync(gateFailLog)) {
    try {
      const content = fs.readFileSync(gateFailLog, 'utf8');
      const lines = content.trim().split('\n');

      for (const line of lines.slice(-50)) {
        // Only process recent entries
        try {
          const entry = JSON.parse(line);
          if (entry.sessionId === sessionId || !entry.sessionId) {
            failures.push({
              type: entry.gateType || 'unknown',
              error: entry.error || entry.message || 'Unknown error',
              timestamp: entry.timestamp
            });
          }
        } catch {
          // Skip malformed lines
        }
      }
    } catch {
      // Ignore
    }
  }

  return failures;
}

function detectPatterns(failures) {
  const patterns = {};

  for (const failure of failures) {
    // Categorize failures
    let pattern = 'other';

    if (failure.error.includes('ENOENT') || failure.error.includes('not found')) {
      pattern = 'missing_file';
    } else if (failure.error.includes('test') || failure.error.includes('failed')) {
      pattern = 'test_failure';
    } else if (failure.error.includes('build') || failure.error.includes('compile')) {
      pattern = 'build_failure';
    } else if (failure.error.includes('timeout')) {
      pattern = 'timeout';
    } else if (failure.error.includes('permission') || failure.error.includes('EACCES')) {
      pattern = 'permission_error';
    }

    patterns[pattern] = (patterns[pattern] || 0) + 1;
  }

  return patterns;
}

function updateContextMetrics(contextPath, metrics) {
  try {
    let content = fs.readFileSync(contextPath, 'utf8');

    // Update the session log section
    const sessionLogMatch = content.match(/## Session Log \(Last 20\)\n\n\| Time \| Skill \| Event \| Details \|\n\|[^\n]+\|\n/);
    if (sessionLogMatch) {
      const timestamp = new Date().toISOString().split('T')[0];
      const newEntry = `| ${timestamp} | auto-capture | SESSION_END | Duration: ${metrics.duration}s, Gates: ${metrics.gatesPassed}/${metrics.gatesTotal} |`;

      // Insert after header row
      const insertPos = sessionLogMatch.index + sessionLogMatch[0].length;
      content = content.slice(0, insertPos) + newEntry + '\n' + content.slice(insertPos);
    }

    // Update sessions in cycle count
    const cycleMatch = content.match(/\*\*Sessions in Cycle\*\*: (\d+)/);
    if (cycleMatch) {
      const currentCount = parseInt(cycleMatch[1], 10);
      content = content.replace(
        /\*\*Sessions in Cycle\*\*: \d+/,
        `**Sessions in Cycle**: ${currentCount + 1}`
      );
    }

    fs.writeFileSync(contextPath, content);
    return true;
  } catch {
    return false;
  }
}

function checkEcosystemImproveNeeded(claudeDir) {
  // Check if pattern counts have reached threshold
  const patternsFile = path.join(claudeDir, 'pattern-counts.json');

  if (fs.existsSync(patternsFile)) {
    try {
      const patterns = JSON.parse(fs.readFileSync(patternsFile, 'utf8'));
      for (const [pattern, count] of Object.entries(patterns)) {
        if (count >= 5) {
          return { needed: true, pattern, count };
        }
      }
    } catch {
      // Ignore
    }
  }

  return { needed: false };
}

function updatePatternCounts(claudeDir, newPatterns) {
  const patternsFile = path.join(claudeDir, 'pattern-counts.json');
  let patterns = {};

  if (fs.existsSync(patternsFile)) {
    try {
      patterns = JSON.parse(fs.readFileSync(patternsFile, 'utf8'));
    } catch {
      // Start fresh
    }
  }

  // Merge new patterns
  for (const [pattern, count] of Object.entries(newPatterns)) {
    patterns[pattern] = (patterns[pattern] || 0) + count;
  }

  // Track last updated
  patterns._lastUpdated = new Date().toISOString();

  try {
    fs.writeFileSync(patternsFile, JSON.stringify(patterns, null, 2));
  } catch {
    // Ignore
  }

  return patterns;
}

/**
 * Cost estimation rates (blended input/output)
 */
const COST_RATES = {
  opus: 0.03,    // $0.03 per 1K tokens
  sonnet: 0.006, // $0.006 per 1K tokens
  haiku: 0.0005  // $0.0005 per 1K tokens
};

/**
 * Update work item metrics in manifest.json
 * @param {string} projectDir - Project directory containing .claude/work-items
 * @param {object} sessionData - Session data to record
 */
function updateWorkItemMetrics(projectDir, sessionData) {
  // Resolve active work item via per-session pointer
  const { wiId: workItemId } = resolveActiveWI(sessionData, projectDir);

  // Skip if no active work item
  if (!workItemId) {
    return { updated: false, reason: 'active_empty' };
  }

  // Find manifest.json
  const manifestPath = path.join(projectDir, '.claude', 'work-items', workItemId, 'manifest.json');
  if (!fs.existsSync(manifestPath)) {
    return { updated: false, reason: 'no_manifest', workItemId };
  }

  // Read and update manifest
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch {
    return { updated: false, reason: 'invalid_manifest', workItemId };
  }

  // Initialize metrics if not present
  if (!manifest.metrics) {
    manifest.metrics = {
      sessions: [],
      totals: {
        sessions: 0,
        prompts: 0,
        estimated_tokens: 0,
        estimated_cost_usd: 0
      }
    };
  }

  // Ensure sessions array exists
  if (!Array.isArray(manifest.metrics.sessions)) {
    manifest.metrics.sessions = [];
  }

  // Add session entry
  const sessionEntry = {
    session_id: sessionData.session_id || sessionData.sessionId || 'unknown',
    started: sessionData.started || new Date().toISOString(),
    ended: new Date().toISOString(),
    prompts: sessionData.prompts || 0,
    estimated_tokens: sessionData.estimated_tokens || 0,
    agents_spawned: sessionData.agents_spawned || 0,
    model: sessionData.model || 'opus'
  };

  manifest.metrics.sessions.push(sessionEntry);

  // Recalculate totals from all sessions
  const totals = manifest.metrics.sessions.reduce((acc, s) => ({
    sessions: acc.sessions + 1,
    prompts: acc.prompts + (s.prompts || 0),
    estimated_tokens: acc.estimated_tokens + (s.estimated_tokens || 0)
  }), { sessions: 0, prompts: 0, estimated_tokens: 0 });

  // Determine primary model for cost estimation
  const modelCounts = {};
  for (const s of manifest.metrics.sessions) {
    const model = s.model || 'opus';
    modelCounts[model] = (modelCounts[model] || 0) + 1;
  }
  const primaryModel = Object.entries(modelCounts)
    .sort((a, b) => b[1] - a[1])[0]?.[0] || 'opus';

  // Estimate cost using blended rate
  const rate = COST_RATES[primaryModel] || COST_RATES.opus;
  totals.estimated_cost_usd = Math.round(totals.estimated_tokens / 1000 * rate * 100) / 100;

  manifest.metrics.totals = totals;

  // Write updated manifest
  try {
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    return { updated: true, workItemId, totals };
  } catch {
    return { updated: false, reason: 'write_failed', workItemId };
  }
}

async function main() {
  try {
    const input = await readStdin();
    let sessionId = 'unknown';
    let cwd = process.cwd();

    try {
      const data = JSON.parse(input);
      sessionId = data.sessionId || process.env.CLAUDE_SESSION_ID || 'default';
      cwd = data.cwd || process.cwd();
    } catch {
      // Use defaults
    }

    const timestamp = new Date().toISOString();
    const claudeDir = path.join(os.homedir(), '.claude');
    ensureDir(claudeDir);

    // Check for session start time
    const startFile = path.join(os.tmpdir(), `claude_session_${sessionId}_start`);
    let duration = 0;

    if (fs.existsSync(startFile)) {
      try {
        const startTime = parseInt(fs.readFileSync(startFile, 'utf8'), 10);
        duration = Math.floor(Date.now() / 1000) - startTime;
        fs.unlinkSync(startFile);
      } catch {
        // Ignore
      }
    }

    // Parse gate failures from this session
    const failures = parseGateFailures(claudeDir, sessionId);
    const patterns = detectPatterns(failures);

    // Update pattern counts
    const allPatterns = updatePatternCounts(claudeDir, patterns);

    // Check if ecosystem-improve should be suggested
    const ecosystemCheck = checkEcosystemImproveNeeded(claudeDir);

    // Find and update context.md
    const contextPath = findContextFile(cwd);
    let contextUpdated = false;

    if (contextPath) {
      contextUpdated = updateContextMetrics(contextPath, {
        duration,
        gatesPassed: failures.length === 0 ? 1 : 0,
        gatesTotal: 1,
        patterns
      });
    }

    // Calculate planning ratio from anomaly state
    let planningRatio = null;
    let planningWarning = false;
    const anomalyStatePath = path.join(claudeDir, 'anomaly-state.json');
    if (fs.existsSync(anomalyStatePath)) {
      try {
        const anomalyState = JSON.parse(fs.readFileSync(anomalyStatePath, 'utf8'));
        const toolUses = anomalyState.toolUses || {};

        // Count read-only vs write/execute tools
        const readOnlyTools = ['Read', 'Grep', 'Glob'];
        const writeExecuteTools = ['Write', 'Edit', 'Bash'];

        let readOnlyCount = 0;
        let writeExecuteCount = 0;

        for (const [tool, count] of Object.entries(toolUses)) {
          if (readOnlyTools.includes(tool)) {
            readOnlyCount += count;
          } else if (writeExecuteTools.includes(tool)) {
            writeExecuteCount += count;
          }
        }

        const totalTools = readOnlyCount + writeExecuteCount;
        if (totalTools > 0) {
          planningRatio = Math.round((readOnlyCount / totalTools) * 1000) / 1000; // Round to 3 decimals

          // Warn if ratio exceeds 90% (0.9)
          if (planningRatio >= 0.9 && totalTools >= 10) {
            planningWarning = true;
          }
        }
      } catch {
        // Ignore errors reading/parsing anomaly state
      }
    }

    // Update work item metrics
    const workItemMetrics = updateWorkItemMetrics(cwd, {
      session_id: sessionId,
      started: fs.existsSync(path.join(os.tmpdir(), `claude_session_${sessionId}_start_iso`))
        ? fs.readFileSync(path.join(os.tmpdir(), `claude_session_${sessionId}_start_iso`), 'utf8').trim()
        : new Date(Date.now() - duration * 1000).toISOString(),
      prompts: 0, // Will be populated if available from session data
      estimated_tokens: 0, // Will be populated if available from session data
      agents_spawned: 0, // Will be populated if available from session data
      model: 'opus' // Default model
    });

    // Log session end with enhanced metrics
    const logFile = path.join(claudeDir, 'session-metrics.log');
    const logEntry = JSON.stringify({
      event: 'session_end',
      sessionId,
      duration,
      timestamp,
      failures: failures.length,
      patterns,
      contextUpdated,
      workItemMetrics,
      ecosystemImproveNeeded: ecosystemCheck.needed,
      planningRatio: planningRatio,
      planningWarning: planningWarning
    }) + '\n';

    try {
      fs.appendFileSync(logFile, logEntry);
    } catch {
      // Ignore
    }

    // Cleanup temp files
    try {
      const tmpDir = os.tmpdir();
      const files = fs.readdirSync(tmpDir);
      for (const file of files) {
        if (file.startsWith(`claude_session_${sessionId}_`)) {
          fs.unlinkSync(path.join(tmpDir, file));
        }
      }
    } catch {
      // Ignore
    }

    // Build response
    const response = { acknowledged: true };

    // Add reminder if /session-improve apply is needed
    if (ecosystemCheck.needed) {
      response.reminder = `Pattern "${ecosystemCheck.pattern}" has reached ${ecosystemCheck.count} occurrences. Consider running /session-improve apply --auto-p1`;
    }

    // Add warning if planning ratio is high
    if (planningWarning) {
      const msg = `High planning ratio detected (${planningRatio * 100}% read-only tools). Session may have been over-planning instead of implementing.`;
      response.warning = response.reminder ? `${response.reminder} | ${msg}` : msg;
    }

    console.log(JSON.stringify(response));
  } catch (err) {
    // Advisory hook - fail-open (metrics/cleanup should never block sessions)
    console.error('[session-end] Error:', err.message);
    console.log(JSON.stringify({ acknowledged: true }));
    process.exit(0);
  }
}

main().catch(() => process.exit(0));
