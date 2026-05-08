#!/usr/bin/env node
/**
 * Hook: PermissionRequest
 * Purpose: Auto-approve safe operations to reduce permission prompts
 *
 * This hook auto-approves read-only and common development operations
 * while leaving potentially destructive operations to prompt the user.
 */

// Patterns that are safe to auto-approve
const AUTO_APPROVE_PATTERNS = [
  // Read-only git operations
  /^git\s+(status|log|diff|branch|show|describe|rev-parse|worktree list)/,
  // Read-only npm operations
  /^npm\s+(list|ls|view|info|outdated|audit)/,
  // Test and build commands
  /^npm\s+(test|run\s+(test|build|lint|check|typecheck))/,
  // Health checks and status
  /^curl\s+.*health/,
  /^docker\s+(ps|images|logs)/,
  /^pwd$/,
];

// Patterns that should always ask (never auto-approve)
const ALWAYS_ASK_PATTERNS = [
  /git\s+push/,
  /git\s+reset/,
  /git\s+rebase/,
  /npm\s+publish/,
  /docker\s+rm/,
  /rm\s+-rf/,
];

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Get the tool and command being requested
    const toolName = data.tool_name || '';
    const toolInput = data.tool_input || {};
    const command = toolInput.command || '';

    // Always ask for non-Bash tools (Read, Write, Edit handled separately)
    if (toolName !== 'Bash') {
      process.exit(0); // Let default behavior handle it
    }

    // Security: Reject compound commands (shell metacharacters)
    // Prevents bypass like "git status; rm -rf /" matching auto-approve pattern
    const SHELL_METACHARACTERS = /[;&|`$()<>\n\r]/;
    if (SHELL_METACHARACTERS.test(command)) {
      // Compound commands always require user approval
      process.exit(0);
    }

    // Check if command should always ask
    for (const pattern of ALWAYS_ASK_PATTERNS) {
      if (pattern.test(command)) {
        // Return without output - use default ask behavior
        process.exit(0);
      }
    }

    // Check if command can be auto-approved
    for (const pattern of AUTO_APPROVE_PATTERNS) {
      if (pattern.test(command)) {
        console.log(JSON.stringify({
          hookSpecificOutput: {
            hookEventName: 'PermissionRequest',
            permissionDecision: 'allow',
            permissionDecisionReason: `Auto-approved safe operation: ${command.substring(0, 50)}...`
          }
        }));
        process.exit(0);
      }
    }

    // Default: let the user decide
    process.exit(0);
  } catch {
    // On error, use default behavior
    process.exit(0);
  }
}

main();
