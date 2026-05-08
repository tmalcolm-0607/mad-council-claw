#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const ALLOWED_STATUS = new Set(['Active', 'Completed', 'Archived', 'Complete', 'Verified', 'Planning Complete']);
const WORK_ITEM_ID_PATTERN = /^WI-\d{8}-\d{4}-.+$/;

function parseArgs(argv) {
  return {
    strict: argv.includes('--strict') || process.env.WORK_ITEM_STRICT === '1',
    strictAll: argv.includes('--strict-all') || process.env.WORK_ITEM_STRICT_ALL === '1',
  };
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    return { __parseError: error.message };
  }
}

function validateManifest(workItemsRoot, workItemId, manifest, isStrictTarget) {
  const errors = [];

  const required = ['id', 'type', 'status', 'created_utc', 'artifacts'];
  for (const field of required) {
    if (!(field in manifest)) {
      errors.push(`missing field '${field}'`);
    }
  }

  if (manifest.id !== workItemId) {
    errors.push(`manifest id mismatch: expected '${workItemId}', got '${manifest.id}'`);
  }

  if (!WORK_ITEM_ID_PATTERN.test(workItemId)) {
    errors.push(`invalid work item folder id format: '${workItemId}'`);
  }

  if (manifest.id && !WORK_ITEM_ID_PATTERN.test(manifest.id)) {
    errors.push(`invalid manifest id format: '${manifest.id}'`);
  }

  if (manifest.status && !ALLOWED_STATUS.has(manifest.status)) {
    errors.push(`invalid status '${manifest.status}'`);
  }

  if (!Array.isArray(manifest.artifacts)) {
    errors.push('artifacts must be an array');
    return errors;
  }

  const expectedPrefix = `.claude/work-items/${workItemId}/`;

  for (let index = 0; index < manifest.artifacts.length; index++) {
    const artifact = manifest.artifacts[index] || {};

    if (!artifact.path || typeof artifact.path !== 'string') {
      if (isStrictTarget) {
        errors.push(`artifacts[${index}] missing string path`);
      }
      continue;
    }

    const normalizedPath = artifact.path.replace(/\\/g, '/');
    if (isStrictTarget && !normalizedPath.startsWith(expectedPrefix)) {
      errors.push(`artifacts[${index}] path '${artifact.path}' is outside active work item namespace '${expectedPrefix}'`);
    }

    if (!artifact.type) {
      errors.push(`artifacts[${index}] missing type`);
    }

    if (!artifact.created_utc) {
      errors.push(`artifacts[${index}] missing created_utc`);
    }
  }

  const specDir = manifest.spec_directory;
  if (specDir && typeof specDir === 'string') {
    if (!specDir.startsWith('specs/')) {
      errors.push(`spec_directory should start with 'specs/': '${specDir}'`);
    }
  }

  return errors;
}

function validateActivePointer(projectRoot, workItemsRoot) {
  const errors = [];
  const warnings = [];

  // Migration note: The legacy ACTIVE file (single global pointer) is being replaced
  // by per-session pointer files in .claude/work-items/sessions/<session-id>.
  // Accept either pattern. A missing ACTIVE file is NOT an error when sessions/ exists
  // or when there is simply no active work item.
  const activeFile = path.join(workItemsRoot, 'ACTIVE');
  const sessionsDir = path.join(workItemsRoot, 'sessions');
  const hasActiveFile = fs.existsSync(activeFile);
  const hasSessionsDir = fs.existsSync(sessionsDir);

  if (!hasActiveFile) {
    if (hasSessionsDir) {
      // New sessions/ pattern in use -- no ACTIVE file needed
      warnings.push('ACTIVE file absent; using sessions/ pattern (expected)');
    } else {
      // Neither exists -- no active work item, which is valid
      warnings.push('ACTIVE file missing and no sessions/ directory (no active work item)');
    }
    return { errors, warnings, activeId: null, activeManifest: null };
  }

  // Legacy ACTIVE file exists -- validate it as before
  const activeId = fs.readFileSync(activeFile, 'utf8').trim();
  if (!activeId) {
    errors.push('ACTIVE file is empty');
    return { errors, warnings, activeId: null };
  }

  const activeManifestPath = path.join(workItemsRoot, activeId, 'manifest.json');
  if (!fs.existsSync(activeManifestPath)) {
    errors.push(`ACTIVE points to missing manifest: '${activeId}'`);
    return { errors, warnings, activeId, activeManifest: null };
  }

  let activeManifest = null;
  try {
    activeManifest = readJson(activeManifestPath);
    if (activeManifest.__parseError) {
      errors.push(`ACTIVE manifest invalid JSON: ${activeManifest.__parseError}`);
      activeManifest = null;
    }
  } catch (error) {
    errors.push(`ACTIVE manifest read error: ${error.message}`);
    activeManifest = null;
  }

  return { errors, warnings, activeId, activeManifest };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const projectRoot = process.cwd();
  const workItemsRoot = path.join(projectRoot, '.claude', 'work-items');

  if (!fs.existsSync(workItemsRoot)) {
    console.log('[work-items] No work-items directory found.');
    process.exit(0);
  }

  const entries = fs.readdirSync(workItemsRoot, { withFileTypes: true });
  const workItemDirs = entries
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((name) => name !== '_TEMPLATE' && name !== 'sessions');

  const failures = [];
  const warnings = [];

  const activeValidation = validateActivePointer(projectRoot, workItemsRoot);
  const activeId = activeValidation.activeId;

  if (activeValidation.activeManifest && activeValidation.activeManifest.status && activeValidation.activeManifest.status !== 'Active') {
    failures.push(`[ACTIVE] points to non-active work item status '${activeValidation.activeManifest.status}'`);
  }

  for (const workItemId of workItemDirs) {
    const manifestPath = path.join(workItemsRoot, workItemId, 'manifest.json');

    const isStrictTarget = args.strictAll || (activeId && workItemId === activeId);

    if (!fs.existsSync(manifestPath)) {
      const msg = `[${workItemId}] missing manifest.json`;
      if (isStrictTarget) {
        failures.push(msg);
      } else {
        warnings.push(msg);
      }
      continue;
    }

    const manifest = readJson(manifestPath);
    if (manifest.__parseError) {
      const msg = `[${workItemId}] invalid JSON: ${manifest.__parseError}`;
      if (isStrictTarget) {
        failures.push(msg);
      } else {
        warnings.push(msg);
      }
      continue;
    }

    const errors = validateManifest(workItemsRoot, workItemId, manifest, isStrictTarget);
    for (const error of errors) {
      failures.push(`[${workItemId}] ${error}`);
    }

    if (!isStrictTarget && manifest.status && !new Set(['Completed', 'Archived']).has(manifest.status)) {
      warnings.push(`[${workItemId}] legacy status '${manifest.status}' retained (not strict target)`);
    }
  }

  for (const error of activeValidation.errors) {
    failures.push(`[ACTIVE] ${error}`);
  }

  // Surface ACTIVE pointer warnings (non-blocking) from sessions/ migration
  if (activeValidation.warnings) {
    for (const warning of activeValidation.warnings) {
      warnings.push(`[ACTIVE] ${warning}`);
    }
  }

  if (warnings.length > 0) {
    console.error('[work-items] Legacy/worktree warnings (non-blocking):');
    for (const warning of warnings) {
      console.error(` - ${warning}`);
    }
  }

  if (failures.length === 0) {
    console.log(`[work-items] Validation passed for ${workItemDirs.length} work item(s).`);
    process.exit(0);
  }

  const mode = args.strict ? 'STRICT' : 'WARN';
  console.error(`[work-items] Validation issues detected (${mode} mode):`);
  for (const failure of failures) {
    console.error(` - ${failure}`);
  }

  process.exit(args.strict ? 2 : 0);
}

main();
