---
artifact-class: physical-proof
generated-by: hand-authored (wave-015 / lane-c)
feature-id: F-011
date: 2026-05-07
---

# F-011 — copilot-sdk-provider RED → GREEN — physical proof

## RED capture

```
$ pnpm test -- tests/unit/F-011-copilot-backend.test.ts
...
TypeError: CopilotBackend is not a constructor
...
Test Files  1 failed (1)
     Tests  7 failed (7)
```

Source: `red-test-output.txt`. All 7 scenarios fail with the same root cause —
`CopilotBackend` is not exported from `@mad-council-claw/engine-core` because
`packages/engine-core/src/backend-copilot.ts` does not exist yet AND
`packages/engine-core/src/index.ts` does not re-export it.

## GREEN capture

```
$ pnpm test -- tests/unit/F-011-copilot-backend.test.ts
...
 ✓ tests/unit/F-011-copilot-backend.test.ts (7 tests) 11ms

Test Files  1 passed (1)
     Tests  7 passed (7)
```

Source: `green-test-output.txt`. All 7 scenarios pass after authoring
`packages/engine-core/src/backend-copilot.ts` (new, ~95 LOC, mirrors F-010's
`backend-anthropic.ts` structure with `origin = 'copilot'` and a `gpt-5`
default model) and adding `export * from './backend-copilot.js'` to
`packages/engine-core/src/index.ts`.

## What 7/7 PASS proves

| Scenario | Contract clause |
|---|---|
| 1 | `CopilotBackend` is a class (`new` works); structural witness for `IBackendProvider` (TS2420 at compile time if any required method is missing) |
| 2 | `startSession` returns a `sessionId` string with the `copilot-` provider prefix (F-019 cost-ledger + F-015 audit-log can route by prefix) |
| 3 | `sendPrompt` yields a `token` event then a `finish` event with reason `stop`; the model id is surfaced in the token text for traceability |
| 4 | `sendPrompt` on an unknown sessionId throws (AsyncGenerator reject path) |
| 5 | `halt` flips the session into halted state; subsequent `sendPrompt` yields `finish/error` rather than streaming tokens (F-018 RUN_HALTED observability) |
| 6 | `stopSession` removes the session entirely; subsequent `sendPrompt` throws |
| 7 | `halt` is idempotent; calling twice on the same session is a no-op |

## What is intentionally NOT proven (per `no-silent-deferrals.md`)

- **Real Copilot CLI / SDK invocation.** The v1 impl is a deterministic stub.
  Real `copilot --yolo -p ...` integration is gated on (a) Copilot CLI being
  installed and authed (device-flow OAuth + entitlement check) on the host
  and (b) a recorded-fixture test harness so unit tests do not require a
  live CLI invocation. Both are explicit out-of-scope per the F-011 ledger
  `out-of-scope-notes`.
- **Multi-model adversarial dispatch.** The kit's
  `lens-multi-model-review-pattern.md` (vendored from LENS-Common
  PR #5138039) and `Invoke-CopilotMultiModel.ps1` describe a parallel
  Opus + GPT-5+ dispatch. That orchestration is M10 (F-082..F-087); F-011 is
  the single-provider concrete impl one M10 dispatch lane will use.
- **Cost accounting.** F-019 cost-ledger consumes token counts; the v1 stub
  does not emit them. The real CLI/SDK swap will populate `inputTokens` /
  `outputTokens` per `BackendEvent` so the cost-ledger can attribute spend.
- **Constructor-time CLI-missing detection.** The F-011 ledger acceptance
  scenario 2 references a `ConfigurationError: copilot CLI not found`
  thrown at construction time. The v1 stub does not shell out, so the
  missing-CLI failure mode is deferred to the real-impl swap. Documented
  openly in the test header per `no-silent-deferrals.md`.

## Cross-feature observation

F-010 (Lane B, concurrent in wave-015) and F-011 (this lane) ship the **same
session-oriented surface** with provider-tagged session ids and identical
halt-finish-error semantics. This cross-provider parity is what F-018's
RUN_HALTED contract requires — F-020 (kill-switch) and F-022 (tool-call
quota) can halt a session of either provider with the same code path. The
M1 (backend pluggability) milestone now has **3 GREEN features** out of 5
(F-009 IBackendProvider + F-010 Anthropic + F-011 Copilot); only F-012
(factory) and F-013 (event-normalization) remain RED.
