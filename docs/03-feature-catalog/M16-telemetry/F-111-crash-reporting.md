---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-111
short-slug: crash-reporting
milestone: M16
provenance:
  surfaces:
    - cp:src/main/crash-reporter
    - cp:electron crashReporter API
    - kit:rules/degradation-fallback-policy.md
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/no-silent-deferrals.md
    - foundational-plan.md D-1 (default local; remote opt-in)
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
  LOCKED if GREEN AND reviews/F-111-crash-reporting-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-110, F-113]
out-of-scope-notes: |
  Remote crash upload (Sentry / Bugsnag / AppCenter / Crashpad-server) is OUT for
  v1 default; F-113 gates remote and ships with remote=off. Symbolication of
  native frames is OUT for v1 (raw stack only); v1.5 considers symbol-server
  integration. Auto-restart-on-crash is M5 desktop-shell concern, not telemetry.
  User-facing "send report?" dialog is OUT for v1 (telemetry-opt-in is single
  global setting via F-113; no per-crash prompt).
confidence: high
---

# F-111 — Crash reporting

## Behavior contract

The engine MUST capture renderer-process and main-process crashes via Electron's `crashReporter` API and persist crash dumps locally to `<userData>/telemetry/crashes/{crash-id}.dmp` plus an OTel-format crash-event record appended to F-110's JSONL sink. Crash records carry: `crash_id` (UUID), `timestamp_utc`, `process_type` (renderer|main|gpu|utility), `engine_version`, `os.platform`, `os.version`, `crash.signal` (if available), `crash.stack` (raw), `session_id` (last known per F-002), and `last_run_id` (per F-001). NO automatic remote upload occurs in default config — crash dumps stay local until the user opts into remote via F-113. On next launch after a crash, the engine MUST log a structured "previous-run-crashed" event to F-110's sink for forensic continuity. PII redaction (per F-018) runs on crash payloads before write. Per `rules/dangerous-operations-policy.md`, any future remote upload path requires explicit user consent (handled by F-113 opt-in flow).

## Acceptance scenarios

1. **Given** an engine running on macOS, **When** the renderer process is force-killed (SIGKILL via test harness) mid-run, **Then** on next launch `<userData>/telemetry/crashes/{uuid}.dmp` exists and a JSONL record with `signal_type: crash` appears in `otel-{date}.jsonl` carrying the crash_id, process_type=renderer, and the last known session_id; no network egress is observed.
2. **Given** a main-process crash with the engine's identity bootstrap incomplete (no session_id yet), **When** the crash record is written, **Then** the record carries `session_id: null` and a `crash.phase: pre-identity` marker, satisfying `rules/no-silent-deferrals.md` (the absence is named, not hidden).
3. **Given** a previous-run crash dump on disk and a fresh launch, **When** the engine boots, **Then** it emits a structured `previous-run-crashed` log at INFO level pointing to the dump's crash_id, and the dump is NOT auto-uploaded regardless of the OS's native crash-reporter prompts.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/e2e/telemetry/renderer-crash-captured.test.ts` | e2e | RED | scenario 1 |
| (TBD) `tests/unit/telemetry/crash-pre-identity-phase-marker.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/telemetry/previous-crash-on-boot.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel; lifecycle hooks for crash detection on next boot), F-008 (storage; crash dump directory), F-110 (OTel sink shared for crash records), F-113 (opt-in modes; remote upload gated)
- **Soft:** F-018 (PII redaction on stack traces), F-002 (session_id when available)
- **Independent:** F-112 (perf metrics; orthogonal to crash capture)

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/main/crash-reporter | clawpilot's crash-reporter wiring as a starting shape |
| cp:electron crashReporter API | Electron-native crash capture with minidump-style output on Windows / Linux, native CrashReporter on macOS |
| kit:rules/degradation-fallback-policy.md | crash records have explicit pre-identity phase marker — degraded state is named not silent |
| kit:rules/dangerous-operations-policy.md | remote upload of crash data requires explicit consent (handled via F-113 opt-in) |
| kit:rules/no-silent-deferrals.md | unknown session_id at crash time is recorded as `null` with phase marker, never elided |
| foundational-plan.md D-1 | default = local; remote crash upload is opt-in only |

## Implementation notes

(empty — populated when implementation begins)
