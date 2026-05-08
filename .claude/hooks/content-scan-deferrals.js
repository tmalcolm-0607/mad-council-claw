#!/usr/bin/env node
/**
 * Hook: PostToolUse (Write|Edit)
 * Purpose: Scan written/edited content for silent-deferral keywords and append
 *          violations to .mad/scratch/deferral-flags.json. PostToolUse cannot
 *          block (the write already happened); a sibling SubagentStop hook
 *          (validate-artifact-completeness.js) reads this flag file and blocks
 *          subagent completion when flags > 0.
 *
 * Why: Iter1-41, the orchestrator silently deferred user-requested features
 *      with phrases like "v1.5 scope", "deferred to next iteration", "OoS",
 *      "follow-up". The user repeatedly flagged: "i never asked for any
 *      deferrals i dont want any deferrals without discussion". The
 *      .claude/rules/no-silent-deferrals.md rule exists but had no
 *      mechanical detector — every cascade re-introduced deferrals.
 *
 * Mechanism:
 *   1. On PostToolUse:Write|Edit, read tool_input.content / new_string.
 *   2. Match against deferral keyword regex.
 *   3. If matches found, append a record to .mad/scratch/deferral-flags.json.
 *   4. Print a non-blocking warning to stderr.
 *
 * Allowed phrases (do NOT trigger):
 *   - In a CHANGELOG.md context (deferrals there are historical, not present)
 *   - Inside a fenced code block (treated as documentation/example)
 *   - In files matching backlog patterns (.mad/work-items/.../backlog.md, etc.)
 *
 * Override:
 *   - Set DEFERRAL_HOOK_DISABLED=true in .claude/settings.local.json env block.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SETTINGS_LOCAL = path.join(REPO_ROOT, '.claude', 'settings.local.json');
const FLAG_FILE = path.join(REPO_ROOT, '.mad', 'scratch', 'deferral-flags.json');

const DEFERRAL_PATTERNS = [
  /\bv1\.5\b/i,
  /\bOoS\b/,                              // case-sensitive — "OoS" the abbreviation
  /\bout[\s-]of[\s-]scope\b/i,
  /\bdeferred\s+to\b/i,
  /\bdeferred\s+for\b/i,
  /\bdefer\s+to\s+(?:v|iteration|phase|next)/i,
  /\bfuture\s+work\b/i,
  /\bfollow[\s-]up\s+(?:work|task|item)\b/i,
  /\bnext\s+iteration\b/i,
  /\bv\d+\.\d+\s+scope\b/i,
  /\bpunt(?:ed|ing)?\s+to\b/i,
  /\bskip(?:ped|ping)?\s+for\s+now\b/i,
  /\bnot\s+in\s+scope\b/i,
  /\bdescoped\b/i,
];

// Path patterns that legitimately track deferrals (skip detection for these)
const ALLOWED_FILE_PATTERNS = [
  /backlog\.md$/i,
  /CHANGELOG\.md$/i,
  /[\\/]decisions\.md$/i,
  /claude-md-backlog\.md$/i,
  /plan-backlog\.md$/i,
  /[\\/]retros[\\/]/i,
  /loop-iter\d+/i,                        // iter audit/retro reports
  /loop-final-retro/i,
  /-deferred\.md$/i,
  /[\\/]archive[\\/]/i,
  // Hook flag files themselves — writing acknowledgement reasons that contain
  // the keywords creates a recursive self-trigger. Exempt all flag files in
  // .mad/scratch/ that are antipattern-tracking artifacts.
  /[\\/]\.mad[\\/]scratch[\\/]deferral-flags\.json$/i,
  /[\\/]\.mad[\\/]scratch[\\/]canonical-marker-flags\.json$/i,
  /[\\/]\.mad[\\/]scratch[\\/]top-n-cap-flags\.json$/i,
  /[\\/]\.mad[\\/]scratch[\\/]missing-autofire-flags\.json$/i,
  /[\\/]\.mad[\\/]scratch[\\/]loop-antipattern-summary\.json$/i,
  // Audit reports under .mad/reports/ — explicit audit-scope-declaration
  // blocks are the canonical shape, not silent deferrals. Matches lens-*
  // audit, mad-ab, council-verdict reports.
  /[\\/]\.mad[\\/]reports[\\/].*\.md$/i,
  // Scratch files under .mad/scratch/ — working notes, context bundles,
  // verification scripts, intermediate state. These reference deferral
  // keywords as documentation/context, not as new deferrals.
  /[\\/]\.mad[\\/]scratch[\\/].*\.md$/i,
  // Hook source files — their inline comments and regex pattern strings
  // necessarily contain the keywords as documentation. Self-scanning the
  // detector's source is meaningless.
  /[\\/]\.claude[\\/]hooks[\\/].*\.js$/i,
  // Script source files — same rationale as hooks; comments and metadata
  // descriptions reference the keywords as concepts.
  /[\\/]\.claude[\\/]scripts[\\/].*\.(ps1|js|sh)$/i,
  // Memory rule files documenting the keywords as concepts.
  // Rule files that reference the deferral keywords as documentation
  // (the rules ARE the exemption list source-of-truth). Without these,
  // every Edit on the rule files triggers a recursive self-flag.
  /[\\/]\.claude[\\/]rules[\\/]no-silent-deferrals\.md$/i,
  /[\\/]\.claude[\\/]rules[\\/]no-top-n-capping\.md$/i,
  // User-memory feedback files under ~/.claude/projects/<sanitized>/memory/
  // legitimately discuss the antipattern keywords as concepts (the memory
  // entries ARE the documentation of the discipline). Same class as the
  // rule files above. Without this, any memory file describing the
  // deferral-detection discipline triggers a recursive self-flag.
  /[\\/]\.claude[\\/]projects[\\/][^\\/]+[\\/]memory[\\/].*\.md$/i,
  // D-13: canonical MAD artifacts under specs/<N>-*/ are path-exempt.
  // These files (plan.md, tasks.md, test-plan.md) are produced by canonical
  // skills (/mad-plan, /mad-tasks, /testplan) and frequently inherit
  // sanctioned deferrals from their source spec.md per the
  // no-silent-deferrals.md asymmetry rule (additions OK, deferrals
  // require asking — but downstream artifacts must preserve verbatim).
  // Pairs with D-12 frontmatter check below for spec.md (which still
  // requires explicit sentinel/inherits-deferrals-from to be exempt).
  /[\\/]specs[\\/]\d+-[^\\/]+[\\/]plan\.md$/i,
  /[\\/]specs[\\/]\d+-[^\\/]+[\\/]tasks\.md$/i,
  /[\\/]specs[\\/]\d+-[^\\/]+[\\/]test-plan\.md$/i,
  // D-13 cleanup: ack scripts and verification helpers under .mad/scratch/
  // (.js, .ps1, .sh) — these are operational artifacts that may contain
  // deferral keywords as documentation/context, mirroring the existing
  // .mad/scratch/*.md exemption.
  /[\\/]\.mad[\\/]scratch[\\/].*\.(?:js|ps1|sh)$/i,
  // Wave-7 lane-d: mad-council-claw catalog/output paths.
  // Multiple parallel waves drop ledgers, lane summaries, council/multi-model
  // review outputs, and research findings into these directories. The
  // canonical wave-2 lane-b ledger template's mandatory `out-of-scope-notes:`
  // block legitimately uses the deferral keywords (per no-silent-deferrals.md
  // "preserved not invented" clause). Per the rule's own MUST clause —
  // "New scanning patterns ... MUST also extend the exemption list to
  // prevent recursive self-trigger" — applied here to canonical templates
  // that legitimately reference the keywords.
  /[\\/]docs[\\/]03-feature-catalog[\\/].*\.md$/i,
  /[\\/]docs[\\/]06-agent-team-outputs[\\/].*\.md$/i,
  /[\\/]docs[\\/]05-design-reviews[\\/].*\.md$/i,
  /[\\/]docs[\\/]04-research[\\/].*\.md$/i,
  // Wave-20 fix: loop-state retrospectives. Files under docs/11-loop-state/
  // (recent-improvements.md, current-wave.md, wave-history/wave-NNN.md,
  // confidence-ledger.md, orchestrator-steering-*.md) are by definition
  // meta-prose ABOUT the antipattern — they describe what each wave learned,
  // what landed, what was scope-routed elsewhere. They quote the keywords
  // to document the antipattern itself. Same class as .mad/reports/*.md
  // (already exempt above). Without this exemption, every wave-close
  // retrospective triggers the hook recursively (wave-20 fired on
  // wave-019.md and recent-improvements.md for exactly this reason).
  /[\\/]docs[\\/]11-loop-state[\\/].*\.md$/i,
  // Wave-20 fix: living roadmap. roadmap.md is a navigable view of
  // milestones and features; it carries an explicit "DEFERRED" status
  // legend (M19 = user-acknowledged tracking row, F-D-001..F-D-018).
  // The keywords appear in the legend, the M19 row, and the milestone
  // status table by design — they categorize user-acknowledged scope
  // decisions, not introduce new ones. Top-level path; matches both
  // repo-root roadmap.md and any docs/<path>/roadmap.md.
  /(?:^|[\\/])roadmap\.md$/i,
];

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => (data += chunk));
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', () => resolve(''));
  });
}

function isHookDisabled() {
  try {
    const raw = fs.readFileSync(SETTINGS_LOCAL, 'utf8');
    const parsed = JSON.parse(raw);
    const env = (parsed && parsed.env) || {};
    const flag = env.DEFERRAL_HOOK_DISABLED;
    if (typeof flag === 'string') return flag === 'true' || flag === '1';
    return flag === true;
  } catch {
    return false;
  }
}

function isAllowedFile(filePath) {
  if (!filePath) return false;
  return ALLOWED_FILE_PATTERNS.some((p) => p.test(filePath));
}

// D-12: frontmatter-aware exemption.
// A file is exempt if either:
//   1. It contains the literal sentinel comment (case-sensitive exact match):
//      <!-- TESTPLAN GENERATED FROM SPEC — DEFERRALS INHERIT FROM SOURCE PER no-silent-deferrals.md ASYMMETRY -->
//   2. It carries `inherits-deferrals-from: <path>` in its first 20 lines AND
//      the source path resolves to an existing file (relative to the target's
//      directory). The deferral keywords were sanctioned in the source.
//
// Reads the first 1000 bytes (or first 20 lines, whichever is smaller) so the
// hook stays cheap on large generated artifacts.
const SENTINEL_COMMENT =
  '<!-- TESTPLAN GENERATED FROM SPEC — DEFERRALS INHERIT FROM SOURCE PER no-silent-deferrals.md ASYMMETRY -->';

function isFrontmatterExempt(filePath, content) {
  let head = '';
  if (typeof content === 'string' && content.length > 0) {
    head = content.split('\n').slice(0, 20).join('\n');
  } else if (filePath && fs.existsSync(filePath)) {
    try {
      const fd = fs.openSync(filePath, 'r');
      const buf = Buffer.alloc(1000);
      const n = fs.readSync(fd, buf, 0, 1000, 0);
      fs.closeSync(fd);
      head = buf.slice(0, n).toString('utf8').split('\n').slice(0, 20).join('\n');
    } catch {
      return false;
    }
  }
  if (!head) return false;

  // Check 1: explicit sentinel comment (case-sensitive exact match)
  if (head.indexOf(SENTINEL_COMMENT) !== -1) {
    return true;
  }

  // Check 2: inherits-deferrals-from frontmatter pointing to an existing file
  const inheritsMatch = head.match(/^inherits-deferrals-from:\s*(\S+)/m);
  if (inheritsMatch && filePath) {
    const sourcePath = inheritsMatch[1].trim();
    try {
      const resolved = path.resolve(path.dirname(filePath), sourcePath);
      if (fs.existsSync(resolved)) return true;
    } catch {
      // fall through — not exempt
    }
  }

  return false;
}

function stripFencedCodeBlocks(content) {
  // Remove ```...``` blocks so example/doc snippets don't trip the scan
  return content.replace(/```[\s\S]*?```/g, '');
}

function findMatches(content) {
  const stripped = stripFencedCodeBlocks(content);
  const matches = [];
  for (const pattern of DEFERRAL_PATTERNS) {
    const m = stripped.match(pattern);
    if (m) {
      // Find line number in original content
      const idx = content.indexOf(m[0]);
      const lineNum = idx >= 0 ? content.slice(0, idx).split('\n').length : null;
      matches.push({ pattern: pattern.source, match: m[0], line: lineNum });
    }
  }
  return matches;
}

// Diff-shape detection (Edit ops only): a keyword match counts as a real
// introduction only if its literal match text is present in new_string but
// absent from old_string. If old_string already had the same match, the Edit
// is reshaping existing content (typo fix, line-shuffle, formatting) and is
// NOT introducing a new deferral.
//
// Why: wave-by-wave retrospectives in docs/11-loop-state/recent-improvements.md
// (and similar long-form running logs) accumulate keyword references as they
// describe the antipattern itself. Every Edit re-scans the full new_string and
// re-fires on keywords that have been there for waves. Path-based exemption is
// whack-a-mole; diff-shape detection is principled — only fire when something
// genuinely new is introduced.
//
// Implementation: we strip fenced code blocks from old_string (matching the
// new_string treatment), then compare each match's literal text against
// old_string. Case-handling mirrors the original pattern: most patterns are
// case-insensitive (compare via toLowerCase); the OoS pattern is the only
// case-sensitive one and we preserve that distinction.
function filterToIntroductions(matches, oldString) {
  if (typeof oldString !== 'string' || oldString.length === 0) return matches;
  const oldStripped = stripFencedCodeBlocks(oldString);
  const oldStrippedLower = oldStripped.toLowerCase();
  return matches.filter((m) => {
    // OoS is the only case-sensitive pattern in DEFERRAL_PATTERNS.
    const caseSensitive = m.pattern === '\\bOoS\\b';
    if (caseSensitive) {
      return !oldStripped.includes(m.match);
    }
    return !oldStrippedLower.includes(m.match.toLowerCase());
  });
}

function appendFlag(record) {
  try {
    fs.mkdirSync(path.dirname(FLAG_FILE), { recursive: true });
    let existing = [];
    try {
      existing = JSON.parse(fs.readFileSync(FLAG_FILE, 'utf8'));
      if (!Array.isArray(existing)) existing = [];
    } catch {
      existing = [];
    }
    existing.push(record);
    fs.writeFileSync(FLAG_FILE, JSON.stringify(existing, null, 2));
  } catch {
    // Best-effort
  }
}

async function main() {
  let raw = '';
  try {
    raw = await readStdin();
  } catch {
    process.exit(0);
  }
  if (!raw || !raw.trim()) process.exit(0);

  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  const toolName = payload.tool_name || payload.toolName;
  if (toolName !== 'Write' && toolName !== 'Edit') process.exit(0);

  if (isHookDisabled()) process.exit(0);

  const toolInput = payload.tool_input || payload.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';

  if (isAllowedFile(filePath)) process.exit(0);

  // Pull written content from whichever field applies (Write: content; Edit: new_string)
  const content =
    toolInput.content ||
    toolInput.new_string ||
    toolInput.newString ||
    '';

  if (typeof content !== 'string' || !content.trim()) process.exit(0);

  // D-12: frontmatter-aware exemption (sentinel comment OR inherits-deferrals-from).
  // For Edit ops the new_string may be a small fragment without frontmatter; in
  // that case the on-disk file (post-edit) is read for the head.
  if (isFrontmatterExempt(filePath, content)) process.exit(0);

  let matches = findMatches(content);
  if (matches.length === 0) process.exit(0);

  // Diff-shape filter (Edit only): keep only matches that are NEW introductions
  // — present in new_string but not in old_string. Edits that reshape existing
  // content (where the same keyword appears in both halves) are not new
  // deferrals and should not re-fire the hook.
  if (toolName === 'Edit') {
    const oldString = toolInput.old_string || toolInput.oldString || '';
    matches = filterToIntroductions(matches, oldString);
    if (matches.length === 0) process.exit(0);
  }

  // Stamp the current session_id on the flag so the Stop-time consumer
  // (validate-artifact-completeness.js) can filter to only flags raised in this
  // session. Flags from other sessions / other work items must not block this
  // session's Stop. PostToolUse payload carries session_id; fall back to env
  // if missing (older Claude Code versions).
  const sessionId =
    payload.session_id ||
    payload.sessionId ||
    process.env.CLAUDE_SESSION_ID ||
    null;

  appendFlag({
    timestamp: new Date().toISOString(),
    session_id: sessionId,
    file: filePath,
    tool: toolName,
    matches,
  });

  process.stderr.write(
    `[content-scan-deferrals] Deferral keyword(s) detected in ${path.basename(filePath)}: ` +
      matches.map((m) => `"${m.match}" (line ${m.line || '?'})`).join(', ') +
      `\n  Per .claude/rules/no-silent-deferrals.md, deferrals require explicit user discussion.\n` +
      `  Flag recorded at .mad/scratch/deferral-flags.json — SubagentStop will block completion if unanswered.\n`
  );
  process.exit(0);
}

main().catch((err) => {
  process.stderr.write(`[content-scan-deferrals] internal error: ${err && err.message}\n`);
  process.exit(0);
});
