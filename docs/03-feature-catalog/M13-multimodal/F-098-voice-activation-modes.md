---
artifact-class: feature-ledger
generated-by: hand-authored (wave-006 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-006 / lane-b
    note: "Initial creation [NEW per Message 11]; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-098
short-slug: voice-activation-modes
milestone: M13
provenance:
  surfaces:
    - kit:foundational-plan.md M13 row (F-096..F-100 multimodal NEW)
    - kit:session-requests.md Message 11
    - kit:rules/dangerous-operations-policy.md (always-listening = consent-gated capture surface)
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
  LOCKED if GREEN AND reviews/F-098-voice-activation-modes-review.md exists with verdict: ACCEPT.
depends-on: [F-067, F-096, F-040]
out-of-scope-notes: |
  Custom wake-word training (user-supplied wake phrase) is post-v1 — v1 ships a fixed
  default wake phrase (TBD at M13 design wave; "hey claw" provisional). Multi-user
  voice-print discrimination (only-respond-to-owner) is v1.5 (FR-IDENTITY-002 family).
  Always-listening mode persisting audio buffers to disk for audit is FORBIDDEN — F-096
  contracts in-memory-only capture; this ledger inherits that constraint. The "shortcut
  binding" affordance for push-to-talk is wired into F-040 keyboard-shortcuts, not
  re-invented here. Cross-app global hotkey registration on Windows / macOS / Linux is
  F-040's scope; this ledger only contracts the *mode-state machine*.
confidence: high
---

# F-098 — Voice activation modes

## Behavior contract

The desktop shell exposes three mutually-exclusive voice-activation modes, settable per workspace via the settings surface (F-067): (a) `push-to-talk` — capture only while a registered keyboard shortcut (per F-040) is held; (b) `wake-word` — engine listens continuously for the wake phrase, then captures the next utterance; (c) `always-listening` — engine captures every utterance with no gate, gated behind an explicit one-time user consent prompt per `rules/dangerous-operations-policy.md`. Mode-switch is atomic — the old mode's listener is fully torn down before the new mode initializes; the audit log records every mode change with `event: stt_mode_change` + the prior + new mode. The `always-listening` consent prompt MUST re-fire on every workspace switch and on every fresh app install; consent does NOT carry across workspaces.

## Acceptance scenarios

1. **Given** the user has selected `push-to-talk` mode and bound the shortcut `Ctrl+Space` via F-040, **When** the user holds `Ctrl+Space`, speaks "list channels", and releases, **Then** F-096 emits exactly one final transcript matching the spoken phrase and no capture happens before press or after release.
2. **Given** the user attempts to switch from `push-to-talk` to `always-listening`, **When** the mode-switch is requested, **Then** the engine surfaces the consent gate, blocks the switch until explicit "yes" is received, audits the consent decision (per `dangerous-operations-policy.md`), and only then transitions; a "no" or timeout leaves the mode unchanged.
3. **Given** `wake-word` mode is active with the default wake phrase, **When** the user speaks an unrelated sentence then the wake phrase followed by "open project workspace", **Then** only the post-wake-phrase utterance is captured and emitted; the pre-wake audio is discarded in-memory.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multimodal/stt-mode-push-to-talk.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/multimodal/stt-mode-always-listening-consent.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/multimodal/stt-mode-wake-word.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-067 (settings surface exposes the mode picker), F-096 (capture pipeline is invoked by every mode), F-040 (keyboard-shortcut binding for push-to-talk)
- **Soft:** F-097 (engine selection is independent of mode), F-015 (audit log records mode changes + always-listening consent decisions)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M13 row | F-098 named as activation modes NEW feature |
| kit:session-requests.md Message 11 | Voice input listed as a v1 multimodal NEW surface |
| kit:rules/dangerous-operations-policy.md | Always-listening = continuous-capture surface = explicit-consent class; consent does NOT carry across workspaces |

## Implementation notes

(empty — populated when implementation begins; default wake-phrase string + per-workspace consent expiry policy decided at M13 design wave)
