#!/usr/bin/env node
/**
 * Hook: {{HOOK_EVENT}}
 * Purpose: {{HOOK_PURPOSE}}
 * Enforcement: {{ENFORCEMENT_LEVEL}}
 *
 * {{HOOK_DESCRIPTION}}
 *
 * Feature flag: {{FEATURE_FLAG_NAME}}
 * Set in .claude/settings.local.json under env:
 * {
 *   "env": {
 *     "{{FEATURE_FLAG_NAME}}": "{{FEATURE_FLAG_DEFAULT}}"
 *   }
 * }
 */

const fs = require('fs');
const path = require('path');

/**
 * Read environment variable from settings.local.json
 * @param {string} varName - Environment variable name
 * @param {string} defaultValue - Default value if not set
 * @returns {string} Variable value
 */
function getEnvVar(varName, defaultValue) {
  try {
    const settingsPath = path.join(process.cwd(), '.claude', 'settings.local.json');
    if (fs.existsSync(settingsPath)) {
      const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      return settings.env?.[varName] ?? defaultValue;
    }
  } catch (err) {
    // Fall through to default
  }
  return defaultValue;
}

/**
 * Parse stdin JSON
 * @returns {Promise<object>} Parsed JSON object
 */
async function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.on('data', (chunk) => data += chunk);
    process.stdin.on('end', () => {
      try {
        resolve(JSON.parse(data));
      } catch (err) {
        reject(new Error(`Failed to parse stdin: ${err.message}`));
      }
    });
  });
}

/**
 * Main hook logic
 * @param {object} input - Parsed stdin
 * @returns {object} Hook output
 */
async function processHook(input) {
  const hookOutput = {
    hookSpecificOutput: {
      {{HOOK_OUTPUT_FIELD_1}}: null,
      {{HOOK_OUTPUT_FIELD_2}}: null,
    }
  };

  // {{HOOK_LOGIC_DESCRIPTION}}

  // Example: PreToolUse - intercept tool calls
  // if (input.toolUse) {
  //   const { name, parameters } = input.toolUse;
  //
  //   if (name === '{{TOOL_NAME_TO_INTERCEPT}}') {
  //     if ({{CONDITION_TO_DENY}}) {
  //       hookOutput.permissionDecision = 'deny';
  //       hookOutput.userMessage = '{{DENIAL_MESSAGE}}';
  //       return hookOutput;
  //     }
  //
  //     if ({{CONDITION_TO_ASK}}) {
  //       hookOutput.permissionDecision = 'ask';
  //       hookOutput.userMessage = '{{ASK_MESSAGE}}';
  //       return hookOutput;
  //     }
  //   }
  // }

  // Example: PostToolUse - react to tool results
  // if (input.toolResult) {
  //   const { toolName, result } = input.toolResult;
  //
  //   if (toolName === '{{TOOL_NAME_TO_MONITOR}}') {
  //     if ({{CONDITION_TO_TRIGGER}}) {
  //       hookOutput.userMessage = '{{WARNING_MESSAGE}}';
  //       hookOutput.hookSpecificOutput.{{FIELD_NAME}} = {{FIELD_VALUE}};
  //     }
  //   }
  // }

  // Example: UserPromptSubmit - augment prompts
  // if (input.userPrompt) {
  //   const augmentedContext = {{CONTEXT_TO_ADD}};
  //   hookOutput.userMessage = augmentedContext;
  // }

  {{YOUR_HOOK_LOGIC_HERE}}

  return hookOutput;
}

/**
 * Entry point
 */
async function main() {
  try {
    // Check feature flag
    const enabled = getEnvVar('{{FEATURE_FLAG_NAME}}', '{{FEATURE_FLAG_DEFAULT}}');
    if (enabled === 'false' || enabled === '0') {
      // Feature disabled - allow operation
      console.log(JSON.stringify({ hookSpecificOutput: {} }));
      process.exit(0);
    }

    // Parse input
    const input = await readStdin();

    // Process hook
    const output = await processHook(input);

    // Output result
    console.log(JSON.stringify(output));

    // Exit with appropriate code
    // exit 0: allow (or advisory message)
    // exit 2: deny with error (hard block)
    process.exit(0);

  } catch (err) {
    // Fail-closed: if hook crashes, deny the operation
    // For advisory hooks, use fail-open (exit 0) instead
    console.error(`[{{HOOK_NAME}}] ERROR: ${err.message}`);
    console.log(JSON.stringify({
      hookSpecificOutput: { error: err.message }
    }));
    process.exit({{FAIL_EXIT_CODE}});  // 0 for fail-open, 2 for fail-closed
  }
}

main().catch((err) => {
  console.error(`[{{HOOK_NAME}}] FATAL:`, err);
  process.exit({{FAIL_EXIT_CODE}});
});

// ---
// Fill Instructions
// ---
// Replace ALL placeholders in {{DOUBLE_BRACES}}:
//
// 1. HOOK_EVENT: PreToolUse, PostToolUse, UserPromptSubmit, etc.
// 2. HOOK_PURPOSE: One-line purpose (e.g., "Prevent unauthorized git push")
// 3. ENFORCEMENT_LEVEL: BLOCK, WARN, ADVISORY
// 4. HOOK_DESCRIPTION: Longer description of what this hook does
// 5. FEATURE_FLAG_NAME: Env var name (e.g., PUSH_GUARD_ENABLED)
// 6. FEATURE_FLAG_DEFAULT: "true" or "false"
// 7. HOOK_OUTPUT_FIELD_1, HOOK_OUTPUT_FIELD_2: Fields in hookSpecificOutput
// 8. HOOK_LOGIC_DESCRIPTION: Comment describing the logic
// 9. TOOL_NAME_TO_INTERCEPT: Tool name to intercept (e.g., Bash)
// 10. CONDITION_TO_DENY: Condition expression for denial
// 11. DENIAL_MESSAGE: Message to user when denied
// 12. CONDITION_TO_ASK: Condition expression for asking user
// 13. ASK_MESSAGE: Message to user when asking
// 14. TOOL_NAME_TO_MONITOR: Tool name to monitor (PostToolUse)
// 15. CONDITION_TO_TRIGGER: Condition expression for triggering
// 16. WARNING_MESSAGE: Message to user when triggered
// 17. FIELD_NAME, FIELD_VALUE: hookSpecificOutput field updates
// 18. CONTEXT_TO_ADD: Context string to add (UserPromptSubmit)
// 19. YOUR_HOOK_LOGIC_HERE: Replace with actual hook logic
// 20. HOOK_NAME: Short hook name (e.g., push-guard)
// 21. FAIL_EXIT_CODE: 0 for fail-open (advisory), 2 for fail-closed (blocking)
// 22. Delete this "Fill Instructions" section when done
//
// Example values:
// - HOOK_EVENT: PreToolUse
// - HOOK_PURPOSE: Warn on unauthorized git push
// - ENFORCEMENT_LEVEL: WARN
// - FEATURE_FLAG_NAME: PUSH_GUARD_ENABLED
// - FEATURE_FLAG_DEFAULT: true
// - HOOK_NAME: push-guard
// - FAIL_EXIT_CODE: 0 (advisory - warn but allow)
