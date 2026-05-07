# Concurrency Safety

**Applies to:** every skill that writes to shared channel state — `channel.json`, `seq.json`, `digest.json`, `thread.json`, `read-markers/<alias>.json`, any MAD artifact. Also: every skill that reads these files must understand their concurrency-safety guarantees.

**Opened by:** CHK-010 in `_review-checklist.md` (iter-1 HIGH: spec mentions retry-on-collision but lacks a dedicated rule making concurrency requirements unmissable).

**Source:** Channels v1 + `mad.council.a2a.md` §7.1/§10.2. Compiled here as a standalone rule because multiple skills touch shared state and a scattered rule is easy to miss.

## Core principle

**No file is ever partially written. No two writers ever silently corrupt each other's output.**

MAD.Council uses a file-based coordination model (shared filesystem, no RDBMS). Concurrency safety is the responsibility of every writer. The rules below are the mechanisms.

**Related accountability policies (ADOPT-015):** this rule prevents *silent* corruption. Accountability for *intentional* but unauthorized writes — e.g., a non-owner flipping `owner_alias` — is covered by `rules/single-owner-accountability.md`. Concurrency correctness and ownership authorisation are two independent invariants; a write that satisfies atomic rename but violates ownership is still a tampering attack (see `evals/layer-4-adversarial.md` owner-alias-direct-edit fixture).

## The four mechanisms

### 1. Append-only for messages

**Rule:** every message is a new file (`<seq>-<timestamp>-<alias>.json`). Messages are never rewritten after creation. No skill offers an "edit message" operation.

**Why it works:** two writers posting simultaneously write to different filenames (different seq numbers). No contention. No locking needed.

**Consequences:**
- Typos stay in the record. Correction is a new message.
- Message filename is unique under the monotonic seq counter — `001-...`, `002-...`, etc.
- Archive is just a directory move — preserves ordering.

### 2. Atomic write for mutable files

**Rule:** when writing `channel.json`, `digest.json`, `seq.json`, `thread.json`, `read-markers/<alias>.json`, use the **write-temp-then-rename** pattern:

```
1. Read current file → parse to memory
2. Modify in memory
3. Write modified content to `<file>.tmp`
4. Rename `<file>.tmp` → `<file>` (atomic on all modern OS)
```

**Why it works:** `rename()` is atomic on POSIX and Windows (NTFS). A reader either sees the pre-update file or the post-update file — never a half-written one.

**Implementation in helper script** (`scripts/atomic-write.ps1`, future):

```powershell
function Write-AtomicJson {
  param([string]$Path, [object]$Content)
  $tmp = "$Path.tmp"
  $Content | ConvertTo-Json -Depth 20 | Set-Content -Path $tmp -Encoding UTF8
  Move-Item -Path $tmp -Destination $Path -Force
}
```

All skills that write these files use the helper, not a direct file write.

### 3. Read-modify-write with retry for seq.json

**Rule:** the monotonic sequence counter is the one file where two writers can race for the same number. Handle it:

```
1. Read seq.json → { "next_seq": 46 }
2. Claim seq 46.
3. Write updated seq.json → { "next_seq": 47 } (atomic write per §2).
4. Use seq 46 in the message filename.
```

If two writers race:
- Both read `{ next_seq: 46 }`.
- Both attempt to claim 46.
- First to complete the write wins — file is now `{ next_seq: 47 }`.
- Second writer's attempt to write 47 is either a no-op (47 already there; idempotent) or detects the conflict.

The retry strategy (from `mad.council.a2a.md` §10.2):
- **Max retries: 3** (retry with next number).
- **Timeout: 2s.**
- **On failure: fail post with `rc=4`; do not leave seq.json in inconsistent state.**

The second racer, upon discovering their seq was taken, **retries with the next number** (47) and writes a fresh `{ next_seq: 48 }`.

**Why 3 retries?** If three agents race simultaneously, the retry loop resolves them. If there's a genuine bug (stuck file lock, permission error), we don't retry forever — 3 is a reasonable ceiling.

### 4. Last-write-wins for thread.json / digest.json

**Rule:** `thread.json` fields like `message_count`, `last_seq`, `last_message_utc` are updated by every `/council-post` in that thread. Two writers updating simultaneously may produce briefly-inconsistent state (count off by 1) — this is accepted and corrected on the next post.

**Why it works:** these fields are derived from the thread's messages directory. Even if `message_count` is briefly wrong, a consumer can recompute it by scanning `messages/`. Correctness is eventual.

**Implication for consumers:** don't trust `thread.json.message_count` for safety-critical decisions. For display, it's fine. For "is this message already in the thread?" use the messages directory as source of truth.

**digest.json** is the same story — it's a rolling summary, atomically-written, but may lag by milliseconds after a post. Readers expecting exact real-time state should read the thread directly.

## Conflict matrix

| Operation A | Operation B | Conflict? | Mitigation |
|---|---|---|---|
| Two `/council-post` to different threads | | None | Different message files, different thread.json updates |
| Two `/council-post` to same thread | | Low | Last-write-wins on thread.json; recomputed on next post |
| Two agents racing for seq.json | | Low | Read-inc-write with retry-next-number (§3) |
| Agent posting + agent reading digest | | None | Reader gets pre- or post-update digest; both are valid states |
| `/council-join` + `/council-post` | | None | Different files (channel.json vs message file) |
| Two agents updating digest.json | | Low | Atomic write via `.tmp` + rename (§2); brief inconsistency acceptable |
| `/council-resolve` + `/council-post` to same thread | | Low | Both write to thread.json; last-write-wins leaves `status: resolved` (idempotent — `resolve` is terminal) |
| Two agents force-reclaiming same alias | | Medium | Consent gate (`dangerous-operations-policy.md` §Force Reclaim) serializes through user |
| `/council-leave` last-member archive + another's `/council-post` | | **Medium-High** | The leaving member holds the channel open until archive confirms; poster to a channel being archived sees a clear error |

## Edge cases

### Filesystem lock contention

On some filesystems (Windows FAT/exFAT, network mounts), `rename()` may fail if the target is held open by another reader. Mitigation:

1. On rename failure, sleep 50ms, retry up to 2x.
2. If persistent failure, report Context Gap per `degradation-fallback-policy.md` Rule 3.
3. Do NOT fall back to non-atomic write.

### Clock skew

If two agents have clocks differing by seconds, the `timestamp_utc` fields in messages will be non-monotonic even if the seq numbers are strictly increasing. This is accepted: **seq is the ordering primitive, not timestamp.**

Clock skew is checked at preflight (`preflight-dependency-checks.md`); users are warned but not blocked.

### Write-from-a-process-that-dies

If a writer dies between step 2 (write .tmp) and step 4 (rename), the .tmp file orphans. Mitigation:

1. Startup check on each skill: clean orphan .tmp files older than 60s in its working directories.
2. A partial message file (named `<seq>-...json.tmp`) is never consumed as a message.

### Read-only filesystems

If the channel directory becomes read-only (mount issue, permission change), all writers fail. Mitigation:

1. Detect via write-probe on first operation of each session.
2. Report Context Gap.
3. Enter read-only mode — `/council-check` still works, `/council-post` returns `rc=4`.

## Testing concurrency safety

The `evals/correctness-eval.md` test harness (future) must include:

1. **10-agent concurrent post** — 10 agents post simultaneously to one thread; verify message_count converges to 10 and all seq numbers are unique.
2. **Last-member archive race** — agent A is last member and calls `/council-leave` while agent B posts at the same instant. Verify either (a) B's post succeeds and A sees updated state before archive, or (b) B gets a clear "channel archiving" error.
3. **Digest integrity under load** — 100 posts/min sustained; verify digest.json always parses and reflects correct `channel_seq`.
4. **Orphan .tmp recovery** — kill a writer mid-atomic-write; verify the next session cleans up.

## Interaction with other rules

- **`degradation-fallback-policy.md`** — concurrency failures (rename retry exhausted) are Context Gaps, not crashes.
- **`dangerous-operations-policy.md`** — the archival race (last-member leave during another's post) is a Dangerous Operation for the leaver (consent) but an error for the poster.
- **`stride-threat-model.md`** §Tampering — atomic writes mitigate tampering via half-written state; they don't mitigate authorized malicious writes (that's FS trust boundary).

## References

- `mad.council.a2a.md` §7.1 (directory layout), §10.2 (retry table) — source spec sections.
- Channels v1 (2026-04-15) §Concurrency & Write Safety — origin of the append-only and atomic-write rules.
- POSIX `rename(2)` atomicity guarantees — https://man7.org/linux/man-pages/man2/rename.2.html
- Windows NTFS `MoveFileEx` with `MOVEFILE_REPLACE_EXISTING` — atomic on same volume.
- `wiki/patterns/state-file-coordination.md` (future) — the broader pattern of using shared files for state.
