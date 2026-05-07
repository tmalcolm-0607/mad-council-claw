---
artifact-class: feature-ledger
generated-by: hand-authored (wave-012 / lane-c)
status: red
status-since: 2026-05-07
status-history:
  - status: planned
    at: 2026-05-06
    by: foundational-plan.md catalog deltas
    note: "F-NNN reserved as one of 5 frontier-research candidates"
  - status: red
    at: 2026-05-07
    by: wave-012 / lane-c
    note: "Initial ledger created; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-125
short-slug: mcp-tool-cap-per-workspace
milestone: M7
provenance:
  surfaces:
    - foundational-plan.md "Plus 5 NEW F-NNN candidates" F-125
    - foundational-plan.md "[R:WorkIQ internal tool-explosion lesson]"
    - foundational-plan.md § Architecture (Tool plane: tool-cap per workspace, default 10)
    - docs/06-agent-team-outputs/wave-001/lane-b-summary.md (finding 15 — WorkIQ internal tool-explosion lesson)
    - kit:rules/no-invented-constraints.md (engine MUST NOT silently invent the default cap)
    - foundational-plan.md D-3 (open decision: is 10 the right default value?)
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
  LOCKED if GREEN AND reviews/F-125-mcp-tool-cap-per-workspace-review.md exists with verdict: ACCEPT.
depends-on: [F-073, F-049, F-058, F-067, F-044]
out-of-scope-notes: |
  ML-driven adaptive cap (auto-shrinking based on observed context-bloat) — out for v1;
  v1 default is a static cap per workspace per the foundational-plan tool-plane guidance.
  Per-tool-class caps (e.g. cap reads-vs-writes separately) — v1.5; v1 caps total active
  tool count.
  Cap on the MCP server count itself (vs the tool count) — adjacent concern; F-049 BYO-MCP
  governs server installation; F-125 governs the tools surfaced from those servers.
  Per-session cap (vs per-workspace) — per-session toggle is F-053; per-workspace is the
  durable scope where the cap belongs.
  Cap enforcement at MCP-protocol level (rejecting tool/list responses past the cap) —
  v1.5 / D-3 follow-up; v1 enforces at the engine's tool-registry layer when surfacing
  tools to the LLM, not at the MCP wire level.
  D-3 closure (default value of 10 — is 10 right?) is OPEN; this ledger's working
  assumption is 10 per foundational-plan; if D-3 closes differently, the constant
  changes and this ledger's tests update accordingly.
confidence: high
---

# F-125 — MCP tool-cap per workspace

## Behavior contract

The engine MUST enforce a per-workspace cap on the number of MCP-surfaced tools active
in any single LLM call (default value 10 per foundational-plan tool-plane guidance;
D-3 OPEN regarding whether 10 is the right default). The cap is a property of the
workspace (per F-073), not a global engine setting; each workspace declares its own
`mcp_tool_cap` integer in workspace settings. When the active workspace's enabled
MCP servers (per F-049 BYO-MCP) collectively expose more than the cap, the engine MUST
require the user to explicitly select which subset of tools is surfaced (via the
permissions UI per F-058 / settings per F-067); silent truncation is forbidden per
`rules/no-invented-constraints.md` (the engine cannot pick which tools to drop on the
user's behalf). The selection is durable (persisted in workspace settings per F-073).
Cap = 0 disables MCP tools for that workspace entirely. Raising the cap triggers a
structured warning in the audit log (per F-060) noting the new cap and the workspace
id; cap raises do NOT require Dangerous Operation consent (the user is intentionally
opting in to more context). Tool-cap exhaustion at LLM-call time emits a
`MCP_TOOL_CAP_EXCEEDED` normalized event (per F-013) with the workspace id, current
cap, and the count of attempted-but-suppressed tools.

## Acceptance scenarios

1. **Given** a workspace with `mcp_tool_cap: 10` and 3 enabled MCP servers exposing
   8 tools total, **When** the engine prepares an LLM call, **Then** all 8 tools are
   surfaced (under the cap) and no warning fires.
2. **Given** a workspace with `mcp_tool_cap: 10` and 4 enabled MCP servers exposing
   15 tools total, **When** the user has not yet selected a subset, **Then** the
   engine refuses to issue the LLM call and emits `MCP_TOOL_CAP_REQUIRES_SELECTION`
   with the workspace id, the cap (10), the actual tool count (15), and the per-server
   tool inventory; the permissions UI (per F-058) prompts the user to select 10.
3. **Given** a workspace where the user has selected 10 of 15 tools, **When** the
   engine issues the LLM call, **Then** exactly the selected 10 tools are surfaced;
   the tool list is stable across repeat calls in the same session; the audit log
   (per F-060) records the selection's hash for tamper detection.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/mcp/tool-cap-under-limit.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/mcp/tool-cap-requires-selection.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/mcp/tool-cap-selection-stable-and-audited.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-073 (project-workspace; cap is a per-workspace setting), F-049 (BYO-MCP;
  the MCP servers whose tools count toward the cap), F-058 (3-tier permissions
  classifier hosts the per-tool selection UI), F-067 (settings shape stores the cap
  value), F-044 (MCP bridge enumerates tools from each server)
- **Soft:** F-051 (skills are NOT counted in the tool cap; the cap governs MCP-surfaced
  tools only), F-060 (permissions audit captures cap raises + selection hashes),
  F-013 (`MCP_TOOL_CAP_EXCEEDED` is a normalized event)
- **Independent:** F-122 (A2A endpoint exposure surfaces the engine's capabilities to
  peers; F-125 is the inverse — capping inbound tool capacity)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan.md F-125 | reserved F-NNN allocation; M7 placement; "[R:WorkIQ internal tool-explosion lesson]" provenance |
| foundational-plan.md § Architecture (Tool plane) | "tool-cap per workspace (default 10) to prevent context bloat" — the source guidance for the default value |
| docs/06-agent-team-outputs/wave-001/lane-b-summary.md finding 15 | WorkIQ internal lesson: agents over-loaded with tools degrade reasoning quality |
| kit:rules/no-invented-constraints.md | engine MUST NOT silently truncate the tool list; user picks which subset |
| foundational-plan.md D-3 | open decision: is 10 the right default cap value? — closure path is research wave grounded in Microsoft 2026 internal data |

## Implementation notes

(empty — populated when implementation begins)
