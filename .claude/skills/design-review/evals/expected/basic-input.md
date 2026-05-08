# Expected output: basic input for /design-review

## Implementability gates

| # | Gate | Status | Reason |
|---|------|--------|--------|
| 1 | Vision/Contract flag | ✗ | Path is `specs/ideas/` → vision document; non-blocking |
| 2 | Newspaper Test | ✗ | "What file confirms FR-1?" has no answer |
| 3 | 3 Nouns Test | ✗ | User stories lack 3 concrete artifacts each |
| 4 | Implementation Squeeze | ✗ | Top 3 FRs do not yield a verification command |
| 5 | Concept Density | ✓ | ≤5 new coined terms |
| 6 | Test Plan Generation | ✗ (non-blocking for ideas/) | No test plan; vision doc, OK |

## Output Contract

Per finding:
- `[severity] section — title`
- Evidence (verbatim quote, ≤6 lines)
- Rule (citation: gate # + skill body section)
- Confidence
- Suggested fix

## Open questions ([NEEDS CLARIFICATION] markers)

- [ ] What does "fast" mean (FR-2)? Define p95 latency target.
- [ ] What does "integrates with Bar" mean (FR-3)? Sync, async, contract?

## Verdict

REJECT — vision document has no verifiable FRs; expected for `specs/ideas/`. Move to `specs/<N>-feature/` and re-run gates after FR Logical Proof points to file/endpoint/command for each FR.

## Skill features exercised

- Smart-default flow ✓
- 6 implementability gates ✓
- Vision-vs-Contract flag ✓
- Anti-hallucination check ✓
- Template applied ✓
