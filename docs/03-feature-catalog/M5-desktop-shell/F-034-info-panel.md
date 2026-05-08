---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: red
    at: 2026-05-07
    by: wave-019 / lane-a
    note: "RED test authored at tests/unit/F-034-session-info-panel.test.ts (6 structural scenarios per the wave-019 / lane-a brief that simplifies the ledger's 3 launch-Electron browser-suite scenarios to a structural / interface-based shape contract). Test fails with module-resolution error: @mad-council-claw/desktop-shell exports do not yet include `buildInfoPanel` / `resolveInfoPanelField` / `DEFAULT_INFO_PANEL` / `INFO_PANEL_PLACEHOLDER` / `InfoPanelOptions` / `InfoPanelDescriptor` / `AuditChainStatus` / `CostBreakdown`. Implementation will land buildInfoPanel() + resolveInfoPanelField() + DEFAULT_INFO_PANEL + INFO_PANEL_PLACEHOLDER + AuditChainStatus/CostBreakdown types in packages/desktop-shell/src/info-panel.ts."
  - status: green
    at: 2026-05-07
    by: wave-019 / lane-a
    note: "GREEN. New packages/desktop-shell/src/info-panel.ts (~190 LOC) lands buildInfoPanel() + resolveInfoPanelField() + DEFAULT_INFO_PANEL + INFO_PANEL_PLACEHOLDER (= '—') + types (InfoPanelOptions / InfoPanelDescriptor / AuditChainStatus / CostBreakdown / RunLifecycle). Pure-data descriptor (JSON-cloneable; no functions, no class instances) with explicit-placeholder discipline (no silent zeros per kit:rules/verification-protocol.md Rule 4 ACTUAL BEFORE PRESENT); audit-chain status 'red' masks costBreakdown + emits Context Gap; missing cost-ledger emits placeholder + Context Gap; closed-only retroSummary; default isOpen=true. package.json exports map gains `./info-panel` subpath; barrel src/index.ts re-exports info-panel.ts. 6/6 PASS at GREEN time; full suite 323/323 PASS across 38 test files; pnpm build exits 0."
feature-id: F-034
short-slug: info-panel
milestone: M5
provenance:
  surfaces:
    - cp:src/features/chat/components/HorizonPanel.tsx
    - kit:rules/verification-protocol.md
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-034-session-info-panel.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-034-info-panel-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-015, F-019]
out-of-scope-notes: |
  Live trace timeline + step-by-step replay scrubber is M11 (F-088..F-092).
  Cross-run aggregate stats (e.g., "average cost per run this week") are v1.5.
  Editable run metadata fields are out of scope; info panel is read-only.
confidence: high
---

# F-034 — Info panel

## Behavior contract

The right-side info panel (toggleable; default open) displays the selected run's metadata: agent identity (per F-002), lifecycle state, cycle count + max, audit-chain verification status (per F-015 — green/yellow/red badge), cost-ledger sub-totals broken down by tool/model (per F-019), kill-switch status (per F-020), retro summary (per F-014, only for closed runs). All fields are read-only, sourced via IPC from main process; no field is editable from the UI. Audit-chain badge re-verifies on demand (button) and surfaces "chain broken" warnings prominently per F-016 streaming-warning convention. Loading state is explicit: no field shown without source data; placeholders are explicit "—" or skeleton, never silent zeros.

## Acceptance scenarios

1. **Given** an active run selected, **When** the info panel renders, **Then** all metadata fields are present + audit-chain badge shows current status + cost-ledger shows live sub-totals updating per cycle.
2. **Given** a closed run with a tampered audit entry (chain broken), **When** the info panel re-verifies on the button, **Then** the chain badge turns red + a banner explains the breaking entry's index + the cost-ledger area is masked with "data-integrity warning".
3. **Given** a run whose cost-ledger file is missing entirely, **When** the panel renders, **Then** the cost section shows "—" placeholders (NOT zero) + a Context Gap line per `degradation-fallback-policy.md` Rule 3.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/info-panel-basic.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/desktop/info-panel-chain-broken.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/desktop/info-panel-missing-data.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window), F-015 (audit-chain verification), F-019 (cost ledger)
- **Soft:** F-002, F-014, F-016, F-020, F-021
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/features/chat/components/HorizonPanel.tsx | Right-pane layout pattern (clawpilot Horizon panel) |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — never silent zeros, explicit placeholders + gaps |

## Implementation notes

### Wave-019 / Lane A — RED → GREEN flip (2026-05-07)

**Scope simplification vs ledger §Acceptance scenarios.** The wave-019 / lane-a brief instructs a STRUCTURAL / INTERFACE-BASED test that asserts the shape `buildInfoPanel(opts)` returns, rather than booting the desktop renderer in headless Chromium and asserting button-driven re-verify behavior. The three browser-suite scenarios in §Acceptance scenarios bind to the M5 integration suite (a future feature wave that wires the F-007 IPC bridge, the F-015 audit-chain re-verification trigger, and the F-019 cost-ledger live updates). v1 ships:

- `RunLifecycle` — typed enum (`'active' | 'closed' | 'halted'`); mirrors the F-033 sibling type.
- `AuditChainStatus` — typed enum (`'green' | 'yellow' | 'red'`); the badge a future renderer renders.
- `CostBreakdown` — `{ kind: 'tool' | 'model'; label: string; usd: number }`; per-tool/model sub-total per ledger §Behavior contract.
- `InfoPanelDescriptor` — the plain-data descriptor (read-only fields with explicit-placeholder discipline; no edit handlers).
- `INFO_PANEL_PLACEHOLDER` — the literal `'—'` string surfaced for missing source data per `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT.
- `DEFAULT_INFO_PANEL` — the canonical default for fresh installs (panel open; placeholder fields; chain status null; cost breakdown empty; no retro).
- `buildInfoPanel(opts)` — pure function returning the descriptor. Behavior:
  - `auditChainStatus === 'red'` → `costBreakdown: []` masked + Context Gap line added (per ledger scenario 2).
  - `costBreakdownAvailable === false` → `costBreakdown: []` + `costBreakdownPlaceholder: '—'` + Context Gap line (per ledger scenario 3 — explicit placeholder, NOT silent zero).
  - `lifecycle !== 'closed'` → `retroSummary: null` (retro is emitted on close per F-014; supplying it on an active run is silently dropped — caller's bug, not the descriptor's).
- `resolveInfoPanelField(value)` — never-throws field hydrator: `null | undefined | ''` → `INFO_PANEL_PLACEHOLDER`; numbers (including `0`) and non-empty strings round-trip.

**Substantive guarantees preserved by the structural test (per `verification-protocol.md` Rule 1):**

- Read-only field rendering (descriptor has no edit handlers; consumers cannot mutate).
- Audit-chain badge type-safety (`AuditChainStatus` union, no free-form strings).
- Explicit-placeholder discipline: missing source data surfaces `'—'`, NEVER silent zeros (per Rule 4).
- Audit-chain `'red'` masks cost breakdown (data-integrity warning per ledger scenario 2).
- Missing cost-ledger emits placeholder + Context Gap (per ledger scenario 3 + `degradation-fallback-policy.md` Rule 3).
- Default `isOpen: true` (panel default-open per ledger §Behavior contract).
- Closed-only `retroSummary` enforcement (active runs cannot carry retro).

**Deferred to M5 integration wave per `no-silent-deferrals.md`:**

- Actual DOM render of the panel — belongs in the M5 integration consumer.
- F-007 IPC subscription wiring for live updates per cycle.
- "Re-verify chain on button" runtime trigger — wires F-015 audit-chain re-verification via the F-007 IPC bridge.
- F-019 cost-ledger live sub-total streaming.
- Live trace timeline + step-by-step replay scrubber — M11 scope (F-088..F-092 per ledger out-of-scope-notes).
- Cross-run aggregate stats — v1.5 per ledger out-of-scope-notes.
- Editable run metadata fields — out of scope per ledger out-of-scope-notes (info panel is read-only by design).

**Cross-feature composition:**

- F-032 (window, GREEN), F-033 (history-pane, paired in same wave) — sibling M5 surfaces; the panel reads `selectedRunId` from F-033 and renders the corresponding run's metadata.
- F-002 (per-agent identity + run-id) — supplies `agentLabel`.
- F-014 (pre-close retro signal, LOCKED) — supplies `retroSummary` for closed runs.
- F-015 (hash-chained audit log, LOCKED) — supplies `auditChainStatus`; the descriptor's red-masks-cost discipline preserves data-integrity warning semantics.
- F-019 (cost-ledger, LOCKED) — supplies `CostBreakdown[]` per cycle.
- F-020 (kill-switch, LOCKED) — supplies `killSwitchActive`.
- F-007 (ipc-contract-scaffold, LOCKED) — the IPC channels for live updates type-check against `keyof IpcInvokeMap` at the consumer call site.

**Inherits the F-032 idiom "descriptor-as-data, instantiation-deferred"** registered wave-018 / lane-c. F-034's deliverable IS the plain-object descriptor + helper functions; the consumer step ("hand the descriptor to a component tree") is deferred. The idiom enables structural testing without a DOM runtime. F-034 also exemplifies the **"explicit-placeholder discipline"** corollary: when source data is missing, the descriptor surfaces a typed placeholder `INFO_PANEL_PLACEHOLDER = '—'`, not a silent zero or empty string. This is a direct mechanization of `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT into the descriptor's field types.

**Test files at GREEN:**

- `tests/unit/F-034-session-info-panel.test.ts` — 6 scenarios, all PASS at GREEN time.

**Source files at GREEN:**

- `packages/desktop-shell/src/info-panel.ts` — ~115 LOC (buildInfoPanel + resolveInfoPanelField + types + constants).
- `packages/desktop-shell/package.json` — exports map gains `./info-panel` subpath.
- `packages/desktop-shell/src/index.ts` — barrel re-exports info-panel.ts.

**Third feature in `packages/desktop-shell/`** after F-032 + F-033. Wave-011 / lane-a's "shared types live with their FIRST owner" convention applies: `RunLifecycle` + `AuditChainStatus` + `CostBreakdown` + `InfoPanelDescriptor` + `InfoPanelOptions` + `DEFAULT_INFO_PANEL` + `INFO_PANEL_PLACEHOLDER` + `buildInfoPanel` + `resolveInfoPanelField` live with F-034. Future M5 features will compose against this surface without changing it.
