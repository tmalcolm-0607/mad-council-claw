---
artifact-class: council-review
feature-id: F-016
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-c
---

# F-016 query-audit-log — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 73 |
| architect-lens | Architect | APPROVE | 87 |

Median confidence: 87

## Implementation reviewed

- `packages/engine-core/src/audit.ts` — F-016 region: ~109 LOC. `AuditQueryOptions` interface (`since` + `top` + `skip` + `action`, all optional), `queryAuditLog(rows, opts) → AuditLogEntry[]` (defensive-copy filter pipeline preserving chronological order), `findChainBreak(rows) → number | null` (wraps F-015's `verifyAuditChain`; returns broken zero-based index or null when chain is intact). Co-hosted with F-015 in the same file (`audit.ts`) since the read API depends directly on the F-015 chain primitive.
- `tests/unit/F-016-query-audit-log.test.ts` — 8 acceptance scenarios (3 ledger scenarios + 5 brief-derived: since filter, skip+top pagination, combined filter compose, defensive copy, scenario 7 read-only); all PASS per `docs/09-examples-proof/F-016/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-016 RED at wave-002 / lane-b (initial ledger); F-016 GREEN at wave-009 / lane-b, RED test commit `eacc651`, impl commit `da48f2a` (NOTE: cross-lane race during wave-009 caused both commits to be filed under other lanes' commit messages — `eacc651` was stamped F-018, `da48f2a` was stamped F-006; see lane-b summary § Anomalies B1+B2 for the writeup); engine-core split (wave-011 / lane-a) carved `audit.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`: ~109 LOC delivers the entire read-side primitive — defensive-copy filter pipeline (`since` → `action` → `skip` → `top`) plus `findChainBreak` wrapper. Composes directly against F-015's `verifyAuditChain` without re-implementing any chain-walk logic. Read-only by design — never mutates the source log.
- All 8 acceptance scenarios PASS: scenarios 1, 3 (ledger) cover filter selectivity (agent_id-equivalent via `action` filter; `top` pagination cap). Ledger scenario 2 (broken chain → first yielded item is `chain_invalid`) is honored architecturally via the separated `findChainBreak` API — callers compose `findChainBreak(log)` BEFORE `queryAuditLog(log, opts)` if they want the chain-validity check; the substantive guarantee (callers can detect tampering before query) is preserved while the cost model is now caller-controlled.
- `findChainBreak(rows) → number | null` is the **right composition shape** for the v1 API: a `null` return means "chain intact"; a number means "broken at zero-based index N". Storage-layer consumers (a future repair tool) can route on a single boolean `findChainBreak(log) !== null` for the simple case OR consume the index for the surgical-repair case. Composability without type-pollution.
- Defensive copy via `[...rows]` at function entry: callers can reorder / mutate the returned array without affecting the source log. Individual entries share object identity (callers mutating `entry.fields` invalidates the chain — `findChainBreak` will detect). Architecturally honest about what is and isn't copied.
- Surface trace per ledger maps cleanly: `ce:FR-AUDIT-001` ("Query-AuditLog" sub-surface companion to F-015's hash-chained audit log). Provenance is auditable.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 73)**

- F-016 is a **brief-narrowed primitive**; the deeper integrations are explicitly out-of-scope per the ledger §Implementation notes. Five distinct deferrals (each surfaced honestly per `no-silent-deferrals.md`):
  1. **Streaming async-iterator shape** (ledger §Behavior contract describes `async iterator` for large logs) — wave-9/lane-b brief specified synchronous filter API only; M2 ships sync. Heavy query needs are tracked under F-088..F-092 / M11 introspect/replay.
  2. **Persistence-layer reads** (querying directly against `runs/<run_id>/audit.ndjson`) — F-008's job; current API takes the in-memory `AuditLogEntry[]` array as input.
  3. **`agent_id` / `run_id` filters** — F-002 stamps these into `fields` via `stampIdentity`; the brief uses `action` as the v1 surface filter to keep the API minimal. Adding these is a 2-LOC follow-on.
  4. **`until_utc` timestamp upper bound** — the brief specifies `since` only; `until` is symmetric and trivial to add.
  5. **Inline chain-validity warn-then-yield** (ledger §Behavior contract describes yielding a `chain_invalid` warning event before remaining entries) — separated into `findChainBreak` for the wave-9 brief. Substantive guarantee preserved (callers can verify before query); cost model now caller-controlled. A reader could mistake "F-016 LOCKED" for "queryAuditLog automatically warns on chain breaks" — which is not yet the case.
- A reader of the ledger could mistake "F-016 LOCKED" for "the streaming async-iterator API with inline chain-warn is locked" — which is not yet the case. The boundary contract (read-only filter + chain-break detection) is locked; the richer streaming envelope is owned by future M11 features.
- The cross-lane race during wave-009 (commits `eacc651` and `da48f2a` filed under wrong lane subjects) is documented in the ledger §Implementation notes and lane-b summary. The race did not affect the substantive code (both commits' file content is correctly attributed to F-016); only the commit subjects were misattributed. This is a process/staging-discipline issue, not a code-quality issue. Wave-13+ has tightened staging discipline (per-path `git commit --only` + per-lane branches) — see wave-012/lane-b's "pre-commit-hook-rerouting-pattern" finding and wave-013's per-lane branch posture.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): track an explicit "audit-query-streaming-extension" follow-on F-NNN that adds the async-iterator shape + inline `chain_invalid` warn + `agent_id`/`run_id`/`until_utc` filters. Pairs with F-008's storage-layer integration follow-on.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/audit.ts` F-016 region directly; the filter pipeline correctly applies `since` (lex-compare on `entry.fields.timestamp`) → `action` (exact match on `entry.action`) → `skip` (slice start) → `top` (slice end); `findChainBreak` correctly wraps `verifyAuditChain` and translates the discriminated-union result into `number | null`.

## Architect lens

**Verdict: APPROVE (confidence 87)**

- File-split posture: `audit.ts` co-hosts F-015 (write) + F-016 (read) — architecturally clean since both surfaces depend on the same `AuditLogEntry` shape and the read API composes directly against F-015's `verifyAuditChain`. Re-exports through the barrel (`packages/engine-core/src/index.ts`). No cross-module imports for F-016.
- API surface (`AuditQueryOptions` + `queryAuditLog` + `findChainBreak`): symmetric and predictable. Optional-only options shape (`since?`, `top?`, `skip?`, `action?`) means "no opts" yields a defensive-copied full-list — the most permissive default, the most-useful for storage-layer consumers walking the full chain.
- Filter pipeline order (`since` → `action` → `skip` → `top`): each step operates on the in-flight array; `since` and `action` are O(N) filters; `skip`/`top` are O(K) array slices. Total worst-case O(N). The order is deliberate: filter-then-paginate is more useful than paginate-then-filter (the latter would yield non-deterministic page shapes when filters drop entries). Architecturally clean.
- `since` filter targets `entry.fields.timestamp` (string, lex-compare on ISO-8601). F-015's `AuditLogEntry` has no top-level timestamp field; the brief's `since` semantics are honored by reading `fields.timestamp`. Entries without a `fields.timestamp` are excluded when `since` is set — this is the right default (filter-out unknowns rather than filter-in-by-default), and matches F-002's "omit when undefined" discipline for serialization. Forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE).
- `action` filter is exact-match per the brief's `e.action === opts.action`. Substring/regex match deferred to v1.5 (heavy query needs M11). The exact-match shape is the minimum-correct contract; richer matchers can be added without breaking callers (add a new option `actionMatcher?: (action: string) => boolean` that takes precedence when set).
- Hard dep on F-015 (audit log to query). Soft dep on F-002 (identity-based filters). The implementation has ZERO compile-time deps on F-002 — pure read-side primitive composing against F-015's `verifyAuditChain`. Compose-at-call-site shape — F-002 stamps fields onto entries; `queryAuditLog` doesn't care; the action filter happens to work because callers can stamp identity into `fields`.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Streaming async-iterator shape deferred to v1.5 / M11 (per ledger Behavior contract describes async iterator for large logs; brief specified sync API only). | Accept; ledger §Implementation notes acknowledges; backlog item: track "audit-query-streaming-extension" F-NNN follow-on. |
| F2 | MINOR | Persistence-layer reads (querying directly against `runs/<run_id>/audit.ndjson`) deferred to F-008 (storage layout). Current API takes in-memory `AuditLogEntry[]` as input. | Accept; F-008 ledger §depends-on covers the integration. |
| F3 | MINOR | `agent_id` / `run_id` filters deferred — brief uses `action` as v1 surface filter; F-002 stamps identity into `fields`, which composes with future filter additions without breaking callers. | Accept; 2-LOC follow-on; tracked under F-016 ledger §Out-of-scope. |
| F4 | MINOR | `until_utc` timestamp upper bound deferred — brief specifies `since` only; symmetric extension trivial to add. | Accept; tracked under F-016 ledger §Out-of-scope. |
| F5 | MINOR | Inline chain-validity warn-then-yield deferred — ledger Behavior contract describes yielding a `chain_invalid` warning event; brief separated into `findChainBreak`. Substantive guarantee preserved (callers can verify before query); cost model now caller-controlled. | Accept; documented in ledger §Implementation notes. |
| F6 | PRAISE | Filter pipeline order (`since` → `action` → `skip` → `top`) is filter-then-paginate, which produces deterministic page shapes vs the inverse order. Architecturally clean. | Keep. |
| F7 | PRAISE | `findChainBreak(rows) → number | null` composition shape is the right v1 API: simple boolean check for the typical case, surgical-repair index for the precision case. Composability without type-pollution. | Keep. |
| F8 | PRAISE | Defensive copy via `[...rows]` at function entry — callers can mutate the returned array without affecting the source log. Architecturally honest about what is and isn't copied (object identity preserved per entry; chain detection still works on caller-mutation). | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 87).

F-016 minimal-contract is implemented correctly; all 8 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-016 ledger frontmatter (`LOCKED if GREEN AND reviews/F-016-query-audit-log-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-016 ledger §Out-of-scope notes / §Implementation notes), not silently elided. The brief-vs-ledger divergence (sync API vs async iterator; `findChainBreak` separation vs inline `chain_invalid`) is documented; substantive guarantees preserved across both shapes. Future streaming-extension work is scoped to a future F-NNN, not a re-scoping of F-016's contract.

F-016 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-016-query-audit-log.md`
- Source: `packages/engine-core/src/audit.ts` (F-016 region; co-hosts F-015 write API)
- Tests: `tests/unit/F-016-query-audit-log.test.ts` (8/8 PASS)
- GREEN proof: `docs/09-examples-proof/F-016/green-test-output.txt` + `physical-proof.md`
- GREEN transition: `docs/07-roadmap/decision-log.md`; impl commit `da48f2a`; wave-009 / lane-b (cross-lane race writeup: `docs/06-agent-team-outputs/wave-009/lane-b-summary.md` § Anomalies B1+B2)
- Engine-core split: wave-011 / lane-a (no behavior change; pure refactor)
- Review verdict envelope: per `docs/05-design-reviews/README.md`
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Precedent: `F-001-engine-bootstrap-loop-review.md`, `F-002-per-agent-identity-runid-review.md`, `F-006-logging-pipeline-review.md`, `F-008-local-storage-layout-review.md`, `F-014-pre-close-retro-signal-review.md`, `F-015-hash-chained-audit-log-review.md` (this wave-013/lane-c batch)
