---
artifact-class: council-review
feature-id: F-014
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-c
---

# F-014 pre-close-retro-signal — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 75 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/retro.ts` — 189 LOC; `RetroOutcome` union, `RetroSignal` interface (5-axis Likert 1-5 + 7 pattern fields + outcome + optional `trigger_evidence_sha256`), `RetroMissingError` class with `.missingFields: string[]`, `closeSession(retro)` boundary contract. Split from monolithic `index.ts` in wave-011/lane-a per the cross-lane staging-race elimination refactor.
- `tests/unit/F-014-pre-close-retro-signal.test.ts` — 8 acceptance scenarios (3 ledger scenarios + halted-by carve-out + 4 extended Likert / pattern validation cases); all PASS per `docs/09-examples-proof/F-014/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-014 RED at wave-002 / lane-b (initial ledger); F-014 GREEN at wave-008 / lane-a, RED test commit `d896ecb`, impl commit `ba54036`; engine-core split (wave-011 / lane-a) carved `retro.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`: ~189 LOC delivers the entire pre-close retro contract — 5-axis Likert validation + 7 pattern-prose validation + halted-by carve-out + `RetroMissingError` with per-field `.missingFields` diagnostic. The boundary primitive that F-008 (filesystem persistence to `runs/<run_id>/retro.json`) and F-015 (audit-chain integration of the retro entry) compose against is locked here; integrations follow.
- All 8 acceptance scenarios PASS: scenarios 1-3 cover the ledger contract (natural close → outcome `completed`; halted close → outcome `halted_by_kill_switch` + `trigger_evidence_sha256`; missing retro → `RETRO_MISSING` rejection). The 5 extended scenarios cover Likert range validation (integer 1-5), non-empty string pattern fields, recognized outcome enum, and 64-hex SHA-256 carve-out validation for halted-by outcomes.
- `RetroMissingError` carries `.missingFields: string[]` so engine code can surface a precise diagnostic ("retro missing: accuracy, completeness") rather than a generic boolean. Per-field granularity is the kit's `verification-protocol.md` Rule 4 (ACTUAL BEFORE PRESENT) discipline applied to error reporting.
- F-014 was the third feature to flip RED → GREEN (after F-001 wave-005, F-002 wave-006) and the FIRST M2 (governance triad) feature. LOCKED transition makes it the first M2 LOCKED transition; the parallel-triple LOCKED-flip wave pattern proposed in wave-011/lane-b's backlog continues into M2.
- Surface trace per ledger maps cleanly: `ce:FR-CORE-004` (mandatory pre-close retro signal — ALAS Step 9 anchor) + `ce:FR-CORE-005` (halted-by carve-out with trigger evidence) + `kit:council-retro-skill` (5-axis scoring rubric + blameless framing). Provenance is auditable.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 75)**

- F-014 is a **boundary primitive**; the deeper integrations are explicitly out-of-scope per the ledger §Implementation notes. Four distinct deferrals (each surfaced honestly per `no-silent-deferrals.md`):
  1. **Filesystem persistence to `runs/<run_id>/retro.json`** — F-008's job (storage layout); the boundary is ready but the storage write is a follow-on flip.
  2. **Audit-pipeline integration** (write retro entry into hash-chained audit log) — F-015's job; the F-015 chain primitive is GREEN (and locked in this same wave-013), but the integration step that routes a retro emit through `appendAuditEntry()` is unfinished.
  3. **Halt-source wiring** — F-020 (kill-switch), F-018 (failure-pattern halt), F-022 (tool-quota) supply `trigger_evidence_sha256`; all three are GREEN but the call-site wiring is engine-cycle integration scope.
  4. **ALAS-compatible learning-hub posting** — M11 deferred (F-088..F-092 soul/introspect/replay).
- A reader of the ledger could mistake "F-014 LOCKED" for "every run automatically emits a retro to disk and the audit chain" — which is not yet the case. The boundary contract (`closeSession` rejects close on missing retro) is locked; the substrate behavior (engine code calls `closeSession` during `closing` lifecycle state, persists to disk, emits to audit chain) is owned by future engine-integration features.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): track a "retro-engine-integration" follow-on F-NNN that wires `closeSession` into F-001's `closing` lifecycle hook + F-008 filesystem write + F-015 audit-chain emit. Pairs with the F-001/F-002 audit-writer integration follow-ons noted in the F-001 + F-002 reviews.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/retro.ts` lines 1-189 and `tests/unit/F-014-pre-close-retro-signal.test.ts` directly; `closeSession` validation matches the contract; the halted-by carve-out (64-hex SHA-256 required when outcome starts with `halted_by_`) is correctly enforced; `RetroMissingError.missingFields` is populated from a missing-keys walk over the input.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-split posture: `retro.ts` lives in `packages/engine-core/src/` per the wave-011/lane-a engine-core split. Clean module boundary; the surface (`RetroOutcome`, `RetroSignal`, `RetroMissingError`, `closeSession`) re-exports through the barrel (`packages/engine-core/src/index.ts`). No cross-feature imports; F-014 is independent of F-001/F-002 at the type level (the lifecycle composition happens at engine-cycle integration time when `closeSession` is called during `closing`).
- API surface (`RetroOutcome` union + `RetroSignal` interface + `RetroMissingError` extends `Error` + `closeSession(retro): {ok: true}`): symmetric and predictable. The `{ok: true}` return on success leaves room for a richer envelope later (e.g. `{ok: true, retro_sha256: ...}` once F-015 audit-chain integration lands) without breaking callers.
- Halted-by carve-out architecture: when `outcome` starts with `halted_by_`, a 64-char lowercase hex `trigger_evidence_sha256` MUST be present. The carve-out shape is forward-compatible with F-018 / F-020 / F-022 — each halt-source feature emits an audit entry; its `entry_sha256` (a 64-hex SHA-256 per F-015) plugs directly into `trigger_evidence_sha256` without transformation. Architecturally clean: the substrate of "every halt is auditable" composes through identity-preserving primitives.
- 5-axis Likert + 7 pattern fields shape: matches the `kit:council-retro-skill` rubric. Each Likert axis is integer 1-5 (validated); each pattern field is non-empty string (validated). The shape is a **content schema**, not a presentation schema — the retro file format on disk (when F-008 lands) is free to render this however; the `RetroSignal` shape is the canonical in-memory contract.
- No surprises in dependencies: F-014 has hard deps on F-001 (lifecycle) and F-008 (storage layout for retro.json — but the storage write itself is deferred). Soft deps on F-015 (retro entry written to audit log) and F-018/F-020/F-022 (halt outcomes feed `trigger_evidence_sha256`). All soft deps are now GREEN; the engine-cycle integration is the load-bearing follow-on.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Filesystem persistence to `runs/<run_id>/retro.json` deferred to F-008 (storage layout). Boundary is ready; storage write is follow-on. | Accept; LOCKED status applies to the in-memory boundary contract; F-008 ledger §depends-on already names the integration. |
| F2 | MINOR | Audit-pipeline integration (write retro entry into hash-chained audit log) deferred. F-015 primitive is GREEN (and LOCKED in this same wave-013); the wiring step is engine-cycle integration scope. | Accept; backlog item: track explicit "retro-engine-integration" F-NNN follow-on. |
| F3 | MINOR | Halt-source wiring deferred. F-018 / F-020 / F-022 are GREEN but the call-site wiring that supplies `trigger_evidence_sha256` from a real halt audit entry is engine-cycle integration scope. | Accept; halt-source primitives are LOCKED-pending; integration F-NNN scope (same as F2). |
| F4 | MINOR | ALAS-compatible learning-hub posting (downstream consumption of the retro signal) deferred to M11 (F-088..F-092 soul/introspect/replay). | Accept; out-of-scope per ledger §out-of-scope-notes. |
| F5 | PRAISE | `RetroMissingError.missingFields` carries per-field diagnostic so engine code surfaces precise rejection reasons rather than generic booleans. Verification-protocol Rule 4 discipline applied to error reporting. | Keep. |
| F6 | PRAISE | Halted-by carve-out enforces 64-hex SHA-256 shape on `trigger_evidence_sha256` — composable with F-015's `entry_sha256` shape without transformation. Forward-compatible by design. | Keep. |
| F7 | PRAISE | First M2 (governance triad) feature to flip GREEN (wave-008/lane-a) AND first M2 LOCKED transition (this wave-013/lane-c). Continues the parallel-triple LOCKED-flip wave pattern proposed in wave-011/lane-b's backlog. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-014 minimal-contract is implemented correctly; all 8 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-014 ledger frontmatter (`LOCKED if GREEN AND reviews/F-014-pre-close-retro-signal-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-014 ledger §Implementation notes), not silently elided. Future engine-cycle integration work (filesystem write, audit-chain emit, halt-source wiring) is scoped to a future F-NNN, not a re-scoping of F-014's contract.

F-014 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-014-pre-close-retro-signal.md`
- Source: `packages/engine-core/src/retro.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-014-pre-close-retro-signal.test.ts` (8/8 PASS)
- GREEN proof: `docs/09-examples-proof/F-014/green-test-output.txt` + `physical-proof.md`
- GREEN transition: `docs/07-roadmap/decision-log.md`; impl commit `ba54036`; wave-008 / lane-a
- Engine-core split: wave-011 / lane-a (no behavior change; pure refactor)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Precedent: `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` (first LOCKED transition; wave-011 / lane-b) + `F-002-per-agent-identity-runid-review.md` + `F-006-logging-pipeline-review.md` + `F-008-local-storage-layout-review.md` (parallel triple wave-012 / lane-d)
