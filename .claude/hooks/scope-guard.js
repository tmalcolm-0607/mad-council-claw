#!/usr/bin/env node

/**
 * Scope Guard Hook (PreToolUse: Write|Edit)
 *
 * STATUS: NOT REGISTERED IN settings.json — Tier 2 feature
 * Enable by adding this hook to settings.json under PreToolUse (matcher: Write|Edit)
 * AND setting scope_guard_enabled: true in anomaly-thresholds.md
 *
 * Warns when file operations target protected or out-of-scope paths.
 *
 * Behavior:
 * 1. Protected paths (.claude/, node_modules/, .git/) always warn
 * 2. Work-item scope check only when scope_guard_enabled=true in thresholds
 * 3. Never blocks (exit 0 only) - warnings via stderr
 * 4. Emergency override: CLAUDE_SKIP_SCOPE_GUARD=1
 */

const fs = require('fs');
const path = require('path');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

// Protected paths that always trigger warnings
const PROTECTED_PATHS = ['.claude/', 'node_modules/', '.git/'];

/**
 * Get project directory by walking up to find .claude folder
 */
function getProjectDir() {
  let dir = process.cwd();
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, '.claude'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

/**
 * Load thresholds from anomaly-thresholds.md
 */
function loadThresholds() {
  const projectDir = getProjectDir();
  const thresholdsPath = path.join(projectDir, '.claude/rules/anomaly-thresholds.md');

  if (!fs.existsSync(thresholdsPath)) {
    return { scope_guard_enabled: false };
  }

  try {
    const content = fs.readFileSync(thresholdsPath, 'utf8');
    const match = content.match(/scope_guard_enabled\s*\|\s*(true|false)/i);
    return {
      scope_guard_enabled: match ? match[1].toLowerCase() === 'true' : false
    };
  } catch (e) {
    return { scope_guard_enabled: false };
  }
}

/**
 * Check if a file path matches any glob-like pattern.
 * Supports simple patterns: **, *, and literal segments.
 */
function matchesPattern(filePath, pattern) {
  // Normalize separators
  const normalized = filePath.replace(/\\/g, '/');
  const normalizedPattern = pattern.replace(/\\/g, '/');

  // Convert glob to regex
  let regex = normalizedPattern
    .replace(/[.+^${}()|[\]]/g, '\\$&')  // Escape special regex chars (not * or ?)
    .replace(/\*\*/g, '{{GLOBSTAR}}')      // Placeholder for **
    .replace(/\*/g, '[^/]*')               // * matches anything except /
    .replace(/\?/g, '[^/]')                // ? matches single char except /
    .replace(/{{GLOBSTAR}}/g, '.*');       // ** matches anything including /

  regex = '^' + regex + '$';

  try {
    return new RegExp(regex).test(normalized);
  } catch (e) {
    return false;
  }
}

/**
 * Check if a file path is under a protected directory
 */
function isProtectedPath(filePath, projectDir) {
  // Normalize to forward slashes and make relative
  const normalized = filePath.replace(/\\/g, '/');
  const normalizedProject = projectDir.replace(/\\/g, '/');

  let relativePath = normalized;
  if (normalized.startsWith(normalizedProject)) {
    relativePath = normalized.slice(normalizedProject.length);
    // Remove leading slash
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.slice(1);
    }
  }

  for (const protectedDir of PROTECTED_PATHS) {
    if (relativePath.startsWith(protectedDir)) {
      return protectedDir;
    }
  }
  return null;
}

/**
 * Load allowed_paths from the active work item's manifest
 */
function loadAllowedPaths(projectDir, data) {
  try {
    const { wiId: activeWI } = resolveActiveWI(data, projectDir);
    if (!activeWI) return null;

    const manifestPath = path.join(projectDir, '.claude/work-items', activeWI, 'manifest.json');
    if (!fs.existsSync(manifestPath)) return null;

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const scope = manifest.scope;
    if (!scope || !Array.isArray(scope.allowed_paths) || scope.allowed_paths.length === 0) {
      return null;
    }

    return scope.allowed_paths;
  } catch (e) {
    return null;
  }
}

/**
 * Main scope guard handler
 */
async function main() {
  // Emergency override
  if (process.env.CLAUDE_SKIP_SCOPE_GUARD === '1') {
    process.exit(0);
  }

  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch (e) {
    process.exit(0);
  }

  // Extract file path from tool input
  const toolInput = data.tool_input || data.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';

  if (!filePath) {
    process.exit(0);
  }

  const projectDir = getProjectDir();

  // Check 1: Protected paths (always enforced regardless of circuit breaker)
  const protectedDir = isProtectedPath(filePath, projectDir);
  if (protectedDir) {
    console.error(`[SCOPE-GUARD] Warning: Writing to protected path '${protectedDir}' - ${filePath}`);
    process.exit(0);
  }

  // Check 2: Circuit breaker - if scope guard is not enabled, stop here
  const thresholds = loadThresholds();
  if (!thresholds.scope_guard_enabled) {
    process.exit(0);
  }

  // Check 3: Work-item scope check (only when enabled)
  const allowedPaths = loadAllowedPaths(projectDir, data);
  if (!allowedPaths) {
    // No allowed_paths defined - no enforcement
    process.exit(0);
  }

  // Normalize file path to be relative to project
  const normalizedFile = filePath.replace(/\\/g, '/');
  const normalizedProject = projectDir.replace(/\\/g, '/');
  let relativePath = normalizedFile;
  if (normalizedFile.startsWith(normalizedProject)) {
    relativePath = normalizedFile.slice(normalizedProject.length);
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.slice(1);
    }
  }

  // Check if file matches any allowed pattern
  const matchesAny = allowedPaths.some(pattern => matchesPattern(relativePath, pattern));
  if (!matchesAny) {
    console.error(`[SCOPE-GUARD] Warning: File '${relativePath}' is outside declared scope. Allowed patterns: ${allowedPaths.join(', ')}`);
  }

  process.exit(0);
}

main().catch((err) => {
  // Hook error - fail-open (advisory hook)
  console.error('[scope-guard] FATAL ERROR:', err.message);
  console.error('[scope-guard] Hook failed - continuing (advisory).');
  process.exit(0);
});
