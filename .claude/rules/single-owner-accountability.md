---
title: Rule — Single-owner accountability
status: preview
since: 2026-04-18
last_reviewed: 2026-04-18
promote_by: 2026-07-31
---

# Rule — Single-owner accountability

Every MAD artifact with mutable state has exactly one accountable owner-of-record. Ownership is explicit, persisted, and transferred only by an explicit council act — never implicitly.

**Source:** internal engineering standards docs (service-ownership guidance — a service-registry as single source of truth for engineering manager + PM per service). Adopted via **ADOPT-001**.

## Scope

| Artifact | Owner field | Transfer mechanism |
|---|---|---|
| Channel (`channel.json`) | `owner_alias` (required) | `council-verdict` with `verdict.type = ownership_transfer` + confirming `council-resolve` |
| Verdict (`verdicts/*.json`) | `issuer_alias` (already required by `schemas/verdict.schema.json`) | Immutable — cannot be transferred; supersede with a new verdict |
| Retro (`retros/*.json`) | `facilitator_alias` (required) | Same as verdict — immutable |
| Completion report (`completion-report.json`) | `reporter_alias` (required) | Immutable |
| Run (implicit; lives in message threads) | `originator_alias` on the initiating message | Follow the chain — cannot be retroactively reassigned |

## Why

1. **Accountability collapse on reads.** Without a named owner, readers (human operators, other agents) have no single point of contact to ask "is this still relevant?" or "why was this decided this way?". Large orgs escalate via EM + PM per service; MAD escalates to the `owner_alias`.
2. **Conflict resolution.** Two Advocates disagreeing with no named owner produces deadlock. The owner is the tiebreaker of last resort — not the decider of every question, but the one whose judgement closes the issue when the council is split.
3. **Blast-radius gating.** `rules/dangerous-operations-policy.md` actions (archive, delete, bulk-edit) MUST check that the invoker is the `owner_alias` or has an explicit ownership-transfer verdict; non-owners get an AskUserQuestion prompt even if they otherwise have write access.
4. **Retro grounding.** `council-retro` needs a single voice to sign off on "we learned X, going forward we will do Y" — consensus retrospectives without an owner dissolve into non-committal prose.

## Required behaviours

### council-open

- MUST set `owner_alias` at creation — either the opener (default) or an explicit `--owner <alias>` flag pointing to another member (must also be joining in the same run).
- MUST reject if `owner_alias` is not present in `members[]` on the initial write.

### council-join

- MAY NOT change `owner_alias` under any circumstance. A joining member is a participant, not an owner.

### council-leave

- If the leaving member IS `owner_alias`, the leave MUST be preceded by an `ownership_transfer` verdict — otherwise reject with exit code `OWNER_LEAVING_WITHOUT_TRANSFER`.
- If another member is leaving, no ownership check required.

### council-verdict

- Accepts a new `verdict.type = ownership_transfer` variant with required fields `from_alias` + `to_alias`, both present in `members[]`. Issuer MUST be the current owner.
- Writes the verdict atomically; downstream `council-resolve` picks it up and rewrites `channel.json:owner_alias` (via atomic replace — no partial-state window).

### council-resolve

- On encountering an `ownership_transfer` verdict, atomically updates `owner_alias` in `channel.json` AND logs the transfer in the verdict's `resolved_utc` + `resolution_outcome` fields.
- Subsequent reads of `channel.json` see the new owner; the verdict history preserves the provenance.

### council-review / council-post

- Advisory — non-owners can still post, review, and cast non-binding verdicts. Ownership only matters for destructive or cross-cutting acts.

## STRIDE implications

- **Spoofing.** `session_id` binding (per `mad.council.a2a.md §7.2`) prevents an attacker from impersonating the owner; session mismatch on an ownership-privileged action fails fast with the existing counter `council_post.session_mismatch_total`.
- **Tampering.** `owner_alias` transfers MUST go through `council-verdict` — direct edits to `channel.json:owner_alias` are detectable by comparing against the verdict history. Layer-3 fault-injection tests include "attacker edits owner_alias directly" as a fixture.
- **Repudiation.** Verdict history is append-only; ownership provenance is auditable from channel creation to current state.
- **Elevation of privilege.** Non-owner cannot issue `ownership_transfer` to themselves — the rule explicitly requires the issuer to be the current owner.

## Related

- `schemas/channel.schema.json` — `owner_alias` field.
- `schemas/verdict.schema.json` — `ownership_transfer` verdict type.
- `rules/dangerous-operations-policy.md` — non-owners require AskUserQuestion before destructive acts.
- `skills/council-verdict/SKILL.md` — verdict type enum.
- `skills/council-resolve/SKILL.md` — ownership-transfer resolution path.

## Anti-patterns (rejected at review)

- **Committee ownership** — "the Advocate and the Skeptic jointly own this channel." Violates single-owner principle. Pick one.
- **Implicit transfer on leave** — "if the owner leaves, the oldest remaining member inherits." Silently reassigns accountability; rejected. Require an explicit `ownership_transfer` verdict.
- **Ownership derived from posting activity** — "whoever posts most is the owner." Ephemeral, non-auditable, gameable. Owner is declared, not inferred.
