---
artifact-class: milestone-overview
generated-by: hand-authored (wave-006 / lane-b)
status: red
milestone: M13
short-slug: multimodal
features: F-096..F-100
authored: 2026-05-06
---

# M13 — Multimodal input NEW

The first NEW-per-Message-11 milestone (`session-requests.md` Message 11 + `foundational-plan.md` M13 row). Voice + screenshot are the v1 multimodal channels; both flow into the same prompt buffer. Voice has its own engine + activation surface; image has its own preprocessing + vision-routing surface. A run lacking M13 ships a text-only chat shell — usable, but missing the inputs Message 11 names as in-scope.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-096 | voice-input-stt | Capture audio → emit final transcript to prompt buffer; in-memory only; typed STT_INPUT_ERROR sub-codes |
| F-097 | voice-engine-selection | Settings picker; Web Speech API default (D-4-style policy), Whisper-local upgrade path; unknown-engine fallback |
| F-098 | voice-activation-modes | Push-to-talk / wake-word / always-listening; always-listening = explicit consent gate per workspace |
| F-099 | screenshot-to-prompt | Clipboard image paste → vision-capable model dispatch; mixed clipboard preserves both modalities |
| F-100 | image-preprocessing | Crop / annotate / redact pipeline; EXIF strip ALWAYS-ON; cancel drops in-memory original |

## Dependency DAG

```
M0 (F-001 kernel, F-008 storage) ──→ all M13 features
M1 (F-014 [per brief — see anomaly note] / F-124 multi-tier-routing) ──→ F-099 (vision-model dispatch)
M5 (F-040 keyboard-shortcuts) ──→ F-098 (push-to-talk binding)
M8 (F-067 settings-shape) ──→ F-097, F-098, F-100 (per-workspace pickers)

F-097 (engine selection) ──→ F-096 (capture routes through selected engine)
F-098 (activation mode) ──→ F-096 (mode invokes capture loop)
F-099 (screenshot) ──→ F-100 (preprocessing fires before send)
F-100 (preprocessing) ──→ F-099 (returns preprocessed image to dispatch)

F-098 always-listening ──→ rules/dangerous-operations-policy.md (consent gate)
F-100 EXIF strip ──→ privacy-by-default (no toggle)
```

## Milestone exit criteria

- All 5 ledgers GREEN
- Mic permission denial surfaces typed `STT_INPUT_ERROR { sub_code: MIC_PERMISSION_DENIED }` (no silent failure)
- Default STT engine on a fresh workspace is `web-speech-api`; an unknown persisted engine falls back with a `STT_ENGINE_FALLBACK` warning
- `always-listening` mode requires explicit consent on every workspace switch and every fresh app install
- A pasted image without a vision-capable active tier rejects send with `VISION_ROUTING_UNAVAILABLE { active_tier: <name> }`
- Image preprocessing strips EXIF metadata in 100% of dispatched images (no toggle to disable)
- Cancel-during-preprocess drops the in-memory original; no path to send the un-edited original

## Pending design decisions blocking M13 implementation

- **D-4-STT** — STT engine routing policy v1 default (web-speech-api default; Whisper-local upgrade path). Adjacent precedent: D-4 multi-tier model routing. Closure: M13 design wave council-review.
- **F-014 vs F-124 dependency naming on F-099** — Brief states F-099 depends on `F-014 multi-tier-routing` but the catalog's F-014 is `pre-close-retro-signal` (M2). The actual multi-tier-routing feature per `foundational-plan.md` line 425 is F-124 (M1 NEW frontier candidate). Honored brief literal in F-099 ledger; lane summary surfaces the mismatch for council-reconciliation.
- **Default wake phrase** for `wake-word` mode (F-098). Provisional: "hey claw"; closure at M13 design wave.
- **Always-listening consent expiry** policy (per workspace? per session? per app install?). F-098 contracts "re-fire on every workspace switch and every fresh app install"; reconfirm at M13 design wave.

## Out of scope (tracked elsewhere)

- Cloud STT engines (Azure Speech, OpenAI Whisper-API, Deepgram) — v1.5 (per F-097 out-of-scope-notes)
- Multi-language transcription (non-en-US) — post-v1
- Real-time streaming partials (interim transcripts) — v1.5
- Speaker diarization / multi-speaker meeting capture — F-D-016 in-meeting-live-assistant (deferred)
- Custom wake-word training — post-v1
- Multi-user voice-print discrimination — v1.5 (FR-IDENTITY-002 family)
- Drag-and-drop image into prompt buffer — v1.5
- Multi-image prompts — v1.5
- Camera / webcam capture — post-v1
- ML-driven auto-redaction (face / license-plate / signature) — post-v1
- OCR text extraction from screenshots — v1.5
- Image format conversion (HEIC etc.) — v1.5
- Multi-frame analysis on animated images — post-v1
- Per-skill or per-automation preprocessing override — v1.5

## Provenance

`kit:foundational-plan.md` M13 row (line 414), `kit:session-requests.md` Message 11 (line 61), `kit:rules/{no-silent-deferrals, dangerous-operations-policy, no-invented-constraints, verification-protocol}.md`, `kit:docs/10-backlog/design-decisions-pending.md` D-4 (adjacent multi-tier-routing precedent). Per-ledger `provenance.surfaces`. Note: M13 has no `ce:` (canonical-e) provenance — multimodal is NEW per Message 11, not a canonical-e FR family. No `cp:` (clawpilot) provenance — clawpilot has no voice or screenshot-to-prompt precedent (confirmed via wave-001 lane-c clawpilot-features-inventory.md).
