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
feature-id: F-097
short-slug: voice-engine-selection
milestone: M13
provenance:
  surfaces:
    - kit:foundational-plan.md M13 row (F-096..F-100 multimodal NEW)
    - kit:session-requests.md Message 11
    - kit:docs/10-backlog/design-decisions-pending.md D-4 (multi-tier model routing — adjacent precedent for engine-policy defaults)
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
  LOCKED if GREEN AND reviews/F-097-voice-engine-selection-review.md exists with verdict: ACCEPT.
depends-on: [F-008, F-067]
out-of-scope-notes: |
  Cloud STT engines (Azure Speech, OpenAI Whisper-API, Deepgram) are post-v1 — v1 ships
  ONLY the two engines named in this ledger: Web Speech API (default) + Whisper-local
  (upgrade path). The D-4-style "router policy default" is referenced as adjacent precedent
  but D-4 itself governs LLM tier-routing, not STT-engine routing; an STT-specific design
  decision (call it D-4-STT) will close at the M13 design wave council-review for the
  v1.5 cloud-engine additions. Per-skill or per-automation engine override is v1.5; v1
  is a single global engine selection per workspace. Cost-aware routing (downgrade on
  battery / cellular) is post-v1.
confidence: high
---

# F-097 — Voice engine selection

## Behavior contract

The settings surface (F-067) exposes a single-select engine picker for STT with two v1 options: `web-speech-api` (DEFAULT per D-4-style frontier-2026 default — browser-native, zero-install, online-only) and `whisper-local` (upgrade path — local model file, offline-capable, larger install footprint). Selection is persisted per workspace (F-008 storage) and read by F-096 at capture time. Switching engines mid-session is allowed; the next utterance uses the new selection. An invalid persisted value (e.g., a v1.5 cloud-engine name written by a downgrade) MUST fall back to `web-speech-api` and surface a one-time `STT_ENGINE_FALLBACK` warning to the user; no silent default change is permitted.

## Acceptance scenarios

1. **Given** a fresh workspace with no STT engine setting persisted, **When** the user opens the settings surface and inspects the STT engine field, **Then** the field shows `web-speech-api` as the selected default and the persisted value is written on first read so subsequent reads are deterministic.
2. **Given** a user with `whisper-local` selected and the model file present, **When** F-096 captures an utterance, **Then** F-096's transcription is routed through the local Whisper engine (verified via the engine-id field on the emitted transcript event) and no network call is made.
3. **Given** a workspace whose persisted STT engine is `azure-speech` (a v1.5 value not recognized by v1), **When** the engine is loaded at bootstrap, **Then** the engine falls back to `web-speech-api`, surfaces a `STT_ENGINE_FALLBACK { from: azure-speech, to: web-speech-api, reason: unrecognized_engine }` warning, and writes `web-speech-api` back to storage.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/multimodal/stt-engine-default-web-speech.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/multimodal/stt-engine-whisper-local-routing.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/multimodal/stt-engine-unknown-fallback.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-008 (workspace storage persists the selection), F-067 (settings UI exposes the picker)
- **Soft:** F-096 (consumes the selection at capture time), F-098 (activation modes do not change engine selection)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M13 row | F-097 named as engine selection NEW feature |
| kit:session-requests.md Message 11 | User-stated answer: voice + screenshot-to-prompt are NEW v1 multimodal surfaces |
| kit:docs/10-backlog/design-decisions-pending.md D-4 | Adjacent multi-tier-routing precedent — same "rules-based default with override" shape applied to STT-engine routing |

## Implementation notes

(empty — populated when implementation begins; D-4-STT design closure at M13 design wave decides v1.5 cloud-engine roster + cost-aware routing policy)
