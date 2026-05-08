#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..', '..');
const agentsDir = path.join(repoRoot, '.claude', 'agents');
const output = path.join(agentsDir, 'CATALOG.md');

function parseFrontmatter(content) {
  if (!content.startsWith('---')) return {};
  const end = content.indexOf('\n---', 3);
  if (end === -1) return {};
  const body = content.slice(3, end).trim();
  const fields = {};
  for (const line of body.split(/\r?\n/)) {
    const idx = line.indexOf(':');
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim().replace(/^"|"$/g, '').replace(/^'|'$/g, '');
    fields[key] = value;
  }
  return fields;
}

const rows = [];
for (const entry of fs.readdirSync(agentsDir, { withFileTypes: true })) {
  if (!entry.isFile() || !entry.name.endsWith('.md')) continue;
  if (entry.name === 'README.md' || entry.name === 'CATALOG.md') continue;

  const fullPath = path.join(agentsDir, entry.name);
  const content = fs.readFileSync(fullPath, 'utf8');
  const fm = parseFrontmatter(content);
  const stat = fs.statSync(fullPath);

  rows.push({
    name: fm.name || entry.name.replace(/\.md$/i, ''),
    model: fm.model || 'unspecified',
    category: fm.category || 'unspecified',
    path: `.claude/agents/${entry.name}`,
    validated: stat.mtime.toISOString().slice(0, 10),
  });
}

rows.sort((a, b) => a.name.localeCompare(b.name));

const lines = [
  '# Agents Catalog',
  '',
  'Auto-generated inventory with catalog-level freshness tracking.',
  '',
  '| Agent | Model | Category | Last Validated | Definition |',
  '|---|---|---|---|---|',
  ...rows.map((r) => `| ${r.name} | ${r.model} | ${r.category} | ${r.validated} | [${r.path}](${r.path}) |`),
  '',
  'Archived agents remain in .claude/agents/_archived and are not listed here for dispatch.',
  '',
];

fs.writeFileSync(output, lines.join('\n'), 'utf8');
console.log(`Generated ${path.relative(repoRoot, output)} (${rows.length} agents).`);
