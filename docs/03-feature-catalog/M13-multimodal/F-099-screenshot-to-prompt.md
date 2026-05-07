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
feature-id: F-099
short-slug: screenshot-to-prompt
milestone: M13
provenance:
  surfaces:
    - kit:foundational-plan.md M13 row (F-096..F-100 multimodal NEW)
    - kit:session-requests.md Message 11 (screenshot-to-prompt named verbatim)
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
  LOCKED if GREEN AND reviews/F-099-screenshot-to-prompt-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-014, F-100]
out-of-scope-notes: |
  Brief states "F-099 depends on F-014 multi-tier-routing (vision-model dispatch)". The
  catalog's F-014 is `pre-close-retro-signal` (M2); the actual multi-tier-routing feature
  per `foundational-plan.md` line 425 is F-124 (M1 NEW frontier candidate). Honored brief
  literal — `depends-on: [..., F-014, ...]` — and surfaced the mismatch to the lane summary
  for council reconciliation. The intent (route image-bearing prompts to a vision-capable
  model tier) is contracted regardless of which F-NNN owns the routing primitive. Direct
  capture of an arbitrary screen region (region-select overlay) is M5 desktop-shell scope
  (F-038-adjacent); this ledger consumes whatever image lands on the OS clipboard.
  Drag-and-drop image into the prompt buffer is v1.5 — v1 ships clipboard-paste only.
  Multi-image prompts (paste 3 screenshots in sequence into one prompt) are v1.5 —
  v1 emits one image per prompt. Camera capture (webcam → vision prompt) is post-v1.
confidence: high
---

# F-099 — Screenshot-to-prompt

## Behavior contract

When the user pastes (Ctrl+V / Cmd+V) into the prompt buffer and the OS clipboard contains an image (PNG / JPEG / WebP MIME), the engine accepts the image as a multimodal prompt input, runs it through F-100 image-preprocessing (crop / annotate / redact applied per user setting), and on prompt-send routes the resulting prompt to a vision-capable model tier per the multi-tier-routing primitive (per the F-014-named dependency). Non-image clipboard content (text, files) falls through to the normal text-paste path; mixed clipboard (text + image) preserves both — text appears inline, image appears as a typed attachment chip in the prompt buffer. If the active workspace's selected model tier has no vision-capable variant, the engine rejects send with `VISION_ROUTING_UNAVAILABLE` + the active tier name and prompts the user to switch tier or remove the image.

## Acceptance scenarios

1. **Given** the user has copied a PNG screenshot to the clipboard and the active model tier has a vision-capable variant, **When** the user pastes into the prompt buffer and clicks send, **Then** the engine routes the prompt to the vision-capable model (verified via the model-id field on the dispatch event) and the image bytes are included in the model request payload exactly once.
2. **Given** mixed clipboard (text + image), **When** the user pastes into the prompt buffer, **Then** the prompt buffer shows the text inline AND a typed image-attachment chip; on send, both modalities are dispatched in one prompt request.
3. **Given** the user pastes an image but the active workspace's tier (e.g., a text-only Haiku tier) has no vision-capable variant, **When** the user clicks send, **Then** the send is rejected with `VISION_ROUTING_UNAVAILABLE { active_tier: <name> }` and the user is prompted with a tier-switch affordance; no model request is dispatched.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multimodal/screenshot-paste-vision-route.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/multimodal/screenshot-paste-mixed-clipboard.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/multimodal/screenshot-paste-no-vision-tier.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine bootstrap registers the paste handler), F-014 (per brief — vision-model dispatch via multi-tier-routing; see out-of-scope note re: F-014 vs F-124 naming), F-100 (image preprocessing fires before send)
- **Soft:** F-067 (settings surface for the per-workspace preprocessing defaults), F-096 (sibling multimodal channel)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M13 row | F-099 named as screenshot-to-prompt NEW feature |
| kit:session-requests.md Message 11 | "screenshot-to-prompt" listed verbatim in the user-stated multimodal NEW set |
| kit:rules/no-silent-deferrals.md | Drag-drop, multi-image, camera explicitly named as v1.5 / post-v1 with deferral rationale |

## Implementation notes

(empty — populated when implementation begins; M13 design wave reconciles F-014 vs F-124 dependency naming and decides per-workspace default vision-capable model)
