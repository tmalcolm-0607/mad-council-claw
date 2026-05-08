// Write-SessionTranscript.js - Claude Code lifecycle hook for JSONL transcripts
//
// Hook types: SubagentStop, PreToolUse, PostToolUse
// Writes structured events to a JSONL file for post-hoc workflow analysis.
// File path from env: EVAL_TRANSCRIPT_PATH
//
// This hook captures agent execution metadata for analysis by:
//   Eval03 (Context Stress) - token usage tracking
//   Eval06 (Workflow Fidelity) - protocol compliance checking
//
// Events written:
//   { event: "SubagentStop", agent_type, turn_number, tokens_used, tool_calls }
//   { event: "PreToolUse",   tool, command_summary, file_path }
//   { event: "PostToolUse",  tool, command_summary, file_path, exit_code }

const fs = require("fs");
const path = require("path");

/**
 * Validate that the transcript path is within allowed directories.
 * Blocks path traversal attacks (review finding MAJOR-1).
 * @param {string} transcriptPath - The path to validate
 * @returns {boolean} true if path is allowed
 */
function isPathAllowed(transcriptPath) {
  if (!transcriptPath) return false;

  const resolved = path.resolve(transcriptPath);

  // Block explicit traversal sequences before resolution
  if (transcriptPath.includes("..")) {
    console.error(
      `[Write-SessionTranscript] Refusing path with traversal: ${transcriptPath}`
    );
    return false;
  }

  const allowedBases = [
    path.resolve(__dirname, "..", "..", "results"),
    path.resolve(__dirname, "..", "..", "results-archive"),
  ];
  const isAllowed = allowedBases.some((base) => resolved.startsWith(base));
  if (!isAllowed) {
    console.error(
      `[Write-SessionTranscript] Refusing to write outside eval results directory: ${resolved}`
    );
  }
  return isAllowed;
}

/**
 * Append a JSONL entry to the transcript file.
 * @param {object} entry - The structured event object to write
 */
function appendEntry(entry) {
  const transcriptPath = process.env.EVAL_TRANSCRIPT_PATH;
  if (!transcriptPath) return; // No transcript path configured; skip silently

  if (!isPathAllowed(transcriptPath)) return;

  try {
    const dir = path.dirname(transcriptPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    const line = JSON.stringify(entry) + "\n";
    fs.appendFileSync(transcriptPath, line, "utf8");
  } catch (err) {
    // Log but do not fail the hook - transcript is best-effort
    console.error(
      `[Write-SessionTranscript] Failed to write transcript: ${err.message}`
    );
  }
}

/**
 * Extract a short summary from a Bash command (first 200 chars, no secrets).
 * @param {string} command - The full command string
 * @returns {string} Truncated summary
 */
function summarizeCommand(command) {
  if (!command) return "";
  // Strip potential secrets: anything after = in key=value patterns
  let safe = command.replace(
    /(?:password|token|secret|key)\s*=\s*\S+/gi,
    "$&=[REDACTED]"
  );
  if (safe.length > 200) {
    safe = safe.substring(0, 200) + "...";
  }
  return safe;
}

/**
 * SubagentStop hook handler.
 * Captures agent lifecycle completion events.
 * @param {{ agent_type: string, turn_number: number, tokens_used: object, tool_calls: Array }} context
 */
function onSubagentStop(context) {
  const entry = {
    timestamp: new Date().toISOString(),
    event: "SubagentStop",
    agent_type: context.agent_type || "unknown",
    turn_number: context.turn_number || 0,
    tokens_used: context.tokens_used || {},
    tool_calls: Array.isArray(context.tool_calls)
      ? context.tool_calls.map((tc) => ({
          tool: tc.tool || tc.name || "unknown",
          duration_ms: tc.duration_ms || 0,
        }))
      : [],
  };
  appendEntry(entry);
}

/**
 * PreToolUse hook handler.
 * Captures tool invocation intent before execution.
 * Used by WF-002 (quality gates), WF-004 (wrapper scripts), WF-005 (plan updates).
 * @param {{ tool: string, input: object }} context
 */
function onPreToolUse(context) {
  const tool = context.tool || "unknown";
  const input = context.input || {};

  const entry = {
    timestamp: new Date().toISOString(),
    event: "PreToolUse",
    tool: tool,
  };

  // Extract relevant fields based on tool type
  switch (tool) {
    case "Bash":
      entry.command_summary = summarizeCommand(input.command || "");
      break;
    case "Edit":
      entry.file_path = input.file_path || "";
      entry.has_old_string = !!(input.old_string && input.old_string.length > 0);
      break;
    case "Write":
      entry.file_path = input.file_path || "";
      break;
    case "Read":
      entry.file_path = input.file_path || "";
      break;
    case "Task":
      entry.agent_type = input.subagent_type || input.agent_type || "";
      entry.description = (input.description || "").substring(0, 100);
      break;
    default:
      // Capture tool name only for other tools
      break;
  }

  appendEntry(entry);
}

/**
 * PostToolUse hook handler.
 * Captures tool execution results after completion.
 * Used for verifying that commands actually succeeded.
 * @param {{ tool: string, input: object, output: object }} context
 */
function onPostToolUse(context) {
  const tool = context.tool || "unknown";
  const input = context.input || {};
  const output = context.output || {};

  const entry = {
    timestamp: new Date().toISOString(),
    event: "PostToolUse",
    tool: tool,
  };

  switch (tool) {
    case "Bash":
      entry.command_summary = summarizeCommand(input.command || "");
      entry.exit_code = output.exit_code !== undefined ? output.exit_code : null;
      break;
    case "Edit":
      entry.file_path = input.file_path || "";
      entry.success = output.success !== undefined ? output.success : true;
      break;
    case "Write":
      entry.file_path = input.file_path || "";
      break;
    case "Task":
      entry.agent_type = input.subagent_type || input.agent_type || "";
      break;
    default:
      break;
  }

  appendEntry(entry);
}

module.exports = { onSubagentStop, onPreToolUse, onPostToolUse };
