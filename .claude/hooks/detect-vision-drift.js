#!/usr/bin/env node

/**
 * detect-vision-drift.js
 *
 * PostToolUse hook for Write/Edit on spec files.
 * Detects when a specification is drifting into vision/architecture territory
 * by checking concept density and concrete artifact references.
 *
 * Fail-open: exits 0 on error (advisory, not blocking).
 */

const fs = require('fs');

async function main() {
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  let event;
  try {
    event = JSON.parse(input);
  } catch {
    process.exit(0); // fail-open
  }

  const toolName = event.tool_name;
  if (toolName !== 'Write' && toolName !== 'Edit') {
    process.exit(0);
  }

  // Only check spec files
  const filePath = event.tool_input?.file_path || event.tool_input?.filePath || '';
  if (!filePath.includes('spec.md') || filePath.includes('ideas/')) {
    process.exit(0); // Don't check idea docs — they're allowed to be visionary
  }

  // Read the file that was just written/edited
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch {
    process.exit(0); // fail-open
  }

  const warnings = [];

  // Check 1: Concept density — count CamelCase coined terms
  const camelCaseTerms = new Set();
  const camelRegex = /\b[A-Z][a-z]+(?:[A-Z][a-z]+){1,}\b/g;
  let match;
  while ((match = camelRegex.exec(content)) !== null) {
    // Filter out common programming terms
    const common = ['GitHub', 'TypeScript', 'JavaScript', 'PostgreSQL', 'PowerShell',
      'WebSocket', 'SignalR', 'OpenTelemetry', 'ProblemDetails', 'CamelCase',
      'PascalCase', 'FluentValidation', 'FluentAssertions', 'NSubstitute',
      'ApiController', 'JsonPropertyName', 'HttpClient', 'DbContext',
      'TaskCreate', 'TaskUpdate', 'TaskList', 'SendMessage', 'AskUserQuestion',
      'EnterPlanMode', 'ExitPlanMode', 'NotebookEdit', 'WebFetch', 'WebSearch',
      'TeamCreate', 'TeamDelete'];
    if (!common.includes(match[0])) {
      camelCaseTerms.add(match[0]);
    }
  }

  if (camelCaseTerms.size > 15) {
    warnings.push(
      `VISION DRIFT: Spec introduces ${camelCaseTerms.size} coined compound terms (threshold: 15). ` +
      `High concept density suggests this may be an architecture vision, not an implementable contract. ` +
      `Top terms: ${[...camelCaseTerms].slice(0, 8).join(', ')}...`
    );
  }

  // Check 2: Vision language ratio
  const visionWords = (content.match(/\b(enables|allows|facilitates|envisions|evolves|graduating|aspirational|theoretical|future|unlimited|self-improving)\b/gi) || []).length;
  const concreteWords = (content.match(/\b(MUST|SHALL|returns|creates|writes|reads|sends|receives|stores|deletes|endpoint|table|file|command|test|assert)\b/gi) || []).length;

  if (visionWords > 0 && concreteWords > 0) {
    const ratio = visionWords / concreteWords;
    if (ratio > 0.5) {
      warnings.push(
        `VISION DRIFT: Vision-language ratio is ${ratio.toFixed(2)} (${visionWords} vision words vs ${concreteWords} concrete words). ` +
        `Specs should have ratio < 0.3. Consider moving aspirational content to specs/ideas/.`
      );
    }
  }

  // Check 3: FRs without Logical Proofs
  const frCount = (content.match(/\*\*FR-/g) || []).length;
  const logicalProofCount = (content.match(/Logical Proof:/gi) || []).length;
  if (frCount > 0 && logicalProofCount < frCount * 0.8) {
    warnings.push(
      `IMPLEMENTABILITY: ${frCount} FRs found but only ${logicalProofCount} have Logical Proofs. ` +
      `Every FR needs a Logical Proof specifying a concrete verification artifact.`
    );
  }

  if (warnings.length > 0) {
    process.stderr.write(`Vision Drift Detection:\n${warnings.join('\n')}\n`);
    process.exit(0); // Advisory — don't block, just warn
  }

  process.exit(0);
}

main().catch(() => process.exit(0));
