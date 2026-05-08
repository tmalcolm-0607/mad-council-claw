# Implementation Plan: /council-resolve

Target: MAD.Council Phase 1 MVP per `mad.council.a2a.md` §12. Thin wrapper over `/council-post`.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `/council-post` (spec + skill) | `MAD/skills/council-post/` ✓ | available |
| `scripts/atomic-write.ps1` | iter 13 | ⏸ |
| `scripts/mad-tasks-checkoff.ps1` (parse + update tasks.md checkboxes) | iter 13 | ⏸ |

## Implementation steps

### 1. Parse arguments

- `<channel>`, `<thread-id>`, optional `"<summary>"`.
- Default summary: `"Resolved by <my-alias>."`.

### 2. Preflight

- Membership check (or let /council-post catch it).
- Thread exists + status=active.
- On not-active: `rc=2` clear error.

### 3. Delegate post to /council-post

- Build `/council-post <channel> --thread <tid> --type resolve "<body>"` invocation.
- Propagate rc from /council-post (0/1/2/3/4/5) to our output.

### 4. MAD task checkoff (if MAD-enabled)

- Detect `[T###]` patterns in summary + all thread messages.
- Call `scripts/mad-tasks-checkoff.ps1 -ChannelDir <path> -TaskIds <list>`.
- Script reads tasks.md, atomically updates matching checkboxes `[ ]` → `[x]`.
- On failure: `rc=1` (don't fail the whole resolve).

### 5. Emit output

- Render per SKILL §Step 5.

## Error messages

| Condition | Message |
|---|---|
| Already resolved | `"Thread is already resolved. Use /council-verdict to issue a verdict, or /council-check to see current state."` |
| Archived | `"Cannot resolve archived thread."` |
| MAD task update fails | (warn only): `"Resolve posted successfully, but tasks.md update failed — manually edit if needed."` |

## Test coverage targets

- All 5 rc codes reachable.
- Default vs custom summary.
- MAD + non-MAD channels.
- T-ID extraction from summary vs thread messages.
- Error propagation from /council-post.

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing | 0.5 |
| Preflight | 0.5 |
| /council-post delegation | 0.5 |
| MAD tasks.md checkoff helper | 3 |
| Output rendering | 0.5 |
| Tests | 3 |
| **Total** | **~8 hours (~1 day)** |

Thinnest skill apart from /council-list.

## Forward-links

- `evals/fixtures/council-resolve-default/` — default summary case.
- `evals/fixtures/council-resolve-with-task-ids/` — MAD + task checkoff.
- `evals/fixtures/council-resolve-already-resolved/` — rc=2.
- `evals/layer-2-integration/council-resolve.test.md`.
