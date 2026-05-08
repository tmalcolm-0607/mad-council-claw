# Expected output: basic input for /skill-audit

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (`.claude/skills/` exists + readable) passes |
| Step 1 | enumerate skills, parse frontmatter |
| Step 2 | score each on 6 dimensions: frontmatter, BP, Standards, evals, templates, multi-pass |
| Step 3 | classify tier: S=6/6, A=5/6, B=4/6, C=2-3/6, D=0-1/6 |
| Step 4 | apply tier-exempt rules (pure utilities exempt from evals/templates) |
| Step 5 | write audit matrix to `.mad/scratch/skill-audit-matrix.csv` + report `.mad/reports/skill-audit-<ts>.md` |

## Output Contract

- Each skill cites: dimension scores + tier + gap list
- Severity: BLOCKING (broken frontmatter) / MUST-FIX (missing required dimension for non-exempt) / SHOULD-FIX / CONSIDER
- Confidence floor enforced
- Anti-hallucination: tier assignments cite explicit scoring rule

## Verdict

ACCEPT — audit complete; gaps surfaced for next standardization loop iteration.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE on every SKILL.md)
- Standards inheritance ✓
- Templates produced ✓ (matrix CSV + report)
