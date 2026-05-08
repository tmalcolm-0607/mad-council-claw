#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  return {
    strict: argv.includes('--strict') || process.env.GUIDANCE_DRIFT_STRICT === '1',
  };
}

function ensureContains(filePath, text, failures, label) {
  if (!fs.existsSync(filePath)) {
    failures.push(`${label}: missing file (${filePath})`);
    return;
  }

  const content = fs.readFileSync(filePath, 'utf8');
  if (!content.includes(text)) {
    failures.push(`${label}: missing required text '${text}'`);
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const root = process.cwd();
  const failures = [];

  const rootClaude = path.join(root, 'CLAUDE.md');
  ensureContains(rootClaude, '## Directory-Scoped Guidance', failures, 'root CLAUDE.md');

  const localGuidance = [
    'docs/CLAUDE.md',
    'specs/CLAUDE.md',
    'src/CLAUDE.md',
    'tests/CLAUDE.md',
    'frontend/CLAUDE.md',
    'infra/CLAUDE.md',
  ];

  for (const relativePath of localGuidance) {
    const fullPath = path.join(root, relativePath);
    ensureContains(fullPath, 'Root rules still apply.', failures, relativePath);
  }

  const docsReadme = path.join(root, 'docs', 'README.md');
  ensureContains(docsReadme, '## Directory-Level Assistant Guidance', failures, 'docs/README.md');

  if (failures.length === 0) {
    console.log('[guidance-drift] Guidance validation passed.');
    process.exit(0);
  }

  const mode = args.strict ? 'STRICT' : 'WARN';
  console.error(`[guidance-drift] Validation issues detected (${mode} mode):`);
  for (const failure of failures) {
    console.error(` - ${failure}`);
  }

  process.exit(args.strict ? 2 : 0);
}

main();
