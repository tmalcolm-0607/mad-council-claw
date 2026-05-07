---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-015 / lane-c)
wave: wave-015
lane: lane-c
topic: F-011 copilot-sdk-provider RED → GREEN — second concrete M1 backend provider
date: 2026-05-07
status: complete
---

# Wave 15 / Lane C — F-011 copilot-sdk-provider RED → GREEN

## Scope

Flip F-011 (`CopilotBackend` — GitHub Copilot SDK provider) from 🔴 RED to 🟢 GREEN per the F-011 ledger's `red-green-rule` predicate:

```
GREEN if all test files exist AND all runners return zero exit.
```

This is the **second concrete M1 backend provider** to flip. M1 was 4R + 0G + 1L at lane start (F-009 LOCKED via wave-15/lane-a; F-010/F-011/F-012/F-013 RED). After this lane: 3R + 1G + 1L. Concurrent with wave-15/lane-b (F-010 anthropic-sdk-provider) — when both lanes land, M1 reaches 2R + 2G + 1L.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test | `tests/unit/F-011-copilot-backend.test.ts` | new (7 scenarios; mirrors F-010 fixture style) |
| Source | `packages/engine-core/src/backend-copilot.ts` | new (~95 LOC) |
| Barrel | `packages/engine-core/src/index.ts` | modified (1-line ownership-table comment + 1-line re-export) |
| Examples-proof | `docs/09-examples-proof/F-011/red-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-011/green-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-011/physical-proof.md` | new |
| Ledger flip | `docs/03-feature-catalog/M1-backend/F-011-copilot-sdk-provider.md` | modified (status: red → green; status-history append; test-files populated; Implementation notes section appended documenting scope deviation + v1 stub deferrals) |
| Roadmap rows | `roadmap.md` | modified (F-011 row 🔴 → 🟢; M1 row 4R+0G+1L → 3R+1G+1L; wave-015/lane-c transition note appended) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 15 lane-c section + 3 entries) |
| Lane summary | `docs/06-agent-team-outputs/wave-015/lane-c-summary.md` | new (this file) |

## Acceptance scenarios verified at GREEN

| # | Scenario | What it proves |
|---|---|---|
| 1 | `CopilotBackend` implements `IBackendProvider` with `origin === 'copilot'` | structural witness — TS2420 at compile time if any required method is missing |
| 2 | `startSession` returns sessionId tagged with `copilot-` prefix containing the runId | F-019 cost-ledger + F-015 audit-log can route by prefix |
| 3 | `sendPrompt` streams a `token` event (with model id surfaced) then a `finish/stop` event | F-009 BackendEvent contract; model-id traceability without separate metadata channel |
| 4 | `sendPrompt` on unknown sessionId throws | AsyncGenerator reject path (F-009 ledger acceptance scenario 2) |
| 5 | `halt` flips session into halted state; subsequent `sendPrompt` yields `finish/error` rather than streaming tokens | F-018 RUN_HALTED observability — parity with F-010 |
| 6 | `stopSession` removes the session entirely; subsequent `sendPrompt` throws | graceful disposal contract |
| 7 | `halt` is idempotent (calling twice on same session is a no-op) | F-009 contract clause |

7/7 PASS at GREEN time. F-011-only run + sibling F-009 stays GREEN. (Full-suite parity with sibling lanes' work is sibling-lane responsibility.)

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) + `no-silent-deferrals.md`:

1. **F-011 ledger original acceptance scenarios reference `provider.complete(prompt, opts)` + `cancel(handle)`.** F-009 (wave-014/lane-d) standardized every backend on a session-oriented surface; F-011 follows the F-009 contract — same as F-010 (wave-15/lane-b). The scope deviation is recorded in the F-011 ledger §Implementation notes and in the test-file header.
2. **v1 minimal impl is a deterministic STUB.** Real Copilot CLI / SDK invocation is gated on (a) Copilot CLI installed and authed (device-flow OAuth + entitlement check) on the host, and (b) recorded-fixture test harness so unit tests do not require a live CLI invocation. Both deferrals are explicit in the F-011 ledger `out-of-scope-notes` and surfaced in the test-file header + this lane summary.
3. **ConfigurationError-on-missing-CLI** (ledger acceptance scenario 2) is also deferred — the v1 stub does not shell out, so the missing-CLI failure mode is impossible to exercise. Documented in test header.

## Cross-feature observations

- **Cross-provider parity** (Lane B's F-010 + this lane's F-011 ship the same session-oriented surface with identical halt-finish-error semantics; only origin string, sessionId prefix, and default model differ). F-018's RUN_HALTED contract requires that callers observe a halt event from the provider — F-020 (kill-switch) and F-022 (tool-call quota) can halt a session of either provider with the same code path. The F-009 session shape is the orthogonal abstraction; per-provider class adds origin-tag + provider-specific defaults but no surface drift. F-012 (factory, RED) will route by origin. F-013 (event-normalization, RED) will normalize per-provider event shapes. **Pattern validates the F-009 design** — concrete providers plug in without touching the F-009 surface, exactly the contract claim from wave-014/lane-d.

- **Cross-lane staging-race sighting #14** (recurring across waves 9-14 + sightings 10-13). 4 concurrent lanes mid-flight: B (F-010), C (this lane, F-011), A wave-15 LOCKED batch, D (F-013). Mitigation: explicit `git add <Lane-C-paths-only>` per commit; never `git add .` / `git add -A` / `git reset`. To handle shared-file staging (`roadmap.md`, `confidence-ledger.md`, `index.ts`) where Lane B + Lane A + Lane D had also written: save interleaved working-tree to `.mad/scratch/wave-015-lane-c/`, reset shared files to HEAD with `git show HEAD:<path> > <path>`, apply Lane-C-only delta, `git add` Lane-C-paths-only, commit, then restore interleaved versions for working tree so sibling lanes' WIP is preserved. Per-lane staging discipline holds at sighting #14.

## Forward path

- F-011 GREEN → LOCKED is a future-wave candidate via post-impl council review (same shape as F-009/F-010 → LOCKED in wave-15/lane-a).
- F-012 (backend-factory, concurrent in wave-15) will route by `origin` tag — F-010 ('anthropic') and F-011 ('copilot') are now the two non-stub concrete providers the factory can produce.
- F-013 (event-normalization, concurrent in wave-15) will provide cross-provider event-shape mapping; F-010 and F-011 emit the same `BackendEvent` shape today (the `[provider model] STUB-RESPONSE-TO: <prompt>` text format), so F-013 has both providers to reason against.
- Real Copilot CLI integration (deferred per ledger out-of-scope-notes) unblocks together with F-010's real Anthropic SDK swap — both share the recorded-fixture test harness and the `[NEEDS CLARIFICATION: secure storage]` token-storage path.

## Stop conditions met

- `tests/unit/F-011-copilot-backend.test.ts` exists ✓
- `pnpm test -- tests/unit/F-011-copilot-backend.test.ts` returns exit 0 with 7/7 PASS ✓
- F-011 ledger frontmatter `status: green` + `status-since: 2026-05-07` + `status-history` append ✓
- All artifacts (test, source, barrel, examples-proof, ledger flip, roadmap row + count + transition note, confidence-ledger entries, lane summary) created in this lane ✓
