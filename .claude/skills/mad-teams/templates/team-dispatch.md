# Template — team dispatch report

Canonical shape for `/mad-teams` output. Lead + N teammates with explicit file ownership.

> **EXAMPLE — replace this when authoring**

```markdown
# Team Dispatch — <task-name>

**Date**: <ISO date>
**Decision-rule trigger**: ≥3 independent tasks + disjoint files + ≥30 min total + no inter-step judgment

## Roster

| Role | Agent | Model | Files owned |
|------|-------|-------|-------------|
| Lead | code-reviewer | Opus | none (coordinator) |
| Teammate 1 | code-reviewer | Sonnet | sub-A/* |
| Teammate 2 | code-reviewer | Sonnet | sub-B/* |
| Teammate 3 | code-reviewer | Sonnet | sub-C/* |

## Cost projection

- Token multiplier: ~6× (per `rules/agent-teams.md` cost table)
- Wall-clock saving estimate: ~3× over sequential
- Justification: cost ≤ saving × quality-lift threshold ✓

## Kill conditions (per agent-teams.md)

- Speedup < 1.5× → revert to subagent
- Cost > 5× with no quality gain → revert
- File conflict detected at runtime → sequential fallback
- Teammate hangs → kill and retry sequentially
- Coordination overhead > 30% → revert

## Lead responsibilities

1. Review each teammate's plan before modifications
2. Run gates after all teammates complete
3. Synthesize findings into single report

## Anti-hallucination

- Never claim team-success without all teammate successes verified
- File-ownership disjoint at runtime, not just at plan time

## Verdict

ACCEPT — team dispatched; lead synthesizes results.
```

## Reference

- `rules/agent-teams.md` — full decision rule + cost table + kill conditions
