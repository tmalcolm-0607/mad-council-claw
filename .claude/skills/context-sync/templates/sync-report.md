# Template — context-sync report

Canonical shape for `/context-sync` output. Drift between in-session belief and persisted state.

> **EXAMPLE — replace this when authoring**

```markdown
# Context Sync — <ISO date>

**Active WI**: <WI-id>

## Drift detected

| Source | In-session belief | Disk truth | Severity |
|--------|-------------------|------------|----------|
| plan.md task count | 3/8 complete | 4/8 complete | SHOULD-FIX |
| tasks.md `[!]` blockers | none | 1 (T7) | MUST-FIX |
| ACTIVE pointer | WI-foo | WI-foo | aligned |

## Proposed alignment

1. Acknowledge T7 blocker explicitly
2. Re-read plan.md after compaction events; in-session state is stale

## Anti-hallucination

- Each row cites disk evidence (Read excerpt or git query output)
- Empty drift stated explicitly ("In-session and disk are aligned.")

## Verdict

ACCEPT — drift surfaced; user reconciles in-session belief.
```
