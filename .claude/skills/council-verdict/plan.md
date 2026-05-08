# Implementation Plan: /council-verdict

Target: MAD.Council Phase 2 — Council Review per `mad.council.a2a.md` §12. Simpler than `/council-review`; manual path.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 11 scripts/ | ⏸ |
| `scripts/channel-helpers.ps1` | iter 11 | ⏸ |

No role orchestration; much simpler than /council-review.

## Implementation steps

### 1. Parse arguments

- Validate: thread-id, verdict (enum), rationale (length 20-2000).
- Verdict case-insensitive normalize → uppercase.
- Rationale → strip whitespace + length check.

### 2. Preflight membership + thread

- Verify channel membership.
- Verify thread exists.
- Status can be `active` or `resolved` (override is the point).
- Archive status → reject (`rc=2`).

### 3. Read existing verdict

- Read `verdict.json` if present.
- Parse. If malformed → treat as no prior verdict (warn).

### 4. Determine override + consent gates

- `override = (existing_verdict.verdict != new_verdict)` when existing exists.
- If new_verdict=FIX AND thread has active tasks/questions without resolve → trigger FIX-on-active consent gate.
- If override → trigger override consent gate with preview of prior verdict + rationale.
- On consent "no" / timeout → `rc=5`.

### 5. Resolve run_id

- Inherit from thread's last message's run_id.

### 6. Archive prior verdict (if override)

- Copy existing `verdict.json` → `verdict.json.previous-<timestamp>.json`.
- Atomic write (actually atomic-copy; or read + write new file).
- On failure: `rc=4`; do NOT overwrite original.

### 7. Write new verdict.json

- Build object per schema (mode="manual-override", findings=[], role_summaries={}, override flag + override_of copy).
- Atomic-rename write.

### 8. Post resolve message (if active)

- Skip if thread.status=resolved already.
- Call `/council-post` with resolve type + truncated rationale.

### 9. Emit output

- Rendered per SKILL §Step 8.

## Rollback

| Step | Failure | Action |
|---|---|---|
| 6 (archive prior) | Copy fails | `rc=4`; do NOT proceed to step 7 |
| 7 (new verdict) | Write fails | `rc=4`; prior verdict unchanged (if archive succeeded, clean up the .previous-*.json) |
| 8 (resolve post) | Post fails | `rc=1`; verdict.json persisted; thread not auto-resolved |

## Error messages

| Condition | Message |
|---|---|
| Rationale too short | `"Rationale required (min 20 chars). Manual verdicts need audit context."` |
| Rationale too long | `"Rationale too long (max 2000 chars). Break into verdict.json's verdict_reasoning + a follow-up thread for details."` |
| Invalid verdict | `"Verdict must be one of: FIX, ACCEPT, ESCALATE, INVESTIGATE."` |
| Thread archived | `"Cannot issue verdict on archived thread. Archives are frozen."` |

## Test coverage targets

- All 6 rc codes reachable.
- All 4 verdict types issued.
- Override path with consent yes/no.
- FIX-on-active consent path.
- Prior-verdict archival.
- Override of already-resolved thread (post-hoc).

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing + validation | 2 |
| Preflight + read existing verdict | 1 |
| Consent gate orchestration | 3 |
| Archive prior verdict | 1 |
| Write new verdict.json | 1 |
| Resolve post | 1 |
| Output rendering | 1 |
| Tests | 4 |
| **Total** | **~14 hours (~1.5 working days)** |

## Risks

| Risk | Mitigation |
|---|---|
| Override misuse (avoiding real review) | Rationale required + override consent gate raises friction |
| Rapid override churn | Bounded iteration cap: max 3 overrides per thread per session; 4th rejected |
| Verdict.json archive bloat (many `.previous-*.json` files) | Accepted; they're audit trail. Rotation policy could be added in future. |
| Rationale contains prompt-injection payload | Rule-1 scan at post time via /council-post; suspicious tag applied to resolve message |

## Forward-links

- `evals/fixtures/council-verdict-accept-no-prior/` — first-time ACCEPT on active thread.
- `evals/fixtures/council-verdict-fix-on-active/` — FIX-on-active consent gate.
- `evals/fixtures/council-verdict-override-fix-to-investigate/` — override consent gate.
- `evals/fixtures/council-verdict-post-hoc-on-resolved/` — override of already-resolved thread; no new resolve message.
- `evals/fixtures/council-verdict-3-overrides-exhausted/` — 4th override rejected.
- `evals/layer-2-integration/council-verdict.test.md`.
