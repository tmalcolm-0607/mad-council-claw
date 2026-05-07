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
feature-id: F-035
short-slug: model-picker
milestone: M5
provenance:
  surfaces:
    - cp:src/features/chat/components/DefaultModelPicker.tsx
    - cp:src/features/chat/components/PersonalityPicker.tsx
    - kit:rules/model-selection.md
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
  LOCKED if GREEN AND reviews/F-035-model-picker-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-009, F-012]
out-of-scope-notes: |
  Per-message model override (changing model mid-conversation) is v1.5.
  Custom model registration (BYO endpoint via UI) is v1.5; v1 ships pinned model list from backend factory (F-012).
  Cost-aware model recommendations ("you're at 80% budget — switch to cheaper model?") are v1.5.
confidence: high
---

# F-035 — Model picker

## Behavior contract

A dropdown in the new-run dialog (and as a setting in the desktop preferences) selects the default model for spawned runs. The list is sourced from the backend factory (per F-012) — backends declare their available models via `IBackendProvider.listModels()`. Selecting a model writes the choice to `<state-dir>/desktop/preferences.json:default_model`; new runs inherit this setting unless overridden via the new-run dialog. Per `kit:rules/model-selection.md` the picker MUST surface a model's tier (Opus/Sonnet/Haiku-equivalent) + rough cost-per-MToken so operators choose intentionally.

## Acceptance scenarios

1. **Given** an Anthropic backend provider with 3 models registered, **When** the model picker opens, **Then** all 3 models appear in the dropdown with tier + cost-per-MToken hints.
2. **Given** the user selecting "Claude Sonnet 4.6" + closing the dialog, **When** preferences are saved, **Then** `<state-dir>/desktop/preferences.json:default_model` equals `"claude-sonnet-4-6"` + the next new-run dialog defaults to it.
3. **Given** a backend provider that fails to enumerate models (e.g., transport down), **When** the picker opens, **Then** the dropdown shows the last-known cached model list + a Context Gap line per `degradation-fallback-policy.md` Rule 3.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/model-picker-list.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/desktop/model-picker-persist.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/desktop/model-picker-degraded.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window), F-009 (IBackendProvider listModels), F-012 (backend factory aggregates providers)
- **Soft:** F-021 (degradation-fallback for transport down)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/features/chat/components/DefaultModelPicker.tsx | Picker UI shape from clawpilot |
| cp:src/features/chat/components/PersonalityPicker.tsx | Tier-display companion shape |
| kit:rules/model-selection.md | Tier-aware selection + cost-aware framing |

## Implementation notes

(empty — populated when implementation begins)
