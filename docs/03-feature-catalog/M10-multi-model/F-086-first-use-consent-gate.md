---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-086
short-slug: first-use-consent-gate
milestone: M10
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
    - kit:rules/dangerous-operations-policy.md
    - ce:US-7
    - ce:FR-MULTI-001
    - cp:wave-002-wave-003-copilot-cli-design-review
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
  LOCKED if GREEN AND reviews/F-086-first-use-consent-gate-review.md exists with verdict: ACCEPT.
depends-on: [F-082]
out-of-scope-notes: |
  Per-invocation re-prompting (every dispatch re-asks for consent) is explicitly NOT the
  v1 behavior — the rule re-uses session-scoped consent. Per-invocation consent is a
  M19-deferred candidate if heightened-trust environments require it.
  Consent revocation mid-session is also out of scope for v1.
confidence: high
---

# F-086 — First-use-per-session consent gate

## Behavior contract

The first time `--council` mode is invoked in a session against a Copilot-CLI-available host (i.e., not the same-model fallback path of F-085), the orchestrator MUST emit an `AskUserQuestion` consent prompt per `kit:rules/dangerous-operations-policy.md` § Cross-org A2A Bridge category. The prompt previews: (a) the brief content, (b) the target models (Claude Opus + GPT-5+), (c) the `OutputDir` where results will land. The prompt waits for explicit "yes". On approval, the consent decision is logged to `<channel>/consent-log.jsonl` per the dangerous-operations enforcement table. Subsequent `--council` invocations in the SAME session reuse that consent — the user is NOT re-prompted per invocation. The consent gate does NOT fire for the same-model fallback path (no third-party egress occurs).

## Acceptance scenarios

1. **Given** a fresh session with Copilot CLI available, **When** the user invokes `--council` for the first time, **Then** an `AskUserQuestion` consent prompt fires showing brief preview + target models + OutputDir; on "yes" the dispatch proceeds AND `<channel>/consent-log.jsonl` carries an entry with `{ts, user, operation: "multi-model-dispatch", decision: "yes", input}`.
2. **Given** consent was granted earlier in the same session, **When** the user invokes `--council` a second time, **Then** the dispatch proceeds WITHOUT re-prompting; consent-log still carries the original entry with no duplicate.
3. **Given** Copilot CLI is unavailable (same-model fallback path per F-085), **When** the user invokes `--council`, **Then** the consent gate does NOT fire (verified by absence of `AskUserQuestion` emission and absence of consent-log entry).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multi-model/consent-gate-first-use.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/multi-model/consent-gate-reused-in-session.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/multi-model/consent-gate-skipped-on-fallback.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-082 (consent gate fires before first dispatch)
- **Soft:** F-085 (consent explicitly bypassed on fallback path), F-015 (consent-log entries also flow into hash-chained audit log)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | § Mechanism — "Consent gate (first-use per session)" exact prompt shape |
| kit:rules/dangerous-operations-policy.md | § Cross-org A2A Bridge category — boundary classification + enforcement table |
| ce:US-7 | Adversarial cross-check user story; consent reflects third-party egress trust boundary |
| ce:FR-MULTI-001 | FR mandates explicit user consent for cross-process model dispatch |
| cp:wave-002-wave-003-copilot-cli-design-review | Production proof: per-session consent reuse pattern (avoiding consent fatigue) |

## Implementation notes

(empty — populated when implementation begins)
