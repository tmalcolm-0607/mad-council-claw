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
feature-id: F-096
short-slug: voice-input-stt
milestone: M13
provenance:
  surfaces:
    - kit:foundational-plan.md M13 row (F-096..F-100 multimodal NEW)
    - kit:session-requests.md Message 11 (multimodal input — voice + screenshot-to-prompt)
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
  LOCKED if GREEN AND reviews/F-096-voice-input-stt-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-097]
out-of-scope-notes: |
  Engine SELECTION (which STT engine: Web Speech API vs Whisper-local vs cloud) is F-097's
  scope, not this ledger's. Activation MODES (push-to-talk vs wake-word vs always-listening)
  are F-098's scope. This ledger contracts only the *input pipeline shape*: capture audio →
  emit transcribed text → hand to the prompt buffer. Multi-language transcription (non-en-US)
  is post-v1 — v1 ships en-US default per Message 11 silence on locale. Real-time streaming
  partials (interim transcripts before utterance-end) are v1.5 — v1 emits final transcript
  on utterance-end. Speaker diarization (multi-speaker meeting capture) is F-D-016
  in-meeting-live-assistant scope, NOT this ledger.
confidence: high
---

# F-096 — Voice input STT

## Behavior contract

The desktop shell exposes a microphone-input affordance that, on user activation (per F-098), captures audio from the system default input device, routes it through the engine selected by F-097, and emits a final transcript string to the active prompt buffer. The transcript is delivered as a single text event on utterance-end (no interim partials in v1). Engine errors (mic permission denied, engine init failure, network drop for cloud STT) reject with `STT_INPUT_ERROR` + a typed sub-code (`MIC_PERMISSION_DENIED`, `ENGINE_INIT_FAILURE`, `ENGINE_TRANSPORT_FAILURE`) and surface to the user; no partial / lossy text reaches the prompt buffer. Audio buffers are NEVER persisted to disk in v1 — capture is in-memory only and the buffer is zeroed after transcription completes.

## Acceptance scenarios

1. **Given** a user with microphone permission granted and Web Speech API selected (per F-097 default), **When** the user activates the mic affordance, speaks "open the project workspace", and stops speaking, **Then** within engine-bound latency the prompt buffer receives the exact final transcript string and no audio buffer remains in memory.
2. **Given** the OS denies microphone access at engine bootstrap, **When** the user activates the mic affordance, **Then** the engine rejects with `STT_INPUT_ERROR { sub_code: MIC_PERMISSION_DENIED }`, surfaces a user-visible permission-denied prompt, and does NOT write any partial transcript to the prompt buffer.
3. **Given** a Whisper-local engine selection (per F-097 upgrade path) and the model file missing from the configured path, **When** the user activates the mic affordance, **Then** the engine rejects with `STT_INPUT_ERROR { sub_code: ENGINE_INIT_FAILURE, engine: whisper-local }` and the user is prompted to either install the model or switch engine.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multimodal/stt-final-transcript.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/multimodal/stt-mic-permission-denied.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/multimodal/stt-engine-init-failure.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine bootstrap registers the STT pipeline), F-008 (storage path for engine-specific config), F-097 (engine selection determines transcription transport)
- **Soft:** F-098 (activation modes invoke the capture loop), F-099 (image input is a sibling multimodal channel sharing the same prompt-buffer contract)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M13 row | F-096 named as the voice STT NEW feature |
| kit:session-requests.md Message 11 | User-stated answer: multimodal input (voice + screenshot-to-prompt) is in scope |
| kit:rules/no-silent-deferrals.md | Out-of-scope notes name the F-NNN that DOES cover diarization (F-D-016), partials (v1.5), locale (post-v1) |

## Implementation notes

(empty — populated when implementation begins; engine-selection D-4-adjacent decisions inform F-097, not this ledger)
