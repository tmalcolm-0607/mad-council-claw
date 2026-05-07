---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-115
short-slug: architecture-docs
milestone: M17
provenance:
  surfaces:
    - cp:docs/architecture
    - cp:docs/architecture/electron-process-model.md
    - cp:docs/architecture/ipc-contract.md
    - kit:rules/verification-protocol.md
    - foundational-plan.md M17 docs section
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
  LOCKED if GREEN AND reviews/F-115-architecture-docs-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008, F-110]
out-of-scope-notes: |
  Per-feature design docs (one per F-NNN) are OUT — those are the per-feature
  ledgers under docs/03-feature-catalog/. Animated architecture diagrams are
  OUT (static SVG / Mermaid only). Decision-log archaeology (ADRs for every
  past decision) is OUT for v1; v1 docs cover current state only. Performance
  tuning + scaling guides are v1.5. Internal Microsoft-only architecture (Geneva
  / WorkIQ inner workings) is OUT — public-architecture only.
confidence: high
---

# F-115 — Architecture docs (mirror clawpilot's docs/architecture/ shape)

## Behavior contract

The repo MUST ship a `docs/architecture/` tree mirroring clawpilot's existing structure (Electron process model, IPC contract, storage layout, lifecycle/state machines, telemetry/audit boundaries, governance triad shape). Each top-level architecture topic gets a single Markdown file with: (1) one-paragraph summary, (2) a Mermaid or static SVG diagram showing component boundaries and data flow, (3) per-component prose describing responsibilities, (4) cross-links to the relevant F-NNN ledgers under `docs/03-feature-catalog/` per `rules/verification-protocol.md` (FETCH BEFORE CITE — every claim about engine behavior cites the ledger it traces to). The architecture-docs tree is the "if you only read 8 files, read these" entry point for engineering contributors. Required topics: `electron-process-model.md` (main / renderer / preload boundaries), `ipc-contract.md` (typed IPC channels), `engine-lifecycle.md` (F-001 phases), `identity-and-sessions.md` (F-002 binding), `storage-layout.md` (F-008), `governance-triad.md` (M2 features), `telemetry-and-audit.md` (M16 + F-015), `mcp-and-skills.md` (M6 + M7).

## Acceptance scenarios

1. **Given** an engineer new to the codebase asked to "explain the IPC contract", **When** they open `docs/architecture/ipc-contract.md`, **Then** they get a Mermaid diagram of all typed IPC channels, a per-channel responsibility table, and clickable cross-links to F-NNN ledgers covering each channel's behavior contract — and can summarize the IPC contract in their own words within 15 minutes.
2. **Given** a CI link-check across `docs/architecture/`, **When** the job runs, **Then** every relative cross-link resolves to a real ledger or rule file; every Mermaid block parses; every external URL returns 200.
3. **Given** an architecture claim like "the engine uses a single-owner accountability model", **When** the claim appears in `docs/architecture/governance-triad.md`, **Then** it MUST be followed by a citation to `kit:rules/single-owner-accountability.md` and the relevant F-NNN ledger (e.g. F-002 identity) — per `rules/verification-protocol.md`, no claim without a fetched citation.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/e2e/docs/architecture-onboarding-comprehension.test.ts` | e2e | RED | scenario 1 |
| (TBD) `tests/integration/docs/architecture-link-check.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/docs/architecture-citation-coverage.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine lifecycle is documented), F-002 (identity model is documented), F-008 (storage layout is documented), F-110 (telemetry boundaries are documented)
- **Soft:** Every M0-M16 feature ledger (architecture docs cross-link to ledgers per the verification protocol)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:docs/architecture | clawpilot architecture-docs tree shape; engine mirrors and adapts |
| cp:docs/architecture/electron-process-model.md | Electron process model description as a starting reference |
| cp:docs/architecture/ipc-contract.md | typed IPC contract documentation pattern; engine adapts to its own channels |
| kit:rules/verification-protocol.md | every architecture claim cites a fetched source (rule or ledger); FETCH BEFORE CITE |
| foundational-plan.md M17 | docs scope: architecture mirrors clawpilot's shape |

## Implementation notes

(empty — populated when implementation begins)
