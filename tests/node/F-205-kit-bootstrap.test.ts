import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

/**
 * F-205 RED -> GREEN test — kit-bootstrap manifest assertion (Wave 19 Lane C, batch 1 of N).
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md.
 *
 * Behavior contract (scoped to wave-019 / lane-c batch-1 RED -> GREEN flip):
 *   The mad-council-claw repo carries a first batch of kit-generic load-bearing
 *   antipattern + orchestration + canonical-pipeline + quality-gate rules copied
 *   from the MAD - Clean kit (the substrate the engine inherits per
 *   docs/04-research/mad-kit-inventory.md:881 "Most kit primitives transfer cleanly").
 *
 *   The 26 rules in this batch are the load-bearing doctrine for the engine's
 *   quality-gate path: antipattern fences (no-silent-deferrals, no-top-n-capping,
 *   canonical-skill-only, canonical-artifact-frontmatter, scope-discipline,
 *   non-negotiable-rules, minimum-change, no-invented-constraints, verification-protocol),
 *   loop discipline (autonomous-loop-discipline, loop-cadence-discipline,
 *   loop-stop-language-discipline), orchestration (orchestration,
 *   orchestrator-identity, agent-teams, anomaly-thresholds, context-guardian),
 *   security + concurrency (prompt-injection-policy, dangerous-operations-policy,
 *   degradation-fallback-policy, concurrency-safety), pipeline + governance
 *   (mad-workflow, quality-gates, skill-standards, _status-convention,
 *   artifact-placement).
 *
 *   This batch is intentionally rules-only. Scope-allocation for items not
 *   landed by this batch is documented in the F-205 ledger §"Future batches"
 *   table — see docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md.
 *   Per .claude/rules/no-silent-deferrals.md, the test asserts ONLY what this
 *   batch landed; the per-batch GREEN interpretation is recorded in F-205
 *   §status-history.
 *
 * Acceptance scenarios (manifest-driven; structural via existsSync +
 * readFileSync; no runtime hook execution):
 *   1. .claude/rules/ directory exists in mad-council-claw repo root.
 *   2. Each of the 26 rule files in the batch exists and is non-empty (size > 0).
 *   3. Each rule file has a recognizable rule-shape opener: either YAML
 *      frontmatter (-- delimiter on line 1) OR a top-level Markdown heading
 *      (# on line 1). Either shape is valid per kit's _status-convention.md
 *      ("Absence of status: implies stable").
 *   4. The 9 load-bearing antipattern rules contain semantic markers proving
 *      the rule body landed (not just frontmatter): a "Rule statement" or
 *      equivalent invariant section. Specifically:
 *        - no-silent-deferrals.md mentions "Don't quietly drop"
 *        - no-top-n-capping.md mentions "enumerate exhaustively"
 *        - canonical-skill-only.md mentions "Inline authoring"
 *        - canonical-artifact-frontmatter.md mentions "frontmatter"
 *        - scope-discipline.md mentions "every item"
 *        - verification-protocol.md mentions "FETCH BEFORE CITE"
 *        - minimum-change.md mentions "smallest change"
 *        - non-negotiable-rules.md mentions "MUST NOT"
 *        - orchestrator-identity.md mentions "ORCHESTRATE ONLY"
 *
 * The test's narrowness is deliberate per F-205 §Implementation notes Batch-4:
 * "manifest-driven; not runtime-execution test". Runtime hook firing is a
 * separate test wave gated on the hooks landing in a later batch.
 */

const repoRoot = join(__dirname, '..', '..');

/** Wave 19 Lane C batch 1 manifest — 26 kit-generic rules. */
const BATCH_1_RULES: ReadonlyArray<string> = [
  // Antipattern fences (load-bearing)
  'no-silent-deferrals.md',
  'no-top-n-capping.md',
  'canonical-skill-only.md',
  'canonical-artifact-frontmatter.md',
  'scope-discipline.md',
  'non-negotiable-rules.md',
  'minimum-change.md',
  'no-invented-constraints.md',
  'verification-protocol.md',
  // Loop discipline
  'autonomous-loop-discipline.md',
  'loop-cadence-discipline.md',
  'loop-stop-language-discipline.md',
  // Orchestration (load-bearing)
  'orchestration.md',
  'orchestrator-identity.md',
  'agent-teams.md',
  'anomaly-thresholds.md',
  'context-guardian.md',
  // Security + concurrency
  'prompt-injection-policy.md',
  'dangerous-operations-policy.md',
  'degradation-fallback-policy.md',
  'concurrency-safety.md',
  // Pipeline + governance
  'mad-workflow.md',
  'quality-gates.md',
  'skill-standards.md',
  '_status-convention.md',
  'artifact-placement.md',
];

/** Semantic-marker spot-checks proving rule body (not just frontmatter) landed. */
const SEMANTIC_MARKERS: ReadonlyArray<{ file: string; pattern: RegExp; description: string }> = [
  {
    file: 'no-silent-deferrals.md',
    pattern: /Don't quietly drop/i,
    description: 'no-silent-deferrals must contain core directive',
  },
  {
    file: 'no-top-n-capping.md',
    pattern: /enumerate exhaustively/i,
    description: 'no-top-n-capping must contain core directive',
  },
  {
    file: 'canonical-skill-only.md',
    pattern: /Inline authoring/i,
    description: 'canonical-skill-only must mention inline-authoring antipattern',
  },
  {
    file: 'canonical-artifact-frontmatter.md',
    pattern: /frontmatter/i,
    description: 'canonical-artifact-frontmatter must reference the contract',
  },
  {
    file: 'scope-discipline.md',
    pattern: /every item/i,
    description: 'scope-discipline must contain "every item" directive',
  },
  {
    file: 'verification-protocol.md',
    pattern: /FETCH BEFORE CITE/i,
    description: 'verification-protocol must contain Rule 1 invariant',
  },
  {
    file: 'minimum-change.md',
    pattern: /smallest change/i,
    description: 'minimum-change must contain core principle',
  },
  {
    file: 'non-negotiable-rules.md',
    pattern: /MUST NOT/,
    description: 'non-negotiable-rules must contain verb-bound permission fences',
  },
  {
    file: 'orchestrator-identity.md',
    pattern: /ORCHESTRATE ONLY/,
    description: 'orchestrator-identity must contain core principle',
  },
];

function rulePath(filename: string): string {
  return join(repoRoot, '.claude', 'rules', filename);
}

describe('F-205 kit-bootstrap (batch 1 — kit-generic rules)', () => {
  it('.claude/rules/ directory exists at repo root', () => {
    const dir = join(repoRoot, '.claude', 'rules');
    expect(existsSync(dir), `.claude/rules/ missing — expected ${dir}`).toBe(true);
  });

  describe('all 26 batch-1 rule files exist and are non-empty', () => {
    for (const rule of BATCH_1_RULES) {
      it(`.claude/rules/${rule} exists and is non-empty`, () => {
        const path = rulePath(rule);
        expect(existsSync(path), `${rule} missing at ${path}`).toBe(true);
        expect(
          statSync(path).size,
          `${rule} is empty — expected size > 0`,
        ).toBeGreaterThan(0);
      });
    }
  });

  describe('each rule file has a recognizable rule-shape opener', () => {
    for (const rule of BATCH_1_RULES) {
      it(`.claude/rules/${rule} opens with frontmatter or top-level heading`, () => {
        const path = rulePath(rule);
        const content = readFileSync(path, 'utf8');
        const firstLine = content.split('\n', 1)[0]!.trim();
        const hasFrontmatter = firstLine === '---';
        const hasHeading = firstLine.startsWith('# ');
        expect(
          hasFrontmatter || hasHeading,
          `${rule} first line "${firstLine}" is neither frontmatter (---) nor a top-level heading (# ...)`,
        ).toBe(true);
      });
    }
  });

  describe('load-bearing rules contain core semantic markers (body landed, not just frontmatter)', () => {
    for (const marker of SEMANTIC_MARKERS) {
      it(marker.description, () => {
        const path = rulePath(marker.file);
        expect(existsSync(path), `${marker.file} missing at ${path}`).toBe(true);
        const content = readFileSync(path, 'utf8');
        expect(
          marker.pattern.test(content),
          `${marker.file} missing pattern ${marker.pattern} — body may not have copied correctly`,
        ).toBe(true);
      });
    }
  });

  it('manifest count matches expected batch-1 size (26 rules)', () => {
    expect(BATCH_1_RULES.length).toBe(26);
  });
});
