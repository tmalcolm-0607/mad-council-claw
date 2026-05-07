---
artifact-class: council-review
feature-id: F-002
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-012 / lane-d
---

# F-002 per-agent-identity-runid — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 92 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 78 |
| architect-lens | Architect | APPROVE | 90 |

Median confidence: 90

## Implementation reviewed

- `packages/engine-core/src/identity.ts` — 146 LOC; `Session`, `Agent`, `CreateAgentOptions`, `IdentityStamped<T>` types + `createSession()`, `createAgent()`, `stampIdentity()` functions + internal `uuidV7()` per RFC 9562 §5.7. Split out from monolithic `index.ts` in wave-011/lane-a per the cross-lane staging-race elimination refactor.
- `tests/unit/F-002-per-agent-identity-runid.test.ts` — 3 acceptance scenarios; all PASS per `docs/09-examples-proof/F-002/green-test-output.txt` and re-confirmed at review time (3/3 PASS in 10ms; full vitest run 13/13 PASS across F-002 + F-006 + F-008).
- Commit history per `docs/07-roadmap/decision-log.md`: F-002 RED at wave-002 / lane-b (initial ledger); F-002 GREEN at wave-006 / lane-d, impl commit `5a0eb21` (`feat(M0): F-002 per-agent-identity-runid GREEN — UUID v7 + spawn correlation + IDENTITY_MISSING rejection`); engine-core split (Lane A wave-011) carved `identity.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 92)**

- Implementation is minimal and correct per `minimum-change.md`: ~146 LOC delivers the entire run_id + agent_id + parent_run_id correlation triple plus the audit-writer rejection contract that downstream features (F-006 logger, F-008 storage, F-019 cost-ledger) compose against.
- UUID v7 generator is hand-rolled because Node 24's `randomUUID()` returns v4 and silently ignores `{version: 7}`. The byte-fiddling is documented inline (RFC 9562 §5.7 layout: 48-bit ms timestamp + version-7 nibble + variant 10xx + remaining random bits). No third-party dependency; canonical 8-4-4-4-12 hex output. Test verifies via `UUID_V7_REGEX` that version + variant nibbles are correct.
- All 3 acceptance scenarios PASS: scenario 1 verifies UUID v7 shape + millisecond-prefix monotonicity (compares 12-hex-char timestamp prefix to honor the RFC's ms-resolution guarantee — the sub-ms ordering caveat is documented and the test deliberately uses a 5ms busy-wait to avoid flake). Scenario 2 verifies spawn correlation: agent B with `parentSession: A` carries `parentRunId = A.runId`, and stamped artifacts emit the full triple. Scenario 3 verifies IDENTITY_MISSING rejection on absent agent or session.
- `stampIdentity` is a **pure function** — returns a new `IdentityStamped<T>` object without mutating the input artifact. This composability is what makes the audit-writer boundary contract (F-006/F-008/F-019) clean: every downstream consumer can treat the stamp as a side-effect-free decoration.
- Surface trace per ledger maps cleanly: `ce:FR-IDENTITY-001` (correlation chain) + `kit:rules/single-owner-accountability.md` (identity is the substrate for ownership) + `cp:src/agents/identity` (clawpilot per-agent allocator pattern). Provenance is auditable and the public type surface (`Session`, `Agent`, `CreateAgentOptions`, `IdentityStamped<T>`) matches what the ledger contract describes.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 78)**

- F-002 explicitly defers cryptographic spawn signing + Entra principal-binding to v1.5 per `ce:FR-IDENTITY-002` / `FR-IDENTITY-003` (M19 deferred catalog). This means the current `stampIdentity` enforces structural-only identity discipline — there's nothing preventing a malicious caller from constructing an `Agent` with a forged `agentId` and stamping artifacts under it. The boundary is **shape-checking**, not **authenticity-checking**. Acceptable for v1; not safe for adversarial multi-tenant scenarios. The deferral is honest per `no-silent-deferrals.md` (ledger §out-of-scope-notes) — surfaced here so future readers don't mistake the contract for crypto-strong.
- The UUID v7 sub-ms ordering caveat: when two sessions are created within the same millisecond, the random-tail bits produce non-deterministic ordering. The test's 5ms busy-wait sidesteps this for the test's monotonicity check, but production callers building strict total-order audit replays need to NOT assume sub-ms order is deterministic. Documented in the ledger §Implementation notes; surfacing here so the v1.5 monotonic-random extension stays on the radar.
- Audit-writer integration is NOT yet wired: `stampIdentity` provides the boundary primitive that F-006 logger / F-008 storage / F-019 cost-ledger MUST compose against, but none of those features actually call `stampIdentity` in their current GREEN flips. The boundary is ready; the integrations are follow-on. This is honest per the ledger §dependencies (F-006/F-008 listed as soft deps, not hard) — but a reader could misread "F-002 LOCKED" as "all writers enforce IDENTITY_MISSING," which is not yet the case.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): track an explicit "identity-integration" follow-on F-NNN that wires `stampIdentity` through F-006 / F-008 / F-019 boundaries (and any future audit-writer). Without it, a reader of F-002 LOCKED could assume universal stamping; in fact only the boundary primitive is locked. The ledger's out-of-scope-notes already references the soft-dep relationship; backlog promotion to a concrete F-NNN is the closure path.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/identity.ts` lines 1-146 and `tests/unit/F-002-per-agent-identity-runid.test.ts` lines 1-96 directly; the implementation matches the contract; types are exported correctly through the `engine-core` barrel; UUID v7 byte layout matches RFC 9562 §5.7 (verified bytes[6] high-nibble = 0x70 and bytes[8] high two bits = 0x80).

## Architect lens

**Verdict: APPROVE (confidence 90)**

- File-split posture: `identity.ts` lives in `packages/engine-core/src/` per the wave-011/lane-a engine-core split. Separation of concerns is clean: `identity.ts` exports identity types + functions; `bootstrap.ts` (F-001) exports lifecycle types + functions. No circular dep, no shared mutable state. The barrel re-export (`packages/engine-core/src/index.ts`) re-surfaces both modules as a single import path for consumers (`@mad-council-claw/engine-core`).
- Public API surface (`Session { readonly runId }`, `Agent { readonly agentId, parentRunId? }`, `IdentityStamped<T> = T & {agent_id, run_id, parent_run_id?}`): symmetric and predictable. The `parent_run_id?` is omitted from the stamped output (rather than emitted as `undefined`) when the agent has no parent session — this avoids serializing optional-undefined fields in NDJSON / JSON outputs that downstream features will produce.
- Per ce:US-2 (every governance feature stamps run_id + agent_id): F-002 owns the per-agent identity that F-001 emits at run boot. The composition is correct — F-001 emits `runId` only via `RunResult`; F-002's `Session { runId }` gives F-001 a way to surface it; `Agent { agentId }` is layered on top per spawned agent. No leakage between the two features' responsibilities.
- The `IdentityStamped<T>` type uses TypeScript's intersection type (`T & { ... }`) to add identity fields without forcing the artifact to declare them upfront. Architecturally clean: callers pass any artifact type; the stamp decorates it; the resulting type carries the original fields plus the identity triple. Forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE) — F-006 / F-008 / F-019 future integrations can stamp their own audit/log/cost-row types without changes here.
- Hard deps: F-002 depends on F-001 only (engine kernel must exist for identity to attach to). Soft deps on F-006/F-008 are appropriate and uncoupled (the boundary is in place; integrations land in follow-on flips). No surprises in dep graph.
- Sub-ms ordering caveat is correctly localized to the test's monotonicity check, NOT to the public API. The public API gives a UUID v7 with the standard guarantees (ms-resolution monotonicity); the test compensates for the test's own ordering needs by using a 5ms busy-wait. The optional monotonic-random extension can be added later without changing the public type surface (per ledger §Implementation notes).

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Cryptographic spawn signing + Entra principal-binding deferred to v1.5 (ce:FR-IDENTITY-002 / 003). Current `stampIdentity` enforces shape-only identity, not authenticity. | Accept; LOCKED status applies to the structural-correlation contract; crypto layer is M19 deferred catalog scope. |
| F2 | MINOR | Audit-writer integration follow-on: `stampIdentity` boundary is ready but F-006 / F-008 / F-019 do not yet call it. Integration is the substrate of "every audit entry stamped"; without it, the rejection contract is theoretical for downstream consumers. | Accept; soft-dep-relationship ledger note already covers; backlog item: track explicit "identity-integration" F-NNN follow-on. |
| F3 | MINOR | Sub-ms UUID v7 ordering: same-ms session creation produces non-deterministic random-tail order. Production audit-replay code needs to NOT assume strict sub-ms total order. | Accept; documented in ledger §Implementation notes + test's 5ms busy-wait sidestep. Optional monotonic-random extension lands without API change. |
| F4 | PRAISE | UUID v7 hand-rolled to work around Node 24's silent `{version: 7}` ignore. No third-party dependency; the byte layout follows RFC 9562 §5.7 verbatim. | Keep. |
| F5 | PRAISE | `stampIdentity` is a pure function — no input mutation, returns a new `IdentityStamped<T>`. Composability for downstream audit-writer integrations. | Keep. |
| F6 | PRAISE | The `parent_run_id?` is omitted (rather than serialized as `undefined`) when an agent has no parent session. Clean NDJSON / JSON output for downstream features. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 90).

F-002 minimal-contract is implemented correctly; all 3 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-002 ledger frontmatter (`LOCKED if GREEN AND reviews/F-002-per-agent-identity-runid-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-002 ledger §out-of-scope-notes), not silently elided. Future deeper integration work (audit-writer enforcement; crypto signing; sub-ms monotonic ordering) is scoped to future F-NNNs, not a re-scoping of F-002's contract.

F-002 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-002-per-agent-identity-runid.md`
- Source: `packages/engine-core/src/identity.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-002-per-agent-identity-runid.test.ts` (3/3 PASS)
- GREEN proof: `docs/09-examples-proof/F-002/green-test-output.txt` + `physical-proof.md`
- GREEN transition: `docs/07-roadmap/decision-log.md` row 3; impl commit `5a0eb21`; wave-006 / lane-d
- Engine-core split: wave-011 / lane-a (no behavior change; pure refactor; verified by 75/75 PASS post-split)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Precedent: `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` (first LOCKED transition; wave-011 / lane-b)
