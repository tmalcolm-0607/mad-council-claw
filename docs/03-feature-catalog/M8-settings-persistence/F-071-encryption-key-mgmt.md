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
feature-id: F-071
short-slug: encryption-key-mgmt
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - foundational-plan:Message-11 (NEW — encrypted local storage requires key management)
    - kit:rules/stride-threat-model.md § Spoofing + § Elevation of Privilege
    - msft-learn:DPAPI (Windows Data Protection API)
    - msft-learn:macOS Keychain Services
    - msft-learn:libsecret (Linux Secret Service via D-Bus)
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
  LOCKED if GREEN AND reviews/F-071-encryption-key-mgmt-review.md exists with verdict: ACCEPT.
depends-on: [F-008]
out-of-scope-notes: |
  Hardware Security Module (HSM) backed keys are M19 deferred (F-D-005 identity-crypto).
  Cross-machine key sync (e.g. via Microsoft Account roaming, iCloud Keychain) is v1.5.
  Key rotation policy enforcement (rotate every N days) is v1.5; v1 supports manual rotation only.
  Recovery codes / printable backup phrase for key loss is v1.5.
  D-3 (encryption key source default = OS keychain DPAPI/Keychain/libsecret) is OPEN — see docs/10-backlog/design-decisions-pending.md.
confidence: high
---

# F-071 — Encryption key management

## Behavior contract

The engine sources the data-encryption key (consumed by F-070) from the host OS's native credential vault, with no plaintext key ever written to `<state-dir>/`. Per platform: **Windows** uses DPAPI (`CryptProtectData` / `CryptUnprotectData` scoped to `CRYPTPROTECT_LOCAL_MACHINE` for system-managed OR current user for per-user); **macOS** uses Keychain Services (`SecItemAdd` / `SecItemCopyMatching` with `kSecAttrAccessibleAfterFirstUnlock`); **Linux** uses libsecret via Secret Service D-Bus API (gnome-keyring / ksecretservice). The engine exposes an internal `IKeyProvider` interface with `getKey(keyId): Promise<Buffer>` + `rotateKey(): Promise<{ oldId, newId }>`. Key IDs are UUIDs persisted in `<state-dir>/key-index.json` (plaintext metadata only — IDs, creation timestamps, status). On first run, F-071 generates a random 256-bit key, stores it under the OS vault under collection `mad-council-claw`, and records the keyId in `key-index.json`. On platform mismatch (e.g. moving `<state-dir>` from Windows to macOS without F-072 export/import), reads MUST fail clearly with `KEY_PROVIDER_NOT_AVAILABLE` rather than silently regenerating a new key (which would orphan all existing encrypted data).

## Acceptance scenarios

1. **Given** a fresh install on Windows, **When** F-070 first writes `settings.json`, **Then** F-071 generates a 256-bit key + stores it via DPAPI under `CRYPTPROTECT_LOCAL_MACHINE` + writes the keyId to `<state-dir>/key-index.json` + the OS-vault entry is observable via `cmdkey` or equivalent CLI inspector.
2. **Given** an existing key in the OS vault + the user calling `engine keys rotate`, **When** rotation runs, **Then** a new key is generated + all existing encrypted files are re-encrypted with the new key + the old key is marked `status: rotated` in `key-index.json` + the old key remains in the OS vault for one rotation window before deletion.
3. **Given** a `<state-dir>` copied from Windows to a Linux machine without F-072 export/import, **When** the engine starts on Linux, **Then** F-071 reports `KEY_PROVIDER_NOT_AVAILABLE: keyId <id> not found in libsecret` + does NOT auto-generate a new key + surfaces a remediation hint pointing to F-072 import.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/keys/dpapi-store-recover.test.ts` | integration | RED — Windows-only | scenario 1 (Windows) |
| (TBD) `tests/integration/keys/key-rotation.test.ts` | integration | RED | scenario 2 (cross-platform) |
| (TBD) `tests/integration/keys/cross-platform-mismatch.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-008 (storage layout defines `<state-dir>/key-index.json` location)
- **Soft:** F-070 (consumes key API), F-072 (export/import for cross-machine moves)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., key-mgmt, ..." |
| foundational-plan:Message-11 | NEW — encrypted storage requires native key management |
| msft-learn:DPAPI | Windows credential-vault API contract |
| msft-learn:macOS Keychain Services | macOS credential-vault API contract |
| msft-learn:libsecret | Linux credential-vault API contract |
| kit:rules/stride-threat-model.md | Spoofing / Elevation-of-Privilege threats; OS vault is trust anchor |

## Implementation notes

(empty — populated when implementation begins)

## Open decisions

- **D-3** (encryption key source default = OS keychain DPAPI/Keychain/libsecret) — pending. See `docs/10-backlog/design-decisions-pending.md`. This ledger assumes the OS-keychain default; if D-3 closes otherwise (e.g. user-provided passphrase as fallback), the IKeyProvider interface is extended without breaking the contract.
