# Layer 2 — Integration Tests

Multi-step workflows. Skill-to-skill flow. Context retention across invocations. Real file system, real helper scripts (not mocked). Still deterministic.

## Scope

**In scope**:
- End-to-end flow of a single skill invocation (preflight → state mutation → output).
- Multi-skill flows that don't require fault injection (e.g., `/council-open` → `/council-join` → `/council-post` → `/council-check`).
- Real filesystem state (under `fixtures/`).
- Real scripts/*.ps1 helpers (once implemented; currently stubs).
- Mocked external services (CronCreate, A2A bridge, ALAS hub).

**Out of scope**:
- Fault injection (kill process, disk-fill) — Layer 3.
- Adversarial inputs — Layer 4.
- Live external service calls — Layer 3.

## Source of truth

Each skill's `tests.md` has a "Layer 2 — Integration" section. Each row translates to one test case here.

## Test file layout

```
evals/fixtures/<skill>/integration/
  happy-path.test.md              ← human-readable plan
  happy-path.Tests.ps1            ← executable Pester
  boundary-body-32k.test.md
  boundary-body-32k.Tests.ps1
  ...
```

## Test skeleton

```markdown
# Test: council-post-happy-path

**Layer:** 2
**Fixture:** `fixtures/council-post/integration/happy-path-active-channel/`
**Reference:** `skills/council-post/tests.md` T2-01

## Setup
1. Copy `fixtures/council-post/integration/happy-path-active-channel/~/claude-data/channels/es-training/` into test workspace.
2. Set `$env:CLAUDE_SESSION_ID = 'sess-abc123'`.
3. Pre-assert: 0 messages in thread.

## Execute
```pwsh
./skills/council-post/council-post.ps1 es-training --new-thread "test thread" --type task "a test body"
```

## Expect
- Exit code: 0
- `channels/es-training/seq.json` next_seq: 2
- `channels/es-training/threads/test-thread/thread.json` exists with message_count=1
- `channels/es-training/threads/test-thread/messages/` has one file matching `1-<ts>-*.json`
- Message JSON has correct `from.alias`, `from.session_id`, `type`, `body`
- `channels/es-training/digest.json` updated: `channel_seq=1`, thread in `active_threads[]`
- Emitted OpenTelemetry spans: `invoke_skill council-post` with rc=0

## Cleanup
Remove test workspace.

## Metrics emitted (expected)
- `invoke_skill council-post` span.
- `execute_tool seq-increment` span.
- `council_post.invocations_total{rc=0, type=task, transport=local}` incremented.
```

## Cross-skill integration scenarios

These scenarios exercise multiple skills in sequence; live under `fixtures/shared/integration/`:

| Scenario | Sequence | Expected outcome |
|---|---|---|
| `open-join-post-check-cycle` | `/council-open` (user A) → `/council-join` (user B) → `/council-post` (A) → `/council-check` (B) | B sees A's message with correct verification + unread count |
| `mad-workflow-full` | `/council-open --mad` → populate spec.md → post task → resolve | MAD gates enforce; tasks.md checks update |
| `council-review-happy-path` | `/council-open` → post thread → `/council-review` | verdict.json written; resolve message posted; thread resolved |
| `leave-rejoin-marker-preserved` | Join → post → leave → rejoin | Read-markers preserved; member status resets to active |
| `force-reclaim-flow` | A joins → A's session "dies" → A'-new-session `/council-join --force-reclaim` | Consent gate fires; reclaim succeeds; status updates |
| `verdict-override-flow` | `/council-review` FIX → `/council-verdict` override to ACCEPT | Consent gate fires; previous verdict archived; new verdict written |

## Categories + target counts

| Category | Tests per skill (avg) | Total |
|---|---|---|
| Happy path variants | 2-4 | ~30 |
| Error-path variants | 5-8 | ~60 |
| Boundary conditions (size, count) | 2-3 | ~25 |
| Degradation / Context Gap paths | 2-4 | ~30 |
| Cross-skill scenarios | N/A | ~12 |
| **Total Layer 2** | | **~155** |

## Coverage + perf

- **All return codes reachable** for each skill (100%).
- **Each consent gate** exercised with yes + no + timeout outcomes.
- **Each degradation path** surfaces Context Gaps correctly.
- **Perf budget**: per-test <5s; full Layer 2 <10min.

## Running Layer 2

```
./run-evals.ps1 -Layer 2
./run-evals.ps1 -Layer 2 -Skill council-post
./run-evals.ps1 -Layer 2 -Scenario open-join-post-check-cycle
```

## Related

- Each skill's `tests.md` §Layer 2.
- `layer-3-e2e-fault-injection.md` — next level up.
- `fixtures/shared/integration/` — cross-skill flows.
