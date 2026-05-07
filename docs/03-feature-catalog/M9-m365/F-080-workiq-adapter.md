---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-080
short-slug: workiq-adapter
milestone: M9
provenance:
  surfaces:
    - cp:@microsoft/workiq ^0.4.1
    - cp:electron/m365/calendar-tools.ts
    - cp:electron/m365/email-tools.ts
    - cp:electron/m365/teams-tools.ts
    - cp:electron/m365/onedrive-tools.ts
    - cp:electron/m365/people-tools.ts
    - cp:electron/m365/graph-query.ts
    - cp:electron/m365/m365-tools.ts
    - cp:pnpm test:m365
    - R:microsoft-2026/workiq-internal-context.md
    - R:microsoft-2026/workiq-a2a-impl-patterns.md
    - R:microsoft-2026/m365-copilot-extensibility.md
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
  LOCKED if GREEN AND reviews/F-080-workiq-adapter-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-076, F-079]
out-of-scope-notes: |
  WRITE operations (post Teams message, send email, create event) are explicitly
  OUT for v1 per G12 ("readonly Microsoft solutions"). The adapter exposes
  read-only surfaces for v1; write operations are a v1.5 feature with explicit
  consent gating per dangerous-operations-policy.md.
  MIP sensitivity-label elevation (MIP labels seen on documents triggering
  consent prompts) is a clawpilot feature deferred to v1.5.
  Sensitivity-elevation logic (electron/sensitivity-elevation.ts) is out of
  scope; engine v1 surfaces labels but does not gate on them.
confidence: high
---

# F-080 — WorkIQ adapter (read-only)

## Behavior contract

The engine MUST expose internal Microsoft 365 context to its run-time grounding loop via a WorkIQ adapter (`@microsoft/workiq` v0.4.1 or compatible). The adapter is READ-ONLY for v1: it surfaces Teams chats / emails / calendar events / SharePoint items / OneDrive files / People context / Presence — but does NOT post, send, create, or modify any Microsoft 365 resource. Every adapter call uses the access token from F-076/F-077 (refreshed via F-079) and is wrapped by F-081's rate-limit + circuit-breaker. The adapter normalizes WorkIQ responses into engine-internal context records that downstream agents consume; PII redaction at egress (per F-017) applies if any adapter output is forwarded outside the engine.

## Acceptance scenarios

1. **Given** an authenticated engine with a valid M365 token, **When** the engine queries WorkIQ for "recent Teams chats with @user", **Then** the adapter returns the read-only chat snippets from WorkIQ within rate-limit + CB constraints, normalized to the engine's context record shape.
2. **Given** an attempt to invoke any write operation (e.g., `sendMessage`, `createEvent`), **When** the adapter is called, **Then** the call is rejected at the adapter boundary with `WORKIQ_WRITE_DISABLED_V1` and the rejection is logged to the audit log per F-015.
3. **Given** a successful read response containing PII (email addresses, names, identifiers), **When** the engine forwards that context to an agent that emits to an external surface, **Then** F-017 PII redaction at egress fires before the data leaves the engine.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/workiq/read-teams-chats.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/workiq/write-rejected.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/workiq/pii-redaction-on-egress.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine cycles consume WorkIQ context), F-076 (MSAL token), F-079 (refreshed token before each call)
- **Soft:** F-077 (WAM token path on Windows), F-081 (rate-limit + CB wraps adapter calls), F-017 (PII redaction at egress), F-015 (write-rejection logged to audit chain), F-022 (per-cycle WorkIQ tool quota)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:@microsoft/workiq ^0.4.1 | WorkIQ SDK version pin (clawpilot baseline; Microsoft AI internal-only package) |
| cp:electron/m365/calendar-tools.ts | calendar read surface pattern |
| cp:electron/m365/email-tools.ts | email read surface pattern |
| cp:electron/m365/teams-tools.ts | Teams chat read surface pattern |
| cp:electron/m365/onedrive-tools.ts | OneDrive file read surface pattern |
| cp:electron/m365/people-tools.ts | People + persona-photo read surface pattern |
| cp:electron/m365/graph-query.ts | Graph query helper used under WorkIQ for direct MSGraph fallback |
| cp:electron/m365/m365-tools.ts | top-level adapter orchestration |
| cp:pnpm test:m365 | dedicated M365 integration test runner pattern |
| R:microsoft-2026/workiq-internal-context.md | Project Lobster + read-only-by-default discipline |
| R:microsoft-2026/workiq-a2a-impl-patterns.md | A2A v1.0 patterns informing WorkIQ adapter shape (Teams SDK plugin pattern is closest analogue) |
| R:microsoft-2026/m365-copilot-extensibility.md | M365 Copilot extensibility surface — frames why read-only is the right boundary |

## Implementation notes

(empty — populated when implementation begins)
