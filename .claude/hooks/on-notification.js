#!/usr/bin/env node
/**
 * Hook: Notification
 * Purpose: Log notifications, optionally send to external systems
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

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

async function main() {
  try {
    const input = await readStdin();
    let notifType = 'info';
    let notifMsg = '';

    try {
      const data = JSON.parse(input);
      notifType = data.type || 'info';
      notifMsg = data.message || '';
    } catch {
      // Use defaults
    }

    const timestamp = new Date().toISOString();
    const claudeDir = path.join(os.homedir(), '.claude');
    ensureDir(claudeDir);

    // Log notification
    const logFile = path.join(claudeDir, 'notifications.log');
    const logEntry = JSON.stringify({
      event: 'notification',
      type: notifType,
      message: notifMsg,
      timestamp
    }) + '\n';

    try {
      fs.appendFileSync(logFile, logEntry);
    } catch {
      // Ignore
    }

    // Optional: Send critical notifications to external system
    // Uncomment to enable:
    // if (notifType === 'error' && process.env.SLACK_WEBHOOK_URL) {
    //   const https = require('https');
    //   // Send to Slack...
    // }

    console.log(JSON.stringify({ acknowledged: true }));
  } catch (error) {
    // fail-open: advisory hook should not crash session
    console.error('[on-notification] ERROR:', error.message);
    process.exit(0);
  }
}

main();
