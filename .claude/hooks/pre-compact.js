#!/usr/bin/env node
/**
 * Hook: PreCompact
 * Purpose: Generate a minimal session handoff document before context compaction.
 *
 * Uses handoff-generator.js to capture workflow state (resume point, progress,
 * blockers, modified files) so the next session can continue seamlessly.
 *
 * Always outputs { continue: true } - compaction must never be blocked.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
let generateHandoff;
try {
  ({ generateHandoff } = require('../../.mad/lib/handoff-generator.js'));
} catch {
  generateHandoff = null;
}

/**
 * Read all of stdin as a string.
 * @returns {Promise<string>}
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Ensure a directory exists; silently ignore errors.
 * @param {string} dir - Directory path
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

async function main() {
  try {
    const input = await readStdin();
    let sessionId = 'unknown';

    try {
      const data = JSON.parse(input);
      sessionId = data.session_id || data.sessionId || 'unknown';
    } catch {
      // Use default
    }

    // Generate minimal handoff document (if handoff-generator is available)
    let result = { success: false };
    if (generateHandoff) {
      result = generateHandoff({
        reason: 'pre_compact_safety',
        tier: 'minimal'
      });
    }

    // Log to compaction.log in ~/.claude/
    const claudeDir = path.join(os.homedir(), '.claude');
    ensureDir(claudeDir);

    const logEntry = JSON.stringify({
      event: 'pre_compact',
      sessionId,
      handoffGenerated: result.success,
      handoffPath: result.handoffPath || null,
      workItemId: result.workItemId || null,
      timestamp: new Date().toISOString()
    }) + '\n';

    try {
      const logFile = path.join(claudeDir, 'compaction.log');
      fs.appendFileSync(logFile, logEntry);
    } catch {
      // Ignore - logging failure is non-fatal
    }

    // Notify via stderr (visible to user but does not affect hook protocol)
    if (result.success) {
      console.error(`PRE-COMPACT: Handoff document saved at ${result.handoffPath}. Resume in new session with /resume-handoff`);
    } else if (!generateHandoff) {
      console.error('PRE-COMPACT: handoff-generator.js not available, skipping handoff generation.');
    } else {
      console.error('PRE-COMPACT: Handoff generation failed. Session state may be lost.');
    }
  } catch (err) {
    // fail-open: advisory hook should not crash session
    console.error('[pre-compact] ERROR:', err.message);
    process.exit(0);
  }

  // If no errors, allow compaction to proceed
  console.log(JSON.stringify({ continue: true }));
}

main();
