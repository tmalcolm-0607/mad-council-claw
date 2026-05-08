#!/usr/bin/env node
/**
 * PreToolUse:Bash hook — blocks any outbound-posting command (PR comments, Slack, Teams,
 * etc.) when the payload contains smart-Unicode characters that mojibake on common
 * non-UTF-8 surfaces (ADO email notifications, some Teams clients, Outlook RTL renders).
 *
 * Detected chars (replace with ASCII before posting):
 *   em-dash —    (U+2014)  → " - "
 *   en-dash –    (U+2013)  → "-"
 *   ellipsis …   (U+2026)  → "..."
 *   left/right single quote ‘ ’ (U+2018, U+2019)  → "'"
 *   left/right double quote “ ” (U+201C, U+201D)  → '"'
 *   non-breaking space (U+00A0) → regular space
 *
 * Trigger: Bash commands matching:
 *   - Post-ReviewFindings.ps1 ... -FindingsFile <path>
 *   - Ado-PR-Comment.ps1 ... -Content "<inline>"
 *   - az devops invoke ... pullRequestThreads ... --in-file <path>
 *   - any of the above with --http-method POST/PATCH where the content body has smart-Unicode
 *
 * Exit codes:
 *   0  no problem found, allow command
 *   2  smart-Unicode detected, BLOCK with error
 *
 * Hook contract: stdin is JSON with .tool_input.command (the bash command string).
 *
 * Disable for one call: pass --allow-smart-unicode in the command (escape hatch for
 * legitimate cases where the user explicitly wants the chars).
 */
'use strict';
const fs = require('fs');
const path = require('path');

const SMART = {
  '—': ['em-dash', ' - '],
  '–': ['en-dash', '-'],
  '…': ['ellipsis', '...'],
  '‘': ['left single quote', "'"],
  '’': ['right single quote', "'"],
  '“': ['left double quote', '"'],
  '”': ['right double quote', '"'],
  ' ': ['non-breaking space', ' '],
};

function readStdinSync() {
  try { return fs.readFileSync(0, 'utf8'); } catch { return ''; }
}

function findSmartChars(text) {
  const hits = [];
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (SMART[ch]) {
      hits.push({ pos: i, ch, name: SMART[ch][0], replacement: SMART[ch][1] });
    }
  }
  return hits;
}

function snippet(text, pos, span = 30) {
  const start = Math.max(0, pos - span);
  const end = Math.min(text.length, pos + span);
  let out = text.slice(start, end);
  // Replace each smart char in the snippet with a marker
  Object.keys(SMART).forEach(c => { out = out.replaceAll(c, `[${SMART[c][0]}]`); });
  return out;
}

function main() {
  const input = JSON.parse(readStdinSync() || '{}');
  const cmd = (input?.tool_input?.command) || '';
  if (!cmd) { process.exit(0); }

  // Escape hatch
  if (cmd.includes('--allow-smart-unicode')) { process.exit(0); }

  // Detect outbound-posting shapes
  const isOutbound =
    /Post-ReviewFindings\.ps1/i.test(cmd) ||
    /Ado-PR-Comment\.ps1/i.test(cmd) ||
    (/az\s+devops\s+invoke/i.test(cmd) &&
      /pullRequestThread|pullRequests.*comments/i.test(cmd) &&
      /--http-method\s+(POST|PATCH)/i.test(cmd));

  if (!isOutbound) { process.exit(0); }

  // Extract the file argument (FindingsFile, --in-file) OR inline content (-Content "...")
  // Quoted paths (with spaces) take precedence; fall back to unquoted (whitespace-terminated).
  const matchFileArg = (flag) => {
    const dq = cmd.match(new RegExp(`${flag}\\s+"([^"]+)"`));
    if (dq) return dq[1];
    const sq = cmd.match(new RegExp(`${flag}\\s+'([^']+)'`));
    if (sq) return sq[1];
    const uq = cmd.match(new RegExp(`${flag}\\s+(\\S+)`));
    return uq ? uq[1] : null;
  };
  let payloadText = '';
  const filePath = matchFileArg('-FindingsFile') || matchFileArg('--in-file');
  if (filePath) {
    try {
      payloadText = fs.readFileSync(filePath, 'utf8');
    } catch (e) {
      // File doesn't exist yet, can't scan — fail-open.
      process.exit(0);
    }
  } else {
    // Inline content: -Content "..." (single or double-quoted, with possible escapes)
    const contentMatch = cmd.match(/-Content\s+["']((?:\\.|[^"'])*)["']/);
    if (contentMatch) { payloadText = contentMatch[1]; }
  }

  if (!payloadText) { process.exit(0); }

  const hits = findSmartChars(payloadText);
  if (hits.length === 0) { process.exit(0); }

  // Aggregate: count per char, plus first 3 with snippets
  const byChar = {};
  hits.forEach(h => {
    if (!byChar[h.ch]) byChar[h.ch] = { name: h.name, count: 0, replacement: h.replacement };
    byChar[h.ch].count += 1;
  });

  const lines = [
    'BLOCKED: smart-Unicode chars detected in outbound-posting payload.',
    'These render as mojibake on ADO email notifications, Outlook RTL, and some Teams clients.',
    '',
    'Counts:',
  ];
  for (const ch of Object.keys(byChar)) {
    const info = byChar[ch];
    lines.push(`  ${info.count}x ${info.name} (replace with ${JSON.stringify(info.replacement)})`);
  }
  lines.push('');
  lines.push('First 3 occurrences:');
  hits.slice(0, 3).forEach(h => {
    lines.push(`  pos ${h.pos}: "${snippet(payloadText, h.pos)}"`);
  });
  lines.push('');
  lines.push('Fix: sanitize the payload (Python one-liner):');
  lines.push('  python -c "import json,sys;t=str.maketrans({\\"—\\":\\" - \\",\\"–\\":\\"-\\",\\"…\\":\\"...\\",\\"‘\\":\\"\\\'\\",\\"’\\":\\"\\\'\\",\\"“\\":chr(34),\\"”\\":chr(34),\\" \\":\\" \\"});d=json.load(open(sys.argv[1]));[setattr(f,k,(f[k] if isinstance(f.get(k),str) else f[k]).translate(t)) if isinstance(f.get(k),str) else None for f in d for k in [\\"comment\\",\\"content\\"]];json.dump(d,open(sys.argv[1],\\"w\\"),indent=2,ensure_ascii=True)" <findings-or-content-file>');
  lines.push('');
  lines.push('Override (when smart-Unicode is intentional, e.g. preserving author quotes verbatim):');
  lines.push('  add --allow-smart-unicode to the command');

  // Hook protocol: write block reason to stderr, exit 2
  process.stderr.write(lines.join('\n') + '\n');
  process.exit(2);
}

try { main(); }
catch (e) { process.stderr.write(`hook crashed: ${e.message}\n`); process.exit(0); /* fail-open */ }
