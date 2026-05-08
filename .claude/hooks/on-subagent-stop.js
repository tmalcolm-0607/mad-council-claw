#!/usr/bin/env node
/**
 * Hook: SubagentStop
 * Purpose: Collect subagent results and log completion metrics
 *
 * Enhanced with agent effectiveness tracking for Phase 3.2
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Metrics file path (project-local)
const METRICS_FILE = '.mad/metrics/agent-effectiveness.json';

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

/**
 * Find the project root directory by looking for .claude folder
 * Walks up from current directory until found
 */
function getProjectDir() {
  let dir = process.cwd();
  const root = path.parse(dir).root;

  while (dir !== root) {
    if (fs.existsSync(path.join(dir, '.claude'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }

  // Fallback to current directory
  return process.cwd();
}

/**
 * Estimate token count from text content
 * Rough approximation: ~4 characters per token for English text
 */
function estimateTokens(text) {
  if (!text) return 0;
  return Math.ceil(text.length / 4);
}

/**
 * Parse metrics from the subagent stop event data
 */
function parseMetrics(data, rawInput) {
  const metrics = {
    success: true,
    duration_ms: 0,
    tokens: 0,
    error_reason: null
  };

  // Check for success/failure indicators
  if (data.error || data.errorMessage || data.failed === true) {
    metrics.success = false;
    metrics.error_reason = data.error || data.errorMessage || data.error_reason || 'unknown';
  }

  // Extract duration if provided
  if (data.duration_ms) {
    metrics.duration_ms = data.duration_ms;
  } else if (data.duration) {
    // Handle duration in seconds
    metrics.duration_ms = data.duration * 1000;
  } else if (data.startTime && data.endTime) {
    // Calculate from start/end times
    const start = new Date(data.startTime).getTime();
    const end = new Date(data.endTime).getTime();
    if (!isNaN(start) && !isNaN(end)) {
      metrics.duration_ms = end - start;
    }
  }

  // Extract or estimate token usage
  if (data.tokens_used) {
    metrics.tokens = data.tokens_used;
  } else if (data.tokensUsed) {
    metrics.tokens = data.tokensUsed;
  } else if (data.output) {
    // Estimate from output length
    metrics.tokens = estimateTokens(data.output);
  } else if (data.result) {
    // Estimate from result
    metrics.tokens = estimateTokens(JSON.stringify(data.result));
  } else {
    // Estimate from raw input as fallback
    metrics.tokens = estimateTokens(rawInput);
  }

  return metrics;
}

/**
 * Update agent effectiveness metrics in the project-local metrics file
 */
function updateAgentMetrics(agentType, metrics) {
  const projectDir = getProjectDir();
  const metricsPath = path.join(projectDir, METRICS_FILE);
  const metricsDir = path.dirname(metricsPath);

  // Ensure metrics directory exists
  ensureDir(metricsDir);

  // Read existing or create default
  let data = {
    schema_version: '1.0.0',
    lastUpdated: null,
    agents: {}
  };

  try {
    if (fs.existsSync(metricsPath)) {
      const content = fs.readFileSync(metricsPath, 'utf8');
      const parsed = JSON.parse(content);
      // Validate it has expected structure
      if (parsed && typeof parsed.agents === 'object') {
        data = parsed;
      }
    }
  } catch {
    // Use default if file is corrupted or unreadable
  }

  // Initialize agent entry if needed
  if (!data.agents[agentType]) {
    data.agents[agentType] = {
      invocations: 0,
      successes: 0,
      failures: 0,
      total_duration_ms: 0,
      total_tokens: 0,
      failure_reasons: {}
    };
  }

  const agent = data.agents[agentType];

  // Update counters
  agent.invocations++;

  if (metrics.success) {
    agent.successes++;
  } else {
    agent.failures++;
    const reason = normalizeErrorReason(metrics.error_reason);
    agent.failure_reasons[reason] = (agent.failure_reasons[reason] || 0) + 1;
  }

  // Update totals
  agent.total_duration_ms += metrics.duration_ms || 0;
  agent.total_tokens += metrics.tokens || 0;

  // Calculate derived metrics
  agent.success_rate = agent.invocations > 0
    ? agent.successes / agent.invocations
    : 0;
  agent.avg_duration_ms = agent.invocations > 0
    ? Math.round(agent.total_duration_ms / agent.invocations)
    : 0;
  agent.avg_tokens = agent.invocations > 0
    ? Math.round(agent.total_tokens / agent.invocations)
    : 0;

  // Update timestamp
  data.lastUpdated = new Date().toISOString();

  // Write atomically using temp file
  const tempPath = metricsPath + '.tmp';
  try {
    fs.writeFileSync(tempPath, JSON.stringify(data, null, 2));
    fs.renameSync(tempPath, metricsPath);
  } catch (err) {
    // Try direct write if rename fails (Windows sometimes has issues)
    try {
      fs.writeFileSync(metricsPath, JSON.stringify(data, null, 2));
    } catch {
      // Silently fail - metrics are nice-to-have, not critical
    }
    // Clean up temp file if it exists
    try {
      if (fs.existsSync(tempPath)) {
        fs.unlinkSync(tempPath);
      }
    } catch {
      // Ignore cleanup errors
    }
  }
}

/**
 * Check if a subagent session qualifies for knowledge extraction.
 * Long investigation/research sessions (>= threshold) are captured
 * as knowledge extraction prompts for later skill generation.
 *
 * @param {string} subagentType - The type of subagent
 * @param {object} metrics - Parsed metrics with duration_ms, success
 * @param {object} data - Raw event data (may contain prompt/topic info)
 */
function checkKnowledgeExtraction(subagentType, metrics, data) {
  // Only process successful investigation/research agents
  if (!metrics.success) return;
  if (!subagentType || subagentType === 'unknown') return;

  const typeLower = subagentType.toLowerCase();
  const isKnowledgeAgent = typeLower.includes('investigator') || typeLower.includes('research');
  if (!isKnowledgeAgent) return;

  // Read threshold from environment variable, default 600000 (10 minutes)
  const envThreshold = process.env.KNOWLEDGE_EXTRACTION_MIN_DURATION_MS;
  let thresholdMs = 600000;
  if (envThreshold) {
    const parsed = parseInt(envThreshold, 10);
    if (!isNaN(parsed)) {
      // Clamp to 1 minute - 60 minutes range
      thresholdMs = Math.max(60000, Math.min(3600000, parsed));
    }
  }

  if (!metrics.duration_ms || metrics.duration_ms < thresholdMs) return;

  // Extract topic from agent prompt or data
  const topic = extractTopic(data, subagentType);
  const suggestedSkillName = generateSkillName(topic);
  const durationMinutes = Math.round(metrics.duration_ms / 60000);
  const timestamp = new Date().toISOString();

  const knowledgePrompt = {
    timestamp,
    agentType: subagentType,
    durationMs: metrics.duration_ms,
    durationMinutes,
    topic,
    suggestedSkillName,
    status: 'pending_extraction',
    extractionPrompt: `This investigation took ${durationMinutes} minutes and uncovered valuable patterns about ${topic}. Consider extracting as a reusable skill.`
  };

  // Write knowledge prompt to disk
  const projectDir = getProjectDir();
  const promptsDir = path.join(projectDir, '.mad', 'scratch', 'knowledge-prompts');
  ensureDir(promptsDir);

  const fileTimestamp = timestamp.replace(/[:.]/g, '-');
  const promptPath = path.join(promptsDir, `${fileTimestamp}.json`);

  try {
    fs.writeFileSync(promptPath, JSON.stringify(knowledgePrompt, null, 2));
  } catch {
    // Non-critical: silently fail if write fails
  }
}

/**
 * Extract a topic keyword from agent data.
 * Attempts to parse from prompt text, falls back to agent type.
 */
function extractTopic(data, agentType) {
  // Try to get topic from prompt or task description
  const promptText = data.prompt || data.task || data.description || data.topic || '';

  if (promptText) {
    // Try to extract meaningful topic from first sentence/phrase
    // Look for patterns like "investigate X", "research Y", "analyze Z"
    const topicMatch = promptText.match(
      /(?:investigate|research|analyze|study|explore|understand|review)\s+(.{5,60}?)(?:\.|,|$|\n)/i
    );
    if (topicMatch) {
      return topicMatch[1].trim().toLowerCase();
    }

    // Fall back to first meaningful phrase (skip common prefixes)
    const cleaned = promptText
      .replace(/^(please|can you|i need to|let's|we need to)\s+/i, '')
      .substring(0, 60)
      .trim();
    if (cleaned.length >= 5) {
      return cleaned.toLowerCase();
    }
  }

  // Fall back to agent type as topic
  return agentType.replace(/-/g, ' ');
}

/**
 * Generate a kebab-case skill name from a topic string.
 */
function generateSkillName(topic) {
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
 * Normalize error reasons to consistent categories
 */
function normalizeErrorReason(reason) {
  if (!reason) return 'unknown';

  const reasonLower = String(reason).toLowerCase();

  // Map common error patterns to categories
  if (reasonLower.includes('timeout') || reasonLower.includes('timed out')) {
    return 'timeout';
  }
  if (reasonLower.includes('context') || reasonLower.includes('token limit') || reasonLower.includes('too long')) {
    return 'context_overflow';
  }
  if (reasonLower.includes('validation') || reasonLower.includes('invalid')) {
    return 'validation_error';
  }
  if (reasonLower.includes('permission') || reasonLower.includes('denied') || reasonLower.includes('unauthorized')) {
    return 'permission_error';
  }
  if (reasonLower.includes('network') || reasonLower.includes('connection') || reasonLower.includes('unreachable')) {
    return 'network_error';
  }
  if (reasonLower.includes('rate limit') || reasonLower.includes('throttl')) {
    return 'rate_limited';
  }
  if (reasonLower.includes('cancelled') || reasonLower.includes('canceled') || reasonLower.includes('abort')) {
    return 'cancelled';
  }

  // Return original if no pattern matches (truncate if too long)
  return reason.length > 50 ? reason.substring(0, 47) + '...' : reason;
}

async function main() {
  try {
    const input = await readStdin();
    let subagentType = 'unknown';
    let subagentId = 'unknown';
    let data = {};

    try {
      data = JSON.parse(input);
      // Support both subagentType and agent_type field names
      subagentType = data.subagentType || data.agent_type || data.agentType || 'unknown';
      subagentId = data.subagentId || data.agent_id || data.agentId || 'unknown';
    } catch {
      // Use defaults
    }

    const timestamp = new Date().toISOString();
    const claudeDir = path.join(os.homedir(), '.claude');
    ensureDir(claudeDir);

    // Log subagent completion (original behavior)
    const logFile = path.join(claudeDir, 'subagent-metrics.log');
    const logEntry = JSON.stringify({
      event: 'subagent_stop',
      type: subagentType,
      id: subagentId,
      timestamp
    }) + '\n';

    try {
      fs.appendFileSync(logFile, logEntry);
    } catch {
      // Ignore
    }

    // NEW: Update agent effectiveness metrics (Phase 3.2)
    if (subagentType !== 'unknown') {
      try {
        const metrics = parseMetrics(data, input);
        updateAgentMetrics(subagentType, metrics);

        // Knowledge extraction detection (Pattern 3)
        try {
          checkKnowledgeExtraction(subagentType, metrics, data);
        } catch {
          // Knowledge extraction failure should not affect hook response
        }
      } catch {
        // Metrics update failure should not affect hook response
      }
    }

    console.log(JSON.stringify({ continue: true }));
  } catch (error) {
    // fail-open: advisory hook should not crash session
    console.error('[on-subagent-stop] ERROR:', error.message);
    process.exit(0);
  }
}

main();
