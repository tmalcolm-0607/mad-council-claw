#!/usr/bin/env node
/**
 * Hook: SubagentStop (command type)
 * Purpose: Validate that agents writing to review scratch dirs produced their deliverable files.
 *
 * On SubagentStop, checks if expected output files exist and have non-trivial content (>5 lines).
 * Uses naming conventions to map agent context to expected file paths:
 *   - Baseline agents: .mad/scratch/review-{ID}/baselines/{repo}-patterns.md
 *   - Cross-ref agents: .mad/scratch/review-{ID}/findings/crossref-{repo}.md
 *   - Consistency agents: .mad/scratch/review-{ID}/findings/architecture.md (shared with architecture)
 *   - Community research: .mad/scratch/review-{ID}/findings/research-results.md
 *   - Domain reviewers: findings returned in-memory (skip file check)
 *
 * Non-blocking: always exits 0 with warnings on stderr.
 * Logs failures to .mad/scratch/review-{ID}/failures.log
 */

const fs = require('fs');
const path = require('path');

const MIN_CONTENT_LINES = 5;

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
 * Find all active review directories (have manifest.json)
 */
function findActiveReviewDirs(projectDir) {
  const scratchDir = path.join(projectDir, '.mad', 'scratch');
  if (!fs.existsSync(scratchDir)) return [];

  try {
    return fs.readdirSync(scratchDir, { withFileTypes: true })
      .filter(d => d.isDirectory() && d.name.startsWith('review-'))
      .filter(d => {
        const manifest = path.join(scratchDir, d.name, 'manifest.json');
        return fs.existsSync(manifest);
      })
      .map(d => ({
        dir: path.join(scratchDir, d.name),
        id: d.name.replace('review-', '')
      }));
  } catch {
    return [];
  }
}

/**
 * Count non-empty lines in a file
 */
function countContentLines(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return content.split('\n').filter(line => line.trim().length > 0).length;
  } catch {
    return 0;
  }
}

/**
 * Detect what kind of deliverable this agent was supposed to produce
 * by examining the agent's description/prompt for review-related keywords
 */
function detectExpectedDeliverables(data, reviewDir) {
  const prompt = (data.prompt || data.description || data.task || '').toLowerCase();
  const agentType = data.subagentType || data.agent_type || data.agentType || '';
  const deliverables = [];

  // Skip domain-reviewers — they return findings in-memory
  if (agentType === 'domain-reviewer') {
    return deliverables;
  }

  // Baseline extraction: look for "baseline" or "pattern summary" keywords
  if (prompt.includes('baseline') || prompt.includes('pattern summary') || (prompt.includes('extract') && prompt.includes('patterns'))) {
    const baselinesDir = path.join(reviewDir, 'baselines');
    if (fs.existsSync(baselinesDir)) {
      // Check if any baseline file was expected but not created
      // We infer repo name from prompt
      const repoMatch = prompt.match(/from\s+(\S+?)[\s,.]/) ||
                         prompt.match(/(\w[\w-]+)\s+(?:repo|repository|patterns)/) ||
                         prompt.match(/baselines?[\\/](\S+?)-(?:patterns|master)\.md/);
      if (repoMatch) {
        const repo = repoMatch[1].toLowerCase().replace(/[^a-z0-9-]/g, '');
        // Detect if this is a master baseline (Phase 0.5) or repo baseline (Phase 1)
        const isMaster = prompt.includes('master') || prompt.includes('authority');
        const fileName = isMaster ? `${repo}-master.md` : `${repo}-patterns.md`;
        deliverables.push({
          type: isMaster ? 'master-baseline' : 'baseline',
          path: path.join(baselinesDir, fileName),
          description: isMaster ? `Master baseline for ${repo}` : `Baseline for ${repo}`
        });
      }
    }
  }

  // Cross-reference: look for "cross-ref" or "compare" keywords
  if (prompt.includes('cross-ref') || prompt.includes('crossref') || (prompt.includes('compare') && prompt.includes('pr'))) {
    const findingsDir = path.join(reviewDir, 'findings');
    const crossRefDir = path.join(reviewDir, 'cross-ref');

    const repoMatch = prompt.match(/against\s+(\S+?)[\s,.]/) ||
                       prompt.match(/(\w[\w-]+)\s+(?:repo|repository)/) ||
                       prompt.match(/crossref-(\S+?)\.md/);
    if (repoMatch) {
      const repo = repoMatch[1].toLowerCase().replace(/[^a-z0-9-]/g, '');
      // Check both possible locations
      deliverables.push({
        type: 'cross-ref',
        path: path.join(findingsDir, `crossref-${repo}.md`),
        altPath: path.join(crossRefDir, `${repo}.md`),
        description: `Cross-reference for ${repo}`
      });
    }
  }

  // Consistency check: look for "consistency" keywords
  if (prompt.includes('consistency') && (prompt.includes('drift') || prompt.includes('baseline') || prompt.includes('enforcement'))) {
    const findingsDir = path.join(reviewDir, 'findings');
    deliverables.push({
      type: 'consistency',
      path: path.join(findingsDir, 'architecture.md'),
      description: 'Architecture + consistency findings (shared agent)'
    });
  }

  // Community research: look for "research" or "community" keywords
  if ((prompt.includes('community') && prompt.includes('research')) || prompt.includes('needs_research')) {
    const findingsDir = path.join(reviewDir, 'findings');
    deliverables.push({
      type: 'community-research',
      path: path.join(findingsDir, 'research-results.md'),
      description: 'Community research results'
    });
  }

  // Explicit file path in prompt
  const filePathMatch = prompt.match(/write\s+(?:findings?\s+)?to\s+(\S+\.md)/i);
  if (filePathMatch) {
    const targetPath = filePathMatch[1];
    // Resolve relative to review dir or project dir
    const resolved = path.isAbsolute(targetPath)
      ? targetPath
      : path.join(reviewDir, targetPath);
    if (!deliverables.some(d => d.path === resolved)) {
      deliverables.push({
        type: 'explicit',
        path: resolved,
        description: `Explicit deliverable: ${path.basename(targetPath)}`
      });
    }
  }

  return deliverables;
}

/**
 * Log a failure to the review directory's failures.log
 */
function logFailure(reviewDir, message) {
  const logFile = path.join(reviewDir, 'failures.log');
  const timestamp = new Date().toISOString();
  const entry = `[${timestamp}] ${message}\n`;
  try {
    fs.appendFileSync(logFile, entry);
  } catch {
    // If we can't write the log, warn on stderr
    console.error(`Could not write to failures.log: ${message}`);
  }
}

async function main() {
  try {
    const input = await readStdin();
    let data = {};

    try {
      data = JSON.parse(input);
    } catch {
      process.exit(0);
    }

    const agentId = data.subagentId || data.agent_id || data.agentId || 'unknown';
    const agentType = data.subagentType || data.agent_type || data.agentType || 'unknown';
    const projectDir = getProjectDir();

    // Find active review directories
    const reviewDirs = findActiveReviewDirs(projectDir);
    if (reviewDirs.length === 0) {
      // No active reviews — not relevant
      process.exit(0);
    }

    // Check deliverables for each active review
    for (const { dir: reviewDir, id: reviewId } of reviewDirs) {
      const deliverables = detectExpectedDeliverables(data, reviewDir);

      for (const deliverable of deliverables) {
        const primaryExists = fs.existsSync(deliverable.path);
        const altExists = deliverable.altPath && fs.existsSync(deliverable.altPath);
        const existingPath = primaryExists ? deliverable.path : (altExists ? deliverable.altPath : null);

        if (!existingPath) {
          const msg = `MISSING DELIVERABLE [${agentType}:${agentId}]: ${deliverable.description} — expected at ${path.relative(projectDir, deliverable.path)}`;
          console.error(`WARNING: ${msg}`);
          logFailure(reviewDir, msg);
          continue;
        }

        const lineCount = countContentLines(existingPath);
        if (lineCount < MIN_CONTENT_LINES) {
          const msg = `TRIVIAL DELIVERABLE [${agentType}:${agentId}]: ${deliverable.description} — only ${lineCount} non-empty lines at ${path.relative(projectDir, existingPath)}`;
          console.error(`WARNING: ${msg}`);
          logFailure(reviewDir, msg);
        }
      }
    }

    // Always allow stop — this is a non-blocking warning hook
    process.exit(0);
  } catch (err) {
    // fail-open: advisory hook should not crash session
    console.error('[validate-agent-deliverable] ERROR:', err.message);
    process.exit(0);
  }
}

main();
