#!/usr/bin/env node
/**
 * Hook: SessionStart
 * Purpose: Initialize session environment
 *
 * This hook runs at session start to set up environment
 * variables and check prerequisites.
 */

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

function getVersion(command, parser) {
  try {
    const output = execSync(command, { encoding: 'utf8', stdio: 'pipe' }).trim();
    return parser ? parser(output) : output;
  } catch {
    return null;
  }
}

function checkDockerRunning() {
  try {
    execSync('docker info', { stdio: 'pipe' });
    return 'running';
  } catch {
    return 'installed (not running)';
  }
}

function main() {
  const prereqs = [];

  // Check Node.js
  const nodeVersion = getVersion('node --version');
  if (nodeVersion) {
    prereqs.push(`Node.js: ${nodeVersion}`);
  }

  // Check Docker
  try {
    execSync('docker --version', { stdio: 'pipe' });
    prereqs.push(`Docker: ${checkDockerRunning()}`);
  } catch {
    // Docker not installed
  }

  // Check Git
  const gitVersion = getVersion('git --version', (output) => {
    const match = output.match(/git version ([\d.]+)/);
    return match ? match[1] : output;
  });
  if (gitVersion) {
    prereqs.push(`Git: ${gitVersion}`);
  }

  // Check .NET SDK
  const dotnetVersion = getVersion('dotnet --version');
  if (dotnetVersion) {
    prereqs.push(`.NET SDK: ${dotnetVersion}`);
  }

  // Write session start marker for session-end.js duration calculation
  try {
    const sessionId = process.env.CLAUDE_SESSION_ID || 'default';
    const startFile = path.join(os.tmpdir(), `claude_session_${sessionId}_start`);
    fs.writeFileSync(startFile, Math.floor(Date.now() / 1000).toString());
    const startIsoFile = path.join(os.tmpdir(), `claude_session_${sessionId}_start_iso`);
    fs.writeFileSync(startIsoFile, new Date().toISOString());
  } catch {
    // Ignore errors writing session start marker
  }

  // Check for pending handoff from previous session
  try {
    const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
    // SessionStart Notification hooks do not receive tool-use session_id in payload;
    // resolveActiveWI falls back to CLAUDE_SESSION_ID env var or 'default'
    const { wiId } = resolveActiveWI(null, projectDir);
    if (wiId) {
        const handoffPointer = path.join(projectDir, '.claude', 'work-items', wiId, 'PENDING_HANDOFF');
        if (fs.existsSync(handoffPointer)) {
          const pointerContent = fs.readFileSync(handoffPointer, 'utf8').trim();
          const lines = pointerContent.split('\n');
          const handoffPath = lines[0];

          // Validate: check handoff file exists
          if (!handoffPath || !fs.existsSync(handoffPath)) {
            // Stale pointer - referenced file doesn't exist
            fs.unlinkSync(handoffPointer);
          } else {
            // TTL check: if older than 24h, auto-delete
            const pointerStat = fs.statSync(handoffPointer);
            const ageMs = Date.now() - pointerStat.mtimeMs;
            if (ageMs > 24 * 60 * 60 * 1000) {
              fs.unlinkSync(handoffPointer);
              console.error('[HANDOFF] Expired handoff found (>24h old). Deleted stale pointer.');
            } else {
              // Valid handoff - notify user
              console.log('[HANDOFF] Previous session handoff pending. Run /resume-handoff to continue from where you left off.');
            }
          }
        }
    }
  } catch {
    // Don't block session start for handoff detection errors
  }

  // Reset context metrics for fresh session
  try {
    const contextMetrics = require('../../.mad/lib/context-metrics.js');
    const sessionId = process.env.CLAUDE_SESSION_ID || `session-${Date.now()}`;
    contextMetrics.resetMetrics(sessionId);
  } catch {
    // context-metrics.js may not exist yet, ignore
  }

  // Clean up old context metrics files (>24h)
  try {
    const tmpDir = os.tmpdir();
    const tmpFiles = fs.readdirSync(tmpDir);
    const now = Date.now();
    const DAY_MS = 24 * 60 * 60 * 1000;
    for (const f of tmpFiles) {
      if (f.startsWith('claude-context-metrics-') && f.endsWith('.json')) {
        const fp = path.join(tmpDir, f);
        const stat = fs.statSync(fp);
        if (now - stat.mtimeMs > DAY_MS) {
          fs.unlinkSync(fp);
        }
      }
    }
  } catch {
    // Best effort cleanup
  }

  // Set up environment file if available
  if (process.env.CLAUDE_ENV_FILE) {
    try {
      const envContent = [
        'export PATH="$PATH:./node_modules/.bin"',
        'export NODE_ENV="${NODE_ENV:-development}"'
      ].join('\n') + '\n';
      fs.appendFileSync(process.env.CLAUDE_ENV_FILE, envContent);
    } catch {
      // Ignore errors
    }
  }

  // Output status
  if (prereqs.length > 0) {
    console.log(`Environment: ${prereqs.join(', ')}`);
  }

  // ── Consolidated from check-active-work-item-staleness.js ──
  // Calls the delegate script with cooldown + feature flag support
  try {
    const sessionId = process.env.CLAUDE_SESSION_ID || 'default';

    // Cooldown: only warn once per 10 minutes per session
    const STALE_COOLDOWN_MS = 10 * 60 * 1000;
    const staleMarker = path.join(os.tmpdir(), `claude-active-stale-${sessionId}`);
    let staleRecentlyWarned = false;
    try {
      if (fs.existsSync(staleMarker)) {
        const stats = fs.statSync(staleMarker);
        staleRecentlyWarned = (Date.now() - stats.mtimeMs) < STALE_COOLDOWN_MS;
      }
    } catch { /* ignore */ }

    if (!staleRecentlyWarned) {
      const staleProjectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
      const stalenessScript = path.join(staleProjectDir, '.claude', 'scripts', 'check-active-work-item-staleness.js');
      const staleStrict = process.env.WORK_ITEM_STALE_STRICT_STATUS === '1';
      const staleResult = spawnSync('node', [stalenessScript, ...(staleStrict ? ['--strict-status'] : [])], {
        cwd: staleProjectDir,
        encoding: 'utf8',
        timeout: 8000,
      });
      if (staleResult.stderr) {
        console.error(staleResult.stderr.trim());
        // Mark warned so we don't repeat within cooldown
        try { fs.writeFileSync(staleMarker, new Date().toISOString()); } catch { /* ignore */ }
      }
      // Note: strict mode exit code is intentionally ignored here (fail-open)
    }
  } catch {
    // Fail-open: staleness check errors are non-fatal
  }

  // ── Consolidated from validate-work-item-integrity.js ──
  // Calls the delegate script with feature flag support
  try {
    const integrityProjectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
    const integrityScript = path.join(integrityProjectDir, '.claude', 'scripts', 'validate-work-items.js');
    const integrityStrict = process.env.WORK_ITEM_STRICT === '1';
    const integrityResult = spawnSync('node', [integrityScript, ...(integrityStrict ? ['--strict'] : [])], {
      cwd: integrityProjectDir,
      encoding: 'utf8',
      timeout: 8000,
    });
    if (integrityResult.stdout) {
      console.error(integrityResult.stdout.trim());
    }
    if (integrityResult.stderr) {
      console.error(integrityResult.stderr.trim());
    }
    // Note: strict mode exit code is intentionally ignored here (fail-open)
  } catch {
    // Fail-open: integrity check errors are non-fatal
  }

  // ── Consolidated from work-item-required.js ──
  // Inline ACTIVE-file check with WORK_ITEM_STRICT feature flag
  try {
    const sessionId = process.env.CLAUDE_SESSION_ID || 'default';

    // Cooldown: only warn once per 10 minutes per session
    const WI_COOLDOWN_MS = 10 * 60 * 1000;
    const wiMarker = path.join(os.tmpdir(), `claude-work-item-warned-${sessionId}`);
    let wiRecentlyWarned = false;
    try {
      if (fs.existsSync(wiMarker)) {
        const stats = fs.statSync(wiMarker);
        wiRecentlyWarned = (Date.now() - stats.mtimeMs) < WI_COOLDOWN_MS;
      }
    } catch { /* ignore */ }

    if (!wiRecentlyWarned) {
      const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
      const { wiId: activeWiId } = resolveActiveWI(null, projectDir);

      let needsWarning = false;
      let warningDetail = '';

      if (!activeWiId) {
        needsWarning = true;
        warningDetail = 'No active work item set.';
      } else {
        // Verify manifest exists
        const wiManifest = path.join(projectDir, '.claude', 'work-items', activeWiId, 'manifest.json');
        if (!fs.existsSync(wiManifest)) {
          needsWarning = true;
          warningDetail = `Work item "${activeWiId}" is set but manifest.json not found.`;
        }
      }

      if (needsWarning) {
        console.error(`[work-item-required] WARNING: ${warningDetail}`);
        console.error('  Without an active work item, artifacts go to .mad/scratch/ (ephemeral).');
        console.error('  To fix: create a work item with /mad-spec or set one manually.');
        try { fs.writeFileSync(wiMarker, new Date().toISOString()); } catch { /* ignore */ }
      }
    }
  } catch {
    // Fail-open: work-item check errors are non-fatal
  }
}

try {
  main();
} catch (err) {
  // Fail-open: don't block session start on unexpected errors
  console.error('[session-start] Error:', err.message);
  process.exit(0);
}
