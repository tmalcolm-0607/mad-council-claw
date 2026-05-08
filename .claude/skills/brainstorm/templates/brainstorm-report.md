# Template — brainstorm report

Canonical shape for `/brainstorm` output. Ranked angles + tradeoffs + recommended next step.

> **EXAMPLE — replace this when authoring**

```markdown
# Brainstorm — <prompt-summary>

**Date**: <ISO date>
**Constraints**: <verbatim from input>
**Mode**: standard | --council | --copilot

## Angles (ranked by composite score)

| # | Angle | Feasibility | Lift | Blast radius | Composite | Confidence |
|---|-------|-------------|------|--------------|-----------|------------|
| 1 | <name> | high | high | low | 0.86 | 0.78 |
| 2 | <name> | medium | high | medium | 0.71 | 0.62 |
| 3 | <name> | high | medium | low | 0.68 | 0.74 |

## Top 3 (deep)

### 1. <Angle name>

**Hypothesis**: <one sentence>
**Mechanism**: <how it would work, 2-3 sentences>
**Cost**: <effort + risk>
**Tradeoffs**: <what you give up>
**Evidence basis**: research / prior art / reasoning
**[NEEDS CLARIFICATION]**: <unknowns that change the score>

### 2. <Angle name>

(same shape)

### 3. <Angle name>

(same shape)

## Recommended next step

<One sentence picking either angle 1 or "user chooses" if top three are within noise.>

## Anti-hallucination

- Confidence per angle reflects evidence basis, not gut feel
- Where an angle requires unverified assumptions, surface them inline
```

## Reference

- Standard rubric: feasibility (1-3) × lift (1-3) × inverse blast radius (1-3) → composite 0-1
