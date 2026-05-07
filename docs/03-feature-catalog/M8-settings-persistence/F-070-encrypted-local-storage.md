---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-d)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-004 / lane-d
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet — surface is NEW per user Message 11"
feature-id: F-070
short-slug: encrypted-local-storage
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - foundational-plan:Message-11 (NEW — "Bring-your-own MCP + encrypted local storage")
    - kit:rules/concurrency-safety.md (atomic write under encryption envelope)
    - kit:rules/stride-threat-model.md § Tampering + § Information Disclosure
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
  LOCKED if GREEN AND reviews/F-070-encrypted-local-storage-review.md exists with verdict: ACCEPT.
depends-on: [F-008, F-067, F-071]
out-of-scope-notes: |
  Encryption key management is F-071 (separate feature) — F-070 consumes the F-071 key API.
  Encrypted import/export across machines is F-072 (separate feature).
  Cloud-side at-rest encryption (Azure Key Vault, AWS KMS) is M19 deferred (F-D-005 identity-crypto).
  Per-field encryption (encrypt only secrets, leave non-sensitive plaintext) is v1.5; v1 encrypts the full file.
  D-5 (BYOK vs system-managed default for v1) is OPEN — see docs/10-backlog/design-decisions-pending.md.
confidence: high
---

# F-070 — Encrypted local storage

> **NEW per user Message 11** ("Bring-your-own MCP + encrypted local storage"). No clawpilot or canonical-e source surface — this is an emergent v1 requirement.

## Behavior contract

The engine encrypts at-rest the sensitive files under `<state-dir>/`: `settings.json` (per F-067), `<state-dir>/audit/*.jsonl` (per F-015), `<state-dir>/runs/*.json` (per F-008), `<state-dir>/personalities/custom-*.json`, and any file matching `<state-dir>/secrets/**`. Plaintext files (e.g. `<state-dir>/desktop/window-state.json` per F-032, `roadmap.md` cache) are NOT encrypted. Encryption uses authenticated encryption (AES-256-GCM) with the data key sourced from F-071 (key management). Reads transparently decrypt; writes wrap the atomic write (per `kit:rules/concurrency-safety.md` §2) — the encrypted bytes are written to `<file>.tmp` + renamed. Decryption failure is a hard error (per `kit:rules/stride-threat-model.md` § Tampering): no silent fallback to plaintext, no auto-rewrite. The encryption envelope carries `{ "v": 1, "alg": "AES-256-GCM", "key_id": "<id>", "nonce": "<base64>", "ciphertext": "<base64>", "tag": "<base64>" }` so future-version migration is greppable.

## Acceptance scenarios

1. **Given** a fresh install + the user writing `settings.json:theme = dark`, **When** the file is persisted, **Then** the on-disk bytes are NOT readable as JSON (encryption envelope present) + a subsequent read by the engine returns `theme: dark` (transparent decrypt).
2. **Given** an existing `settings.json` written by F-070, **When** the file is tampered (1 byte flipped in ciphertext via external tool), **Then** the next read fails with `DECRYPT_AUTHENTICATION_FAILED` + the engine surfaces a structured error + does NOT silently fall back to plaintext.
3. **Given** an existing plaintext `settings.json` from a pre-F-070 build, **When** the engine first runs with F-070 enabled, **Then** the engine reads the plaintext + re-writes it encrypted on first save + a one-time migration audit entry is appended to `<state-dir>/audit/migrations.jsonl`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/storage/encryption-envelope.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/storage/decrypt-tamper-fail.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/storage/plaintext-migration.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-008 (storage layout defines which paths are sensitive), F-067 (settings.json is encryption target), F-071 (key API)
- **Soft:** F-015 (hash-audit chain integrity preserved across encrypted JSONL — encryption-of-line not file)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., encrypted storage, ..." |
| foundational-plan:Message-11 | NEW user requirement — encrypted local storage as v1 must-have |
| kit:rules/concurrency-safety.md | Atomic-write integration with encryption envelope |
| kit:rules/stride-threat-model.md | Tampering / Info-Disclosure threat coverage; decrypt-fail is hard-fail |

## Implementation notes

(empty — populated when implementation begins)

## Open decisions

- **D-5** (BYOK vs system-managed default for v1) — pending. See `docs/10-backlog/design-decisions-pending.md`. Default in this ledger assumes system-managed (OS keychain via F-071) unless D-5 closes otherwise.
