#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function fileContainsAll(filePath, requiredSnippets) {
  if (!fs.existsSync(filePath)) {
    return [`missing file: ${filePath}`];
  }

  const content = fs.readFileSync(filePath, 'utf8');
  const failures = [];

  for (const snippet of requiredSnippets) {
    if (!content.includes(snippet)) {
      failures.push(`missing snippet '${snippet}' in ${filePath}`);
    }
  }

  return failures;
}

function main() {
  const root = process.cwd();
  const failures = [];

  const required = [
    'scripts/run-quality-gates.ps1 -Profile backend',
    'scripts/run-quality-gates.ps1 -Profile frontend',
    'scripts/run-quality-gates.ps1 -Profile full',
  ];

  failures.push(...fileContainsAll(path.join(root, 'CLAUDE.md'), required));
  failures.push(...fileContainsAll(path.join(root, 'AGENTS.md'), required));

  if (failures.length > 0) {
    console.error('[gate-drift] Gate command drift detected:');
    for (const failure of failures) {
      console.error(` - ${failure}`);
    }
    process.exit(2);
  }

  console.log('[gate-drift] Gate command references are aligned.');
  process.exit(0);
}

main();
