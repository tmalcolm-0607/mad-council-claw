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
feature-id: F-072
short-slug: encrypted-import-export
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - foundational-plan:Message-11 (NEW — encrypted storage cross-machine portability)
    - kit:rules/dangerous-operations-policy.md (consent gate on key export)
    - kit:rules/stride-threat-model.md § Information Disclosure
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
  LOCKED if GREEN AND reviews/F-072-encrypted-import-export-review.md exists with verdict: ACCEPT.
depends-on: [F-070, F-071]
out-of-scope-notes: |
  Selective export (export only specific runs, only settings, etc.) is v1.5; v1 exports the entire <state-dir>.
  Streaming / chunked export for large state dirs (>1 GB) is v1.5; v1 produces a single archive file.
  Cloud-storage upload of the export bundle is v1.5; v1 writes to a local file path the user picks.
  Automatic scheduled exports (backup-on-cron) is v1.5.
  Import from a non-MAD-Council source (e.g. clawpilot settings.json) is M19 deferred (F-D-004 schema migration).
confidence: high
---

# F-072 — Encrypted import/export

## Behavior contract

The engine produces a portable bundle (`<state-dir>.mcc-bundle`) that wraps the encrypted state from `<state-dir>/` plus a wrapped data-encryption key, suitable for moving across machines or operating systems. The bundle is itself encrypted under a passphrase the user supplies at export time (passphrase derives a wrapping key via Argon2id with parameters `t=3, m=64MB, p=4`). The bundle file format is `{ "v": 1, "kdf": "argon2id", "kdf_params": {...}, "wrapped_key": "<base64>", "state_archive": "<base64-tar.gz>" }`. Export is a Dangerous Operation per `kit:rules/dangerous-operations-policy.md`: the user MUST confirm + the passphrase prompt requires explicit re-entry to confirm. Import takes the bundle file + passphrase, derives the wrapping key, unwraps the data key, restores the data key into the local OS vault (per F-071), and unpacks the state archive into `<state-dir>/`. Import refuses if `<state-dir>/` is non-empty (require explicit `--overwrite` flag + a second consent gate).

## Acceptance scenarios

1. **Given** an active install with encrypted state, **When** the user runs `engine settings export --output backup.mcc-bundle` and supplies a passphrase, **Then** a consent dialog appears showing the export scope + on confirmation a `backup.mcc-bundle` file is produced + the passphrase is NEVER persisted to disk + the bundle is unreadable without the passphrase.
2. **Given** a `backup.mcc-bundle` file + the correct passphrase, **When** the user runs `engine settings import backup.mcc-bundle` on a different machine with an empty `<state-dir>/`, **Then** the data key is restored to the local OS vault (per F-071) + the encrypted state is unpacked to `<state-dir>/` + a subsequent F-070 read returns the original `settings.json` content.
3. **Given** a `backup.mcc-bundle` file + a wrong passphrase, **When** the user runs `engine settings import backup.mcc-bundle`, **Then** the import fails with `IMPORT_AUTHENTICATION_FAILED` after Argon2id verification + no partial state is written + no key is added to the OS vault.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/import-export/export-bundle-shape.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/import-export/round-trip-cross-platform.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/import-export/import-wrong-passphrase.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-070 (encrypted state files are export targets), F-071 (data key is wrapped during export, restored on import)
- **Soft:** F-068 (Settings UI may surface Export/Import buttons), F-008 (storage layout defines what's in `<state-dir>/`)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., encrypted import/export, ..." |
| foundational-plan:Message-11 | NEW — encrypted-storage cross-machine portability requirement |
| kit:rules/dangerous-operations-policy.md | Export-as-destructive-class; passphrase double-entry pattern |
| kit:rules/stride-threat-model.md | Info-Disclosure threat coverage; passphrase-strength enforcement |

## Implementation notes

(empty — populated when implementation begins)
