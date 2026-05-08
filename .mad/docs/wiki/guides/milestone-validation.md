# Milestone Validation Rules

These rules are MANDATORY for all implementation work.

## Before Starting Any Milestone

1. **Read the milestone requirements** in `docs/00-PROJECT/milestones.md`
2. **Check feature traceability** in `docs/00-PROJECT/feature-traceability.md` for all features in that milestone
3. **Update feature status** to `in-progress` as you start each feature

## During Implementation

### For Every Feature

1. **Find the feature ID** in `docs/00-PROJECT/feature-traceability.md`
2. **Update status** from `not-started` to `in-progress`
3. **Implement the feature** following the workflow specification
4. **Write tests** (unit + integration for API/WS features)
5. **Update status** to `complete` when code works
6. **Update status** to `tested` when tests pass

### For Every API Endpoint

1. Must have integration test using real database (no mocks)
2. Must return RFC 7807 error format
3. Must emit metrics (latency histogram)
4. Must include correlation ID in logs

### For Every WebSocket Event

1. Must have handler test
2. Must be documented in event schema
3. Must propagate trace context

## Before Marking Milestone Complete

Run this checklist:

```bash
# 1. All milestone features tested
grep "M{N}" docs/00-PROJECT/feature-traceability.md | grep -v "tested"
# Should return empty (all features marked tested)

# 2. Build passes
dotnet build

# 3. All tests pass
dotnet test

# 4. Health check works
curl http://localhost:5000/health

# 5. Metrics exposed
curl http://localhost:5000/metrics | grep <service_metric_prefix>_
```

## Feature Status Rules

| Status | Meaning | Requirements |
|--------|---------|--------------|
| `not-started` | Not yet begun | - |
| `in-progress` | Currently implementing | Code being written |
| `complete` | Code done | Implementation finished, not yet tested |
| `tested` | Verified | Unit tests + integration tests pass |

**A milestone is NOT complete until ALL its features have status `tested`.**

## Observability Requirements (ALL Milestones)

Every milestone must maintain observability:

1. **Logging**: All new code uses structured logging with context
2. **Metrics**: New endpoints have latency histograms
3. **Tracing**: New operations have spans
4. **Health**: New dependencies have health checks

See `docs/10-INFRASTRUCTURE/observability.md` for standards.

## Enforcement

- Do NOT commit milestone completion without running validation checklist
- Do NOT skip feature traceability updates
- Do NOT mark features `tested` without actual tests
- Pre-commit hooks will verify build passes
