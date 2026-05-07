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
feature-id: F-038
short-slug: primitives
milestone: M5
provenance:
  surfaces:
    - cp:src/features/ (chat input, message, button, dialog, tab patterns)
    - cp:src/features/chat/components/ChatInput.tsx
    - cp:src/features/chat/components/ChatMessage.tsx
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
  LOCKED if GREEN AND reviews/F-038-primitives-review.md exists with verdict: ACCEPT.
depends-on: [F-032]
out-of-scope-notes: |
  Animation library (Framer Motion equivalents) is v1.5.
  Custom design system (beyond functional primitives) is v1.5.
  Storybook + visual regression testing of primitives is v1.5.
confidence: high
---

# F-038 — UI primitives

## Behavior contract

The desktop ships a minimal set of reusable UI primitives that the rest of M5 builds on: `Button`, `IconButton`, `Dialog`, `Tab`, `TextField`, `TextArea`, `Dropdown`, `Toggle`, `Badge`, `Tooltip`, `Toast`, `ProgressIndicator`. Each primitive: is keyboard-accessible (Tab + Shift+Tab traversal, Enter/Space activation, Esc dismissal where applicable); declares its ARIA role; supports light + dark color tokens (per F-039 theming); is unit-tested (rendering + interaction). Every primitive carries a `.telemetry.test.tsx` companion (per clawpilot pattern) that verifies render-time + click-time emit no errors. No primitive embeds business logic; they are pure presentation + interaction. Composition (e.g., a "search dialog" composed of Dialog + TextField + Button) lives in higher-level components, not in primitives.

## Acceptance scenarios

1. **Given** any primitive rendered (e.g., Button), **When** focused via Tab + activated via Enter, **Then** the click handler fires + ARIA role is correctly declared + telemetry test reports zero errors.
2. **Given** a Dialog primitive open, **When** Esc is pressed, **Then** the dialog closes + focus returns to the trigger element (focus-trap restoration).
3. **Given** the design tokens swapped from light to dark theme, **When** every primitive re-renders, **Then** all colors update + no primitive uses hardcoded hex outside the token system.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/desktop/primitives/button.test.tsx` | unit | RED | scenario 1 |
| (TBD) `tests/browser/desktop/dialog-focus-trap.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/desktop/theme-token-coverage.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window context for rendering)
- **Soft:** F-039 (theming consumes color tokens)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/features/ | Component organization pattern |
| cp:src/features/chat/components/ChatInput.tsx | TextArea + auto-resize primitive shape |
| cp:src/features/chat/components/ChatMessage.tsx | Message rendering primitive shape |

## Implementation notes

(empty — populated when implementation begins)
