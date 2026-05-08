# Template — idea.md

Canonical shape for `/mad-idea` output. Vision document under `specs/ideas/<slug>.md`.

> **EXAMPLE — replace this when authoring**

```markdown
# Idea — <slug>

**Status**: vision (path under `specs/ideas/`)
**Author**: <alias>
**Date**: <ISO date>

## Problem

<1-3 sentences on the user-visible problem. Cite the audience.>

## User stories

- As a <role>, I want <capability> so I can <outcome> — concrete artifact: <file/endpoint/UI>
- As a <role>, I want <capability> so I can <outcome> — concrete artifact: <file/endpoint/UI>
- As a <role>, I want <capability> so I can <outcome> — concrete artifact: <file/endpoint/UI>

(3 Nouns Test: each story names ≥3 concrete artifacts)

## Functional Requirements

| FR | Description | Logical Proof (TBD until promoted to contract) |
|----|-------------|------------------------------------------------|
| FR-1 | <one-line description> | [NEEDS CLARIFICATION: what file/endpoint/command verifies this?] |
| FR-2 | <one-line description> | [NEEDS CLARIFICATION] |

## Non-functional considerations

- Latency: <target or [NEEDS CLARIFICATION]>
- Throughput: <target or [NEEDS CLARIFICATION]>
- Availability: <target or [NEEDS CLARIFICATION]>

## Open questions

- [ ] Q1: ...
- [ ] Q2: ...

## Promotion path

When ready: `/mad-spec` → produces contract spec at `specs/<N>-<slug>/spec.md` with FR Logical Proofs filled.

## Anti-hallucination

- Empty FRs stated explicitly
- Every assumption tagged `[NEEDS CLARIFICATION]`
- This document is a vision, NOT a contract — implementability gates apply only after promotion
```

## Reference

- `mad-spec/SKILL.md` § implementability gates (the upgrade path)
- `rules/_status-convention.md` — vision vs contract status semantics
