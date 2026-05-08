# 2. Exhaustive enumeration over ruthless filtering for kit inventories

Date: 2026-04-21
Status: Accepted

## Context

During the gap-analysis loop, iter 7 reported convergence (only 1 new gap found) — suggesting the port was effectively complete. Iter 8 was run anyway as a sanity pass, using a different method: exhaustive file-by-file enumeration of every candidate source under `MAD/.claude/` and `MAD/.mad/` rather than conceptual-bucket-then-filter.

Iter 8 surfaced **117 additional sub-gaps** that the "ruthless filtering" approach had silently collapsed. Parent-level gap identifiers (G17, G18, …) hid fine-grained items that each needed their own decision (port verbatim, adapt, reject, defer).

## Decision

When building an inventory or port map for a kit, the primary method is **file-by-file enumeration**. Conceptual bucketing is allowed as a presentation layer over an enumerated base, never as a substitute for it.

Convergence is not declared until a single iteration performs exhaustive enumeration and produces zero new items.

## Consequences

**Easier**:
- Fewer "silent misses" — anything skipped was skipped deliberately, with a recorded reason.
- Reviewers can audit the inventory by re-running the enumeration.
- Future port rounds (e.g. when new source material lands upstream) follow the same reproducible method.

**Harder**:
- One iteration becomes long and tedious (iter 8 was 61K of raw output before PORTED.md collapsed it).
- Requires discipline — the temptation to conceptually filter upfront is strong because it feels efficient.

## References

- `_gap-analysis-loop.md:33-36` (iter-8 finding that invalidated iter-7 convergence)
- `_gap-analysis-iter8-raw.md` (the enumeration itself — 61K)
- `PORTED.md` — consolidated post-enumeration map

## Related

- Reinforces the "fetch before claiming convergence" memory rule (project-level).
