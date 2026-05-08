# Template — dashboard validation report

Canonical shape for `/validate-dashboard` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Dashboard Validation — <name>

**Dashboard**: `<path or URL>`
**Schema reference**: <path or stream name>
**Date**: <ISO date>

## Tile inventory

| Tile | Query (excerpt) | Binds to schema? | Last used |
|------|-----------------|------------------|-----------|
| Request rate | `requests | summarize ...` | ✓ | recent |
| p99 latency | `requests | percentile(latency_ms, 99)` | ✓ | recent |
| Error rate by tenant | `exceptions | by tenantId` | ✗ (field renamed to `tenant_id`) | recent |

## Findings

### [BLOCKING] Error rate tile binds to deprecated field

Evidence: query `by tenantId` against schema field `tenant_id`
Rule: schema-binding consistency
Confidence: 0.91
Suggested fix: rename to `tenant_id` in the query.

### [SHOULD-FIX] Missing top-N slow operations tile

Evidence: expected per `validate-dashboard/evals/fixtures/basic-input.md`; absent from inventory.
Confidence: 0.62
Suggested fix: add tile.

## Anti-hallucination

- Each tile's query was test-bound against the schema (ACTUAL BEFORE PRESENT)
- Empty queries stated explicitly

## Verdict

REJECT (BLOCKING) | ACCEPT_WITH_CAVEATS | ACCEPT
```

## Reference

- Same shape as code-audit findings (severity tag, evidence, rule, confidence, fix)
