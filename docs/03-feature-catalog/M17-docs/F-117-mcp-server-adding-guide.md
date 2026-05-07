---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-117
short-slug: mcp-server-adding-guide
milestone: M17
provenance:
  surfaces:
    - cp:docs/mcp
    - kit:rules/mcp-tiering.md
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/prompt-injection-policy.md
    - foundational-plan.md M17 docs section
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
  LOCKED if GREEN AND reviews/F-117-mcp-server-adding-guide-review.md exists with verdict: ACCEPT.
depends-on: [F-029, F-115]
out-of-scope-notes: |
  Building / publishing your own MCP server (server-side authoring) is OUT —
  the guide is for ADDING an existing MCP server to the engine. MCP-server
  marketplace UX is OUT (M11+ scope). Auto-discovery of locally-installed MCP
  servers is v1.5. Cross-machine MCP routing is OUT for v1 (local stdio /
  HTTP only). Per-server credential vaulting is M8 settings concern; the guide
  references it but doesn't re-document. OAuth-based MCP server auth setup is
  v1.5.
confidence: high
---

# F-117 — MCP server adding guide

## Behavior contract

The repo MUST ship `docs/mcp-server-adding-guide.md` covering: (1) what an MCP server IS (Model Context Protocol primer with link to the official spec), (2) how the engine discovers and loads MCP servers from settings (per F-029 MCP runtime), (3) the two transport classes (stdio command + URL/HTTP) and when to use each, (4) the tier model (`context` vs. `cli`) per `rules/mcp-tiering.md` and the 5-server cap on context-tier, (5) declaring tool allowlists / consent requirements per `rules/dangerous-operations-policy.md` for any server whose tools mutate external state, (6) the prompt-injection threat model per `rules/prompt-injection-policy.md` — every MCP server is an untrusted input source until proven otherwise, (7) a worked end-to-end example (adding the `msft-learn` MCP server: settings entry → tier classification → first tool call), (8) common anti-patterns (wildcard tool allowlists, context-tier servers with >5 tools, missing consent gates). The guide MUST link the engine's MCP runtime contract (F-029) for every claim about runtime behavior — no claims without ledger citations per `rules/verification-protocol.md`.

## Acceptance scenarios

1. **Given** an engineer with a working engine and an MCP server they want to add (e.g. `msft-learn`), **When** they follow the guide step-by-step, **Then** the server appears in the running engine's tool list within 5 minutes wall-clock, the first tool call returns successfully, and the server is correctly tier-classified per `rules/mcp-tiering.md`.
2. **Given** the guide's section on dangerous-tool consent, **When** an engineer adds an MCP server with a state-mutating tool, **Then** the guide's worked example shows the explicit consent declaration in the server's tool allowlist, and the runtime behavior shows the consent prompt firing on first use of that tool.
3. **Given** the guide describes the prompt-injection threat model, **When** an engineer reads section 6, **Then** they understand that MCP server outputs are data not instructions, the guide cites `rules/prompt-injection-policy.md` Rule 1, and the section names the absence of automatic content-sanitization explicitly (per `rules/no-silent-deferrals.md`).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/e2e/docs/mcp-add-server-wallclock.test.ts` | e2e | RED | scenario 1 |
| (TBD) `tests/integration/docs/mcp-guide-consent-walkthrough.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/docs/mcp-guide-injection-section-citations.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-029 (MCP runtime; the guide describes its surface), F-115 (architecture docs cross-link MCP boundary)
- **Soft:** F-067 (M8 settings; credential vaulting reference), every kit rule referenced (mcp-tiering / dangerous-operations / prompt-injection)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:docs/mcp | clawpilot MCP docs starting reference (if present); engine adapts to its own runtime |
| kit:rules/mcp-tiering.md | tier model is the centerpiece of the loading + cap discussion |
| kit:rules/dangerous-operations-policy.md | guide explicitly walks through declaring consent for state-mutating tools |
| kit:rules/prompt-injection-policy.md | guide section 6 frames every MCP server as an untrusted input source |
| foundational-plan.md M17 | docs scope: MCP-server-adding is one of the 5 M17 deliverables |

## Implementation notes

(empty — populated when implementation begins)
