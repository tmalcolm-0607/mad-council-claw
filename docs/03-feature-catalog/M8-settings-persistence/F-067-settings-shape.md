---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-d)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-004 / lane-d
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-067
short-slug: settings-shape
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - cp:settings-shape (clawpilot settings.json layout)
    - kit:rules/concurrency-safety.md (atomic write)
    - kit:rules/single-owner-accountability.md (owner_alias on settings)
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
  LOCKED if GREEN AND reviews/F-067-settings-shape-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008]
out-of-scope-notes: |
  Cloud-synced settings (sync to OneDrive / Settings backup service) is v1.5; v1 is local-file-only.
  Settings UI is F-068 (separate feature).
  Per-automation rule shape is F-069 (composes into F-067 surface).
  Encrypted at-rest storage is F-070 (wraps F-067 read/write paths).
  Project-scoped overrides land in F-073 (workspace) — F-067 is the global shape.
  Schema migration / version bumps across releases is M19 deferred (F-D-004).
confidence: high
---

# F-067 — Settings shape

## Behavior contract

The engine persists user preferences in a single canonical JSON file at `<state-dir>/settings.json` (Windows: `%APPDATA%/mad-council-claw/settings.json`; macOS: `~/Library/Application Support/mad-council-claw/settings.json`; Linux: `~/.config/mad-council-claw/settings.json`). The shape is a versioned object: `{ "version": 1, "model": ..., "personality": ..., "system_prompts": ..., "mcp_servers": ..., "permissions": ..., "theme": ..., "telemetry": ..., "automation_rules": ... }`. Reads MUST tolerate missing keys (default-fill); writes MUST be atomic (write-temp-then-rename per `kit:rules/concurrency-safety.md` §2). Unknown top-level keys are preserved across read-modify-write cycles (forward-compatible). Schema validated against `schemas/settings.schema.json` on every load; validation failure surfaces a structured error rather than silently overwriting.

## Acceptance scenarios

1. **Given** a fresh install with no `settings.json`, **When** the engine first loads settings, **Then** a default settings object is returned in memory + a default `settings.json` is written atomically + `version: 1` is set.
2. **Given** a `settings.json` containing a future-version key (`"experimental_foo": true`), **When** the engine reads, modifies the `theme` field, and writes back, **Then** the `experimental_foo` key is preserved verbatim in the output file.
3. **Given** two concurrent writes (A writes `theme=dark`, B writes `model=opus`), **When** both complete, **Then** the resulting `settings.json` is valid JSON + contains exactly one of the two writes (last-writer-wins is acceptable; corruption is not).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/settings/settings-shape-defaults.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/settings/settings-shape-forward-compat.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/settings/settings-concurrent-write.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel hosts settings reader/writer), F-008 (storage layout defines `<state-dir>` path)
- **Soft:** F-068 (UI consumes the shape), F-069 (automation rules compose into the shape), F-073 (project workspace overlay reads global as base)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "shape, UI, per-automation rules, ..." |
| cp:settings-shape | Clawpilot settings.json layout pattern (model/personality/prompts/MCP/perms/theme) |
| kit:rules/concurrency-safety.md | Atomic-write discipline (write-temp-then-rename) |
| kit:rules/single-owner-accountability.md | Pattern: settings.json carries an explicit `owner_alias`/profile owner |

## Implementation notes

(empty — populated when implementation begins)
