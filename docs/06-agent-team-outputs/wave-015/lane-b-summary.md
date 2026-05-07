---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-015 / lane-b)
wave: wave-015
lane: lane-b
topic: F-010 anthropic-backend RED → GREEN
date: 2026-05-07
status: complete
---

# Wave 15 / Lane B — F-010 anthropic-sdk-provider RED → GREEN

## Scope

Flip F-010 (M1 anthropic-sdk-provider) RED → GREEN per the ledger §Behavior
contract. F-010 is the second M1 (backend pluggability) feature; it
implements F-009's `IBackendProvider` interface with origin `'anthropic'`.

## Outcome

**F-010 RED → GREEN** in 5 commits (pre-summary). 7/7 scenarios passing;
full suite 136/136 across 20 test files (was 122/122 across 18 pre-F-010 +
6 from sibling F-011 lane that landed during wave-15).

| State | Test result | Files added/modified |
|---|---|---|
| RED  | 7/7 fail (`TypeError: AnthropicBackend is not a constructor`); 122 prior pass | tests/unit/F-010-anthropic-backend.test.ts (new) |
| GREEN | 7/7 pass; 136/136 total | packages/engine-core/src/backend-anthropic.ts (new); packages/engine-core/src/index.ts (1-line export append + 1-line ownership-table comment) |

## Test results

```
$ pnpm test
 Test Files  20 passed (20)
      Tests  136 passed (136)
   Duration  ~14s
```

## What landed

1. **`tests/unit/F-010-anthropic-backend.test.ts`** — 7 scenarios mirrored
   from the F-010 ledger + the F-009 contract: IBackendProvider
   compliance with origin='anthropic'; startSession sessionId tagged
   with 'anthropic-' prefix; sendPrompt streams token (with model id
   surfaced) + finish/stop; unknown sessionId throws; halt yields
   finish/error rather than removing session (observability-preserving
   variant per F-018 RUN_HALTED contract); stopSession removes session;
   halt is idempotent.
2. **`packages/engine-core/src/backend-anthropic.ts`** (~85 LOC) —
   `AnthropicBackend` class implementing F-009 `IBackendProvider`. v1
   uses a deterministic STUB body (no `@anthropic-ai/sdk` call). Halt
   path keeps session registered and short-circuits subsequent
   sendPrompt to a `finish/error` event with `details: 'Session halted'`
   — composes with F-018 RunHaltedVerdict and F-020 / F-022 callers.
3. **`packages/engine-core/src/index.ts`** — append `export * from
   './backend-anthropic.js'` + 1 line in the ownership-table comment.
4. **F-010 ledger** — status: red → green; status-history append;
   test-files populated; Implementation notes section authored
   documenting STUB-vs-real-SDK rationale + halt-semantics divergence
   from `StubBackend` per `no-silent-deferrals.md`.
5. **roadmap.md** — F-010 row 🔴 RED → 🟢 GREEN with test citation; M1
   row 4R+1G → 3R+2G; wave-15 lane-b transition note added below
   wave-14/lane-d note. TOTAL aggregate reconciliation deferred to
   last-lander per the wave-13/14 `last-lander` pattern.
6. **confidence-ledger.md** — new "Wave 15 (lane-b)" section with 4
   entries (F-010 GREEN, stub-body-vs-deferred-real-SDK pattern,
   cross-lane staging-race sighting #13, post-split sixth wave
   validation).

## Out of scope (per ledger + tests/unit/F-010-anthropic-backend.test.ts header)

Surfaced explicitly per `rules/no-silent-deferrals.md`:

1. **Real `@anthropic-ai/sdk` integration**. Gated on (a) F-070
   secure-storage for `ANTHROPIC_API_KEY` (per ledger
   `[NEEDS CLARIFICATION: secure storage]` note) and (b) a recorded-
   fixture test harness so unit tests do not require a live API key +
   network. Both surfaced openly in the F-010 ledger §Implementation
   notes. The stub satisfies the F-009 structural contract; swapping
   the stub body for a real SDK call is a self-contained future change.
2. **Prompt-caching tuning** — owned by F-126 (NEW context-budget-
   allocation, M8) per F-010 ledger out-of-scope-notes.
3. **Extended-thinking opt-in** — F-126 territory.
4. **Cost accounting** — F-019 cost-ledger consumes token counts; the
   v1 stub does not emit them. Real SDK integration will populate
   token counts at that time.

## Cross-lane discipline

Per user directive 2026-05-07 (NO `git reset` for staging-race recovery;
selective `git add` / `git restore --staged` only) and per kit
`rules/scope-discipline.md`:

- Staged ONLY Lane B paths in each commit:
  - Commit 1: `tests/unit/F-010-anthropic-backend.test.ts`
  - Commit 2: `packages/engine-core/src/backend-anthropic.ts`,
    + selective `index.ts` lines (the `backend-anthropic.js` export +
    the corresponding ownership-table comment line — `git add -p` to
    peel out from sibling F-011 lane's edits to the same file)
  - Commit 3: `docs/03-feature-catalog/M1-backend/F-010-anthropic-sdk-provider.md`,
    `roadmap.md`, `docs/11-loop-state/confidence-ledger.md`
  - Commit 4: `docs/06-agent-team-outputs/wave-015/lane-b-summary.md`

- Sibling-lane WIP at lane execution time:
  - Sibling F-011 lane: `tests/unit/F-011-copilot-backend.test.ts`,
    `packages/engine-core/src/backend-copilot.ts`,
    `packages/engine-core/src/index.ts` (their export line + comment
    line for backend-copilot.ts), `docs/09-examples-proof/F-011/`,
    plus their own ledger / roadmap / confidence-ledger / summary.
  - None of these were touched by this lane.

## Key findings

### Stub-body-vs-deferred-real-SDK pattern (first sighting)

F-010 establishes a new ledger-deferral idiom for SDK-bound features:
implement the F-009 contract surface with a deterministic STUB body
that satisfies structural-witness + halt-composition + event-shape
correctness, but defer the real network-bound SDK call to a future
feature gated on (a) secure-storage for the credential and (b) a
recorded-fixture test harness. Distinct from F-004's "config-present,
runtime-deferred" pattern (config files present without runtime
wiring): F-010's variant is "contract-present, real-SDK-call-deferred"
(class implementing real interface but with stub body).

The stub MUST satisfy the structural contract (origin tag, all
IBackendProvider methods present, BackendEvent shapes correct) so the
next layer (F-012 factory) can route to it without knowing it's a stub;
swapping the stub body for a real SDK call must be a self-contained
future change.

Future SDK-bound features (F-011 Copilot, F-029..F-031 MCP transports,
F-184..F-187 Foundry memory) should cite this entry.

### Halt-semantics divergence from F-009 StubBackend (intentional)

F-009's `StubBackend.halt(sessionId)` removes the session — subsequent
`sendPrompt` throws `Unknown session: <id>`. F-010's
`AnthropicBackend.halt(sessionId, verdict)` keeps the session
registered and short-circuits subsequent `sendPrompt` to a
`finish/error` event with `details: 'Session halted'`.

The variant honors F-018's RUN_HALTED observability requirement:
callers must observe a halt event from the provider, not just an
"unknown session" error. F-020 (kill-switch) and F-022 (tool-call
quota) both rely on this. The divergence is documented in the file
header of `backend-anthropic.ts` and in the F-010 ledger §Implementation
notes.

### Sixth-consecutive post-split wave with no engine-core race

Wave-15 / lane-b is the **sixth post-split wave/lane** to ship cleanly
without engine-core file collisions (after wave-12 + wave-13 + wave-14
lanes b/c/d). F-010's only engine-core touches are: NEW file
`backend-anthropic.ts` + 1-line append to the barrel + 1-line append to
the ownership-table comment. The sibling F-011 lane does the symmetric
pattern.

The wave-11 split's value is now empirically validated across 6+
consecutive post-split lanes spanning 19+ feature transitions. The
load-bearing constraint is documented as: per-feature files in
`engine-core/src/` + append-only barrel in `index.ts` = no engine-core
race even for parallel lanes adding new providers. Recommend wave-16
lane to formally retire `Lane-A-w11-staging-race-eliminated` from
"needs-validation" to LOCKED-permanent.

### Cross-lane staging-race sighting #13

The wave-13 mitigation (per-commit `git add <Lane-B-paths-only>`) holds
at sighting #13. Shared-file co-edit on `index.ts` resolved cleanly:
both lanes appended at end of export list with no overlap. The
ownership-table comment block was append-only too. Both edits
coexist cleanly. No need to escalate to per-lane branches.

## What this lane does NOT do

- Does NOT flip F-010 GREEN → LOCKED (no council review). LOCKED
  is a future-wave candidate.
- Does NOT touch sibling-lane WIP (F-011).
- Does NOT integrate the real `@anthropic-ai/sdk` package — explicit
  out-of-scope per ledger; gated on F-070 + recorded-fixture harness.
- Does NOT update the milestone-overview TOTAL row independently —
  the last-lander pattern from wave-13 reconciles aggregate counts
  from current per-row state.

## Next steps

- **F-010 LOCKED candidate**: future wave runs council review →
  LOCKED transition. Likely paired with F-009 + F-011 in a similar
  shape to wave-13/lane-c/d's parallel-quadruple LOCKED flip.
- **F-070 secure-storage feature** (currently RED in M19 deferred or
  similar) is the unblocker for swapping the stub body for the real
  SDK call. Recommend a focused wave once F-070 lands.
- **F-012 backend-factory**: now has TWO concrete IBackendProvider
  impls to route between (origin='anthropic' from this lane,
  origin='copilot' from sibling). Wave-16 candidate.
- **Wave-15 last-lander**: should reconcile M1 + TOTAL aggregate
  counts from per-row state at wave close.

## Push at end

Per user directive 2026-05-07: push at end of this loop session is
authorized.
