# Recovery Protocol

Named recoveries for common session-health failures.

| Symptom | Recovery |
|---------|----------|
| API 400 "concurrent tool_use blocks" | Type `/rewind` to revert last message |
| Tool use stuck / not completing | `/rewind` then retry |
| Post-compaction state corruption | See `rules/context-guardian.md` |
| Usage limit hit | Wait for reset; reduce `session_duration_hours` |
| Session hitting context HALT threshold (85%) | Run `hooks/pre-compact.js` handoff writer; reopen with `/resume-handoff` |
| Subagent truncated at 32K tokens | Instruct agent to split response into ≤30K segments; re-invoke |
| Hook fails-open unexpectedly | See `hooks/hook-fail-open-policy.md` |

## Resume after disconnect / compaction

1. Check `work-items/ACTIVE` — it points to the active work-item ID.
2. Check the WI directory for `PENDING_HANDOFF` — if present, invoke `/resume-handoff`.
3. Read `plan.md` for the active feature; locate last `[x]` checkbox.
4. Check for `[!]` markers (blockers) in `tasks.md`.
5. Continue from the first unchecked task.

See `rules/resume-protocol.md` for the full step-by-step.

## Context-budget Guardian

See `rules/context-guardian.md`.

- ADVISORY at 50% — warn in status line
- PREPARE at 70% — write handoff, shed non-essential context
- HALT at 85% — auto-write `PENDING_HANDOFF` and stop

Configurable via `CONTEXT_GUARDIAN_*` env vars.
