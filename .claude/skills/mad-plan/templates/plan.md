# Template — plan.md

Canonical shape for `/mad-plan` output. The plan.md becomes the source of truth for phase boundaries, gate runs, and checkpoint commits.

> **EXAMPLE — replace this when authoring**

```markdown
# Plan — <feature-name>

**Author**: <alias>
**Spec**: specs/<N>-<slug>/spec.md
**Test plan**: specs/<N>-<slug>/test-plan.md
**Date**: <ISO date>

## Overview

<2-3 sentences on the implementation approach. Cite the highest-impact architectural decisions only — alternatives belong in research.md, not plan.md.>

## Architectural decisions

| Decision | Why | ADR |
|----------|-----|-----|
| Use Foo for X | Cited tradeoff | docs/adr/0042-foo.md |

## Verification Spec

**MANDATORY per Phase 0.5.** All 5 sub-sections below are required before any phase runs.

### Feature Intent

<1-2 sentences stating what the feature is supposed to accomplish from the user/system perspective. Avoid implementation language; describe the observable outcome.>

### Change Type

<One of: new-capability | bug-fix | refactor | perf | security | infra. Drives which structural signals matter.>

### Expected Impact

<Concrete metric / observable that should move when this ships. Examples: "p95 latency drops from 240ms to <150ms", "validation rejection count rises by ~5/day", "no behavior change — refactor only".>

### Structural Signals

How each FR will be verified — concrete, observable evidence:

| FR | How verified | Evidence captured |
|----|--------------|-------------------|
| FR-1 | `curl POST /api/v1/foo` returns 201 + Location header | response body excerpt + status code |
| FR-2 | xUnit test `FooHandlerTests.HappyPath` passes against real Cosmos | test runner output |
| FR-3 | Behavioural probe captures p95 < 200ms over 100 requests | Geneva dashboard screenshot |

If an FR has no verification path, that's an Implementability gap — escalate to /mad-spec for revision before continuing.

### Not a Failure

Outcomes that look like failures but are intentional / acceptable:

- "Coverage drops on new error paths until follow-up tests land" → flag, don't revert
- "Existing benchmark regresses by <2%" → within noise budget; not a regression
- "Some callers see HTTP 400 where they used to see 200" → that IS the feature (input validation)

Document these explicitly so feature-verifier doesn't trigger a premature revert.

## Phases

### Phase 1: <name>

**Goal**: <single sentence>
**Inputs**: <files/data this phase reads>
**Outputs**: <files/data this phase writes>
**Gate**: <test selector or behavioural probe that must pass before Phase 2 begins>

- [ ] T1: <atomic task>
- [ ] T2 [P]: <parallel-eligible task>
- [ ] T3: <atomic task>

### Phase 2: <name>

(same shape)

## Quality gates

- [ ] Unit tests for new code
- [ ] Integration tests for new endpoints
- [ ] Bicep lint on changed .bicep files
- [ ] 100% diff coverage (verify against ADO, not local Measure-DiffCoverage)

## Open questions

- [ ] Q1: ... (resolve before phase 2)
- [ ] Q2: ... (resolve before phase 4)

## Rollback plan

<How to revert if a phase ships and breaks prod. Cite specific commits / migrations / feature flags.>
```

## Phase boundary rule

A phase boundary is where:
- A user-visible behavior changes
- A new dependency is introduced
- A migration runs
- The blast radius of a partial deploy crosses a service boundary

Don't fragment phases below that — extra phases produce extra gate runs without value.

## Reference templates

- `mad-spec/templates/spec.md` — upstream input
- `mad-tasks/templates/tasks.md` — downstream output
- `mad-validate/templates/validation-report.md` — gate-time companion
