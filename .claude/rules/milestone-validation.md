# Milestone Validation Rules

Generic milestone discipline. Paths and tooling commands below are placeholders — the consumer project (`./CLAUDE.md`) overrides with project-specific paths and gate commands. The intent (status flow, per-feature gates, completion checklist) applies to any project that uses milestone + feature-traceability tracking.

## Before Starting Any Milestone

1. Read milestone requirements at the project's milestone-requirements doc (e.g. `docs/milestones.md`, `specs/<N>-<feature>/milestone.md`, or whatever the consumer project uses).
2. Find the feature list for the milestone in the project's feature-traceability doc.
3. Update each feature status to `in-progress` as work begins.

## During Implementation

### Per Feature

1. Find the feature ID in the feature-traceability doc.
2. Set status: `not-started` → `in-progress` → `complete` → `tested`.
3. Write unit + integration tests before marking `complete`.

### Per API Endpoint (if the feature exposes one)

- Integration test against a real backing store (avoid mocks where the real store is cheap to spin up — Cosmos emulator, in-memory SQLite, etc.).
- Conform to the project's error-format convention (RFC 7807 ProblemDetails for HTTP APIs).
- Latency / throughput metric per endpoint.
- Correlation ID propagated through request/response and into logs.

### Per Async Event Handler (if the feature dispatches/consumes events)

- Handler unit test with synthetic event input.
- Event schema documented in the project's contract surface.
- Trace context propagated end-to-end.

## Before Marking Milestone Complete

The consumer project supplies the actual gate commands. Generic shape:

```bash
# All milestone features must be `tested`. The query below should return nothing.
grep "M{N}" <feature-traceability-path> | grep -v "tested"

# Build + tests — invoke the project's gates wrapper (varies per project)
# Examples:
#   .NET project: powershell.exe -NoProfile -File scripts/Run-Gates.ps1
#   Node project: npm run gates
#   Python project: make gates
<project-specific gate command>

# Observability sanity (if applicable)
curl <health-endpoint>
curl <metrics-endpoint> | grep <project-metric-prefix>
```

## Feature Status

| Status | Meaning |
|--------|---------|
| `not-started` | Not yet begun |
| `in-progress` | Code being written |
| `complete` | Implementation done, not yet tested |
| `tested` | Unit + integration tests pass |

**A milestone is NOT complete until ALL features have status `tested`.**

## Enforcement

- Do NOT commit milestone completion without running the consumer-project gate suite.
- Do NOT skip feature-traceability updates.
- Do NOT mark features `tested` without actual passing tests.
- The consumer project documents the canonical observability runbook (logging conventions, metric naming, tracing rules, health endpoints) at its observability doc — see the consumer project's CLAUDE.md for the path.

## Consumer-project override

The consumer project's `CLAUDE.md` overrides this rule's placeholders with concrete paths, gate commands, and metric prefixes. If the consumer doesn't supply them, the placeholders here are merely a checklist shape — adapt to the project's reality.
