# Dry Run — the Happy Path

A narrative walk-through of MAD.Council from `/council-open` through `/council-leave`, tracing every file read, every file written, every rule invoked, and every metric emitted. Two agents ("Alice" and "Bob") collaborate on fixing a bug. No adversarial behavior; no failures. This is **what working looks like**.

If this narrative reads smoothly end-to-end, the scaffold is coherent. If a step requires "handwaving" — e.g., "Alice's session_id appears from somewhere" — that's a gap.

Use this doc when:
- Onboarding someone to the kit (read this after the spec, before any skill).
- Sanity-checking a Phase-1 implementation: can we actually walk through the whole scenario?
- Writing a Layer-2 integration test scenario — this narrative is the shape of `evals/fixtures/e2e-happy-path/`.

---

## Setup

Alice is at `C:\dev\repo-a\`, session_id `sess-alice-001`, on Claude Code.
Bob is at `C:\dev\repo-b\`, session_id `sess-bob-002`, on Claude Code.
Both have `~/claude-data/` empty (fresh install).
Target: resolve one bug — a race condition in `sources/auth/token-refresh.ts`.

---

## Step 1. Alice runs `/council-open bug-auth-race "Investigate token-refresh race condition observed 2026-04-16"`

**What the skill does (per `skills/council-open/SKILL.md`):**

1. **Preflight** (per `wiki/patterns/preflight-dependency-checks.md`): checks Claude Code version ≥2.1.105, PowerShell 7+, write access to `~/claude-data/`, CronCreate available. All pass.
2. **Validate args**: `bug-auth-race` matches `^[a-z0-9][a-z0-9-]{0,63}$` → OK. Purpose ≤500 chars → OK.
3. **Literal-phrase scan** on purpose string (`rules/prompt-injection-policy.md` Rule 1): no ban-list hits → OK.
4. **Create channel dir**: `~/claude-data/channels/bug-auth-race/`.
5. **Generate run_id**: GUID `11111111-1111-4111-8111-111111111111` (per `wiki/patterns/run-id-correlation.md`).
6. **Write channel.json** atomically (per `rules/concurrency-safety.md` + `scripts/atomic-write.ps1`):
   ```json
   {
     "name": "bug-auth-race",
     "purpose": "Investigate token-refresh race condition observed 2026-04-16",
     "created_utc": "2026-04-17T14:00:00Z",
     "created_with_run_id": "11111111-1111-4111-8111-111111111111",
     "members": [{
       "alias": "Alice",
       "session_id": "sess-alice-001",
       "project": "repo-a",
       "joined_utc": "2026-04-17T14:00:00Z",
       "status": "active",
       "last_seen_utc": "2026-04-17T14:00:00Z"
     }],
     "settings": { "mad_enabled": false, "a2a_enabled": false }
   }
   ```
7. **Initialize `seq.json`**: `{ "current": 0 }`.
8. **Initialize `digest.json`**: `{ "channel_seq": 0, "rebuilt_utc": "2026-04-17T14:00:00Z", "total_messages": 0, "threads": [] }`.
9. **Register in `~/claude-data/.sessions.json`** (session-local): adds `bug-auth-race` to Alice's memberships list.
10. **Arm poller** via `CronCreate` (every 1 min): `claude code -p "/council-check bug-auth-race"`.
11. **Emit completion report**: "Channel bug-auth-race created. 1 member (Alice). 0 threads. Run_id 11111111…"

**Files written:** 4 new (channel.json, seq.json, digest.json, .sessions.json).
**Rules invoked:** prompt-injection (scan purpose), dangerous-ops (none — create is non-destructive), concurrency (atomic write).
**Metrics emitted:** `invoke_skill council-open` span (rc=0), `council_open.invocations_total{mode="propose"}` += 1.

---

## Step 2. Alice pings Bob: "I opened bug-auth-race — join when you're free."

(Out-of-band. Slack, email, whatever.)

---

## Step 3. Bob runs `/council-join bug-auth-race --as "Bob"`

**What the skill does (per `skills/council-join/SKILL.md`):**

1. **Preflight**: same as above. All pass.
2. **Resolve channel**: `~/claude-data/channels/bug-auth-race/channel.json` exists → OK.
3. **Check alias uniqueness**: `Bob` not in `members[]` → OK (no reclaim path taken).
4. **Literal-phrase scan** on alias: no ban-list hits → OK.
5. **Append to members[]** via read-modify-atomic-write:
   ```json
   {
     "alias": "Bob",
     "session_id": "sess-bob-002",
     "project": "repo-b",
     "joined_utc": "2026-04-17T14:03:00Z",
     "status": "active",
     "last_seen_utc": "2026-04-17T14:03:00Z"
   }
   ```
6. **Register membership** in Bob's `.sessions.json`.
7. **Arm Bob's poller**: CronCreate.
8. **Initialize read-marker** `read-markers/Bob.json`: `{ "alias": "Bob", "session_id": "sess-bob-002", "last_read_seq": 0, "updated_utc": "2026-04-17T14:03:00Z" }`.
9. **Emit completion report**: "Joined bug-auth-race. Members: 2 (Alice, Bob). 0 unread."

**Files written:** 2 (channel.json update, read-markers/Bob.json new).
**Concurrency:** Alice's `/council-check` poller may be running concurrently. Read happens at atomic boundaries; Bob's write to channel.json uses `.tmp+rename`. If Alice reads mid-write, she sees the pre-write or post-write state — never partial.
**Metrics:** `invoke_skill council-join` span (rc=0).

---

## Step 4. Alice runs `/council-post bug-auth-race --type task "@Bob reproduce the race with ./repro-auth.ps1, run 50 concurrent sessions, share the failure stack trace."`

**What the skill does (per `skills/council-post/SKILL.md`) — the heaviest skill in MVP:**

1. **Preflight**: dependencies OK.
2. **Resolve channel + membership**: Alice is in `members[]` with `sess-alice-001` → OK. **Session-id binding check** (spec §7.2): Alice's current session_id `sess-alice-001` matches `members[0].session_id` → OK. (If mismatch: `rc=2 spoofing rejected`.)
3. **Thread resolution**: no `--thread` flag → create new thread. Generate thread_id from first 20 chars of body + hash: `reproduce-the-race-a1b2`. Create `threads/reproduce-the-race-a1b2/`.
4. **Body validation**:
   - Size check: 112 bytes → well under 32KB cap (`mad.council.a2a.md §8.5`).
   - Literal-phrase scan (Rule 1 of `rules/prompt-injection-policy.md`): no ban-list hits → OK. `suspicious: false`.
5. **Mention validation**: body contains `@Bob`. Check `channel.members[].alias` — `Bob` present → OK. (If not found: warn and ask user; skip validation for aliases that look like user-text typos.)
6. **Batch gate**: 1 mention < 10-mention threshold → no confirmation prompt.
7. **Type = task** → MAD gate check: `settings.mad_enabled = false` → skip MAD tasks.md update.
8. **Increment seq**: `scripts/seq-increment.ps1` with retry-on-collision. seq becomes 1.
9. **Generate message_id**: `msg-001`.
10. **Generate run_id**: new for this work unit → `22222222-2222-4222-8222-222222222222`. (Alice's /council-post is a new work unit; if she were replying, she'd inherit the root thread's run_id.)
11. **Write message atomically** at `threads/reproduce-the-race-a1b2/messages/001-2026-04-17T14-10-00Z-Alice.json`:
    ```json
    {
      "id": "msg-001",
      "seq": 1,
      "thread_id": "reproduce-the-race-a1b2",
      "from": {
        "alias": "Alice",
        "session_id": "sess-alice-001",
        "project": "repo-a"
      },
      "timestamp_utc": "2026-04-17T14:10:00Z",
      "type": "task",
      "body": "@Bob reproduce the race with ./repro-auth.ps1, run 50 concurrent sessions, share the failure stack trace.",
      "mentions": ["Bob"],
      "run_id": "22222222-2222-4222-8222-222222222222",
      "transport": "local",
      "body_size_bytes": 112
    }
    ```
12. **Write thread.json**:
    ```json
    {
      "thread_id": "reproduce-the-race-a1b2",
      "status": "active",
      "created_utc": "2026-04-17T14:10:00Z",
      "created_by": {"alias": "Alice", "session_id": "sess-alice-001"},
      "run_id_root": "22222222-2222-4222-8222-222222222222"
    }
    ```
13. **Rebuild digest** (incremental path) via `scripts/digest-rebuild.ps1`: `channel_seq: 1, total_messages: 1, threads[0] = { id: "reproduce-the-race-a1b2", status: "active", last_msg_seq: 1, message_count: 1 }`.
14. **Update Alice's read-marker**: `last_read_seq: 1`.
15. **Emit completion**: "Posted msg-001. Thread reproduce-the-race-a1b2. Body 112 bytes."

**Files written:** 4 (message, thread.json, digest.json update, read-markers/Alice.json update).
**Rules invoked:** prompt-injection (scan body), concurrency (atomic writes, seq increment with retry), degradation (no context gaps here).
**Metrics:** `council_post.invocations_total` += 1, `council_post.body_size_bytes` histogram samples 112.

---

## Step 5. Bob's poller fires `/council-check bug-auth-race`

**What the skill does (per `skills/council-check/SKILL.md`):**

1. **Fast path check**: read `digest.json` + `read-markers/Bob.json`. channel_seq=1, last_read_seq=0 → 1 unread.
2. **Read message**: `threads/reproduce-the-race-a1b2/messages/001-*.json`.
3. **Reader-side session-id verification** (defense in depth): message's `from.session_id` = `sess-alice-001`. Current `channel.members[alias=Alice].session_id` = `sess-alice-001` → match → no ⚠️ badge.
4. **Rule-1 scan at read time** (per `rules/prompt-injection-policy.md`): body has no ban-list hits → render plain.
5. **Render for Bob**: "`[task] Alice @Bob: reproduce the race with ./repro-auth.ps1, run 50 concurrent sessions, share the failure stack trace.`"
6. **Update read-marker**: `last_read_seq: 1`.
7. **Emit completion**: "1 unread processed. Thread reproduce-the-race-a1b2."

**Files written:** 1 (read-markers/Bob.json update).
**Metrics:** `council_check.invocations_total{mode="cron"}` += 1, `council_check.unread_count` histogram samples 1.

---

## Step 6. Bob runs his repro, finds the bug, and runs `/council-post bug-auth-race --thread reproduce-the-race-a1b2 --type answer "Reproduced. Stack trace:\n\nTypeError: Cannot refresh tokenFactory: undefined\n    at refreshToken (token-refresh.ts:42)\n    at Promise.all\n\nRoot cause: two concurrent callers both see token expired, both call refresh, first write wins but second's deref fails."`

Same skill flow as Step 4, with differences:
- **`--thread` provided** → use it; no new thread created.
- **`in_reply_to`** is inferred from thread's last message (msg-001) → `in_reply_to: "msg-001"`.
- **run_id inherited** from thread's root: `22222222-2222-4222-8222-222222222222` (not a new work unit — it's a reply).
- Body is longer (~250 bytes); still under cap.
- seq becomes 2. message_id `msg-002`.

Alice's poller picks it up on the next minute boundary.

---

## Step 7. Alice runs `/council-review reproduce-the-race-a1b2`

**What the skill does (per `skills/council-review/SKILL.md`):**

1. **Preflight**: dependencies OK.
2. **Resolve thread**: `reproduce-the-race-a1b2` exists → OK.
3. **Membership check**: Alice is in members → OK.
4. **Mode resolution**: channel `settings.ensemble_mode` unset → default to `propose` (single-reviewer per role, not 3-model ensemble).
5. **Assemble brief**: thread messages (msg-001, msg-002) + any linked code files cited by content (none here) + relevant rules + relevant wiki patterns.
6. **Rule-1 scan on brief** (per `wiki/patterns/evidence-beats-assertion.md`): clean.
7. **Dispatch 3 roles in parallel** via synchronous Task calls (never `run_in_background`):
   - **Advocate** (single Opus, 4-min timeout): "Defends Bob's root-cause analysis. Confidence 0.9. Evidence: `token-refresh.ts:42` quoted from the stack. Finding severity: nothing to escalate — the root cause is well-diagnosed."
   - **Skeptic** (single Opus in propose mode — no ensemble; 4-min timeout): "Attacks the fix premise. Finding: 'Diagnosis names the symptom but doesn't show the race window. Is there a lock? Does refreshToken() use optimistic concurrency? Without that detail, a fix can't be verified.' Severity HIGH. Evidence: cited line `token-refresh.ts:42`. Confidence 0.82."
   - **Architect** (single Opus, 4-min timeout): "Evaluates direction. Finding: 'This is a single-line refactor opportunity — if the race is real, a Mutex around refresh resolves it in one line, and we should check the other 3 call-sites.' Severity MEDIUM. Evidence: pattern match on `token-refresh.ts:42`. Confidence 0.78."
8. **Citation verification**: grep for cited paths. `token-refresh.ts:42` would need to exist — in a real dry run, this would be a repo check. Confidence that citations resolve: 3/3 OK.
9. **Confidence aggregation**: max role confidence 0.9, min 0.78, average 0.83. Threshold 0.85 for autonomous; <0.85 → **with-caveats** (per `skills/council-review` §Confidence thresholds, ICLR 2025).
10. **Verdict computation**: Skeptic's HIGH + Architect's MEDIUM + Advocate's no-block → suggest **FIX**. No mechanical ESCALATE trigger fires (no disagreement>0.5; no timeout; citations all resolved; role confidences above floor).
11. **Write `verdict.json`** atomically:
    ```json
    {
      "thread_id": "reproduce-the-race-a1b2",
      "verdict": "FIX",
      "issued_utc": "2026-04-17T14:25:00Z",
      "issuer": {"alias": "Alice", "session_id": "sess-alice-001", "mode": "auto"},
      "rationale": "Race condition confirmed by Skeptic; needs Mutex around refreshToken() at token-refresh.ts:42 and audit of 3 other call-sites. Advocate defends diagnosis; Architect suggests single-line refactor.",
      "roles_run": [
        {"role":"advocate","confidence":0.9,"model":"opus","latency_ms":41000,"timed_out":false},
        {"role":"skeptic","confidence":0.82,"model":"opus","latency_ms":38000,"timed_out":false},
        {"role":"architect","confidence":0.78,"model":"opus","latency_ms":33000,"timed_out":false}
      ],
      "findings": [
        {"role":"skeptic","severity":"HIGH","summary":"Race window not localized; needs explicit Mutex","evidence":"token-refresh.ts:42","confidence":0.82},
        {"role":"architect","severity":"MEDIUM","summary":"Pattern suggests single-line Mutex fix + audit 3 other call-sites","evidence":"token-refresh.ts:42","confidence":0.78}
      ],
      "run_id": "22222222-2222-4222-8222-222222222222",
      "override_count": 0
    }
    ```
12. **Post resolve message** to the thread (type `resolve`) with the verdict summary. Thread status → `resolved`.
13. **Emit completion**: "Verdict FIX on thread reproduce-the-race-a1b2. 3 roles, autonomous-with-caveats. 2 findings."

**Files written:** 3 (verdict.json new, resolve message new, thread.json update).
**Metrics:** `council_review.invocations_total` += 1, `council_review.verdict_distribution{verdict="FIX"}` += 1, `council_review.role_confidence` histogram per role (3 samples), `council_review.role_latency_ms` histogram (3 samples).

---

## Step 8. Bob implements the fix; Alice confirms in a thread reply; Bob runs `/council-resolve reproduce-the-race-a1b2`

Skill wraps `/council-post` with `type=resolve` and checks off any pending task in a MAD tasks.md if one existed (here: none, MAD off). The thread is already resolved from the verdict; this just posts the final "fix shipped as PR-123" note.

---

## Step 9. Alice runs `/council-retro bug-auth-race`

**What the skill does (per `skills/council-retro/SKILL.md`):**

1. **7-prompt flow** (blameless, 1-5 scoring): what_worked, what_was_hard, accuracy, completeness, tsg_alignment, dx, confidence.
2. **Heuristics**: scan what_was_hard for "improvise|adapt|unexpected" → none in Alice's input. Scan verdicts for role_confidence < 0.5 → none. `improvisation_needed = false`.
3. **Write retro** at `retros/2026-04-17-14-40-Alice.json`.
4. **ALAS submission**: `ALAS_HUB_URL` unset → skip.
5. **Emit completion**: scores captured, improv=false.

---

## Step 10. Both run `/council-leave bug-auth-race`

Alice goes first. Her `/council-leave`:

1. **Scan threads for her contributions** (per `wiki/patterns/completion-report-protocol.md`): threads created 1, resolved 1 (via verdict), participated 1.
2. **Not last member** (Bob still active) → no archive prompt.
3. **Remove Alice from members[]**, update channel.json.
4. **Delete Alice's read-marker** (optional; conservative default: keep for 30d).
5. **CronDelete** Alice's poller.
6. **Emit completion report JSON** per schema:
   ```json
   {
     "alias": "Alice", "session_id": "sess-alice-001",
     "channel": "bug-auth-race",
     "joined_utc": "2026-04-17T14:00:00Z",
     "left_utc": "2026-04-17T14:45:00Z",
     "threads": {"created": 1, "resolved": 1, "participated": 1, "verdict_pending": 0},
     "tasks": {"picked_up": 0, "completed": 0, "dropped": 0},
     "questions": {"asked": 0, "answered": 0},
     "final_state": "left",
     "run_ids": ["22222222-2222-4222-8222-222222222222"]
   }
   ```

Bob's `/council-leave` is the **last-member case**:

1. **Scan contributions**.
2. **Last active member** — consent gate fires (per `rules/dangerous-operations-policy.md`): shows a preview of what will be archived (channel metadata, 2 messages, 1 verdict), asks yes/no.
3. Bob says "yes".
4. **Archive**: atomic directory move `~/claude-data/channels/bug-auth-race/` → `~/claude-data/channels/archive/2026-04-17-bug-auth-race/`. All `spec.md`/`plan.md`/`tasks.md`/`verdict.json` travel with it.
5. **CronDelete** Bob's poller.
6. **Emit report**: `final_state: "last-member-archived"`.

---

## What happened in aggregate

- **14 files written / updated** across the whole flow.
- **2 threads created** (the original task-thread + a resolve posting).
- **6 skill invocations** (1 open + 1 join + 2 post + 1 check + 1 review + 1 retro + 2 leave = 9 actually — plus poller fires).
- **3 rules invoked** multiple times each (prompt-injection, dangerous-operations, concurrency).
- **~40 metric samples** emitted to OTel.
- **0 HIGH findings escalated**. 0 adversarial events. 1 session-mismatch false alarm possible (not triggered here).

Total wall-clock in this scenario: ~45 minutes of agent work + human think time. Claude Code + tooling overhead: the review took ~2 minutes (3 parallel 4-min-budgeted role calls, actual latency 33–41s each).

---

## Where this trace reveals gaps

Running this narrative end-to-end revealed these wrinkles worth tracking:

1. **Thread-id generation from body** (Step 4, derived name) is hand-waved in the skill — `skills/council-post/SKILL.md` should specify the collision handling (what if the first 20 chars + hash matches an existing thread?). Minor; flag for Phase-1 implementation.
2. **MAD-off channels skip `mad_state`** in digest — the schema allows it (`mad_state` is optional) but the spec could be more explicit. Non-blocking.
3. **`/council-review` in `propose` mode** runs 1 model per role — the spec reads as if it always runs 3 models per role. Clarify in `skills/council-review/SKILL.md §Mode-aware sizing`.
4. **Citation verification** (Step 7.8) assumes the reviewing session has filesystem access to the cited path. If Bob's message cites a file only in Bob's repo, Alice can't verify. Cross-repo citation verification is a Phase-4 A2A concern; flag for Phase-4 plan.

These four observations are **NEW CHECKLIST ITEMS** opened in iter 24.

## Related

- `skills/council-*/SKILL.md` — the per-step authoritative behavior source.
- `evals/layer-2-integration.md` — this narrative is the shape of the happy-path integration test.
- `schemas/*.schema.json` — every JSON blob quoted here is schema-validated.
- `wiki/patterns/run-id-correlation.md` — run_id rules cited throughout.
- `rules/concurrency-safety.md` — atomic-write pattern cited throughout.
