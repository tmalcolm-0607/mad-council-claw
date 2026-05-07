---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-034
short-slug: info-panel
milestone: M5
provenance:
  surfaces:
    - cp:src/features/chat/components/HorizonPanel.tsx
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

(empty — populated when implementation begins)
