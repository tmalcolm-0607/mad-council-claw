# Fixture: basic input for /validate-dashboard (synthetic)

Synthetic input for the validate-dashboard skill. The skill audits a Geneva/Grafana/App Insights dashboard JSON for missing tiles, stale queries, or queries that won't bind to current schema.

## Synthetic input artifact

Dashboard: `dashboards/myapp-overview.json` (Geneva format)
Schema: events stream with fields `tenantId`, `eventType`, `timestamp`, `latency_ms`.

Expected tiles:
- request rate
- p50/p95/p99 latency
- error rate by tenantId
- top 10 slow operations

## Skill invocation

```
/validate-dashboard
```

## Notes

This fixture exercises the smart-default flow (parse → bind → check). For mode-specific fixtures (--strict, --suggest-fixes), add additional fixtures.
