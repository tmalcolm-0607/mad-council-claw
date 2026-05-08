# 3. Context-before-action: three failure modes from the 2026-04-22 MAD install session

Date: 2026-04-22
Status: Accepted

## Context

During the 2026-04-22 session that ported the mad-council plugin + authoring kit into a unified MAD repo, the operating agent (Claude) made three substantive errors that the user had to push back on. Each was caught and fixed. The common root cause was **insufficient context-gathering before action** — jumping to "do the thing" before fully understanding the request and the surrounding state.

This ADR captures the three failure modes as a kit-authoring guideline so future operators (human or AI) can avoid them.

## Decision

The kit adopts a **context-before-action** discipline for three specific situations. Each failure mode below maps to a specific guideline.

### Failure 1 — "Install" interpreted as merge instead of replace

**What happened**: User asked to "install our new MAD system instead" (replacing old content in the target repo). Agent interpreted "instead" as "alongside" and built a four-tier union-merge that preserved every file at its existing location, even when the new install added the same content at the kit-canonical layout. End state: 377 of 516 target files were duplicates (legacy flat layout + new subfolder layout).

**Root cause**: Defaulted to safest-possible-data-preservation when user wanted clean replacement. Misread the imperative "instead" because no destructive action felt safe.

**Guideline**:
- When a user says "install X instead of Y", treat it as REPLACEMENT, not addition.
- Before any merge-style install, restate the user's intent in your own words and confirm: "You want me to delete the old version and put the new one in its place — yes?"
- For kit-content installs into a consumer that has older copies of kit content, DELETE the older copies. Don't preserve in parallel layouts.
- Use union-merge only when the user explicitly says "merge" / "preserve" / "add alongside" / "don't delete".

### Failure 2 — Installed authoring kit instead of packaged plugin

**What happened**: User asked to "install MAD". Agent installed `playground-main/MAD/` (the authoring kit — meta-content for building plugins) into the target. The user's actual intent was the `mad-council` plugin at `playground-main/plugins/mad-council/` (the packaged runtime artifact). Agent never even thought to install the plugin because "MAD" was conflated with "kit".

**Root cause**: Multiple things share the "MAD" name (the kit, the plugin, the broader Multi-Agent Discipline concept). Agent picked the literal directory match without disambiguating.

**Guideline**:
- When a user-named entity could refer to multiple artifacts, **explicitly disambiguate before action**. For "MAD", ask: "Do you mean the runtime plugin (`mad-council`), the authoring kit (`MAD/` in playground), or both?"
- Cross-reference user context. If they describe usage ("the council can build features autonomously across LENS-CMS, LENS-Common"), that's plugin-usage language — install the plugin, not the kit.
- Use the **factory-vs-product distinction**: if the user describes runtime behavior, they want the product (plugin). If they describe authoring/development, they want the factory (kit). If both, install both — but explicitly.

### Failure 3 — Wrote a feature spec without reading the existing skill design

**What happened**: Agent invoked `/mad-spec` workflow on "Phase 2 council-review + council-verdict" without first checking whether the kit had already designed those skills. Authored `specs/001-council-review-verdict/spec.md` from greenfield with invented vocabulary (BLOCK/WARN/LOG/ACCEPT) that conflicted with the existing `schemas/verdict.schema.json` (FIX/ACCEPT/ESCALATE/INVESTIGATE), invented data model (separate review messages vs. embedded findings), and invented test approach (Pester on `.ps1` for skills that are SKILL.md-only).

**Root cause**: Treated the spec-template as "fill out greenfield" without checking whether `skills/<feature>/SKILL.md + plan.md + tests.md` already existed. The mad-spec workflow assumes greenfield design; using it on a feature the kit already specified creates divergent specs that mislead downstream work.

**Guideline**:
- **Before invoking `/mad-spec` or authoring `specs/<NNN>-<feature>/spec.md`, grep for existing design**. Search:
  - `skills/<feature-or-related-name>/SKILL.md` and sibling `plan.md` + `tests.md`
  - `schemas/<related>.schema.json` for entities already designed
  - `decisions/` for ADRs that constrain the design
  - `mad.council.a2a.md` and `plans/phase-*.md` for spec-source references
- If existing design is found, the work is **implementation**, not (re-)specification. Skip `/mad-spec`. Author code + tests against the existing design.
- If existing design is partial (e.g. SKILL.md exists but no implementation), produce a thin **implementation-readiness doc** pointing at the authoritative design — do not duplicate it.
- Vocabulary, data model, and test approach must conform to existing schemas + SKILL.md contracts. If divergence is genuinely needed, evolve the existing design via a separate ADR + schema-version bump — not by inventing parallel terms in a new spec.

## Consequences

**Easier**:
- Future install operations stay aligned with user intent. Less wasted work on fixes-for-misunderstanding.
- Spec authoring stays cheap because greenfield re-design is avoided when prior design exists.
- Plugin-vs-kit confusion gets disambiguated upfront, not after the wrong thing is shipped.

**Harder**:
- More upfront questioning. Feels like friction, but the cost of a clarifying question is dwarfed by the cost of cleaning up wrong work.
- Requires discipline to grep first / restate intent first, even when the obvious-seeming action is tempting.

## References

- `specs/001-council-review-verdict/SUPERSEDED.md` — durable record of failure 3
- `decisions/002-exhaustive-enumeration-over-ruthless-filtering.md` — companion lesson on inventory-building (also "context-before-action")
- Session commits showing the three failures + their fixes:
  - Failure 1: `c59d679` (T5 cleanup commit that retroactively removed 82 duplicate files after the merge install ran)
  - Failure 2: `077c886` (port commit that fixed the "missed 4 skill dirs" symptom of the kit-vs-plugin misread)
  - Failure 3: `7d3f719` + `627e82c` (supersede + delete of the wrong spec/plan)

## Related

This ADR is part of a small cluster on **context-before-action** discipline. ADR-002 covers the same theme at a different scale (don't filter conceptually before enumerating exhaustively). Together they argue for: gather full context, restate intent, search for prior work, and only then act.
