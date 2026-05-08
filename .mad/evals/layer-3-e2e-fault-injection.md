# Layer 3 — End-to-End + Fault Injection

Realistic scenarios with induced failures. The "what happens when things go wrong" layer. Slower than Layer 2 (minutes per scenario); runs pre-release.

## Scope

**In scope**:
- Real multi-agent scenarios (spawn 2-3 processes, have them collaborate).
- Fault injection: kill-process, disk-fill, network partition, clock-skew, permission-revoke.
- Race conditions: concurrent posts, concurrent leaves, concurrent reviews.
- Recovery scenarios: resume from partial state after crash.
- Long-running flows (5+ minute tests simulating real collaboration).

**Out of scope**:
- Adversarial inputs — Layer 4.
- Simple happy paths — Layer 2.

## Source of truth

Each skill's `tests.md` has a "Layer 3 — E2E + fault injection" section (T3-XX rows). Each translates to a scenario file here.

## Test file layout

```
evals/fixtures/<skill>/e2e/
  concurrent-10-agents.test.md
  concurrent-10-agents.orchestrator.ps1     ← spawns + coordinates test processes
  kill-mid-write.test.md
  kill-mid-write.orchestrator.ps1
  ...

evals/fixtures/shared/e2e/
  archive-half-move.test.md                 ← shared by /council-leave
  session-restart-recovery.test.md          ← shared
  ...
```

## Fault-injection techniques

| Fault | Implementation |
|---|---|
| **Kill process mid-operation** | `Start-Job` the skill; `Stop-Job -PassThru` at a specific point (before state write, between writes, after writes). |
| **Disk full** | Use `fixtures/shared/fault/fill-disk.ps1` to consume `~/claude-data/` parent volume to near-full, then run the skill. Cleanup restores space. |
| **Permission revoke** | `chmod` the channel dir read-only mid-operation. |
| **Network partition** | For A2A tests: block localhost:8222 via firewall rule (or mock-server stops responding). |
| **Clock skew** | `fixtures/shared/fault/clock-skew-<N>-seconds.ps1` runs under a process-local clock offset. |
| **Slow disk** | Inject delays into `scripts/atomic-write.ps1` via a wrapped mock. |
| **Partial write** | Simulate a writer that creates `.tmp` then dies before rename — exercise orphan cleanup. |
| **Concurrent writes** | Launch N processes simultaneously, coordinate via a barrier (file presence) so they race exactly. |

## Canonical scenarios

### Scenario: 10-agent concurrent post

**Fixture**: `fixtures/shared/e2e/concurrent-10-agents-one-thread/`

Setup:
- Channel with 10 members (alice1 through alice10).
- One active thread.
- Barrier file: `fixtures/.barrier-release`.

Execute:
- Spawn 10 processes simultaneously, each as one member.
- Each reads the barrier file, then posts `/council-post --thread <tid> --type status "seed N done"`.

Expect:
- 10 unique messages written.
- `seq.json.next_seq = 11`.
- `thread.json.message_count = 10` (eventually; may be briefly lower during race).
- `digest.json.channel_seq = 10`.
- No duplicate seq numbers.
- No corrupted JSON files.

### Scenario: Kill mid-archive-move

**Fixture**: `fixtures/shared/e2e/archive-half-move/`

Setup:
- Channel with only 1 member (last-member archive trigger ready).
- Mock consent = "yes".

Execute:
- Start `/council-leave` in a subprocess.
- Kill the subprocess during the archive move (inject delay in `scripts/archive-channel.ps1` at the `rename` call).

Expect:
- State is partially moved: some files in `channels/es-training/`, others in `channels/archive/es-training-<ts>/`.
- Next session's `/council-open` or `/council-list` preflight detects the orphan.
- Clear error message with manual-recovery instructions.
- NO data loss: every message file exists at exactly one path.

### Scenario: Kill between channel.json write + digest rebuild

**Fixture**: `fixtures/shared/e2e/kill-post-between-writes/`

Setup:
- Channel with 1 active thread.

Execute:
- `/council-post` runs up to thread.json update, then killed before digest.json update.

Expect:
- Message file exists (append-only; truth).
- thread.json updated (partial — but reliable since atomic-write).
- digest.json NOT updated yet; channel_seq reflects old value.
- Next `/council-post` or `/council-check` rebuilds digest and syncs channel_seq.
- No user-visible corruption.

### Scenario: Session restart recovery

**Fixture**: `fixtures/shared/e2e/session-restart/`

Setup:
- Channel with member A active; some unread messages.

Execute:
- Kill member A's session entirely.
- Start new session; call `/council-join --as A`.

Expect:
- Case B (disconnected) reclaim per `skills/council-join/SKILL.md` §Step 3.
- Read-marker preserved.
- A sees unread count correctly on `/council-check`.

## Categories + target counts

| Category | Scenarios |
|---|---|
| Concurrent posts | 3 variants (2 agents, 10 agents, race across channels) |
| Kill-mid-operation | 6 variants (mid-post, mid-leave, mid-review, mid-retro, mid-join, mid-verdict) |
| Disk / permission | 3 variants |
| Network partition (A2A) | 2 variants |
| Clock skew | 2 variants |
| Session restart recovery | 3 variants |
| Orphan .tmp cleanup | 1 |
| Archive atomicity | 2 |
| **Total** | **~22 scenarios** |

## Perf budget

- Per-scenario: <5 min (some concurrent-agent scenarios take minutes to spin up).
- Full Layer 3 suite: <30 min.
- Run on pre-release CI only (not every commit).

## Running Layer 3

```
./run-evals.ps1 -Layer 3
./run-evals.ps1 -Layer 3 -Scenario archive-half-move
```

## Recovery + rollback verification

Every Layer-3 scenario that induces a partial state must also verify that:

1. The recovery path (preflight orphan sweep, manual cleanup, etc.) produces a valid state.
2. No message data is lost (append-only invariant holds).
3. User-facing error messages are actionable.

## Related

- Each skill's `tests.md` §Layer 3.
- `rules/concurrency-safety.md` — concurrency invariants being stress-tested.
- `scripts/preflight.ps1` — orphan sweep tested here.
- `wiki/patterns/state-file-coordination.md` — pattern underlying these tests.
