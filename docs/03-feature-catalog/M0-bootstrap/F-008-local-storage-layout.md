---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b); LOCKED flip wave-012 / lane-d
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: red
    at: 2026-05-07
    by: wave-010 / lane-d
    note: "RED test landed at tests/node/F-008-local-storage-layout.test.ts — 6 acceptance scenarios fail with TypeError: getStorageLayout is not a function. Baseline at docs/09-examples-proof/F-008/red-test-output.txt."
  - status: green
    at: 2026-05-07
    by: wave-010 / lane-d
    note: "Impl landed at packages/engine-core/src/index.ts (F-008 region ~150 LOC): StorageLayout interface + getStorageLayout / ensureStorageLayout / atomicWriteJson / readJson. 6/6 acceptance scenarios pass; full unit suite 39/39 GREEN-feature tests still passing (F-001/F-002/F-006/F-014/F-015/F-016/F-018). GREEN proof at docs/09-examples-proof/F-008/green-test-output.txt."
  - status: locked
    at: 2026-05-07
    by: wave-012 / lane-d
    note: "Council review verdict ACCEPT (Verdict consensus: APPROVE; median confidence 88; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE) at docs/05-design-reviews/council-reviews/F-008-local-storage-layout-review.md. red-green-rule predicate satisfied: GREEN AND review file with verdict ACCEPT. MINOR findings are honest scope-narrowing notes per no-silent-deferrals.md (per-run subdirectory creation follow-on; .tmp orphan sweep; concurrent-writer race harness; encrypted-at-rest M8 scope). Source post-wave-011/lane-a engine-core split lives at packages/engine-core/src/storage.ts (119 LOC). 6/6 acceptance scenarios continue to PASS unchanged. Fourth LOCKED transition in the repo (sibling with F-002 + F-006 in wave-012 / lane-d)."
feature-id: F-008
short-slug: local-storage-layout
milestone: M0
provenance:
  surfaces:
    - cp:userData layout
    - ce:FR-AUDIT-001
    - kit:rules/concurrency-safety.md
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-008-local-storage-layout.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-008-local-storage-layout-review.md exists with verdict: ACCEPT.
depends-on: []
out-of-scope-notes: |
  Encrypted-at-rest storage of secrets/keys is owned by M8 (F-070 encrypted-storage,
  F-071 key-mgmt). This feature defines the on-disk directory layout + atomic-write
  helpers; it does not perform encryption.
confidence: high
---

# F-008 — Local storage layout

## Behavior contract

The engine writes all persistent state under a single `userData/mad-council-claw/` root. Subdirectories: `runs/<run_id>/` (per-run audit log + cost ledger + manifest), `skills/` (allowlist + pinned bundles), `verdicts/` (manual + automated verdicts), `kill-switch.json` (read-time-propagating halt), `automations/` (cron + condition + multistep state). Every mutable JSON file is written atomically via the write-temp-then-rename pattern from `concurrency-safety.md` §2; readers never observe a half-written file. The layout is documented in `RUNBOOK.md`.

## Acceptance scenarios

1. **Given** a fresh engine boot with `run_id=R1`, **When** the engine writes the first audit entry, **Then** the path `userData/mad-council-claw/runs/R1/audit.ndjson` exists and contains exactly one line.
2. **Given** a write of `verdicts/manual-2026-05-07.json`, **When** the writer is interrupted between temp-write and rename, **Then** no readable file exists at the target path (only the `.tmp` orphan, swept on next boot per `concurrency-safety.md` §Edge cases).
3. **Given** two concurrent writes to `kill-switch.json`, **When** both complete, **Then** the final file content equals one of the two inputs (last-write-wins) and the file always parses as valid JSON.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-008-local-storage-layout.test.ts` | node | GREEN (wave-010 / lane-d) | All 6 acceptance scenarios — layout-shape, idempotent dir creation, JSON round-trip, .tmp orphan suppression, prior-content replacement, default-root path-shape |

## Dependencies

- **Hard:** none (foundational)
- **Soft:** F-001 (engine consumes this layout), F-006 (logger writes here)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:userData layout | clawpilot Electron `app.getPath('userData')` pattern |
| ce:FR-AUDIT-001 | hash-chained audit log lives at `runs/<run_id>/audit.ndjson` |
| kit:rules/concurrency-safety.md | atomic write-temp-then-rename pattern |

## Implementation notes

Wave-010 / Lane D landed the GREEN flip. Surface delivered:

- `StorageLayout` interface — `{root, sessions, skills, automations, audit, settingsFile}`.
- `getStorageLayout(rootOverride?)` — pure path computation; defaults to `~/.mad-council-claw`.
- `ensureStorageLayout(layout)` — idempotent `mkdirSync(..., { recursive: true })` over the four subdirs + root.
- `atomicWriteJson(path, content)` — write-temp-then-rename per kit's `concurrency-safety.md` §2.
- `readJson<T>(path)` — typed JSON read helper.

Brief-vs-ledger scope reconciliation: the wave-002 / lane-b ledger contract describes a richer subdirectory tree (`runs/<run_id>/`, `verdicts/`, `kill-switch.json`). Lane D's wave-010 brief scoped the flip to the static layout primitives (`sessions / skills / automations / audit + settingsFile`) — the per-run subdirectory creation lands in F-001 / F-008 integration; the kill-switch and verdicts directories land alongside their feature flips (F-020 kill-switch, F-022 + governance triad). Per `rules/no-silent-deferrals.md`: surfaced explicitly in this notes block + the wave-010 lane-d summary's confidence ledger entry rather than silently expanding the brief.

Out-of-scope (carried forward from §out-of-scope-notes; tracked for follow-on flips):
- Encrypted-at-rest storage of secrets/keys (M8 / F-070-F-071).
- Sweep of orphaned `<path>.tmp` files on startup (`concurrency-safety.md` §Edge cases).
- Concurrent writer race testing harness (last-write-wins is the §4 guarantee for digest.json-class files; the atomic helper itself is the building block, not the harness).
- Per-run `runs/<run_id>/` subdirectory creation — F-001/F-008 integration flip.
