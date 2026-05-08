# Expected output: post-mortem doc PR

## Smart-default flow

| Step | Result |
|------|--------|
| 0 PR status | active |
| 1 PR data collection | OK |
| 1.3 Preflight | passes |
| **1.4 Content-type detection** | mixed (`doc-change` + `skill-md-change`); `recommended_oracles`: `cosmos-doc.md` + `skill-md.md`; `blast_radius_max=7`; `council_escalate=true`; `cross_file_groups` includes 2× SKILL.md |
| **1.5 Production grounding** | **fired=true**, 7+ triggers (work-item ID, reference-repo `LENS-CMS`, keywords: cosmos repository, partition key strategy, etag propagation, validator wiring) |
| **1.6 Risk score** | blast_radius=7 → auto-promote to `--council` |
| **1.7 Reference-repo cross-check** | runs (decoupled from consumer-code gate); each prescription cross-checked against `references/LENS-CMS` |
| **1.8 Same-type cross-file consistency** | runs on the 2× SKILL.md group; flags inherits-rules divergence (A.md inherits prompt-injection-policy; B.md doesn't) |
| **1.9 Completeness oracle** | loads `cosmos-doc.md` + `skill-md.md`; emits per-section `present \| partial \| missing` |

## Expected findings (in posting order)

### First — structural absence (BLOCKING per content-type calibration)

```
[BLOCKING] docs/patterns/cosmos-repository-pattern.md — PATCH / partial-update semantics section missing

Evidence:
  Doc covers partition keys, indexing, queries, but no section addresses
  If-Match ETag propagation, 412 Precondition Failed handling, or PATCH vs
  ReplaceItem semantics.

Rule:
  rules/prescriptive-content-review.md § Gap 3
  + .mad/templates/coverage-oracles/cosmos-doc.md § 4 (PATCH / partial-update semantics)

Confidence: 95
Suggested fix:
  Add a "PATCH / partial-update semantics" section covering:
  - If-Match header propagation pattern
  - 412 Precondition Failed handling
  - 428 Precondition Required handling
  - PATCH vs ReplaceItem distinction
```

### Second — cross-file consistency (BLOCKING per skill-md severity table)

```
[BLOCKING] .claude/skills/A/SKILL.md vs .claude/skills/B/SKILL.md — inconsistent inherits-rules

Evidence:
  A.md inherits-rules:
    - rules/prompt-injection-policy.md
  B.md inherits-rules:
    (prompt-injection-policy.md absent)

Rule:
  rules/prescriptive-content-review.md § Gap 4 (same-type cross-file consistency)
  + .mad/templates/coverage-oracles/skill-md.md § Cross-file consistency

Confidence: 88
Suggested fix:
  Both skills consume external message bodies; both should inherit
  prompt-injection-policy.md. Either add to B.md or document why B.md
  is exempt.
```

### Third+ — additional missing oracle sections

- `[BLOCKING]` Bicep / infra index sync section missing (cosmos-doc oracle § 7)
- `[SHOULD-FIX]` Migration / version handling section missing (oracle § 9)
- `[SHOULD-FIX]` Telemetry section partial (oracle § 10)

### NOT first

`[CONSIDER]` field rename inconsistency in line 219 — present but emitted AFTER all BLOCKING / MUST-FIX findings, not first.

## Verdict

REJECT (BLOCKING findings present); auto-promoted to `--council` mode for Architect to confirm scoping.

## Anti-hallucination check

- Every cited oracle section number verified by reading the oracle
- Every "missing" claim cites the oracle's section title verbatim
- Cross-file findings quote both skills' relevant frontmatter lines
- Topic-keyword matches cite the keyword from `topic-grounding-keywords.json`

## Skill features exercised

- Step 1.4 dispatcher ✓
- Step 1.5 grounding (work-item + topic + reference-repo triggers) ✓
- Step 1.6 blast_radius axis + council auto-escalate ✓
- Step 1.7 reference-repo cross-check on prescriptive content ✓
- Step 1.8 same-type cross-file consistency ✓
- Step 1.9 completeness oracle ✓
- Content-type-aware severity calibration ✓
- Post-mortem regression test ✓
