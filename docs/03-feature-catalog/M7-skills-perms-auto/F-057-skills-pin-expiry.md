---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-057
short-slug: skills-pin-expiry
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/permissions-calendar.ts
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/_status-convention.md
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
  LOCKED if GREEN AND reviews/F-057-skills-pin-expiry-review.md exists with verdict: ACCEPT.
depends-on: [F-055, F-056]
out-of-scope-notes: |
  Allowlist that holds the expiry field is F-055; sha256 pin is F-056.
  Notification UI on imminent expiry is M5 / F-042 (notifications).
  Auto-renew of pins via remote registry is OUT OF SCOPE for v1.
  Audit-log entries on expiry-triggered rejection are written to F-015 (hash-audit) by reference.
confidence: high
---

# F-057 — Skills pin expiry

## Behavior contract

An allowlist entry may carry an `expires_utc: string (ISO-8601)` field alongside `sha256_pin`. The loader checks the current UTC time at registration and at each new run start; entries whose expiry is in the past are rejected with `SKILL_PIN_EXPIRED` and the rejection event records `{ name, expired_at_utc, current_utc, days_overdue }`. An entry within 7 days of expiry is registered normally but emits a structured warning `{ event: "SKILL_PIN_EXPIRY_WARNING", days_remaining: N }` at engine start AND once per session start. Expiry is a fail-closed mechanism (expired pin = excluded skill, not "warn and proceed") per `dangerous-operations-policy.md` rule 7.

## Acceptance scenarios

1. **Given** an allowlist entry with `expires_utc: "2026-01-01T00:00:00Z"` and current UTC `2026-05-06T...`, **When** the engine registers, **Then** the skill is rejected with `SKILL_PIN_EXPIRED` AND the rejection log records `days_overdue: 125`.
2. **Given** an entry expiring in 5 days, **When** the engine starts a new session, **Then** the skill is registered AND a warning `SKILL_PIN_EXPIRY_WARNING` is emitted with `days_remaining: 5` exactly once per session start.
3. **Given** an entry expiring in 30 days, **When** the engine starts, **Then** the skill is registered with no warning emitted (above the 7-day threshold).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/skills/pin-expiry-rejection.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/skills/pin-expiry-warning-7-days.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/skills/pin-expiry-no-warning-far-future.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-055 (allowlist holds the `expires_utc` field), F-056 (pin without expiry is allowed; expiry without pin is rejected with a config-error)
- **Soft:** F-042 (M5 notifications surface the expiry-warning to the user), F-015 (hash-audit logs the rejection)
- **Independent:** F-058..F-066

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "expiry" is item 7 of the M7 catalog list |
| cp:electron/permissions-calendar.ts | Reference pattern for calendar-aware policy entries (perms have an analogous expiry concept) |
| kit:rules/dangerous-operations-policy.md | Fail-closed on expiry — never "warn and proceed" |
| kit:rules/_status-convention.md | Status-versioned-with-expiry pattern — preview rules carry `promote_by`, this carries `expires_utc` |

## Implementation notes

(empty — populated when implementation begins)
