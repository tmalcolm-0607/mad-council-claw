#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..', '..');
const skillsDir = path.join(repoRoot, '.claude', 'skills');
const exceptionsPath = path.join(repoRoot, '.claude', 'rules', 'background-exceptions.json');

const exceptions = fs.existsSync(exceptionsPath)
  ? JSON.parse(fs.readFileSync(exceptionsPath, 'utf8')).allowedSkills || []
  : [];

const violations = [];

for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true })) {
  if (!entry.isDirectory() || entry.name.startsWith('_')) continue;
  const skillFile = path.join(skillsDir, entry.name, 'SKILL.md');
  if (!fs.existsSync(skillFile)) continue;

  const content = fs.readFileSync(skillFile, 'utf8');
  if (/run_in_background\s*:\s*true/i.test(content) && !exceptions.includes(entry.name)) {
    violations.push(`.claude/skills/${entry.name}/SKILL.md`);
  }
}

if (violations.length > 0) {
  console.error('Background policy violation: run_in_background: true is forbidden unless allowlisted.');
  console.error('Violations:');
  for (const v of violations) console.error(`  - ${v}`);
  process.exit(1);
}

console.log('Background policy check passed.');
