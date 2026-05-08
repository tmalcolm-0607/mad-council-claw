# Template — debate transcript

Canonical shape for `/debate` output. Round-by-round positions + synthesis.

> **EXAMPLE — replace this when authoring**

```markdown
# Debate — <topic>

**Date**: <ISO date>
**Format**: N rounds, devil's-advocate <enabled|disabled>
**Mode**: standard | --council | --copilot

## Positions

| Side | Strongest claim |
|------|-----------------|
| Pro-A | <one sentence> |
| Pro-B | <one sentence> |

## Round 1 — opening

**Pro-A**: <claim with evidence>
**Pro-B**: <claim with evidence>

## Round 2 — rebut

**Pro-A → Pro-B's R1**: <addressing the actual claim, no straw-man>
**Pro-B → Pro-A's R1**: <same>

## Round 3 — defend & advance

**Pro-A**: <new evidence or reframing>
**Pro-B**: <same>

## Devil's-advocate pass (if enabled)

<challenges to whichever consensus emerged; surface hidden assumptions>

## Synthesis

### Where positions agree

- <factual common ground>

### Where they diverge

- <unresolved tradeoff with explicit decision criteria>

### Recommended path

<one sentence — usually picks one side OR proposes a hybrid OR documents that the choice depends on a constraint we haven't fixed yet>

## Anti-hallucination

- Factual claims (latency, cost, throughput) flagged `[UNVERIFIED]` if unsupported
- Empty rebuttals stated explicitly ("Pro-B had no rebuttal to Pro-A's R1.")
```

## Reference

- See `rules/verification-protocol.md` Rule 4 — `[UNVERIFIED]` tag on factual claims without evidence
