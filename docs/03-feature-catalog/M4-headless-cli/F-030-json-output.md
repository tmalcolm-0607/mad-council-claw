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
feature-id: F-030
short-slug: json-output
milestone: M4
provenance:
  surfaces:
    - foundational-plan:V:8
    - kit:rules/verification-protocol.md (ACTUAL BEFORE PRESENT)
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
  LOCKED if GREEN AND reviews/F-030-json-output-review.md exists with verdict: ACCEPT.
depends-on: [F-029]
out-of-scope-notes: |
  Streaming NDJSON for very-long outputs (e.g., audit query >10k entries) is supported
  in v1 (one record per line). Pretty-printed JSON (`--pretty`) is v1.5.
  YAML or TOML output is out of scope; JSON is the only structured format in v1.
confidence: high
---

# F-030 — JSON output

## Behavior contract

Every CLI subcommand (per F-029) supports two output modes: `--format text` (default; human-readable plain UTF-8) and `--format json` (machine-readable). When `--format json` is passed, stdout MUST be a single JSON document for query/single-record subcommands, OR newline-delimited JSON (NDJSON, one record per line) for streaming subcommands (`audit query`, `cron fires`, `run list`). Stderr is reserved for diagnostics — error envelopes go to stdout in JSON mode (with `{"error": {...}, "exit_code": N}`), so callers can parse them. Exit codes follow sysexits.h conventions consistently across both modes. JSON output never embeds ANSI color codes, never embeds shell-formatting characters, and never silently truncates — large outputs MUST be streamed (NDJSON) rather than buffered.

## Acceptance scenarios

1. **Given** `mad-council run status <run_id> --format json`, **When** the run exists, **Then** stdout is a single valid JSON object containing at least `{run_id, lifecycle, cycle_count, last_audit_entry_sha256}` + a trailing newline + exit 0.
2. **Given** `mad-council audit query --run <run_id> --format json` against a run with 50,000 audit entries, **When** the command runs, **Then** stdout is NDJSON (one JSON object per line, each parseable independently) + memory usage stays bounded (<200MB) + the stream completes without truncation.
3. **Given** `mad-council run halt <invalid-id> --format json`, **When** the run does not exist, **Then** stdout is `{"error": {"code": "RUN_NOT_FOUND", "message": "..."}, "exit_code": 65}` + exit code 65 (EX_DATAERR) + stderr empty.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cli/json-format-status.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/cli/json-ndjson-streaming.test.ts` | integration | RED — needs 50k-entry fixture | scenario 2 |
| (TBD) `tests/unit/cli/json-error-envelope.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-029 (subcommand surface that outputs)
- **Soft:** F-016 (audit query streaming source for NDJSON), F-013 (event-normalization shape if events are surfaced to CLI)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:V:8 | Machine-readable output for external orchestrators consuming the CLI |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — JSON output is the verifiable form |

## Implementation notes

(empty — populated when implementation begins)
