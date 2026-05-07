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
feature-id: F-100
short-slug: image-preprocessing
milestone: M13
provenance:
  surfaces:
    - kit:foundational-plan.md M13 row (F-096..F-100 multimodal NEW)
    - kit:session-requests.md Message 11
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
  LOCKED if GREEN AND reviews/F-100-image-preprocessing-review.md exists with verdict: ACCEPT.
depends-on: [F-099, F-067]
out-of-scope-notes: |
  ML-driven auto-redaction (face / license-plate / signature detection) is post-v1 — v1
  ships ONLY user-driven redaction (drag-rectangle to mask region with solid fill). OCR
  text extraction from screenshots is v1.5 — v1 sends raw image bytes to the vision model
  and lets the model parse text. Image format conversion (HEIC → PNG, etc.) is v1.5 —
  v1 supports only PNG / JPEG / WebP per F-099 contract. EXIF metadata stripping is
  ALWAYS-ON in v1 (no toggle) — privacy-by-default per `rules/no-silent-deferrals.md`
  framing of user-data discipline. Animated images (GIF, animated WebP) are flattened to
  the first frame in v1; multi-frame analysis is post-v1. Per-skill or per-automation
  preprocessing override is v1.5; v1 is per-workspace global defaults.
confidence: high
---

# F-100 — Image preprocessing

## Behavior contract

Before any image leaves the prompt buffer for model dispatch (per F-099), the image flows through a deterministic preprocessing pipeline with three user-controllable stages, configured per-workspace via the settings surface (F-067): (1) **CROP** — optional rectangular crop applied via an inline editor; (2) **ANNOTATE** — optional draw-on-top markup (arrows, text, highlight) flattened into the image; (3) **REDACT** — optional drag-rectangle solid-fill mask to obscure regions before they reach any model. EXIF metadata is ALWAYS stripped (no toggle). The pipeline is pure: same input + same edit history produces byte-identical output. The original (pre-edit) image is held in memory only — never persisted — and is dropped on prompt-send. If the user cancels the edit, no image reaches F-099's send path.

## Acceptance scenarios

1. **Given** the user pastes an image (per F-099) and applies a 200x200 px crop in the inline editor, **When** the user clicks send, **Then** F-100 emits a cropped image of exactly 200x200 px to F-099's dispatch path, the EXIF block is empty (zero metadata bytes), and the original full-size image is no longer present in memory.
2. **Given** the user pastes an image, draws a redaction rectangle over a region containing visible text, and clicks send, **When** the dispatched image is inspected, **Then** the redacted region is solid-fill (no original pixel data recoverable) and the surrounding pixels are byte-identical to the input.
3. **Given** the user pastes an image and clicks cancel in the preprocessing editor, **When** the cancel completes, **Then** F-099's dispatch path receives no image, the prompt buffer's image attachment chip is removed, and the in-memory original is dropped.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multimodal/preprocess-crop-exif-strip.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/multimodal/preprocess-redact-fill.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/multimodal/preprocess-cancel-no-dispatch.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-099 (consumes preprocessed output for vision dispatch), F-067 (settings surface for per-workspace defaults)
- **Soft:** F-015 (audit log records redaction-applied events for governance review), F-008 (workspace storage for default-stage settings)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M13 row | F-100 named as image preprocessing NEW feature |
| kit:session-requests.md Message 11 | Multimodal NEW set includes screenshot-to-prompt; preprocessing is the privacy boundary on that path |
| kit:rules/no-silent-deferrals.md | Auto-redaction, OCR, format-conversion, EXIF-toggle, multi-frame all named with deferral rationale; EXIF strip is ALWAYS-ON (privacy-by-default) |

## Implementation notes

(empty — populated when implementation begins; ML auto-redaction roadmap and per-skill override design closed at M13 design wave)
