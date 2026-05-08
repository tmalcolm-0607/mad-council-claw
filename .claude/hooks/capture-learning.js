#!/usr/bin/env node

/**
 * Capture Learning Hook
 *
 * Monitors session events to capture success/failure patterns for
 * the learning system. Patterns are stored in .mad/learning/
 *
 * Events: SubagentStop, PostToolUse (gate results), Stop
 */

const fs = require('fs');
const path = require('path');

const PATTERNS_FILE = '.mad/learning/patterns.json';
const FAILURES_FILE = '.mad/learning/failures.json';

// Pattern detection thresholds
const THRESHOLDS = {
  min_occurrences_for_pattern: 3,
  high_confidence: 0.9,
  medium_confidence: 0.7,
  success_tokens_threshold: 15000,  // Below this = efficient
  failure_retry_threshold: 2         // Failures before same error = pattern
};

/**
 * Sanitize error text to remove secrets and sensitive paths
 */
function sanitizeErrorText(text) {
  if (!text) return text;
  return text
    .replace(/postgresql:\/\/[^@]+@[^\/]+/g, 'postgresql://[REDACTED]')
    .replace(/Bearer [A-Za-z0-9_-]+/g, 'Bearer [REDACTED]')
    .replace(/password["\s:=]+[^\s"]+/gi, 'password=[REDACTED]')
    .replace(/api[_-]?key["\s:=]+[^\s"]+/gi, 'apikey=[REDACTED]')
    .replace(/C:\\Users\\[^\\]+/g, 'C:\\Users\\[USER]')
    .replace(/\/home\/[^\/]+/g, '/home/[USER]');
}

/**
 * Get project directory
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
 * Generate unique pattern ID
 */
function generateId(prefix) {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 6);
  return `${prefix}-${timestamp}-${random}`;
}

/**
 * Load patterns file
 */
function loadPatterns() {
  const projectDir = getProjectDir();
  const filePath = path.join(projectDir, PATTERNS_FILE);

  const defaultData = {
    schema_version: '1.0.0',
    lastUpdated: null,
    patterns: { success: [], efficiency: [] },
    statistics: { total_captured: 0, total_applied: 0, total_rejected: 0 }
  };

  try {
    if (fs.existsSync(filePath)) {
      return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    }
  } catch (e) {
    // Return default on error
  }
  return defaultData;
}

/**
 * Load failures file
 */
function loadFailures() {
  const projectDir = getProjectDir();
  const filePath = path.join(projectDir, FAILURES_FILE);

  const defaultData = {
    schema_version: '1.0.0',
    lastUpdated: null,
    failures: [],
    resolutions: {},
    statistics: { total_captured: 0, total_resolved: 0, auto_resolved: 0 }
  };

  try {
    if (fs.existsSync(filePath)) {
      return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    }
  } catch (e) {
    // Return default on error
  }
  return defaultData;
}

/**
 * Save patterns file
 */
function savePatterns(data) {
  const projectDir = getProjectDir();
  const filePath = path.join(projectDir, PATTERNS_FILE);

  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    data.lastUpdated = new Date().toISOString();
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  } catch (e) {
    // Silently fail
  }
}

/**
 * Save failures file
 */
function saveFailures(data) {
  const projectDir = getProjectDir();
  const filePath = path.join(projectDir, FAILURES_FILE);

  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    data.lastUpdated = new Date().toISOString();
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  } catch (e) {
    // Silently fail
  }
}

/**
 * Extract error signature for pattern matching
 */
function extractErrorSignature(errorText) {
  if (!errorText) return 'unknown';

  // Common error patterns to normalize
  const patterns = [
    { regex: /Cannot read propert(y|ies) .* of (undefined|null)/i, sig: 'null_property_access' },
    { regex: /Cannot find module ['"](.+)['"]/i, sig: 'module_not_found' },
    { regex: /TS\d+:/i, sig: 'typescript_error' },
    { regex: /expected .* to (equal|be|match)/i, sig: 'assertion_failure' },
    { regex: /timeout/i, sig: 'timeout' },
    { regex: /ENOENT/i, sig: 'file_not_found' },
    { regex: /EACCES/i, sig: 'permission_denied' },
    { regex: /CS\d+:/i, sig: 'csharp_error' },
    { regex: /error MSB\d+:/i, sig: 'msbuild_error' },
    { regex: /NullReferenceException/i, sig: 'null_reference' },
    { regex: /ArgumentNullException/i, sig: 'argument_null' },
    { regex: /Build FAILED/i, sig: 'build_failed' },
    { regex: /Test Failed/i, sig: 'test_failed' }
  ];

  for (const p of patterns) {
    if (p.regex.test(errorText)) {
      return p.sig;
    }
  }

  // Return first 50 chars as signature
  return errorText.substring(0, 50).replace(/[^a-zA-Z0-9_]/g, '_').toLowerCase();
}

/**
 * Capture success pattern from agent completion
 */
function captureSuccessPattern(data) {
  const patterns = loadPatterns();

  const agentType = data.subagentType || data.agent_type || 'unknown';
  const tokens = data.tokens_used || data.tokens || 0;
  const duration = data.duration_ms || data.duration || 0;

  let patternsModified = false;

  // Check for efficiency pattern (low tokens, fast completion)
  if (tokens > 0 && tokens < THRESHOLDS.success_tokens_threshold) {
    // Look for existing similar pattern
    const existingIdx = patterns.patterns.efficiency.findIndex(
      p => p.context.agent_type === agentType
    );

    if (existingIdx >= 0) {
      // Update existing
      const existing = patterns.patterns.efficiency[existingIdx];
      existing.evidence.occurrences++;
      existing.evidence.avg_tokens = Math.round(
        (existing.evidence.avg_tokens * (existing.evidence.occurrences - 1) + tokens) /
        existing.evidence.occurrences
      );
      existing.confidence = Math.min(0.95, existing.confidence + 0.05);
    } else {
      // Add new pattern
      patterns.patterns.efficiency.push({
        id: generateId('ep'),
        type: 'efficiency',
        captured: new Date().toISOString(),
        context: {
          agent_type: agentType,
          task_type: 'agent_completion'
        },
        pattern: {
          description: `Efficient ${agentType} completion`,
          trigger: `${agentType} task`,
          approach: 'Focused task with minimal context'
        },
        evidence: {
          occurrences: 1,
          avg_tokens: tokens,
          avg_duration_ms: duration
        },
        confidence: 0.5,
        status: 'pending'
      });
    }

    patterns.statistics.total_captured++;
    patternsModified = true;
  }

  // Knowledge candidate detection (Pattern 3: Automatic Knowledge Extraction)
  // Long investigation/research sessions are marked as knowledge candidates
  try {
    const knowledgeCandidate = detectKnowledgeCandidate(agentType, duration, data);
    if (knowledgeCandidate) {
      // Ensure knowledge_candidates array exists
      if (!patterns.patterns.knowledge_candidates) {
        patterns.patterns.knowledge_candidates = [];
      }

      // Check for existing candidate from same agent type to avoid duplicates
      const existingKC = patterns.patterns.knowledge_candidates.findIndex(
        p => p.context.agent_type === agentType && p.status === 'pending_extraction'
      );

      if (existingKC >= 0) {
        // Update existing candidate
        const existing = patterns.patterns.knowledge_candidates[existingKC];
        existing.evidence.occurrences++;
        existing.evidence.latest_duration_ms = duration;
        existing.confidence = Math.min(0.95, existing.confidence + 0.1);
        existing.lastSeen = new Date().toISOString();
      } else {
        // Add new knowledge candidate
        patterns.patterns.knowledge_candidates.push(knowledgeCandidate);
      }

      patterns.statistics.total_captured++;
      patternsModified = true;
    }
  } catch {
    // Knowledge candidate detection failure is non-critical
  }

  if (patternsModified) {
    savePatterns(patterns);
  }
}

/**
 * Detect if an agent completion qualifies as a knowledge candidate.
 * Returns a knowledge candidate pattern object or null.
 */
function detectKnowledgeCandidate(agentType, durationMs, data) {
  if (!agentType || agentType === 'unknown') return null;

  const typeLower = agentType.toLowerCase();
  const isKnowledgeAgent = typeLower.includes('investigator') || typeLower.includes('research');
  if (!isKnowledgeAgent) return null;

  // Read threshold from environment variable, default 600000 (10 minutes)
  const envThreshold = process.env.KNOWLEDGE_EXTRACTION_MIN_DURATION_MS;
  let thresholdMs = 600000;
  if (envThreshold) {
    const parsed = parseInt(envThreshold, 10);
    if (!isNaN(parsed)) {
      thresholdMs = Math.max(60000, Math.min(3600000, parsed));
    }
  }

  if (!durationMs || durationMs < thresholdMs) return null;

  const durationMinutes = Math.round(durationMs / 60000);
  const topic = extractTopicFromData(data, agentType);
  const suggestedSkillName = generateKebabSkillName(topic);

  return {
    id: generateId('kc'),
    type: 'knowledge_candidate',
    pattern_type: 'knowledge_candidate',
    captured: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
    context: {
      agent_type: agentType,
      task_type: 'knowledge_extraction'
    },
    pattern: {
      description: `Long ${agentType} session: ${topic}`,
      trigger: `${agentType} running >= ${durationMinutes} minutes`,
      approach: 'Extract findings as reusable skill'
    },
    evidence: {
      occurrences: 1,
      latest_duration_ms: durationMs,
      duration_minutes: durationMinutes
    },
    extraction_metadata: {
      durationMs,
      agentType,
      suggestedSkillName,
      topic
    },
    confidence: 0.6,
    status: 'pending_extraction'
  };
}

/**
 * Extract topic from agent data for knowledge candidate.
 */
function extractTopicFromData(data, agentType) {
  const promptText = data.prompt || data.task || data.description || data.topic || '';
  if (promptText) {
    const topicMatch = promptText.match(
      /(?:investigate|research|analyze|study|explore|understand|review)\s+(.{5,60}?)(?:\.|,|$|\n)/i
    );
    if (topicMatch) return topicMatch[1].trim().toLowerCase();

    const cleaned = promptText
      .replace(/^(please|can you|i need to|let's|we need to)\s+/i, '')
      .substring(0, 60)
      .trim();
    if (cleaned.length >= 5) return cleaned.toLowerCase();
  }
  return agentType.replace(/-/g, ' ');
}

/**
 * Generate a kebab-case skill name from a topic.
 */
function generateKebabSkillName(topic) {
  return topic
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .substring(0, 50)
    + '-analysis';
}

/**
 * Extract error text from a hook payload.
 *
 * PostToolUse (Bash) shapes vary across Claude Code versions:
 *  - Newer: { tool_response: { stdout, stderr, output } }
 *  - Older: { tool_output, stderr, stdout }
 *  - SubagentStop / explicit failures: { error, errorMessage }
 *
 * Returns the most specific text available (stderr preferred over stdout)
 * or '' if nothing useful is present.
 */
function extractErrorText(data) {
  const tr = data.tool_response || data.toolResponse || {};
  const candidates = [
    data.error,
    data.errorMessage,
    tr.stderr,
    data.stderr,
    tr.stdout,
    data.stdout,
    tr.output,
    data.tool_output,
    data.output
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim().length > 0) {
      return c;
    }
  }
  return '';
}

/**
 * Capture failure pattern from gate failure
 */
function captureFailurePattern(data) {
  const gate = data.gate || 'unknown';
  const errorText = extractErrorText(data);
  const signature = extractErrorSignature(errorText);

  // Skip-on-no-signature: if we can't extract anything useful, don't write
  // a noise entry. Better to lose a data point than pollute failures.json
  // with thousands of unknown/empty rows that all collapse onto a single
  // bucket (the failure mode this guard prevents).
  if (signature === 'unknown' && (!errorText || errorText.trim().length === 0)) {
    return;
  }

  const failures = loadFailures();

  // Look for existing similar failure
  const existingIdx = failures.failures.findIndex(
    f => f.context.gate === gate && f.pattern.error_signature === signature
  );

  if (existingIdx >= 0) {
    // Update existing
    const existing = failures.failures[existingIdx];
    existing.evidence.occurrences++;
    existing.confidence = Math.min(0.95, existing.confidence + 0.1);
    existing.lastSeen = new Date().toISOString();
  } else {
    // Add new failure
    failures.failures.push({
      id: generateId('fp'),
      type: 'failure',
      captured: new Date().toISOString(),
      lastSeen: new Date().toISOString(),
      context: {
        gate,
        error_type: signature
      },
      pattern: {
        description: `${gate} failure: ${signature}`,
        error_signature: signature,
        sample_error: sanitizeErrorText(errorText.substring(0, 200))
      },
      resolution: null,
      evidence: {
        occurrences: 1,
        resolution_success_rate: 0
      },
      confidence: 0.3,
      status: 'pending'
    });
  }

  failures.statistics.total_captured++;
  saveFailures(failures);
}

/**
 * Record resolution for a failure pattern
 */
function recordResolution(failureId, resolution) {
  const failures = loadFailures();

  const failure = failures.failures.find(f => f.id === failureId);
  if (failure) {
    failure.resolution = {
      description: resolution,
      recorded: new Date().toISOString()
    };
    failure.status = 'resolved';
    failure.confidence = Math.min(0.95, failure.confidence + 0.2);
    failures.statistics.total_resolved++;
    saveFailures(failures);
  }
}

/**
 * Main hook handler
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

  const eventName = data.hook_event_name || data.hookEventName;

  // SubagentStop - capture success patterns
  if (eventName === 'SubagentStop') {
    const failed = data.error || data.errorMessage || data.failed;
    if (!failed) {
      captureSuccessPattern(data);
    } else {
      captureFailurePattern(data);
    }
  }

  // PostToolUse - capture gate failures
  if (eventName === 'PostToolUse') {
    const exitCode = data.exit_code || data.exitCode;
    const toolName = data.tool_name || data.toolName;

    if (toolName === 'Bash' && exitCode !== 0) {
      const command = data.tool_input?.command || '';
      // Detect gate commands
      if (/npm (run )?(build|test)|dotnet (build|test)|cargo (build|test)/.test(command)) {
        captureFailurePattern({
          ...data,
          gate: command.includes('test') ? 'TEST' : 'BUILD'
        });
      }
    }
  }

  // Always continue
  console.log(JSON.stringify({ continue: true }));
}

// Only run main() when invoked as a hook script. When `require()`d from
// tests, exports must be importable without triggering stdin reads.
if (require.main === module) {
  main().catch(e => {
    // fail-open: advisory hook should not crash session
    console.error('[capture-learning] ERROR:', e.message);
    process.exit(0);
  });
}

// Export for testing
module.exports = {
  extractErrorSignature,
  extractErrorText,
  captureSuccessPattern,
  captureFailurePattern,
  recordResolution,
  detectKnowledgeCandidate,
  extractTopicFromData,
  generateKebabSkillName
};
