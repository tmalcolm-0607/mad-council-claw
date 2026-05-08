#!/usr/bin/env node

/**
 * validate-plan-gates.js
 *
 * Purpose: Validate plan.md pattern compliance and verification spec completeness.
 *
 * Event: PostToolUse (Write|Edit) - checks after plan.md is written/edited
 * Behavior: Blocking on FAIL pattern compliance, warning on missing verification spec sections.
 *
 * Checks:
 *   1. verification-spec-completeness - All 5 required sections present
 *   2. pattern-compliance-fail        - No FAIL status in Pattern Compliance table
 *   3. contract-consistency           - Contracts referenced in plan exist on disk
 */

const fs = require('fs');
const path = require('path');

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Check 1: Verification Spec section has all 5 required subsections.
 * Required: Feature Intent, Change Type, Expected Impact, Structural Signals, Not a Failure
 */
function checkVerificationSpecCompleteness(content) {
  const warnings = [];

  // Check if plan has a Verification Spec section at all
  if (!/##\s*Verification Spec/i.test(content)) {
    warnings.push({
      rule: 'verification-spec-completeness',
      severity: 'warn',
      message: 'Plan is missing "## Verification Spec" section. This is MANDATORY per Phase 0.5.',
    });
    return warnings;
  }

  // Extract the Verification Spec section (from its heading to the next ## heading)
  const sectionMatch = content.match(/##\s*Verification Spec[\s\S]*?(?=\n##\s[^#]|\n---\s*$|$)/i);
  if (!sectionMatch) return warnings;

  const section = sectionMatch[0];

  const requiredSections = [
    { name: 'Feature Intent', pattern: /feature\s*intent/i },
    { name: 'Change Type', pattern: /change\s*type/i },
    { name: 'Expected Impact', pattern: /expected\s*impact/i },
    { name: 'Structural Signals', pattern: /structural\s*signals/i },
    { name: 'Not a Failure', pattern: /not\s*a\s*failure/i },
  ];

  for (const req of requiredSections) {
    if (!req.pattern.test(section)) {
      warnings.push({
        rule: 'verification-spec-completeness',
        severity: 'warn',
        message: `Verification Spec missing "${req.name}" section. All 5 sections are required.`,
      });
    }
  }

  return warnings;
}

/**
 * Check 2: Pattern Compliance table has no FAIL entries.
 * If any FAIL is found, this is a blocking error.
 */
function checkPatternCompliance(content) {
  const warnings = [];

  // Check if plan has a Pattern Compliance section
  if (!/##\s*Pattern Compliance/i.test(content)) {
    // No pattern compliance section is OK (patterns may not be specified in spec)
    return warnings;
  }

  // Extract the Pattern Compliance section
  const sectionMatch = content.match(/##\s*Pattern Compliance[\s\S]*?(?=\n##\s[^#]|\n---\s*$|$)/i);
  if (!sectionMatch) return warnings;

  const section = sectionMatch[0];

  // Look for FAIL entries in the table
  // Table format: | pattern | constraint | decision | FAIL |
  const failPattern = /\|\s*FAIL\s*\|/gi;
  const failMatches = section.match(failPattern);

  if (failMatches && failMatches.length > 0) {
    warnings.push({
      rule: 'pattern-compliance-fail',
      severity: 'block',
      message: `Pattern Compliance has ${failMatches.length} FAIL entry/entries. Plan MUST NOT proceed until all pattern violations are resolved.`,
    });

    // Extract the specific failing rows for context
    const lines = section.split('\n');
    for (const line of lines) {
      if (/\|\s*FAIL\s*\|/i.test(line)) {
        // Extract pattern name and constraint from the table row
        const cells = line.split('|').map(c => c.trim()).filter(c => c);
        if (cells.length >= 2) {
          warnings.push({
            rule: 'pattern-compliance-fail',
            severity: 'block',
            message: `  FAIL: ${cells[0]} - ${cells[1]}`,
          });
        }
      }
    }
  }

  return warnings;
}

/**
 * Check 3: Contract files referenced in plan exist on disk.
 * Non-blocking warning if contracts are mentioned but files don't exist yet.
 */
function checkContractConsistency(content, projectDir) {
  const warnings = [];

  // Look for contract file references in the plan
  const contractRefPattern = /contracts\/(api|events|errors)\.md/g;
  const refs = new Set();
  let match;

  while ((match = contractRefPattern.exec(content)) !== null) {
    refs.add(match[0]);
  }

  if (refs.size === 0) return warnings;

  // Find the specs directory for this plan
  const specsDir = path.join(projectDir, 'specs');
  if (!fs.existsSync(specsDir)) return warnings;

  // Check each referenced contract
  try {
    const specDirs = fs.readdirSync(specsDir, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => d.name);

    for (const ref of refs) {
      let found = false;
      for (const specDir of specDirs) {
        const contractPath = path.join(specsDir, specDir, ref);
        if (fs.existsSync(contractPath)) {
          found = true;
          break;
        }
      }
      if (!found) {
        warnings.push({
          rule: 'contract-consistency',
          severity: 'warn',
          message: `Plan references ${ref} but file not found in any specs directory. Ensure contracts are generated.`,
        });
      }
    }
  } catch (err) {
    // Ignore directory read errors
  }

  return warnings;
}

// --- Main ---

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Extract file path from tool input
    const filePath = data.tool_input?.file_path || '';

    // Only process plan.md files (matches plan.md, plan-*.md, *-plan.md, etc.)
    if (!filePath) {
      process.exit(0);
    }

    const baseName = path.basename(filePath).toLowerCase();
    if (!baseName.endsWith('.md')) {
      process.exit(0);
    }

    // Must contain "plan" in the filename
    if (!baseName.includes('plan')) {
      process.exit(0);
    }

    // Exclude backlog files (plan-backlog.md, claude-md-backlog.md, etc.) — they are
    // backlog lists of deferred items, not feature implementation plans, and don't
    // need the Verification Spec / Pattern Compliance / contract-consistency gates.
    if (baseName.includes('backlog')) {
      process.exit(0);
    }

    // Read the file content
    let content;
    try {
      content = fs.readFileSync(filePath, 'utf-8');
    } catch (readError) {
      process.exit(0);
    }

    if (!content || content.length === 0) {
      process.exit(0);
    }

    const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();

    // Run all checks
    const allWarnings = [
      ...checkVerificationSpecCompleteness(content),
      ...checkPatternCompliance(content),
      ...checkContractConsistency(content, projectDir),
    ];

    if (allWarnings.length === 0) {
      process.exit(0);
    }

    // Separate blocking errors from warnings
    const blockers = allWarnings.filter(w => w.severity === 'block');
    const warns = allWarnings.filter(w => w.severity === 'warn');

    // Format output
    const fileName = path.basename(filePath);

    if (warns.length > 0) {
      const warnDetails = warns
        .map(w => `  [${w.rule}] ${w.message}`)
        .join('\n');
      console.error(`[plan-gates] ${warns.length} warning(s) in ${fileName}:\n${warnDetails}`);
    }

    if (blockers.length > 0) {
      const blockDetails = blockers
        .map(w => `  [${w.rule}] ${w.message}`)
        .join('\n');
      const blockMessage = `[plan-gates] BLOCKED: ${blockers.length} pattern compliance failure(s) in ${fileName}:\n${blockDetails}\n\nResolve all FAIL entries in Pattern Compliance before proceeding.`;
      console.error(blockMessage);

      // Output as additionalContext for conversation visibility
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PostToolUse',
          additionalContext: blockMessage,
        },
      }));

      // Exit non-zero to block
      process.exit(2);
    }

    // Warnings only - output context but don't block
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: `Plan gate warnings for ${fileName}:\n${warns.map(w => `- [${w.rule}]: ${w.message}`).join('\n')}`,
      },
    }));

    process.exit(0);
  } catch (error) {
    // Hook error - fail-closed
    console.error('[validate-plan-gates] FATAL ERROR:', error.message);
    console.error('[validate-plan-gates] Hook failed - operation blocked for safety.');
    console.log(JSON.stringify({
      exit: 2,
      message: `validate-plan-gates failed: ${error.message}. Operation blocked for safety.`
    }));
    process.exit(2);
  }
}

main();
