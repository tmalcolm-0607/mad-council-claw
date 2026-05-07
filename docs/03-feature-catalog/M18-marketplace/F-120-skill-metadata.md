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
feature-id: F-120
short-slug: skill-metadata
milestone: M18
provenance:
  surfaces:
    - kit:foundational-plan.md M18 row
    - kit:rules/skill-standards.md Dimension 1 (frontmatter integrity)
    - kit:rules/canonical-artifact-frontmatter.md
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
  LOCKED if GREEN AND reviews/F-120-skill-metadata-review.md exists with verdict: ACCEPT.
depends-on: [F-051, F-119]
out-of-scope-notes: |
  Skill votes / reviews / download counters are OUT for v1 — tracked as F-D-002 in the M19
  deferred catalog. Author identity verification (signed manifests, Entra-bound publisher
  IDs) is OUT — overlaps with F-D-006 / F-D-007 deferred identity items. Skill compatibility
  matrix (engine-version ranges, OS-specific bundles) is post-v1; v1 metadata records the
  authored engine-version but does not enforce a range. Localization of metadata strings
  (description, README) is OUT and overlaps with F-D-014 i18n deferred.
confidence: high
---

# F-120 — Skill metadata

## Behavior contract

Every installable skill bundle MUST carry a **metadata block** that the marketplace surfaces to the user when listing or browsing. The metadata extends the F-051 SKILL.md frontmatter contract with marketplace-display fields: `name` (required, kebab-case), `description` (required, ≤200 chars per skill-standards.md Dimension 1), `version` (required, semver), `author` (required, free-text or Entra-handle string — no verification in v1), `tags` (optional, list of free-text labels for search), `homepage` (optional, URL), `license` (optional, SPDX identifier or free-text), `engine-min-version` (optional, semver — informational only in v1), and `installed-at` (set by F-119 install-from-path; ISO-8601 UTC). The metadata is queryable as a structured object: F-119's list-installed and F-121's search/browse UI both consume it. Reading metadata is a pure function of SKILL.md frontmatter — no derived state, no network call.

## Acceptance scenarios

1. **Given** a SKILL.md with frontmatter `name: my-skill`, `description: helpful tools`, `version: 1.2.0`, `author: Tony Malcolm`, `tags: [productivity, llm]`, **When** the metadata reader parses it, **Then** the returned object contains exactly those five fields plus the (absent) optional fields explicitly set to `null`/`undefined`; no defaults invented per `rules/no-invented-constraints.md`.
2. **Given** a SKILL.md missing the required `version` field, **When** the metadata reader parses it, **Then** it returns a structured error `METADATA_MISSING_VERSION` citing the F-051 frontmatter contract; no partial metadata returned.
3. **Given** F-119 install-from-path completes successfully at `2026-06-01T14:23:11Z`, **When** the metadata is later read for the installed bundle, **Then** the `installed-at` field equals `2026-06-01T14:23:11Z` exactly (read back from the in-workspace bundle's metadata sidecar; clock-stable per `rules/verification-protocol.md` ACTUAL-BEFORE-PRESENT).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/marketplace/metadata-parse-shape.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/marketplace/metadata-rejects-missing-version.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/marketplace/metadata-installed-at-roundtrip.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-051 (SKILL.md frontmatter is the substrate metadata extends), F-119 (install-from-path writes `installed-at` and triggers metadata indexing)
- **Soft:** F-055 (version-pin reads the metadata version field), F-066 (audit-chain records metadata-validation outcomes), F-121 (search/browse UI is the primary consumer of the structured metadata)
- **Independent:** F-D-002 (votes/reviews/downloads) — v1.5 deferred; F-D-006/F-D-007 (identity verification) — v1.5 deferred

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M18 row | "Skill metadata: F-120" |
| kit:rules/skill-standards.md Dimension 1 | Required frontmatter contract (name, description, allowed-tools, version) — metadata is a superset |
| kit:rules/canonical-artifact-frontmatter.md | Frontmatter discipline (no fabricated fields, no silent defaults) the reader enforces |

## Implementation notes

(empty — populated when implementation begins; metadata reader is a pure function over parsed YAML; failed parses surface verbatim YAML errors per `rules/verification-protocol.md`)
