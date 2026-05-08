#!/usr/bin/env node
/**
 * Hook: PreToolUse (Bash)
 * Purpose: Validate bash commands before execution
 *
 * This hook checks for potentially dangerous commands and
 * blocks them or warns the user.
 */

const DANGEROUS_PATTERNS = [
  /rm\s+-rf\s+\//,
  /rm\s+-rf\s+\/\*/,
  /rm\s+-rf\s+~/,
  /rm\s+-rf\s+\$HOME/,
  /:\(\)\{\s*:\|:&\s*\};:/,  // Fork bomb
  /mkfs/,
  /dd\s+if=\/dev\/zero/,
  /chmod\s+-R\s+777\s+\//,
  />\s*\/dev\/sda/,
  /curl.*\|.*sh/,
  /wget.*\|.*sh/,
  // Windows-specific dangerous patterns
  /(?<!dotnet\s)format\s+[A-Z]:/i,
  /del\s+.*\/[sq].*\/[sq].*[A-Z]:\\/i,
  /Remove-Item\s+.*(-Recurse|-Force).*(-Recurse|-Force).*[A-Z]:\\/i,
  /diskpart/i,
  /cipher\s+\/w:/i,
  /reg\s+delete/i,
  /icacls\s+.*\/grant\s+Everyone/i,
  /net\s+user\s+\w+\s+/i,
];

const WARN_PATTERNS = [
  { pattern: /DROP\s+TABLE/i, name: 'DROP TABLE' },
  { pattern: /DROP\s+DATABASE/i, name: 'DROP DATABASE' },
  { pattern: /TRUNCATE/i, name: 'TRUNCATE' },
  { pattern: /DELETE\s+FROM.*WHERE\s+1=1/i, name: 'DELETE FROM...WHERE 1=1' },
  { pattern: /git\s+push.*--force\b(?!-with-lease)/i, name: 'git push --force' },
  { pattern: /git\s+reset\s+--hard/i, name: 'git reset --hard' },
  { pattern: /git\s+push\b(?!.*--force)(?!.*--dry-run)/i, name: 'PUSH GUARD', pushGuard: true },
];

const fs = require('fs');
const path = require('path');

const GATES_LAST_RUN_FILE = path.join(__dirname, '..', '..', '.mad', 'scratch', 'gates-last-run.json');

/**
 * Check gate-status freshness. Returns an advisory string or empty string.
 */
function getGateStatusAdvisory() {
  try {
    if (!fs.existsSync(GATES_LAST_RUN_FILE)) {
      return '\n\n⚠️ Quality gates have not been run this session. Run `powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1` before pushing.';
    }
    const data = JSON.parse(fs.readFileSync(GATES_LAST_RUN_FILE, 'utf-8'));
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (data.timestamp && (nowSeconds - data.timestamp) > 1800) {
      return '\n\n⚠️ Quality gates were last run >30 minutes ago. Consider re-running before pushing.';
    }
  } catch {
    // Cannot read gate status — treat as not run
    return '\n\n⚠️ Quality gates have not been run this session. Run `powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1` before pushing.';
  }
  return '';
}

// Shell escaping checks - produce warnings (non-blocking)
const SHELL_ESCAPE_CHECKS = [
  {
    // Missing MSYS_NO_PATHCONV=1 before az commands with route parameters
    pattern: /(?<!MSYS_NO_PATHCONV=1\s)az\s+.*\/(?!dev\/null)/,
    skip: /MSYS_NO_PATHCONV/,
    name: 'Missing MSYS_NO_PATHCONV=1 before az command with route parameter (Windows Git Bash path mangling)'
  },
  {
    // $args usage in PowerShell commands (reserved variable)
    pattern: /(?:powershell|pwsh|\.ps1).*\$args\b/i,
    name: '$args is a reserved PowerShell variable - use $Arguments or named parameters'
  },
  {
    // Unquoted paths with spaces on Windows (common pattern: C:\Program Files or paths with spaces)
    pattern: /(?:^|\s)(?:cd|cat|type|copy|move|del|rm|mkdir|ls|dir)\s+[A-Z]:\\[^\s"']*\s+[^\s|>&]/i,
    name: 'Unquoted Windows path that may contain spaces - wrap in double quotes'
  },
  {
    // Unquoted arguments with special chars after common commands
    pattern: /(?:npx|node|py|python|powershell)\s+[^\s"'-][^\s"']*[#$!&|;`(){}[\]]/,
    name: 'Unquoted argument with special characters - wrap in quotes to prevent shell interpretation'
  }
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
    const command = data.tool_input?.command || '';

    if (!command) {
      process.exit(0);
    }

    // Check dangerous patterns
    for (const pattern of DANGEROUS_PATTERNS) {
      if (pattern.test(command)) {
        console.log(JSON.stringify({
          hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'deny',
            permissionDecisionReason: `Blocked potentially dangerous command pattern: ${pattern.toString()}`
          }
        }));
        process.exit(0);
      }
    }

    // Check warn patterns
    for (const { pattern, name, pushGuard } of WARN_PATTERNS) {
      if (pattern.test(command)) {
        // PUSH_GUARD_MODE: when 'block', treat push guard matches as blocking (exit 2)
        // Gate-status advisory for push guard matches
        const gateAdvisory = pushGuard ? getGateStatusAdvisory() : '';

        if (pushGuard && process.env.PUSH_GUARD_MODE === 'block') {
          console.error(`[PUSH GUARD] Unsolicited git push detected. Blocked by PUSH_GUARD_MODE=block.`);
          console.log(JSON.stringify({
            hookSpecificOutput: {
              hookEventName: 'PreToolUse',
              permissionDecision: 'deny',
              permissionDecisionReason: `[PUSH GUARD] Unsolicited git push blocked (PUSH_GUARD_MODE=block). Only push when explicitly requested.${gateAdvisory}`
            }
          }));
          process.exit(0);
        }

        // Push guard in default warn mode: emit stderr warning, continue execution
        if (pushGuard) {
          console.error(`[PUSH GUARD] Unsolicited git push detected. Confirm this was explicitly requested.`);
        }

        console.log(JSON.stringify({
          hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'ask',
            permissionDecisionReason: `Command contains potentially destructive pattern: ${name}`,
            additionalContext: `Please confirm this is intentional.${gateAdvisory}`
          }
        }));
        process.exit(0);
      }
    }

    // Shell escaping checks - warnings only (non-blocking)
    const shellWarnings = [];
    for (const check of SHELL_ESCAPE_CHECKS) {
      if (check.pattern.test(command)) {
        // Some checks have a skip pattern - if the skip pattern matches, don't warn
        if (check.skip && check.skip.test(command)) continue;
        shellWarnings.push(check.name);
      }
    }

    if (shellWarnings.length > 0) {
      // Emit warnings via stderr (non-blocking, command still proceeds)
      console.error(`[SHELL-ESCAPE WARNING] ${shellWarnings.join('; ')}`);
    }

    // Allow the command
    process.exit(0);
  } catch (err) {
    // Hook error - fail-closed (security hook must deny on failure)
    console.error('[pre-bash-validate] FATAL ERROR:', err.message);
    process.exit(2);
  }
}

main();
