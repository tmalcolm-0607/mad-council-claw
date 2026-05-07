---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-119
short-slug: local-skill-marketplace
milestone: M18
provenance:
  surfaces:
    - kit:foundational-plan.md M18 row + Message 11 marketplace ask
    - kit:rules/no-silent-deferrals.md
    - kit:rules/dangerous-operations-policy.md
    - kit:.claude/skills/* (kit's bundled-skill substrate the marketplace exposes)
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
  LOCKED if GREEN AND reviews/F-119-local-skill-marketplace-review.md exists with verdict: ACCEPT.
depends-on: [F-008, F-051, F-052, F-053, F-074]
out-of-scope-notes: |
  Cloud-hosted marketplace (registry server, account auth, paid skills) is OUT for v1 — tracked
  as F-D-001 in the M19 deferred catalog. v1 is a LOCAL marketplace: the user's filesystem is
  the registry; the "store" is a directory of SKILL.md bundles the user has placed (manually or
  via export from another workspace) under a known path. Skill votes / reviews / download
  counters are OUT (F-D-002). Ring-based distribution (alpha/beta/stable channels) is OUT
  (F-D-003). v1 marketplace is install-from-disk + browse-installed — no network calls.
confidence: high
---

# F-119 — Local skill marketplace

## Behavior contract

The engine MUST expose a **local skill marketplace** that lets the user install skills from a filesystem path and browse the set of skills currently installed in the active F-074 project workspace. "Marketplace" in v1 means a directory under `<workspace>/skills-registry/` holding SKILL.md bundles the user has placed there (by manual copy, by `export-skill` from another workspace, or by clone of a kit-shipped bundle). The marketplace surface offers three operations: (1) **list-installed** — enumerate every skill currently active in the workspace per F-051..F-053; (2) **install-from-path** — copy a SKILL.md bundle from a user-supplied filesystem path into the workspace's skill set, validating the bundle's frontmatter against the F-051 contract before activation; (3) **uninstall** — remove a previously installed skill from the active set without deleting the source bundle. No network calls. No accounts. No remote registry. The marketplace is the local skill plane made navigable.

## Acceptance scenarios

1. **Given** workspace W has 3 skills active (per F-052 toggle) and 2 bundled SKILL.md directories on disk under `<workspace>/skills-registry/`, **When** the user invokes the marketplace's list-installed operation, **Then** the response enumerates exactly the 3 active skills with their name, version, and source-path; the 2 disk-only bundles are listed separately as "available, not active" — the response is deterministic given the same workspace state.
2. **Given** a SKILL.md bundle at `~/Downloads/my-custom-skill/` with valid F-051 frontmatter (name, description, allowed-tools, version), **When** the user invokes install-from-path on that directory, **Then** the bundle is copied into `<workspace>/skills-registry/my-custom-skill/`, registered per F-053 custom-load, and an INSTALL audit-chain entry is appended per F-015; the source `~/Downloads/my-custom-skill/` is unchanged.
3. **Given** a malformed bundle whose SKILL.md is missing required frontmatter (e.g. no `allowed-tools`), **When** install-from-path runs against it, **Then** the install rejects with `MARKETPLACE_INVALID_BUNDLE` citing the specific frontmatter violation per `rules/skill-standards.md` Dimension 1, the bundle is NOT copied into the workspace, and the user receives the validator output verbatim — no silent acceptance.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/marketplace/list-installed-shape.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/marketplace/install-from-path-roundtrip.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/marketplace/install-rejects-malformed-bundle.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-008 (storage layout determines `<workspace>/skills-registry/` path), F-051 (SKILL.md frontmatter contract is what install-from-path validates against), F-052 (toggle interface is the active-vs-installed boundary), F-053 (custom-load is what registers a newly installed skill), F-074 (workspace scopes the registry)
- **Soft:** F-015 (install/uninstall audit entries), F-054 (allowlist gates which skills the marketplace will offer to activate), F-055 (version-pin interacts with version field surfaced in list-installed)
- **Independent:** F-D-001 cloud marketplace — v1.5 successor; deferred catalog tracks the cloud-hosted variant explicitly

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M18 row + Message 11 | "Marketplace local-v1: F-119..F-121" + user's "local marketplace" answer in Message 11 |
| kit:rules/no-silent-deferrals.md | Cloud marketplace deferral is explicit (F-D-001 in M19 catalog), not silently dropped |
| kit:rules/dangerous-operations-policy.md | Install-from-path is a write to the workspace's skill set; consent + audit per the policy |
| kit:.claude/skills/* | Kit's bundled-skill substrate is the canonical example of "what an installable bundle looks like" |

## Implementation notes

(empty — populated when implementation begins; install-from-path's validator MUST run F-051 frontmatter checks before any filesystem write so a malformed bundle never lands partial-installed)
