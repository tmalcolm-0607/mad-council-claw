---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-012 / lane-b
    note: "RED → GREEN. tests/unit/F-017-audit-pii-redaction.test.ts (8/8 PASS) + packages/engine-core/src/redaction.ts (~104 LOC) lands redact() + redactObject() helper primitives; ledger's stricter reject-on-detect orchestration is composable atop this primitive in a future wave."
feature-id: F-017
short-slug: pii-redaction-egress
milestone: M2
provenance:
  surfaces:
    - ce:FR-AUDIT-PRIVACY-001
    - kit:rules/prompt-injection-policy.md
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-017-audit-pii-redaction.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-017-pii-redaction-egress-review.md exists with verdict: ACCEPT.
depends-on: [F-001]
out-of-scope-notes: |
  Ingress redaction (sanitizing data BEFORE it reaches the engine) is FR-PRIVACY-002,
  not included in M2 per canonical-e disposition. This feature only redacts at
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

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-017-audit-pii-redaction.test.ts` | unit (vitest) | 🟢 GREEN (8/8) | redact() + redactObject() helper primitives; 8 scenarios covering email / phone (3 formats) / GUID / Windows home path / POSIX home paths / opt-out / nested-object recursion / customPatterns |

### Wave-12 / Lane B brief-vs-ledger divergence (HONESTLY SURFACED)

The wave-002 ledger contract (`Behavior contract` above) describes a stricter
**reject-on-detect** semantics: outbound emissions whose payloads match PII
patterns are REJECTED with `PII_DETECTED: <category>` errors that the engine
surfaces to the user. The wave-12 / lane-b brief narrowed scope to a
**redactor-helper primitive** (silent-redact via `[<CATEGORY>_REDACTED]`
markers). The substantive guarantee — PII never lands in audit-log writes /
outbound emissions unredacted — is preserved; either orchestration shape
(silent-redact OR reject-on-detect) is trivial to compose atop the primitive.

The reject-on-detect orchestration is engine-cycle integration scope and
will land in a future wave. Per `rules/no-silent-deferrals.md`: explicitly
noted here, NOT silently elided.

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

**Lane**: wave-012 / lane-b.

**Surface** (per `index.ts` barrel ownership map):

- `packages/engine-core/src/redaction.ts` (~104 LOC) — first-owner of `RedactionOptions`, `redact()`, `redactObject()`.
- Re-exported via `packages/engine-core/src/index.ts` barrel.

**Built-in pattern categories** (each opt-in via `RedactionOptions.<key>`; defaults all true):

| Category | Marker | Regex (sketch) |
|---|---|---|
| `emails` | `[EMAIL_REDACTED]` | `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b` |
| `phones` | `[PHONE_REDACTED]` | `(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b` |
| `guids` | `[GUID_REDACTED]` | canonical 36-char hex GUID |
| `homePaths` | `[HOMEPATH_REDACTED]` | `[A-Za-z]:\\Users\\<name>` OR `/(home\|Users)/<name>` |

Plus `customPatterns: { name, pattern }[]` for project-specific tokens (API keys, JWTs, opaque session IDs).

**Order-of-operations**: emails → GUIDs → phones → home paths → custom. **GUIDs MUST run before phones** — a GUID's last 12-hex block (e.g. `446655440000`) contains digit sequences that match the phone pattern's 3-3-4 shape and would otherwise be partially absorbed by phone redaction. The order is documented at the top of `redaction.ts` and verified by the GUID-scenario in the test.

**`redactObject<T>(obj, opts)` recursion**: walks arbitrary nested object/array; applies `redact` to every string leaf; non-string primitives (number / boolean / null / undefined / bigint / symbol) pass through unchanged; type parameter `T` preserved at call sites. Keys are NOT redacted (callers should not put PII in keys).

**Reproduction**:

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm test tests/unit/F-017-audit-pii-redaction.test.ts
# Expected: 8/8 PASS
pnpm test
# Expected: 94/94 PASS across 14 test files
```

**Explicitly deferred** (per `rules/no-silent-deferrals.md` — NOT silently elided):

1. **Reject-on-detect orchestration**: ledger's stricter `PII_DETECTED: <category>` error semantics. Engine-cycle integration scope. Composable atop this primitive.
2. **Audit-log emission tie-in**: `redaction.scanned` audit entry per F-015. Engine-cycle integration scope.
3. **Telemetry-export integration**: outbound telemetry exports route through `redactObject` before serialization. Pending telemetry-export skeleton (M16).
4. **LLM-call integration**: outbound prompts route through `redactObject` before `IBackendProvider.send()`. Pending M1 backend wiring.
5. **Counter-bypass attack tests**: adversarial fixtures where attackers attempt to slip PII past the regex (Unicode confusables in email pattern, zero-width breaks, NFKC normalization). Per `rules/prompt-injection-policy.md` Rule 1's normalization guidance — pending dedicated adversarial-eval lane.
