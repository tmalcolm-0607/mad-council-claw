#!/usr/bin/env node
/**
 * Hook: EnforceOrchestration
 * Purpose: Block main conversation from reading code files directly
 * Event: PreToolUse (Read)
 *
 * This hook enforces the orchestrator pattern by blocking direct code file
 * reads, forcing the use of agents (code-investigator, code-implementer, etc.)
 * for code work.
 */

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

// Patterns for allowed files (config, docs, specs, rules)
const ALLOWED_PATTERNS = [
  /\.md$/i,
  /\.json$/i,
  /\.ya?ml$/i,
  /specs\//i,
  /\.claude\//i,
  /\.mad\//i,
  /appsettings/i,
  /package\.json/i,
  /\.config/i,
  /\.env/i,
  /\.gitignore/i,
  /Dockerfile/i,
  /docker-compose/i,
  // Reference repos + fix-worktrees: external/auxiliary clones, not the orchestrator's project code.
  // Orchestrator-pattern protection is for the working tree we're developing in.
  // Subagents commit fix work in references/<repo>-*-fix-*/ and the orchestrator must verify those commits.
  // Match `references/` either at start of path OR preceded by a separator (handles relative + absolute forms).
  /(^|[\/\\])references[\/\\]/i,
];

// Patterns for code files that should be blocked
const CODE_PATTERNS = [
  /\.cs$/i,
  /\.ts$/i,
  /\.tsx$/i,
  /\.js$/i,
  /\.jsx$/i,
  /\.py$/i,
  /\.go$/i,
  /\.rs$/i,
  /\.java$/i,
  /\.cpp$/i,
  /\.c$/i,
  /\.h$/i,
  /\.hpp$/i,
];

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Only check Read tool
    if (data.tool_name !== 'Read') {
      process.exit(0);
      return;
    }

    // Allow subagents to read code (they're doing the work)
    // Only block main orchestrator thread
    if (data.agent_id || data.context?.agent_id || data.is_subagent) {
      process.exit(0);
      return;
    }

    const filePath = (data.tool_input?.file_path || '').replace(/\\/g, '/');

    // Allow reading config, docs, specs, rules
    if (ALLOWED_PATTERNS.some(p => p.test(filePath))) {
      process.exit(0);
      return;
    }

    // Allow reading hook files (infrastructure code)
    if (/\.claude[\/\\]hooks[\/\\].*\.js$/i.test(filePath)) {
      process.exit(0);
      return;
    }

    // Block reading source code files directly
    if (CODE_PATTERNS.some(p => p.test(filePath))) {
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason: `BLOCKED: Reading code file directly.

ORCHESTRATOR RULE: For lightweight inspection, use Grep/Glob.
- Find files: Glob (e.g., Glob pattern="**/*.ts")
- Search code: Grep (e.g., Grep pattern="class.*Component")
- For deep analysis or changes: Spawn 'code-investigator' or 'code-implementer'

File: ${filePath}`
        }
      }));
      process.exit(0);
      return;
    }

    // Allow other files
    process.exit(0);
  } catch (err) {
    // Hook error - fail-closed
    console.error('[enforce-orchestration] FATAL ERROR:', err.message);
    console.error('[enforce-orchestration] Hook failed - operation blocked for safety.');
    console.log(JSON.stringify({
      exit: 2,
      message: `enforce-orchestration failed: ${err.message}. Operation blocked for safety.`
    }));
    process.exit(2);
  }
}

main();
