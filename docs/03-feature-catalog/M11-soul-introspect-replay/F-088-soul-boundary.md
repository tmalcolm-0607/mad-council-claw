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
feature-id: F-088
short-slug: soul-boundary
milestone: M11
provenance:
  surfaces:
    - ce:FR-SOUL-001
    - kit:rules/non-negotiable-rules.md
    - kit:rules/orchestrator-identity.md
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
  LOCKED if GREEN AND reviews/F-088-soul-boundary-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-015, F-089]
out-of-scope-notes: |
  D-8 (soul scope default = full canonical-e concept) is PENDING — closure path is the M11
  design wave council-review per `docs/10-backlog/design-decisions-pending.md`. Until then,
  this ledger contracts the boundary-enforcement mechanism only; the default scope envelope
  (which clauses are immutable in v1) is fixed by F-089 (soul-document-schema) once D-8 lands.
  Soul boundary enforcement *location* (D-2: IBackendProvider vs orchestration plane vs tool plane)
  is also pending and tracked under F-009 (M1) ledger council-review.
  Compile-time package-boundary enforcement (D-26 option (a): eslint-plugin-boundaries +
  import-ban + test fixture) is the recommended path; runtime check here is defense-in-depth only.
  Capability-based enforcement (object-capability model, D-26 option (c)) is deferred to v-next.
confidence: high
---

# F-088 — Soul boundary

## Behavior contract

Every run loads `soul.json` (validated per F-089) at bootstrap and freezes it for the run's lifetime. Engine-mediated `--force`, environment overrides, runtime mutation attempts, or any caller (including admin / owner_alias) MUST NOT alter the loaded boundary in-flight. Any tool call, agent action, or orchestration step that would violate a soul clause rejects with `SOUL_BOUNDARY_VIOLATION` and stamps the audit log (per F-015) with `trigger: soul_boundary_violation` + the violated clause-id. The boundary is read-only after load; the only path to change it is between runs by editing the source `soul.json` file.

## Acceptance scenarios

1. **Given** a run that has loaded a `soul.json` containing a clause forbidding `Bash` tool calls, **When** an agent attempts `Bash echo hi`, **Then** the call rejects with `SOUL_BOUNDARY_VIOLATION` and an audit entry records `trigger: soul_boundary_violation` + `clause_id: <id>`.
2. **Given** a running engine with soul loaded, **When** a developer issues `--force` on a soul-violating operation, **Then** the engine rejects identically (no override path); the audit log shows the `--force` flag was present but ignored.
3. **Given** an attacker patches the in-memory soul object via a debugger or a second process, **When** the next cycle's tool dispatch runs, **Then** the engine re-verifies the loaded boundary against the on-disk `soul.json` SHA-256 and halts with `SOUL_INTEGRITY_VIOLATION` if mismatch is detected.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/soul/boundary-tool-violation.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/soul/force-cannot-override.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/soul/in-memory-tamper-detect.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine bootstrap loads soul), F-015 (hash-chained audit log records violations), F-089 (soul-document-schema validates the loaded soul.json)
- **Soft:** F-018 (failure-pattern-halt — soul violations may escalate halt), F-020 (kill-switch — soul violation MAY trigger kill)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-SOUL-001 | Immutable boundaries doc; engine-mediated `--force` cannot override |
| kit:rules/non-negotiable-rules.md | Verb-bound permission fences pattern (compile-time + runtime fences) |
| kit:rules/orchestrator-identity.md | Boundary enforcement is "ORCHESTRATE ONLY"-shaped: enforced at every dispatch point |

## Implementation notes

(empty — populated when implementation begins; D-2 + D-8 + D-26 closures will inform the location + default scope + enforcement-mechanism choices)
