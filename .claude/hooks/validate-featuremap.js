#!/usr/bin/env node
/**
 * Hook: SubagentStop
 * Purpose: Non-blocking staleness warnings for docs/00-PROJECT/_featuremap.md
 *
 * Triggers on SubagentStop when agent type is mad-implement or mad-validate.
 * Checks featuremap existence, staleness, and sync with feature-traceability.md.
 * Logs warnings to .mad/scratch/featuremap-warnings.log.
 * NEVER blocks execution - informational warnings only.
 */

const fs = require('fs');
const path = require('path');

// Default staleness threshold in days (configurable via config.json or FEATUREMAP_STALENESS_DAYS env var)
const DEFAULT_STALENESS_DAYS = 7;

// Default agent types that trigger this hook (overridden by config.json)
const DEFAULT_TRIGGER_AGENT_TYPES = ['mad-implement', 'mad-validate'];

/**
 * Load hook configuration from .claude/hooks/config.json
 * Falls back to defaults if file missing or invalid
 */
function loadConfig() {
  const configPath = path.join(__dirname, 'config.json');
  try {
    if (fs.existsSync(configPath)) {
      const raw = fs.readFileSync(configPath, 'utf8');
      const config = JSON.parse(raw);
      return config['validate-featuremap'] || {};
    }
  } catch {
    // Fall back to defaults on any error
  }
  return {};
}

const CONFIG = loadConfig();

// Hook enabled flag (default: true)
const HOOK_ENABLED = CONFIG.enabled !== false;

// Agent types from config or defaults
const TRIGGER_AGENT_TYPES = (CONFIG.filters && CONFIG.filters.agentType) || DEFAULT_TRIGGER_AGENT_TYPES;

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Find the project root directory by looking for .claude folder
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

  return process.cwd();
}

/**
 * Ensure a directory exists, creating it recursively if needed
 */
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
 * Parse last_updated from file content.
 * Supports:
 *   - YAML frontmatter: last_updated: 2026-02-09
 *   - Markdown bold: **Last Updated**: 2026-02-09
 *   - Markdown bold: **last_updated**: 2026-02-09
 */
function parseLastUpdated(content) {
  // YAML frontmatter
  const frontmatterMatch = content.match(/^---\s*\n[\s\S]*?last_updated:\s*(\S+)[\s\S]*?\n---/m);
  if (frontmatterMatch) {
    const date = new Date(frontmatterMatch[1]);
    if (!isNaN(date.getTime())) return date;
  }

  // Markdown bold pattern: **Last Updated**: DATE or **last_updated**: DATE
  const markdownMatch = content.match(/\*\*(?:Last Updated|last_updated)\*\*:\s*(\S+)/i);
  if (markdownMatch) {
    const date = new Date(markdownMatch[1]);
    if (!isNaN(date.getTime())) return date;
  }

  return null;
}

/**
 * Count feature IDs matching pattern M\d+-US\d+-F\d+ in file content
 */
function countFeatures(content) {
  const matches = content.match(/M\d+-US\d+-F\d+/g);
  if (!matches) return 0;
  // Return unique count
  return new Set(matches).size;
}

/**
 * Log a warning to the scratch warnings log file
 */
function logWarning(projectDir, message) {
  const scratchDir = path.join(projectDir, '.mad', 'scratch');
  ensureDir(scratchDir);

  const logFile = path.join(scratchDir, 'featuremap-warnings.log');
  const timestamp = new Date().toISOString();
  const entry = `[${timestamp}] ${message}\n`;

  try {
    fs.appendFileSync(logFile, entry);
  } catch {
    // If we can't write the log, emit on stderr
    console.error(`Could not write to featuremap-warnings.log: ${message}`);
  }
}

/**
 * Get staleness threshold in days from config.json, environment, or default
 * Priority: env var > config.json > default
 */
function getStalenessThresholdDays() {
  const envVal = process.env.FEATUREMAP_STALENESS_DAYS;
  if (envVal) {
    const parsed = parseInt(envVal, 10);
    if (!isNaN(parsed) && parsed > 0) return parsed;
  }
  if (CONFIG.staleness_threshold_days && typeof CONFIG.staleness_threshold_days === 'number' && CONFIG.staleness_threshold_days > 0) {
    return CONFIG.staleness_threshold_days;
  }
  return DEFAULT_STALENESS_DAYS;
}

async function main() {
  try {
    // Check if hook is enabled via config.json
    if (!HOOK_ENABLED) {
      process.exit(0);
    }

    const input = await readStdin();
    let data = {};

    try {
      data = JSON.parse(input);
    } catch {
      // Not valid JSON, nothing to do
      process.exit(0);
    }

    // Determine agent type
    const agentType = data.subagentType || data.agent_type || data.agentType || '';

    // Only trigger for mad-implement and mad-validate
    if (!TRIGGER_AGENT_TYPES.includes(agentType)) {
      process.exit(0);
    }

    const projectDir = getProjectDir();
    const featuremapPath = path.join(projectDir, 'docs', '00-PROJECT', '_featuremap.md');
    const traceabilityPath = path.join(projectDir, 'docs', '00-PROJECT', 'feature-traceability.md');
    const warnings = [];

    // Check 1: Does _featuremap.md exist?
    if (!fs.existsSync(featuremapPath)) {
      const msg = 'Feature map (docs/00-PROJECT/_featuremap.md) does not exist. Consider creating it to track feature validation.';
      warnings.push(msg);
    } else {
      const featuremapContent = fs.readFileSync(featuremapPath, 'utf8');

      // Check 2: Staleness - check last_updated timestamp
      const lastUpdated = parseLastUpdated(featuremapContent);
      if (lastUpdated) {
        const thresholdDays = getStalenessThresholdDays();
        const ageMs = Date.now() - lastUpdated.getTime();
        const ageDays = ageMs / (1000 * 60 * 60 * 24);

        if (ageDays > thresholdDays) {
          const msg = `Feature map may be stale (last updated ${Math.floor(ageDays)} days ago, threshold: ${thresholdDays} days)`;
          warnings.push(msg);
        }
      } else {
        warnings.push('Feature map has no last_updated timestamp - cannot check staleness');
      }

      // Check 3: Sync with feature-traceability.md
      if (fs.existsSync(traceabilityPath)) {
        const traceabilityContent = fs.readFileSync(traceabilityPath, 'utf8');
        const mapFeatureCount = countFeatures(featuremapContent);
        const traceFeatureCount = countFeatures(traceabilityContent);

        if (mapFeatureCount !== traceFeatureCount) {
          const msg = `Feature map out of sync (${traceFeatureCount} features in traceability, ${mapFeatureCount} in map)`;
          warnings.push(msg);
        }
      }
    }

    // Emit warnings (non-blocking)
    if (warnings.length > 0) {
      for (const warning of warnings) {
        console.error(`[validate-featuremap] WARNING: ${warning}`);
        logWarning(projectDir, warning);
      }
    }

    // Always exit 0 - this hook is non-blocking
    process.exit(0);
  } catch (error) {
    // Even on error, do NOT block - this is informational only
    console.error(`[validate-featuremap] ERROR: ${error.message}`);
    process.exit(0);
  }
}

main();
