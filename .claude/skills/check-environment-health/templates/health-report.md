# Template — environment health report

Canonical shape for `/check-environment-health` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Environment Health — <env>

**Environment**: `<name>` (subscription `<sub-id>`, resource group `<rg>`)
**Date**: <ISO date>

## Per-resource

| Resource | Type | Status | Last probe | Notes |
|----------|------|--------|------------|-------|
| app-myapi-<env>-westus3 | App Service | GREEN | <ts> | running, healthy |
| cosmos-myapp-<env>-westus3 | Cosmos | YELLOW | <ts> | RU consumption 92% |
| appi-myapp-<env>-westus3 | App Insights | GREEN | <ts> | ingesting |
| id-myapi-<env>-westus3 | Managed Identity | RED | <ts> | RBAC missing on Cosmos role |

## Recent errors (App Insights, last 1h)

For RED rows, capture top exceptions with timestamps and operation_Ids.

## Anti-hallucination

- Status cites: probe response (HTTP status, RBAC test result, CSL query output)
- Never claim GREEN without actual probe success (ACTUAL BEFORE PRESENT)
- Empty per-row state stated explicitly

## Verdict

REJECT (any RED) | ACCEPT_WITH_CAVEATS (any YELLOW) | ACCEPT (all GREEN)
```

## Reference

- `rules/deployment-failure-diagnosis.md` — when health probes disagree with pipeline status, ARM activity log is truth
