---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-048
short-slug: tool-result-streaming
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - cp:electron/mcp-tools.ts
    - cp:electron/ipc/mcp-ipc.ts
    - kit:rules/concurrency-safety.md
    - kit:rules/dangerous-operations-policy.md
    - "wave-1 lane-c lessons-learned.md (cleanup is bounded; cancel propagates to MCP server)"
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
  LOCKED if GREEN AND reviews/F-048-tool-result-streaming-review.md exists with verdict: ACCEPT.
depends-on: [F-007, F-044, F-047]
out-of-scope-notes: |
  Live trace timeline UI showing each streamed chunk is M11+M12 (F-088..F-095).
  Backpressure-driven flow control across the IPC channel for >100 MB results is v1.5 (F-NNN candidate).
  Resumable streaming after an IPC disconnect (mid-stream reconnect) is v1.5 (F-NNN candidate).
  Multimodal results (binary blobs > N MB) handling beyond JSON is M13 (F-096..F-100 multimodal-input — symmetric problem).
confidence: high
---

# F-048 — Tool result streaming

## Behavior contract

Tool results stream incrementally from the MCP server through the bridge (per F-044) to the consumer (renderer or CLI) over the F-007 IPC contract. Servers that emit progress notifications (`notifications/progress` per MCP spec) push partial results that flow as a sequence of `tool.partial` IPC events, terminated by a `tool.complete` event carrying the final result. Servers that emit only a single response produce one `tool.complete` event with no preceding partials. Cancellation MUST propagate within ≤500ms: the consumer issues `mcp.cancelTool(callId)`, the bridge sends MCP `notifications/cancelled`, and the run pipeline acknowledges by emitting a `tool.cancelled` IPC event + a `cancelled` outcome to the audit (per F-047). Stream cleanup is bounded per `wave-1 lane-c lessons-learned.md` — no orphan event listeners, no leaked subscriptions, no hung promises. Result chunk ordering is preserved by the bridge's per-call sequence counter.

## Acceptance scenarios

1. **Given** an MCP server that emits 5 progress notifications + a final response for a long-running tool, **When** the renderer subscribes to the call's stream, **Then** the renderer receives 5 ordered `tool.partial` events followed by exactly one `tool.complete` event — no out-of-order delivery, no duplicates.
2. **Given** an in-flight tool call mid-stream (3 partials received), **When** the consumer issues cancel, **Then** within ≤500ms the bridge dispatches `notifications/cancelled` to the server, emits `tool.cancelled` to the consumer, the audit log gets a `cancelled` outcome entry per F-047, and no further `tool.partial` or `tool.complete` events arrive for that call ID.
3. **Given** a tool call subscribed by two renderer instances (multi-window per F-043), **When** the call completes, **Then** both renderers receive the complete sequence (`tool.partial` × N, then `tool.complete`) — fan-out delivery is in-order per consumer; cancellation from one consumer cancels the underlying call (callId is the unit of work), which delivers `tool.cancelled` to both subscribers.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/mcp/streaming-partial-then-complete.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/mcp/streaming-cancel-propagation.test.ts` | integration | RED — ≤500ms latency | scenario 2 |
| (TBD) `tests/integration/mcp/streaming-fanout-multi-subscriber.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-007 (IPC contract carries the stream events), F-044 (bridge owns sequence counter + cancel dispatch), F-047 (audit records partial-vs-complete-vs-cancelled)
- **Soft:** F-020 (kill-switch causes cancel propagation), F-043 (multi-window subscriber fan-out), F-021 (degradation if stream hangs past timeout)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | MCP user story (streaming is part of the tool-call surface) |
| cp:electron/mcp-tools.ts | Streaming dispatch pattern + cancel handling |
| cp:electron/ipc/mcp-ipc.ts | `tool.partial` / `tool.complete` / `tool.cancelled` event shapes |
| kit:rules/concurrency-safety.md | No half-written or interleaved partial chunks |
| kit:rules/dangerous-operations-policy.md | Cancellation as an explicit op (cleanup is bounded) |
| wave-1 lane-c lessons-learned.md | Bounded cleanup + cancel propagation discipline |

## Implementation notes

(empty — populated when implementation begins)
