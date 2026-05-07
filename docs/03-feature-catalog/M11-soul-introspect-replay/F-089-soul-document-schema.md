---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-c)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-c
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-089
short-slug: soul-document-schema
milestone: M11
provenance:
  surfaces:
    - ce:FR-SOUL-SCHEMA-001
    - kit:rules/canonical-artifact-frontmatter.md
    - kit:rules/no-silent-deferrals.md
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
  LOCKED if GREEN AND reviews/F-089-soul-document-schema-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008]
out-of-scope-notes: |
  D-8 (soul scope default = full canonical-e concept) is PENDING — the JSON Schema's
  REQUIRED clause set (which categories MUST appear in a v1 soul.json) is contracted
  here AS A SHAPE only. The default v1 scope envelope (e.g. forbidden tool list,
  forbidden write paths, mode lock to CoClaw single-player per FR-COCLAW-001) is fixed
  by the M11 design wave council-review per `docs/10-backlog/design-decisions-pending.md`.
  Migration tooling for soul schema version bumps (v1 → v1.1) is deferred to v1.5.
  Cryptographic signing of soul.json (third-party timestamp / sigstore) is deferred to
  v1.5 per FR-IDENTITY-002 family.
confidence: high
---

# F-089 — Soul document schema

## Behavior contract

`soul.json` MUST validate against the canonical JSON Schema at `schemas/soul.schema.json` before the run boots. Unknown top-level keys reject with `SOUL_SCHEMA_VIOLATION` (no silent acceptance, no auto-coercion). Required fields include `version`, `clauses[]` (each with `clause_id`, `category`, `directive`, `enforcement`), and `loaded_sha256` (computed by the loader, written back atomically per `concurrency-safety.md` §2). The loader records the schema version and SHA-256 in the audit log's first entry (`event: soul_loaded`) and emits `SOUL_LOADED_V1` to stdout.

## Acceptance scenarios

1. **Given** a `soul.json` missing the required `clauses[]` array, **When** the engine boots, **Then** load rejects with `SOUL_SCHEMA_VIOLATION` and exit code `2`; no run state is written.
2. **Given** a `soul.json` containing an unknown top-level key (`{"extra_thing": "..."}`), **When** the engine boots, **Then** load rejects with `SOUL_SCHEMA_VIOLATION` naming the unknown key (no silent strip, no warn-only).
3. **Given** a valid `soul.json` with 3 clauses, **When** the engine boots, **Then** the audit log's first entry is `event: soul_loaded` with `fields.schema_version` and `fields.loaded_sha256` present, and the clauses are frozen for F-088 enforcement.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/soul/schema-required-fields.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/soul/schema-unknown-keys-reject.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/soul/load-and-audit-stamp.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine bootstrap reads soul), F-008 (storage layout — `schemas/soul.schema.json` + `runs/<run_id>/soul-loaded.json` snapshot)
- **Soft:** F-088 (boundary enforcement consumes the loaded clauses), F-015 (audit log stamps the load event)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-SOUL-SCHEMA-001 | soul.json JSON Schema; unknown keys reject with SOUL_SCHEMA_VIOLATION |
| kit:rules/canonical-artifact-frontmatter.md | Schema-validated artifact pattern (frontmatter contract → JSON Schema contract) |
| kit:rules/no-silent-deferrals.md | Unknown-key reject is the no-silent-strip discipline applied to schema validation |

## Implementation notes

(empty — populated when implementation begins; D-8 closure will fix the v1 default clause set; consider sigstore signing track in v1.5)
