---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-037
short-slug: system-message
milestone: M5
provenance:
  surfaces:
    - cp:src/features/chat/
    - kit:rules/canonical-skill-only.md (system message as canonical input)
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-037-system-message-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-036]
out-of-scope-notes: |
  Templating / variable interpolation in the system message (e.g., {{date}} substitution)
  is v1.5. v1 is plain text only.
  Per-cycle dynamic system message updates (changing mid-run) are out of scope for v1.
confidence: high
---

# F-037 — System message

## Behavior contract

A run's system message is the top-of-context prompt that frames the agent's behavior. It is composed at run-start from: (a) the selected personality preset's bundled text (per F-036) + (b) any per-run override the operator typed in the new-run dialog's "additional instructions" field. The composed system message is persisted to the run config + emitted as the first audit entry's `system_message_sha256`. After run start the system message is IMMUTABLE — no UI affordance exists to modify it mid-run, and any IPC call attempting to do so is rejected. The desktop renders the active system message in the info panel (per F-034) as a read-only collapsible section.

## Acceptance scenarios

1. **Given** the user selecting personality "code-focused" + adding "Focus on TypeScript only" in the override field, **When** the run starts, **Then** the composed system message contains both segments (preset + override) + the run config persists the composed text + `system_message_sha256` matches.
2. **Given** an active run, **When** the desktop attempts to send an IPC call to update the system message, **Then** the call is rejected with `SYSTEM_MESSAGE_IMMUTABLE` + the run's audit log records the rejection attempt as a tamper signal.
3. **Given** a closed run + the info panel open, **When** the user expands the system message section, **Then** the full composed text is shown read-only + the panel labels both the personality-preset portion and the override portion (visual diff against bundled preset).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/desktop/system-message-compose.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/desktop/system-message-immutable.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/browser/desktop/system-message-display.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window), F-036 (personality preset bundled text)
- **Soft:** F-001 (run config carries system message), F-015 (audit-log first entry stores sha256), F-034 (info panel display)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/features/chat/ | New-run dialog + override field shape |
| kit:rules/canonical-skill-only.md | System message is canonical input — immutable post-start |

## Implementation notes

(empty — populated when implementation begins)
