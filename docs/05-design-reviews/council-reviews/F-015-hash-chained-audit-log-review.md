---
artifact-class: council-review
feature-id: F-015
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-c
---

# F-015 hash-chained-audit-log — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 91 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 76 |
| architect-lens | Architect | APPROVE | 89 |

Median confidence: 89

## Implementation reviewed

- `packages/engine-core/src/audit.ts` — 263 LOC (covers F-015 + F-016 surfaces; F-015 region: ~165 LOC). `GENESIS_SENTINEL = 'GENESIS' as const`, `AuditLogEntry` interface, `AuditLogEntryInput` interface, `VerifyAuditChainResult` discriminated union, `appendAuditEntry(log, input) → AuditLogEntry`, `verifyAuditChain(log) → VerifyAuditChainResult`, internal `canonicalJson` recursive key-sorted serializer + `computeEntrySha256` over canonical JSON. Split from monolithic `index.ts` in wave-011/lane-a per the cross-lane staging-race elimination refactor.
- `tests/unit/F-015-hash-chained-audit-log.test.ts` — 4 acceptance scenarios; all PASS per `docs/09-examples-proof/F-015/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-015 RED at wave-002 / lane-b (initial ledger); F-015 GREEN at wave-008 / lane-b, RED test commit `3d91a72`, impl commit `23f4475`; engine-core split (wave-011 / lane-a) carved `audit.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 91)**

- Implementation is minimal and correct per `minimum-change.md`: ~165 LOC delivers the entire hash-chain primitive — `appendAuditEntry` (writer with chain stamping) + `verifyAuditChain` (reader with first-mismatch reporting) + canonical-JSON serializer + SHA-256 over canonical JSON. The boundary primitive that F-001 cycle audit, F-006 logger, F-008 storage, and F-014 retro signal compose against is locked here; integrations follow.
- All 4 acceptance scenarios PASS: scenario 1 (genesis entry → `prev_sha256 === "GENESIS"` and valid 64-hex `entry_sha256`); scenario 2 (manual edit of `fields.cycle` → `verifyAuditChain` returns `{valid: false, broken_at: K, reason: "entry_sha256 mismatch"}`); scenario 3 (append after valid chain preserves chain integrity); plus a fourth scenario covering `prev_sha256` tampering (caught via `entry_sha256 mismatch` first since prev_sha256 is part of the hash input).
- `appendAuditEntry` returns the **sealed entry** — caller-facing `AuditLogEntryInput` (cycle + action + fields) is decorated with the chain fields (`prev_sha256` + `entry_sha256`) by the writer. This keeps the caller API minimal: the hash chain is a writer-side concern, not something every caller must compute.
- `VerifyAuditChainResult` is a discriminated union with two failure modes (`entry_sha256 mismatch` vs `prev_sha256 mismatch`) — gives storage-layer consumers (a future repair-from-backup tool per `ce:FR-AUDIT-002`) precise diagnostics for the failure class.
- Surface trace per ledger maps cleanly: `ce:FR-AUDIT-001` (hash-chained audit log + Query-AuditLog) + `ce:FR-AUDIT-002` (repair / restore from backup pathway) + `kit:rules/concurrency-safety.md §1` (append-only message-file pattern). Provenance is auditable.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 76)**

- F-015 is a **boundary primitive**; the deeper integrations are explicitly out-of-scope per the ledger §Implementation notes. Four distinct deferrals (each surfaced honestly per `no-silent-deferrals.md`):
  1. **Cryptographic signing of audit entries** (third-party timestamping per `ce:FR-IDENTITY-002`) — deferred to v1.5; tracked in F-D-005. The current implementation **detects tampering** (any post-hoc edit breaks the chain) but does NOT **prevent** it cryptographically. A motivated attacker with FS write access can rewrite the entire chain (recompute every hash forward from the tampered point) and the result will validate. This is acceptable for v1's threat model (filesystem trust inherits from OS); not safe for adversarial multi-tenant scenarios.
  2. **Persistence to `runs/<run_id>/audit.ndjson`** — F-008's job (storage layout); the boundary is ready, the storage write is a follow-on flip.
  3. **Logging-pipeline wiring** (engine cycle events emit through `appendAuditEntry`) — F-006's job; the F-006 logger primitive is GREEN + LOCKED, but the integration step that routes engine cycle events through the audit chain is unfinished.
  4. **Repair-from-backup** (per `ce:FR-AUDIT-002`) — `verifyAuditChain` pinpoints the broken index; the repair tool that splices in a backup row is a follow-on feature.
- The canonical-JSON serializer is **lightweight** (recursive key-sort, sufficient for v1's free-form `fields` payload). RFC 8785 (JCS) precision is deferred to v1.5 if cross-language verification is ever needed. A reader could mistake "F-015 LOCKED" for "audit chain is verifiable across language boundaries" — which is not yet the case. Ledger §Implementation notes acknowledges this; surfacing here so the v1.5 RFC 8785 extension stays on the radar.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): track an explicit "audit-chain-engine-integration" follow-on F-NNN that wires `appendAuditEntry` through engine cycle emits + retro-signal emits + cost-ledger emits. Pairs with F-006's "logging-storage-integration" follow-on noted in the F-006 review.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/audit.ts` lines 1-263 directly; F-015's `appendAuditEntry` correctly stamps `prev_sha256` from the prior entry's `entry_sha256` (or `GENESIS_SENTINEL` for the first entry); `verifyAuditChain` walks once O(N) and reports the first failure with zero-based index; both entry and prev mismatch modes are correctly distinguished.

## Architect lens

**Verdict: APPROVE (confidence 89)**

- File-split posture: `audit.ts` lives in `packages/engine-core/src/` per the wave-011/lane-a engine-core split. The file co-hosts F-015 (write side) and F-016 (read side) surfaces — architecturally clean since the read API (`queryAuditLog`, `findChainBreak` — the F-016 region) shares the same `AuditLogEntry` shape and depends directly on `verifyAuditChain`. Re-exports through the barrel (`packages/engine-core/src/index.ts`).
- API surface (`GENESIS_SENTINEL` + `AuditLogEntry` + `AuditLogEntryInput` + `VerifyAuditChainResult` + `appendAuditEntry` + `verifyAuditChain`): symmetric and predictable. The `AuditLogEntryInput`-vs-`AuditLogEntry` separation distinguishes caller-facing input from writer-sealed output — the same pattern as F-002's `IdentityStamped<T>` decoration. Forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE).
- Type-name collision discipline: the wave-008/lane-b discovery that `AuditEntry` (brief's hint) collided with F-001's existing `interface AuditEntry { cycle, hash, state }` — and the rename to `AuditLogEntry` to avoid silent TypeScript declaration-merging — is the **right architectural call**. The two shapes serve different audiences (F-001's transient cycle audit kept in `RunResult.audit` vs F-015's durable chain row destined for `runs/<run_id>/audit.ndjson`); separating the names keeps the contracts independently evolvable. Documented in F-015 ledger §Implementation notes; this lesson informs the wave-9 loop-improvement (grep for type-name first when adding to a shared module).
- `broken_at` indexing as zero-based array position: matches `log[i]` calls and ndjson row offsets a repair tool would seek to. Documented inline with the `VerifyAuditChainResult` type — storage-layer consumers can rely on the indexing base. Architecturally clean.
- Order-of-failure-mode-checks: `entry_sha256 mismatch` is reported FIRST per entry. If both fail, the user sees the more specific signal. (For `prev_sha256` tampering, the `entry_sha256` ALSO breaks because `prev_sha256` is part of the hash input, so `entry_sha256 mismatch` fires at the tampered index.) The ordering preserves the most-actionable error class.
- Hard deps per ledger: F-001 (engine produces entries), F-002 (identity stamps every entry), F-008 (storage layout). Soft dep on F-006 (logger pipeline is the upstream). Compose-at-call-site shape — no compile-time deps on F-001/F-002/F-006/F-008 in `audit.ts`. Forward-compatible.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Cryptographic signing of audit entries (third-party timestamping per ce:FR-IDENTITY-002) deferred to v1.5. Current implementation detects tampering, does not prevent it cryptographically. | Accept; LOCKED status applies to the structural-integrity contract; crypto layer is M19 deferred catalog scope (F-D-005). |
| F2 | MINOR | Persistence to `runs/<run_id>/audit.ndjson` deferred to F-008 (storage layout). Boundary is ready; storage write is follow-on. | Accept; F-008 ledger §depends-on covers the integration. |
| F3 | MINOR | Logging-pipeline wiring (engine cycle events emit through `appendAuditEntry`) deferred. F-006 logger primitive is GREEN + LOCKED; the integration step is unfinished. | Accept; backlog item: track explicit "audit-chain-engine-integration" F-NNN follow-on (or fold into F-006's "logging-storage-integration" follow-on). |
| F4 | MINOR | Canonical-JSON serializer is lightweight (recursive key-sort). RFC 8785 (JCS) precision deferred to v1.5 if cross-language verification is ever needed. | Accept; documented in ledger §Implementation notes. |
| F5 | PRAISE | `AuditEntry` → `AuditLogEntry` rename to avoid silent TypeScript declaration-merging with F-001's existing `AuditEntry`. Discovered during wave-008/lane-b integration verification; informs wave-9 loop-improvement (grep type-name first). | Keep. |
| F6 | PRAISE | Discriminated union `VerifyAuditChainResult` with two failure modes (`entry_sha256 mismatch` vs `prev_sha256 mismatch`) gives precise diagnostics for storage-layer repair tools. | Keep. |
| F7 | PRAISE | Co-hosting F-015 (write) + F-016 (read) in `audit.ts` keeps the read API directly composed against `verifyAuditChain` without cross-module imports. Architectural cohesion. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 89).

F-015 minimal-contract is implemented correctly; all 4 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-015 ledger frontmatter (`LOCKED if GREEN AND reviews/F-015-hash-chained-audit-log-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-015 ledger §out-of-scope-notes / §Implementation notes), not silently elided. Future engine-cycle integration work (storage write, logging pipeline, repair-from-backup, cryptographic signing) is scoped to future F-NNNs, not a re-scoping of F-015's contract.

F-015 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-015-hash-chained-audit-log.md`
- Source: `packages/engine-core/src/audit.ts` (F-015 region; co-hosts F-016 read API)
- Tests: `tests/unit/F-015-hash-chained-audit-log.test.ts` (4/4 PASS)
- GREEN proof: `docs/09-examples-proof/F-015/green-test-output.txt` + `physical-proof.md`
- GREEN transition: `docs/07-roadmap/decision-log.md`; impl commit `23f4475`; wave-008 / lane-b
- Engine-core split: wave-011 / lane-a (no behavior change; pure refactor)
- Review verdict envelope: per `docs/05-design-reviews/README.md`
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Precedent: `F-001-engine-bootstrap-loop-review.md`, `F-002-per-agent-identity-runid-review.md`, `F-006-logging-pipeline-review.md`, `F-008-local-storage-layout-review.md`, `F-014-pre-close-retro-signal-review.md` (this wave-013/lane-c batch)
