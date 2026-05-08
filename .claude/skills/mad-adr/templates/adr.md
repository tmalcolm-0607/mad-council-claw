# Template — ADR (Architecture Decision Record)

Canonical shape for `/mad-adr` output. Format follows the standard ADR convention.

> **EXAMPLE — replace this when authoring**

```markdown
# ADR-<NNN>: <Decision title>

**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXX
**Date**: <ISO date>
**Author**: <alias>

## Context

<2-4 sentences on the problem, forces, constraints. Cite the artifacts that triggered the decision (PR, incident, research doc).>

## Decision

<One sentence — the actual choice made. Concrete, not aspirational.>

## Consequences

### Positive
- <observable benefit 1>
- <observable benefit 2>

### Negative
- <cost 1>
- <cost 2>

### Neutral but worth tracking
- <change in conventions or interfaces>

## Alternatives considered

| Option | Rejected because |
|--------|------------------|
| <Alt A> | <reason> |
| <Alt B> | <reason> |

## Related

- Supersedes: ADR-NNN (if applicable)
- Influenced by: <doc, RFC, or research>
- See also: <related ADRs>

## [NEEDS CLARIFICATION] open questions

- [ ] Q1: <unresolved>
- [ ] Q2: <unresolved>
```

## Status discipline

- Default to `Proposed` until human-approved.
- `Accepted` is set explicitly by the user, not inferred.
- `Superseded` ADR retains its body verbatim; only status + cross-link change.

## Anti-hallucination

- Alternatives must be cited as actually considered, not invented for symmetry
- Consequences cite observable signals, not aspirations

## Reference

- https://adr.github.io
