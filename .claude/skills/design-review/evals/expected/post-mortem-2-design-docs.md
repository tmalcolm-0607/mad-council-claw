# Expected output: post-mortem 2 design-doc consistency case

## Smart-default flow

| Step | Result |
|------|--------|
| 1.4 content-type | both `spec-change`; oracle: `spec.md`; vision-flag set (paths under `specs/ideas/`) |
| 1.5 grounding | fires (keywords: event sourcing + CQRS) |
| 1.6 risk score | 2 prescriptive design docs → blast surfaces for council |
| 1.7 ref-repo cross-check | cross-checks both prescription claims against `references/` |
| 1.8 cross-file consistency | **fires**: 2× spec-change group |
| 1.9 oracle | `spec.md` loaded; vision-flag relaxes some severity to non-blocking |

## Findings (in posting order)

### First — cross-file architectural contradiction (BLOCKING)

```
[BLOCKING] specs/ideas/event-sourcing-pattern.md vs specs/ideas/cqrs-pattern.md — contradictory consistency model

Evidence:
  event-sourcing-pattern.md:
    Eventual consistency between read and write models.
  cqrs-pattern.md:
    Strong consistency between command and query models within a single tenant.

Both docs touch overlapping domain (aggregate snapshots, read-vs-write
model relationship). One prescribes eventual; the other strong. Without
explicit reconciliation, downstream readers will pick one and break the
other.

Rule:
  rules/prescriptive-content-review.md § Gap 4 (same-type cross-file consistency)
  + .mad/templates/coverage-oracles/spec.md § Special checks (vision-vs-contract)

Confidence: 92
Suggested fix:
  Either:
  (a) reconcile in one doc that names the other as the primary consistency rule,
  (b) explicitly scope: doc A applies to module-A only, doc B to module-B only,
      and document the boundary,
  (c) merge into a single domain-level architecture doc.
```

### Second — cross-file inconsistent value (MUST-FIX)

```
[MUST-FIX] specs/ideas/event-sourcing-pattern.md vs specs/ideas/cqrs-pattern.md — snapshot frequency disagreement

Evidence:
  event-sourcing-pattern.md: "Snapshot frequency: every 100 events."
  cqrs-pattern.md: "Snapshot frequency: every 50 events."

Same operational concern; two different values; no rationale for divergence.

Rule:
  rules/prescriptive-content-review.md § Gap 4
  + .mad/templates/coverage-oracles/spec.md

Confidence: 78
Suggested fix:
  If the modules legitimately need different frequencies, justify in each
  doc. If not, align to a single value derived from operational constraints
  (Cosmos read-cost, recovery-time-objective).
```

### Third — both docs missing FR Logical Proof (per spec.md oracle)

```
[MUST-FIX] specs/ideas/*.md — Functional Requirements lack Logical Proof

Vision-flag relaxes this to MUST-FIX (not BLOCKING) because docs are
under specs/ideas/. When promoted to specs/<N>-feature/, this becomes
BLOCKING per spec.md oracle § Special checks.

Rule:
  .mad/templates/coverage-oracles/spec.md § 4 (Functional Requirements)
```

## Implementability gates

| # | Gate | Status |
|---|------|--------|
| 1 | Vision/Contract flag | ✗ (vision; non-blocking) |
| 2 | Newspaper Test | partial — FRs lack file/endpoint anchors |
| 3 | 3 Nouns Test | ✗ (each story lacks 3 concrete artifacts) |
| 4 | Implementation Squeeze | ✗ |
| 5 | Concept Density | ✓ |
| 6 | Test Plan Generation | ✗ (non-blocking for ideas/) |

## Verdict

REJECT — vision-grade documents with structural contradictions; require reconciliation before promotion to contract.

## Anti-hallucination

- Both contradictory passages quoted verbatim from each doc
- Snapshot-frequency claim cites both numbers + both filenames
- Cross-file findings emitted via Step 1.8, not synthesized

## Skill features exercised

- Step 1.8 cross-file consistency on 2× spec-change ✓
- Vision-vs-contract flag in spec oracle ✓
- 6 implementability gates passed-or-failed individually ✓
- Severity escalation for architectural contradiction (BLOCKING > MUST-FIX) ✓
