---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-005 / lane-a)
wave: wave-005
lane: lane-a
topic: per-feature-ledger-authoring-M9
date: 2026-05-06
status: complete
---

# Wave 5 / Lane A — per-feature ledgers for M9 (M365 integration)

## Scope

Author RED-state ledgers for milestone M9 (M365 integration). Span: F-076..F-081 (6 features). Format matches wave-002 lane-b template verbatim — frontmatter contract, body sections (behavior contract / acceptance scenarios / red→green wire-up / dependencies / surface trace / implementation notes).

M9 is the first M5+ milestone catalog drop. Together with M9 README + this summary, lane delivers 8 net-new artifacts.

## What was created

| Group | Path | Count |
|---|---|---|
| M9 ledgers | `docs/03-feature-catalog/M9-m365/F-{076..081}-*.md` | 6 |
| Milestone README | `docs/03-feature-catalog/M9-m365/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-005/lane-a-summary.md` | 1 |
| **Total** | | **8** |

## Per-ledger frontmatter contract (matches wave-002 lane-b template verbatim)

Every ledger carries:
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-005 / lane-a)`
- `status: red`, `status-since: 2026-05-06`, `status-history: [...]`
- `feature-id: F-NNN`, `short-slug`
- `milestone: M9`
- `provenance.surfaces: [kit:..., cp:..., R:...]`
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (filled by M9 implementation wave)
- `red-green-rule:` literal (matches lane brief verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md` — every adjacent surface explicitly tracked
- `confidence: high`

## Per-ledger body sections

Every ledger has the 6 required body sections from the wave-002 lane-b template:
1. Behavior contract (3-5 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios each)
3. Red→green wire-up (test-file table, all marked TBD)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

## Provenance distribution

Sources synthesized across the 6 ledgers:

| Source family | Surfaces cited |
|---|---|
| Clawpilot (`cp:`) | `electron/auth/msal-provider.ts`, `electron/m365-token.ts`, `electron/m365-token-wam.ts`, `electron/m365-token-wam-gate.ts`, `electron/tenant-policy.ts`, `electron/auth/safe-storage-file.ts`, `electron/ipc/with-timeout.ts`, `src/features/auth/AuthScreen.tsx`, `src/features/auth/useM365Auth.ts`, `src/features/auth/stages/*` (10 stage cards), `AuthScreen.telemetry.test.tsx`, `electron/m365/*` (calendar / email / teams / onedrive / people / graph-query / m365-tools), `pnpm test:m365`, package pins (`@azure/msal-node ^5.1.2`, `@azure/msal-node-extensions ^5.1.2`, `@microsoft/workiq ^0.4.1`), commit `89be5fa5` (macOS broker / WAM tenant filter) |
| MAD kit (`kit:`) | `rules/single-owner-accountability.md` (session_id binding), `rules/concurrency-safety.md` (atomic writes), `rules/degradation-fallback-policy.md` (CB rules), `rules/anomaly-thresholds.md` (CB thresholds) |
| Microsoft 2026 research (`R:`) | `microsoft-2026/agent-365-sdk.md` (Entra Agent ID context), `microsoft-2026/workiq-internal-context.md` (Lobster + read-only patterns), `microsoft-2026/workiq-a2a-impl-patterns.md` (wave-4 lane-c), `microsoft-2026/m365-copilot-extensibility.md` |
| Foundational plan | `foundational-plan.md` § Architecture (4 planes; WorkIQ Lobster pattern); G12 ("WorkIQ + readonly Microsoft solutions"); F-076..F-081 catalog table; QG8 (Microsoft tools every 3 waves) |

## Anomalies / context gaps

- **F-NNN -> FR-XXX exact mapping deferred.** Per the wave-002 lane-b template, `fr-coverage: []` is empty. The mapping will be done via `/mad-spec` per-feature in the M9 implementation wave. M9 lacks specific FR-AUTH-* IDs in the canonical-e inventory's wave-1 export; ledgers cite clawpilot impl + foundational-plan G12 directly. Confidence remains HIGH because the source material (clawpilot's auth surface) is unambiguous.
- **No live test files.** Per the brief, test-files frontmatter arrays stay empty until the M9 wave lands the actual `tests/{unit,integration,browser,e2e}/F-NNN-*.test.ts` files.
- **F-077 WAM is Windows-only.** The integration tests for F-077 will need to skip gracefully on non-Windows runners; the ledger's red-green-rule allows this (zero exit on skip is GREEN).
- **F-078 stage-card reuse pattern.** Several clawpilot stage cards (`ConnectGitHubCard`, `GitHubDeviceCodeCard`, `CopilotAccessRequiredCard`) are part of clawpilot's UX but NOT in engine v1 scope. The shell + telemetry pattern is reused; per-card logic is M365-only for v1. Documented in F-078 `out-of-scope-notes`.

## Out of scope (per `rules/no-silent-deferrals.md`)

Every M9 ledger's `out-of-scope-notes` block names where adjacent surfaces are tracked:

- **Write operations** (post Teams, send email, create event) — explicitly v1.5 per G12 (`readonly Microsoft solutions`)
- **MIP sensitivity-label elevation** — clawpilot has it (`electron/sensitivity-elevation.ts` + `electron/m365/sensitivity-labels.ts` + integration tests); engine v1 surfaces labels but does not gate; v1.5 adds gating
- **macOS broker** for WAM (clawpilot has recent fixes at `89be5fa5` / `9f7989a4` / `d6b15b21`) — engine v1 ships with WAM on Windows only; macOS broker is v1.5
- **Tenant-filter UX** (multi-tenant switcher) — deferred to M8 settings (F-067..F-075)
- **BYOK / customer-managed token cache encryption** — v1.5 enterprise feature
- **Cross-device token sync** — explicitly OUT (tokens are local-only)
- **Adaptive rate-limiting based on Graph 429 retry-after hints** — v1.5 hardening
- **Cross-tenant rate-limit pooling** — explicitly OUT
- **Agent 365 SDK Entra Agent ID provisioning** — separate identity plane; M11+
- **GitHub auth surfaces** (ConnectGitHubCard, GitHubDeviceCodeCard) — engine v1 is M365-only; v1.5 if engine adds GitHub integrations

## Confidence

HIGH (all 6 ledgers + README). Source material — clawpilot's auth + M365 surface (HIGH-confidence per wave-1 lane-d clawpilot-features-inventory.md), wave-1 microsoft-2026 research, and wave-4 lane-c TS-impl deep-dives — is consistent and unambiguous for M9 scope. Behavior contracts are present-tense imperative, acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes, dependencies trace cleanly through the milestone DAG. Out-of-scope-notes name every adjacent surface explicitly per `rules/no-silent-deferrals.md`.

## Quality-gate checklist (QG1-QG9 for wave-005 lane-a)

- [x] QG1 — net-new — first M9 catalog drop; 6 ledgers + 1 milestone README + 1 lane summary are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists kit/cp/R surfaces; this summary cites foundational-plan.md + wave-1 + wave-4 lane-c
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G12 (WorkIQ + readonly Microsoft solutions), G18 (multi-agent fan-out at wave level)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by /mad-spec runs (tracked in M9 README exit criteria)
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-005 plan has multiple lanes
- [ ] QG7 — Copilot CLI design review — N/A this lane (mechanical catalog drop; Copilot review better suited to architecture lanes)
- [x] QG8 — Microsoft tools used — wave-1 microsoft-2026 + wave-4 lane-c TS-impl deep-dives synthesized; satisfies "Microsoft tools every 3 waves" cadence
- [x] QG9 — open questions captured — frontmatter `out-of-scope-notes` + summary `Anomalies` section

## Loop-improvement proposal (QG5)

Three observations from the M9 catalog drop:

1. **Wave-002 lane-b template is reusable as-is.** Lifting the M0/M1/M2 template verbatim to M9 worked first-pass. Recommend: future catalog drops (M3-M8, M10-M19) use the same template without modification. Future template changes should be batched and applied across milestones in one pass to avoid drift.

2. **Provenance gets richer at later milestones.** M0 ledgers cited mostly `kit:` rules and a few `cp:` paths. M9 ledgers cite ~25 distinct cp paths + 4 R: research files + 4 kit rules. The provenance density signals that M9 is well-grounded; sparse provenance in a future milestone catalog drop is a smell to flag in retro.

3. **`out-of-scope-notes` carries the most decision-load.** For M9, the v1.5 scoping (read-only, Windows-only WAM, no MIP gating, no GitHub) is the most consequential set of decisions in the catalog. Recommend: future milestones prepend their `out-of-scope-notes` review to /mad-spec invocations as load-bearing context — these are the decisions implementers will defer to most.

## Next steps

- M3+M4+M5+M6+M7+M8 catalog drops can run in parallel waves with the same template.
- M10 (multi-model adversarial review) catalog drop is a natural pair for QG7 (Copilot CLI design review) coverage.
- M9 implementation wave begins when this catalog is committed AND the M0+M1+M2 implementation waves have made the engine kernel testable end-to-end (auth screen needs F-001 lifecycle in place).
