# Implementation Plan: /council-post

Target: MAD.Council Phase 1 MVP per `mad.council.a2a.md` §12. Highest-validation-load skill in Phase 1.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 10 | ⏸ |
| `scripts/channel-helpers.ps1` (membership lookup, session-id check) | iter 10 | ⏸ |
| `scripts/seq-increment.ps1` (read-inc-write with retry) | iter 10 | ⏸ |
| `scripts/digest-rebuild.ps1` | iter 10 | ⏸ |
| `scripts/literal-phrase-scan.ps1` (Rule-1 ban list) | iter 10 | ⏸ |
| `scripts/slugify.ps1` (thread-id from title) | iter 10 | ⏸ |
| MAD gate checker (if channel has MAD) | iter 10 or Phase 3 | ⏸ (optional in Phase 1) |
| A2A transport adapter (if non-local transport) | Phase 4 | ⏸ |

**Phase 1 MVP excludes A2A transports** — `--transport local` only. `a2a-*` transports reject with `rc=2` "A2A layer not yet implemented; use --transport local."

## Implementation steps

### 1. Parse arguments

- Exactly one of `--thread` / `--new-thread` required (not both).
- Validate `--type` against enum.
- Body parsing handles multi-line quoted strings.
- On parse failure → `rc=2`.

### 2. Preflight channel + membership

- Verify `~/claude-data/channels/<c>/channel.json` exists. Missing → `rc=3`.
- Read channel.json. Find `members[]` entry where `session_id == $thisSessionId`.
- No match → `rc=2` ("not a member").

### 3. Session-id binding (explicit check)

- Using the alias from the membership-match, re-verify `channel.json.members[?alias=$fromAlias].session_id == $thisSessionId`.
- Defense-in-depth: two lookups. Prevents race where membership changed between reads.
- Mismatch → `rc=2` ("session hijack possible").

### 4. Resolve thread (branch)

**`--new-thread` path**:
- Slugify title. Append numeric suffix on collision.
- Check MAD gate if channel.mad_enabled (per `mad.council.a2a.md` §4.5): `--type task` requires spec-gate passed.
- Create `threads/<id>/` dir + `thread.json` stub.

**`--thread <id>` path**:
- Read `threads/<id>/thread.json`. Missing → `rc=2`.
- Status check: `active` always OK; `resolved` accepts only `resolve` type; `archived` rejects.

### 5. Validate body

- UTF-8 byte-count ≤ 32768. Exceed → `rc=2`.
- Run literal-phrase scan (`scripts/literal-phrase-scan.ps1`). Records match/no-match.
- Tag `suspicious: true` if match AND no `--force-raw`.

### 6. Resolve + validate mentions

- Merge `--mentions` arg + body-derived `@alias` matches (dedupe).
- Filter against `channel.json.members[].alias`. Phantoms dropped.
- Warnings surface in output.
- If >10 validated → batch gate consent.

### 7. Thread-creation batch gate (if `--new-thread`)

- Count active threads. If >10 → consent gate.

### 8. Resolve run_id

- If `--reply-to <msg-id>`: read that message file; inherit `run_id`.
- Else if `--run-id <guid>`: validate + use.
- Else: use session's current run_id.

### 9. Atomic seq increment

- Call `scripts/seq-increment.ps1`. Returns claimed `<N>` + new next_seq persisted.
- Retries up to 3 on collision with "next number" strategy.
- Exhausted → `rc=4`.

### 10. Compose + write message file

- Build message object.
- Write `threads/<tid>/messages/<N>-<ts>-<alias>.json` via atomic-write (though single-writer on new filename — atomic is still cheap).

### 11. Update thread.json

- Read + modify + atomic-rename write.
- Touch fields: `message_count`, `last_seq`, `last_message_utc`, `last_message_from`, `participants[]`.
- If `--type resolve`: `status: resolved`, `resolved_utc`, `resolved_by`, trigger archive timer (60 min).

### 12. Rebuild digest

- Call `scripts/digest-rebuild.ps1`. It scans `threads/` + archives, composes the digest, atomic-writes.
- Retries on write failure.

### 13. A2A transport (Phase 4 only; Phase 1 rejects non-local)

- Not in Phase 1 scope.

### 14. Emit output

- Render success report with message ID, thread ID, warnings, MAD gate notes.

## Rollback

Post is the most-rollback-sensitive operation because many files update together:

| Step | Failure mode | Rollback |
|---|---|---|
| 9 (seq.json) | Collision retries exhausted | No state written; `rc=4` |
| 10 (message file) | Write fails after seq claimed | Roll forward: next post uses the incremented seq anyway (gap is acceptable — we document this in the spec). Alternative: rollback seq (read-inc-write dec). Pick one; document. **Choice: roll forward with gap.** |
| 11 (thread.json) | Update fails after message written | Message is the truth (append-only). thread.json stats off by 1 until next post fixes. `rc=1` with warning. |
| 12 (digest.json) | Update fails after thread.json updated | digest stale briefly. `/council-check` will detect staleness vs channel_seq. `rc=1` with Context Gap warning. |

## Error messages

| Condition | Message |
|---|---|
| Not a member | `"You are not a member of '<c>'. Run /council-join <c> --as \"<alias>\" first."` |
| Session mismatch | `"Session ID mismatch — alias may have been reclaimed. Run /council-join --force-reclaim if this session should hold the alias."` |
| Body too large | `"Body exceeds 32 KB limit (<n> bytes). Reduce size or reference file paths instead of embedding."` |
| Type invalid | `"--type must be one of: task, question, answer, status, fyi, resolve"` |
| Thread missing | `"Thread '<tid>' not found in '<c>'. Use --new-thread \"<title>\" or check /council-check for active threads."` |
| Thread not active | `"Thread '<tid>' is <status>. Cannot post (except --type resolve to active threads)."` |
| MAD gate not met | `"MAD spec gate not passed. Complete spec.md in '<c>'/spec.md before posting task-type messages."` |
| seq collision retries exhausted | `"Failed to claim a unique seq after 3 attempts. High contention — retry in a few seconds."` |
| Phantom mentions | (warning, not error) `"Dropped non-member mentions: <list>. Posting with validated mentions: <list>."` |

## Test coverage targets

Per `tests.md`:

- All 5 return codes reachable.
- All 6 message types covered.
- Session-id binding pass + fail explicitly tested.
- Phantom mention handling covered.
- Literal-phrase match with + without `--force-raw` covered.
- Body size cap edge: 32767, 32768, 32769 bytes.
- Thread-creation batch gate (11 active threads) covered.
- Mention batch gate (11 mentions) covered.
- MAD gate check (if Phase 3 impl'd) covered.
- seq.json collision + retry covered.
- Rollback semantics (seq claimed, message write fails) covered.

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing (complex) | 3 |
| Membership + session-id binding | 2 |
| Thread resolution (both branches) | 3 |
| Body validation (size + literal-phrase scan + UTF-8) | 3 |
| Mention validation (merge, filter, batch gate) | 3 |
| seq.json increment + retry logic | 4 |
| Message write | 1 |
| thread.json + digest.json updates | 4 |
| Rollback semantics | 3 |
| Tests (extensive) | 10 |
| **Total** | **~36 hours (~4.5 working days)** |

## Risks

| Risk | Mitigation |
|---|---|
| Session-id binding race (membership changed between reads) | Two-lookup defense-in-depth; `rc=2` on mismatch is acceptable outcome |
| seq.json contention under heavy load | Retry-next-number pattern; 3-attempt cap prevents infinite retry |
| Digest rebuild takes too long on channels with many threads | Rebuild is optimized to touch only affected thread entries; full rebuild is fallback |
| MAD gate false-blocks valid task posts | Clear error message with remediation path (complete spec); user can bypass by completing spec |
| Body scan false-positives on legitimate content | `--force-raw` escape hatch |
| A2A queue-locally fills up | Out-of-Phase-1 scope; Phase 4 adds queue-size cap |

## Forward-links

- `evals/fixtures/council-post-happy-path/` — fresh task post.
- `evals/fixtures/council-post-body-overflow/` — 32769-byte body test.
- `evals/fixtures/council-post-injection-body/` — Rule-1 literal phrase with and without --force-raw.
- `evals/fixtures/council-post-phantom-mention/` — mention of non-member.
- `evals/fixtures/council-post-seq-collision/` — concurrent posting fixture.
- `evals/fixtures/council-post-mad-gate-fail/` — task post without spec-gate.
- `evals/layer-2-integration/council-post.test.md` — integration tests.
- `evals/layer-3-e2e/multi-agent-conversation.test.md` — end-to-end scenario.
- `evals/layer-4-adversarial/session-hijack-via-post.test.md` — spoofing attempt.
