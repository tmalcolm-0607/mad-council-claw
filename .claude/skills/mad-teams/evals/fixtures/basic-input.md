# Fixture: basic input for /mad-teams (synthetic)

Synthetic input for the mad-teams skill. The skill spawns an agent-team (lead + N teammates) for a multi-agent task per `rules/agent-teams.md`.

## Synthetic input artifact

Task: review 3 disjoint sub-features in parallel (sub-A, sub-B, sub-C) and synthesize.
Expected team: lead = code-reviewer (Opus); teammates = 3× code-reviewer (Sonnet) — one per sub-feature.
Estimated wall-clock saving: 3× over sequential.

## Skill invocation

```
/mad-teams review-sub-features
```

## Notes

This fixture exercises the smart-default flow (decision rule → spawn → coordinate). For mode-specific fixtures (--lead-model opus, --teammate-model sonnet), add additional fixtures.
