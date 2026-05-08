#!/usr/bin/env node
/**
 * Validates Claude Code configuration kit structure
 */

const fs = require('fs');
const path = require('path');

const requiredPaths = [
  '.claude/agents',
  '.claude/rules',
  '.claude/skills',
  '.mad/templates',
  'CLAUDE.md'
];

let passed = 0;
let failed = 0;

console.log('Validating configuration kit structure...\n');

for (const p of requiredPaths) {
  const fullPath = path.join(process.cwd(), p);
  const exists = fs.existsSync(fullPath);

  if (exists) {
    console.log(`  ✓ ${p}`);
    passed++;
  } else {
    console.log(`  ✗ ${p} (missing)`);
    failed++;
  }
}

console.log(`\nResults: ${passed} passed, ${failed} failed`);

if (failed > 0) {
  process.exit(1);
}

console.log('\nConfiguration kit validation: OK');
