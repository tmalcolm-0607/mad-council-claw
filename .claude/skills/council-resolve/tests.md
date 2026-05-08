# Tests: /council-resolve

Thin wrapper over /council-post. Maps to 6-layer harness.

## Layer 1 — Unit

| Test ID | Scenario | Expected |
|---|---|---|
| T1-01 | Parse `/council-resolve ch tid` (no summary) | default summary populated |
| T1-02 | Parse with summary | summary captured |
| T1-03 | T-ID extraction: `"done [T001] [T002]"` | list=[T001, T002] |
| T1-04 | T-ID extraction: no matches | empty list |
| T1-05 | T-ID extraction across messages | dedupe |
| T1-06 | tasks.md checkbox update pattern `[ ] [T001]` → `[x] [T001]` | correct |

## Layer 2 — Integration

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | Happy path default summary on active thread | resolved; archive timer set; `rc=0` |
| T2-02 | Summary with T-IDs on MAD channel | tasks.md updated; `rc=0` |
| T2-03 | Summary with T-IDs on non-MAD channel | tasks.md not touched; `rc=0` |
| T2-04 | Already-resolved thread | `rc=2` |
| T2-05 | Archived thread | `rc=2` |
| T2-06 | Non-member caller | `rc=3` (via /council-post) |
| T2-07 | tasks.md update fails (FS error) | `rc=1`; resolve succeeded |
| T2-08 | /council-post fails | `rc=4` propagates |
| T2-09 | Summary contains Rule-1 phrase | /council-post flags suspicious; resolve still succeeds |

## Layer 3 — E2E + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | Two agents concurrent resolve same thread | last-write-wins on thread.json; both resolves post; harmless duplication |
| T3-02 | Kill process between post + tasks.md update | tasks.md not updated; next resolve or manual edit fixes |

## Layer 4 — Adversarial

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | Summary contains `[T999]` referencing nonexistent task | helper doesn't find matching checkbox; no-op; note in output |
| T4-02 | Summary path-traversal in channel name | `/council-post` catches via its own validation |

## Fixture requirements

Under `evals/fixtures/council-resolve/`:

| Fixture | Purpose |
|---|---|
| `active-thread-mad/` | thread in MAD-enabled channel with task-IDs in messages |
| `active-thread-non-mad/` | non-MAD channel |
| `already-resolved/` | `rc=2` test |
| `archived/` | `rc=2` test |
| `task-ids-in-thread/` | extraction test |
| `task-ids-not-in-tasks-md/` | graceful no-op |

## Coverage: 95%+ branch. All rc codes reachable.

## Metrics

- `invoke_skill council-resolve` span with rc, run_id, mad_tasks_updated_count.
- `council_resolve.invocations_total` counter.
- `council_resolve.mad_task_updates_total` counter.

## Related
- `SKILL.md` + `plan.md`.
- `skills/council-post/tests.md` — delegated-to.
