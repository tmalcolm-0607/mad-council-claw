#!/usr/bin/env node
/**
 * Hook: PreToolUse (Write|Edit)
 * Purpose: BLOCK writing E2E tests that mock APIs
 *
 * E2E tests MUST run against real backend.
 * Using page.route() to mock APIs defeats the purpose of E2E testing.
 *
 * Reference: .claude/rules/testing.md
 */

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

// Check if file is an E2E test
function isE2ETest(filePath) {
  if (!filePath) return false;
  const normalized = filePath.replace(/\\/g, '/').toLowerCase();
  return normalized.includes('/e2e/') || normalized.includes('.e2e.');
}

// Forbidden patterns in E2E tests
const FORBIDDEN_PATTERNS = [
  { pattern: /page\.route\s*\(/g, message: 'page.route() mocks API - E2E tests must use real backend' },
  { pattern: /route\.fulfill\s*\(/g, message: 'route.fulfill() mocks response - E2E tests must use real backend' },
  { pattern: /vi\.mock\s*\(/g, message: 'vi.mock() not allowed in E2E tests' },
  { pattern: /jest\.mock\s*\(/g, message: 'jest.mock() not allowed in E2E tests' },
];

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);
    const filePath = data.tool_input?.file_path || '';

    // Only check E2E test files
    if (!isE2ETest(filePath)) {
      process.exit(0);
    }

    // Read content from stdin payload (PreToolUse: file not yet written to disk)
    const toolName = data.tool_name || '';
    let content = '';
    if (toolName === 'Write') {
      content = data.tool_input?.content || '';
    } else if (toolName === 'Edit') {
      content = data.tool_input?.new_string || '';
    }

    if (!content) {
      process.exit(0);
    }
    const lines = content.split('\n');
    const violations = [];

    lines.forEach((line, index) => {
      FORBIDDEN_PATTERNS.forEach(({ pattern, message }) => {
        if (pattern.test(line)) {
          violations.push({
            line: index + 1,
            content: line.trim().slice(0, 80),
            message,
          });
        }
        // Reset regex lastIndex for global patterns
        pattern.lastIndex = 0;
      });
    });

    if (violations.length > 0) {
      console.error('\n❌ BLOCKED: E2E TEST MOCK VIOLATION\n');
      console.error(`File: ${filePath}\n`);
      console.error('E2E tests must run against REAL backend, not mocked APIs.\n');
      console.error('Violations:\n');

      violations.forEach(v => {
        console.error(`  Line ${v.line}: ${v.content}`);
        console.error(`    → ${v.message}\n`);
      });

      console.error('Fix: Remove mocking and test against Docker deployment.');
      console.error('See: .claude/rules/testing.md\n');

      // Return BLOCKED status (exit 2 = security block)
      console.log(JSON.stringify({
        hookSpecificOutput: {
          permissionDecision: 'block',
          permissionDecisionReason: `E2E mock violation in ${filePath}: ${violations.map(v => v.message).join('; ')}`
        }
      }));
      process.exit(2);
    }

    process.exit(0);
  } catch (err) {
    // Hook error - fail-open (advisory: cannot determine file path on parse error)
    process.exit(0);
  }
}

main();
