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
feature-id: F-017
short-slug: pii-redaction-egress
milestone: M2
provenance:
  surfaces:
    - ce:FR-AUDIT-PRIVACY-001
    - kit:rules/prompt-injection-policy.md
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
  LOCKED if GREEN AND reviews/F-017-pii-redaction-egress-review.md exists with verdict: ACCEPT.
depends-on: [F-001]
out-of-scope-notes: |
  Ingress redaction (sanitizing data BEFORE it reaches the engine) is FR-PRIVACY-002,
  deferred to v1.5 per canonical-e disposition. This feature only redacts at
  egress: outbound LLM calls, audit-log emissions to external sinks, telemetry exports.
confidence: high
---

# F-017 — PII redaction at egress

## Behavior contract

Every outbound emission from the engine (LLM API calls, telemetry exports, external audit-log shipping) passes through a redaction layer that rejects literal repository paths, alias strings, code snippets above a threshold, secrets matching common patterns (API keys, JWTs, AWS access keys), and IP addresses. Detection is case-insensitive normalized (NFKC) substring + regex match. On match, the egress call is rejected with `PII_DETECTED: <category>`; the engine surfaces the rejection to the user — never silently strips and continues.

## Acceptance scenarios

1. **Given** an outbound LLM call whose prompt contains the literal string `C:\Users\jdoe\secret.env`, **When** the redaction layer scans it, **Then** the call is rejected with `PII_DETECTED: filesystem_path` and a remediation hint.
2. **Given** an outbound telemetry export whose payload includes `sk-ant-api03-...` (Anthropic API key shape), **When** the redaction scans, **Then** the export is rejected with `PII_DETECTED: secret_pattern: anthropic_api_key`.
3. **Given** an outbound emission with no PII patterns, **When** the layer scans, **Then** the call passes through unchanged and a `redaction.scanned` audit entry is logged.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/redaction/filesystem-path.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/redaction/secret-patterns.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/redaction/clean-passthrough.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine is the egress gateway)
- **Soft:** F-006 (logger emits redaction.scanned + rejections), F-015 (audit log records every scan)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-AUDIT-PRIVACY-001 | Outbound emission rejects literal repo/alias/code/secrets/IP |
| kit:rules/prompt-injection-policy.md | Treats outbound payloads as untrusted by default |

## Implementation notes

(empty — populated when implementation begins)
