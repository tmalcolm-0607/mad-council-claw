# Template — workiq-scan report

Canonical shape for `/workiq-scan` output.

> **EXAMPLE — replace this when authoring**

```markdown
# WorkIQ Scan — <topic>

**Date**: <ISO date>
**Topic**: <verbatim user query>
**Throttle state**: clean | backoff (10m → 30m → 60m cap)

## Findings

For each WorkIQ message returned:

```
[<msg-id>] <author> @ <ts>
  Excerpt: "<verbatim quote, ≤6 lines>"
  Source: <Teams channel | email subject | DM>
  Relevance: high | medium | low
```

## Aggregate signals

- Hot threads: <list>
- Frequent participants: <list>
- Open questions raised: <list>

## Context Gaps

(only if WorkIQ degraded)

| Source | Status | Impact |
|--------|--------|--------|
| Teams query | 429 → backoff 30m | partial results from cache |

## Anti-hallucination

- Every finding cites: WorkIQ message-id + author + ts
- Never fabricate WorkIQ content
- Empty result stated explicitly ("WorkIQ returned 0 matches for the topic.")
- Throttle backoff persisted per `lens-engineering-craftsmanship/docs/BACKOFF-PATTERNS.md`

## Verdict

ACCEPT (or ACCEPT_WITH_CAVEATS with Context Gaps when WorkIQ degraded).
```
