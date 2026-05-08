# Fixture: post-mortem doc PR (replicates PR #5157555 + #5157551 misses)

Synthetic input modeled on the May 2026 post-mortem. Validates that Steps 1.4-1.9 catch the 6 misses pr-review previously made.

## Synthetic input artifact

PR scope:
- 2 SKILL.md files modified (introducing a new "cosmos-repository-doc" skill + updating the related "cosmos-pattern-author" skill)
- 1 doc file added: `docs/patterns/cosmos-repository-pattern.md` — a teaching doc prescribing the Cosmos repository pattern for the org
- 0 source code changes

The doc file body covers (from the post-mortem):
- Partition key strategy ✓
- Indexing policy ✓
- Query patterns ✓ (3 queries shown)
- **PATCH / partial-update semantics — MISSING** (the load-bearing absence)
- Read patterns ✓
- Error handling — partial (only 429 retry; no 412/428 PATCH semantics tied)
- Bicep / infra index sync — missing
- Test coverage — present
- Migration / version handling — missing
- Telemetry — partial

The 2 SKILL.md files:
- A.md: `inherits-rules:` includes `prompt-injection-policy.md`
- B.md: `inherits-rules:` does NOT include it

PR description: "Documents how we use cosmos repository with partition key strategy. Reviewers should check the etag propagation guidance and the validator wiring section. Related work item: WI #5078234. See also references/LENS-CMS."

## Skill invocation

```
/pr-review <pr-id>
```

## Notes

This fixture is the regression test for the post-mortem. The 6 misses each map to a Step the new pipeline runs:

| Miss | Caught by Step |
|------|----------------|
| 1. No production grounding pull | Step 1.5 — keyword match on "cosmos repository", "etag propagation", "validator wiring", "partition key strategy", reference-repo mention "LENS-CMS", explicit work-item "WI #5078234" |
| 2. No reference-repo cross-check on doc PRs | Step 1.7 — content-type is `doc-change` + prescriptive language ("uses", "should") triggers cross-check independent of consumer-code gate |
| 3. No content-coverage pass | Step 1.9 — `cosmos-doc.md` oracle loaded; PATCH section missing → BLOCKING |
| 4. No cross-document consistency step | Step 1.8 — 2× SKILL.md in `cross_file_groups[]`; flag inherits-rules divergence |
| 5. Risk-score blind to doc-PR blast radius | Step 1.6 — content-type `doc-change` with org-wide audience → blast_radius=7 → auto-promote to `--council` |
| 6. Severity calibration off | Output Contract content-type-aware table — for doc-change, structural absence (PATCH section) is BLOCKING; stylistic precision (typo) is CONSIDER. First finding posted is BLOCKING-PATCH-missing, not CONSIDER-typo. |
