#!/usr/bin/env node
'use strict';

/**
 * context-metrics.js
 *
 * Shared library for context usage estimation (Context Guardian).
 *
 * Tracks estimated token consumption per session using a heuristic
 * (~4 chars per token) and compares against configurable thresholds.
 * Metrics are persisted in os.tmpdir() as JSON files so they survive
 * across hook invocations within the same session.
 *
 * Exports:
 *   getSessionId(data)               → string
 *   updateMetrics(sessionId, chars)  → metricsObj
 *   getThresholdStatus(metricsObj)   → { level, percentage, rawPercentage }
 *   getGrowthRate(metricsObj)        → number | null
 *   saveMetrics(sessionId, obj)      → void
 *   resetMetrics(sessionId)          → void
 *   getEffectiveCapacity()           → number (tokens)
 *   THRESHOLDS                       → { ADVISORY, PREPARE, HALT }
 *   GUARDIAN_RULE_PATH               → string
 *
 * Configuration (via env vars in .claude/settings.local.json):
 *   CONTEXT_GUARDIAN_ADVISORY_THRESHOLD  (default 0.50)
 *   CONTEXT_GUARDIAN_PREPARE_THRESHOLD   (default 0.70)
 *   CONTEXT_GUARDIAN_HALT_THRESHOLD      (default 0.85)
 *   CONTEXT_GUARDIAN_HIDDEN_BUFFER       (default 0.165)
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// ── Constants ─────────────────────────────────────────────────────────────────

/** Total context window reported by Claude Code (tokens). */
const TOTAL_CAPACITY = 200_000;

/** Rough chars-to-tokens ratio for English text. */
const CHARS_PER_TOKEN = 4;

/** Fraction of TOTAL_CAPACITY reserved for Claude Code internal overhead. */
const HIDDEN_BUFFER = parseFloat(
  process.env.CONTEXT_GUARDIAN_HIDDEN_BUFFER || '0.165'
);

/** Threshold fractions (applied to effective capacity). */
const THRESHOLDS = {
  ADVISORY: parseFloat(process.env.CONTEXT_GUARDIAN_ADVISORY_THRESHOLD || '0.50'),
  PREPARE:  parseFloat(process.env.CONTEXT_GUARDIAN_PREPARE_THRESHOLD  || '0.70'),
  HALT:     parseFloat(process.env.CONTEXT_GUARDIAN_HALT_THRESHOLD     || '0.85'),
};

/** Path shown in warning messages. */
const GUARDIAN_RULE_PATH = '.claude/rules/context-guardian.md';

/** File prefix for temp metrics files. */
const FILE_PREFIX = 'claude-context-metrics-';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Return the path to the temp metrics file for a session.
 * @param {string} sessionId
 * @returns {string}
 */
function metricsFilePath(sessionId) {
  const safe = (sessionId || 'default').replace(/[^a-zA-Z0-9_-]/g, '_');
  return path.join(os.tmpdir(), `${FILE_PREFIX}${safe}.json`);
}

/**
 * Load metrics from disk. Returns a blank object if the file is missing or invalid.
 * @param {string} sessionId
 * @returns {object}
 */
function loadMetrics(sessionId) {
  try {
    const raw = fs.readFileSync(metricsFilePath(sessionId), 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return blank(sessionId);
    if (!Array.isArray(parsed.entries)) parsed.entries = [];
    if (typeof parsed.promptCount !== 'number') parsed.promptCount = 0;
    return parsed;
  } catch {
    return blank(sessionId);
  }
}

/**
 * Create a blank metrics object.
 * @param {string} sessionId
 * @returns {object}
 */
function blank(sessionId) {
  return {
    sessionId,
    startTime: new Date().toISOString(),
    promptCount: 0,
    lastAdvisoryTurn: 0,
    entries: [],
  };
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Extract a stable session ID from hook event data.
 * @param {object} data - Hook stdin payload
 * @returns {string}
 */
function getSessionId(data) {
  if (data && typeof data === 'object') {
    const id = data.session_id || data.sessionId;
    if (id && typeof id === 'string') return id;
  }
  return process.env.CLAUDE_SESSION_ID || `session-${Date.now()}`;
}

/**
 * Effective token capacity after subtracting the hidden buffer.
 * @returns {number}
 */
function getEffectiveCapacity() {
  return Math.floor(TOTAL_CAPACITY * (1 - HIDDEN_BUFFER));
}

/**
 * Add a new prompt event to the metrics and save to disk.
 * @param {string} sessionId
 * @param {number} promptCharCount - Character length of the submitted prompt
 * @returns {object} Updated metrics object
 */
function updateMetrics(sessionId, promptCharCount) {
  try {
    const m = loadMetrics(sessionId);
    const estimatedTokens = Math.max(1, Math.round((promptCharCount || 0) / CHARS_PER_TOKEN));
    const prevCumulative = m.entries.length > 0
      ? m.entries[m.entries.length - 1].cumulativeTokens
      : 0;

    m.entries.push({
      promptLength: promptCharCount || 0,
      estimatedTokens,
      cumulativeTokens: prevCumulative + estimatedTokens,
      timestamp: new Date().toISOString(),
    });
    m.promptCount = (m.promptCount || 0) + 1;

    saveMetrics(sessionId, m);
    return m;
  } catch {
    return blank(sessionId);
  }
}

/**
 * Determine which threshold level applies to the current metrics.
 * @param {object} m - Metrics object (from updateMetrics / loadMetrics)
 * @returns {{ level: string, percentage: number, rawPercentage: number }}
 *   level: 'HALT' | 'PREPARE' | 'ADVISORY' | ''
 *   percentage: fraction of effective capacity (0–1+)
 *   rawPercentage: fraction of total capacity (0–1+)
 */
function getThresholdStatus(m) {
  const safe = {
    level: '',
    percentage: 0,
    rawPercentage: 0,
  };

  try {
    if (!m || !Array.isArray(m.entries) || m.entries.length === 0) return safe;

    const last = m.entries[m.entries.length - 1];
    const cumulative = last.cumulativeTokens || 0;
    const effective = getEffectiveCapacity();

    const percentage = cumulative / effective;
    const rawPercentage = cumulative / TOTAL_CAPACITY;

    let level = '';
    if (percentage >= THRESHOLDS.HALT) {
      level = 'HALT';
    } else if (percentage >= THRESHOLDS.PREPARE) {
      level = 'PREPARE';
    } else if (percentage >= THRESHOLDS.ADVISORY) {
      level = 'ADVISORY';
    }

    return { level, percentage, rawPercentage };
  } catch {
    return safe;
  }
}

/**
 * Estimate the average token growth rate over the last several turns.
 * @param {object} m - Metrics object
 * @returns {number|null} Tokens per turn, or null if insufficient data
 */
function getGrowthRate(m) {
  try {
    if (!m || !Array.isArray(m.entries) || m.entries.length < 2) return null;

    const window = m.entries.slice(-5); // last 5 entries
    const totalTokens = window.reduce((sum, e) => sum + (e.estimatedTokens || 0), 0);
    return Math.round(totalTokens / window.length);
  } catch {
    return null;
  }
}

/**
 * Persist metrics to disk. Best-effort — never throws.
 * @param {string} sessionId
 * @param {object} m - Metrics object
 */
function saveMetrics(sessionId, m) {
  try {
    fs.writeFileSync(metricsFilePath(sessionId), JSON.stringify(m, null, 2), 'utf8');
  } catch {
    // Non-fatal
  }
}

/**
 * Reset metrics for a session (called at session start for a fresh baseline).
 * @param {string} sessionId
 */
function resetMetrics(sessionId) {
  try {
    const filePath = metricsFilePath(sessionId);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  } catch {
    // Non-fatal
  }
}

// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
  getSessionId,
  getEffectiveCapacity,
  updateMetrics,
  getThresholdStatus,
  getGrowthRate,
  saveMetrics,
  resetMetrics,
  THRESHOLDS,
  GUARDIAN_RULE_PATH,
};
