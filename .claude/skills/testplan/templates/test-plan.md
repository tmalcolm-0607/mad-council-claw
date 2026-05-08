# Template — test-plan.md

Canonical shape for `/testplan` output. One scenario per FR-level test target across unit / integration / e2e / non-functional dimensions.

> **EXAMPLE — replace this when authoring**

```markdown
# Test Plan — <feature-name>

**Source spec**: specs/<N>-<slug>/spec.md
**Date**: <ISO date>

## Coverage matrix

| FR | Unit | Integration | E2E | NFR |
|----|------|-------------|-----|-----|
| FR-1 | UT-1 | IT-1 | E2E-1 | — |
| FR-2 | UT-2 | IT-2 | — | NFR-1 (p95 latency) |

## Scenarios

### UT-1 — FooHandler.Post happy path

**Level**: unit
**Given**: valid request DTO
**When**: handler.Post(req)
**Then**: returns Result<TFoo>.Success with id, persists to repo
**Acceptance**: assertion + repo verify

### IT-1 — POST /api/v1/foo end-to-end

**Level**: integration
**Given**: API up + Cosmos emulator + valid auth
**When**: curl POST /api/v1/foo with body B
**Then**: 201 + Location header + record in Cosmos
**Acceptance**: HTTP status + body shape + Cosmos read

(repeat per scenario)

## Non-functional targets

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| NFR-1 | p95 latency | <200ms | k6 100 reqs/s for 60s |

## Anti-hallucination

- Empty scenarios per FR stated explicitly (gap signal)
- Every scenario maps back to a spec FR or marked as cross-cutting

## Verification Spec

Test plans are themselves verification material; this section restates intent in the canonical plan-gate format. All 5 sub-sections required.

### Feature Intent

<Restate the spec's user-visible outcome the test plan covers, 1-2 sentences.>

### Change Type

<new-capability | bug-fix | refactor | perf | security | infra — same as the source spec.>

### Expected Impact

<What metric or observable should move once tests pass and the implementation lands. Identical to the source spec's Expected Impact.>

### Structural Signals

The Coverage matrix above (FR × Level) IS the structural-signal map. Each cell's scenario row shows how the FR will be observed.

### Not a Failure

- Skipped tests (`SkippableFact`) for missing infra (Cosmos emulator, etc.) → not a failure; flagged for ADO-only execution
- Coverage drop on new error paths until follow-up tests land → flag, don't revert
- Pre-existing failures in other test projects → tracked separately, not dismissed
```

## Reference

- `mad-spec/templates/spec.md` — upstream input
- `mad-validate/templates/validation-report.md` — downstream consumer
