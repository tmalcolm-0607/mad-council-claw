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
feature-id: F-056
short-slug: skills-version-pinning
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - ce:US-6
    - cp:electron/skills.ts
    - cp:common/skill-sanitization.ts
    - kit:rules/concurrency-safety.md
    - kit:rules/verification-protocol.md
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
  LOCKED if GREEN AND reviews/F-056-skills-version-pinning-review.md exists with verdict: ACCEPT.
depends-on: [F-051, F-055]
out-of-scope-notes: |
  Allowlist where pins live is F-055.
  Pin-expiry semantics are F-057.
  Skills format itself is F-051.
  Marketplace upgrade flows (notify on new version available) are M18.
  Cryptographic signing of skill bundles (PGP / sigstore) is OUT OF SCOPE for v1; sha256 of canonicalized SKILL.md + reference files is the pin substrate.
  Multiple-pinned-versions-side-by-side support (e.g., two versions of the same skill name) is v1.5.
confidence: high
---

# F-056 — Skills version pinning (sha256)

## Behavior contract

An allowlist entry may carry a `sha256_pin: string` field. When present, the loader computes the canonical sha256 over the skill's content set (SKILL.md + every `references:` file in the SKILL.md frontmatter, sorted by path, separated by `0x00`-byte) and matches against the pin. A pin mismatch causes the skill to be rejected with `SKILL_PIN_MISMATCH` and excluded from the active registry. The mismatch event records `{ name, expected_sha256, actual_sha256, files_hashed: string[] }` so an operator can diff the change. Pin computation is deterministic and reproducible; the same skill content produces the same pin on Windows + macOS + Linux (forward-slash path normalization applied). Per canonical-e US-6, pinning is the mechanism that makes "allowlist + pinning" a reproducible-build-class guarantee.

## Acceptance scenarios

1. **Given** an allowlist entry `{ name: "loop", source: "bundled", sha256_pin: "abc123..." }` AND the bundled `loop/SKILL.md` content matches the pin, **When** the engine registers, **Then** `loop` is active and the registration log records `pin_status: "matched"`.
2. **Given** the same allowlist entry AND someone has edited `bundled-skills/loop/SKILL.md` post-install (sha now differs), **When** the engine starts, **Then** `loop` is rejected with `SKILL_PIN_MISMATCH` and the rejection record includes both the expected and actual sha256.
3. **Given** the same skill content is hashed on Windows (CRLF normalized to LF for hashing) and Linux, **When** both compute the canonical sha, **Then** the resulting sha is bit-identical (cross-platform reproducibility).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/skills/pin-match-success.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/skills/pin-mismatch-rejection.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/skills/pin-computation-cross-platform.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-051 (SKILL.md format defines what gets hashed), F-055 (allowlist entry holds the pin)
- **Soft:** F-057 (a pinned entry may also carry an expiry), F-052 (bundled installation is the most common pin subject)
- **Independent:** F-058..F-066

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "version-pin" is item 6 of the M7 catalog list |
| ce:US-6 | Canonical-e user story for "allowlist + pinning" — sha256 is the pin substrate |
| cp:electron/skills.ts | Loader is the natural pin-check site at registration time |
| cp:common/skill-sanitization.ts | Sanitization computes a deterministic content hash already; pin reuses the same canonicalization |
| kit:rules/concurrency-safety.md | Pin write/read is atomic per the file-write discipline |
| kit:rules/verification-protocol.md | Pin is a "verify-before-trust" — canonical-e calls this reproducible build for skills |

## Implementation notes

(empty — populated when implementation begins)
