# MAD Workflow Integration

## Workflow Order

For each milestone, follow this sequence:

```
1. /mad-spec    → Define what to build (reads from workflows + feature-traceability)
2. /mad-plan    → Design implementation approach
3. /mad-tasks   → Generate task list
4. /mad-implement → Execute tasks with validation
5. /mad-validate  → Verify against feature-traceability
```

## Spec Phase Requirements

When running `/mad-spec` for a milestone:

1. **Source documents** (MUST read):
   - `docs/00-PROJECT/milestones.md` - Milestone requirements
   - `docs/00-PROJECT/feature-traceability.md` - Feature list for milestone
   - Relevant workflow file from `docs/05-USER-EXPERIENCE/workflows/`

2. **Output spec must include**:
   - All feature IDs from traceability matrix
   - All API endpoints for the milestone
   - All WebSocket events for the milestone
   - Observability requirements

## Validation Phase Requirements

When running `/mad-validate`:

1. **Check feature coverage**:
   ```bash
   # Count features for milestone
   grep "M{N}" docs/00-PROJECT/feature-traceability.md | wc -l

   # Count tested features
   grep "M{N}" docs/00-PROJECT/feature-traceability.md | grep "tested" | wc -l

   # These numbers must match
   ```

2. **Check observability**:
   - Health endpoint returns healthy
   - Metrics endpoint has new metrics
   - Logs show correlation IDs

3. **Check test coverage**:
   - Unit tests exist for business logic
   - Integration tests exist for API endpoints
   - No mocking in integration tests

## Key Files to Reference

| File | Purpose | When to Read |
|------|---------|--------------|
| `docs/00-PROJECT/milestones.md` | What to build | Start of milestone |
| `docs/00-PROJECT/feature-traceability.md` | Feature checklist | Throughout |
| `docs/04-DATA-SCHEMAS/component-architecture.md` | ECS patterns | When building entities |
| `docs/10-INFRASTRUCTURE/observability.md` | Logging/metrics | When adding new code |
| `docs/08-TESTING-VALIDATION/validation-checkpoints.md` | Validation rules | When implementing rules |

## Anti-Patterns

- Starting implementation without reading milestone requirements
- Skipping feature traceability updates
- Adding code without tests
- Adding endpoints without metrics
- Marking milestone complete without validation
