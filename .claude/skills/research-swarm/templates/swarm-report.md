# Template — research-swarm report

Canonical shape for `/research-swarm` output. Per-topic findings + cross-topic synthesis.

> **EXAMPLE — replace this when authoring**

```markdown
# Research Swarm — <ISO date>

**Topics**:
1. <topic A>
2. <topic B>
3. <topic C>

**Researchers dispatched**: 3 parallel-researcher agents (one per topic)

## Topic A — <name>

**Findings**:
- F1 (high confidence): <claim with citation URL>
- F2 (medium): <claim with citation URL>
- F3 (low — single-source): <claim with citation URL>

## Topic B — <name>

(same shape)

## Topic C — <name>

(same shape)

## Cross-topic synthesis

### Overlaps
- Topics A and B both reference <shared concept>; convergent guidance.

### Contradictions
- Topic A's F2 conflicts with Topic C's F1; surface for user judgment with both citations.

### Recommended path
<one sentence picking a coherent direction OR documenting that the contradiction must be resolved before action>

## Anti-hallucination

- Every finding cites a URL or document
- Confidence levels drop when sources are sparse, single-vendor, or aged
- Empty topics stated explicitly ("Topic C: 0 findings — search returned generic results without primary sources.")

## Verdict

ACCEPT — research synthesized; recommendation returned.
```
