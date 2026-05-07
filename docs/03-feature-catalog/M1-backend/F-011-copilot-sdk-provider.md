---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-011
short-slug: copilot-sdk-provider
milestone: M1
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
    - cp:src/services/llm/copilot
    - kit:.claude/scripts/Invoke-CopilotMultiModel.ps1
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
  LOCKED if GREEN AND reviews/F-011-copilot-sdk-provider-review.md exists with verdict: ACCEPT.
depends-on: [F-009]
out-of-scope-notes: |
  Multi-model adversarial dispatch (--council pattern) is owned by M10 (F-082..F-087).
  This feature implements Copilot as one of the providers; the dispatch orchestration
  that selects two-providers-in-parallel lives in M10.
confidence: high
---

# F-011 — GitHub Copilot SDK provider

## Behavior contract

`CopilotProvider` is a concrete `IBackendProvider` wrapping the GitHub Copilot CLI / SDK (`copilot --yolo -p ...` or the equivalent Node SDK when stable). It supports model selection (Claude Opus / GPT-5+ / etc. per Copilot's exposed catalog), streams text deltas mapped to the F-013 normalized shape, and respects cancellation. Authentication uses GitHub's device-flow OAuth; the token is stored per F-070 (deferred — M1 reads from env `COPILOT_TOKEN` with the same `[NEEDS CLARIFICATION]` shape as F-010).

## Acceptance scenarios

1. **Given** a valid Copilot token and `model: "gpt-5"`, **When** `provider.complete("Hello", {model: "gpt-5"})` is iterated, **Then** the stream yields normalized text_delta events and final `message_stop`.
2. **Given** a Copilot CLI that is not installed on the host, **When** the provider is constructed, **Then** the constructor throws `ConfigurationError: copilot CLI not found` with a remediation hint pointing at the install instructions.
3. **Given** an in-progress completion and a `cancel(handle)` call, **When** the cancellation propagates, **Then** the underlying child process is killed and no further deltas arrive.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/backend/copilot-stream.test.ts` | integration | RED — recorded fixture | scenario 1 |
| (TBD) `tests/unit/backend/copilot-cli-missing.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/backend/copilot-cancel.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-009 (must conform to interface)
- **Soft:** F-013 (event normalization shape), F-019 (cost ledger consumes token counts)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | dispatch shape used in --council mode |
| cp:src/services/llm/copilot | clawpilot Copilot SDK wrapping pattern |
| kit:Invoke-CopilotMultiModel.ps1 | local dispatcher precedent for parallel CLI invocation |

## Implementation notes

(empty — populated when implementation begins)
