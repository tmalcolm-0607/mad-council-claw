# Plan: <channel-purpose>

<!--
MAD plan template per mad.council.a2a.md §4.3 and plugins/dotnet-dev-kit/skills/mad-plan/SKILL.md.

Gate rules:
  - Every FR from spec.md must appear in this plan.
  - Contract integrity gate: every contract (§Phase 1) has inputs + outputs + test hook.
  - C4 diagrams required when architectural complexity warrants (subjective — include
    for cross-service or cross-component work).

Plan gate passes → channel advances from `plan-drafting` → `tasks-drafting` phase.
-->

## Work-item hierarchy (ADOPT-007)

Before drafting, classify the work at each level of this hierarchy and fill in the responsible role. Derived from internal engineering standards docs (`Documentation/adoworkitemguide.md`) — sized so MAD councils map 1:1 to the ecosystem work items when operating inside an internal docs repo-governed teams.

| Level | Size (rough) | MAD analog | Owner role | What gets written |
|---|---|---|---|---|
| **Initiative** | multi-phase (1+ quarters) | Multi-channel programme | PM or equivalent | Outcome + rationale; not scoped here — referenced in `## Context` |
| **Epic** | a full Phase (1 quarter) | One phase (`plans/phase-<n>.md`) | PM + Architect | High-level FRs + milestones |
| **Feature** | 1 sprint ≤ 1 quarter | One channel (this plan.md) | PM + Engineer | The section you are reading |
| **User Story** | fits one sprint (~1 week) | One `/council-post --type task` that spawns a thread | Engineer | Phase 2 row |
| **Task** | <1 engineering day | One bullet inside a Phase 2 row | Engineer | — |

Fill in:

- **Initiative** (if any): <!-- e.g., "MAD kit productionisation" or "N/A" -->
- **Epic**: <!-- e.g., "Phase 2 — Council layer" or "N/A" -->
- **Feature owner**: <!-- alias of the PM-role member, or "N/A for local-tier channels" -->
- **Engineer**: <!-- alias of the channel's `owner_alias` for task-level decomposition -->

## Phase 0 — Research (optional)

<!--
Run when the spec references technologies the team hasn't worked with.
Uses the 3-role pipeline: scout → curator → reviewer.
Skip entirely if spec-referenced tech is well-understood.
-->

- [ ] **Scout**: identify research topics from spec's [NEEDS CLARIFICATION] and unfamiliar NFRs.
  - Output: `research.md` with raw findings.
- [ ] **Curator**: deduplicate scout's output; extract references to `/contracts/`.
  - Output: `/contracts/<topic>.md` per extracted pattern.
- [ ] **Reviewer**: review curator's output against spec FRs; sign off or reject.
  - Output: check here when signed off.

## Phase 1 — Contracts

<!--
Each contract states: inputs, outputs, failure modes, test hook.
The "contract integrity gate" runs before Phase 2 advances.
-->

- [ ] **data-model.md** — data shapes referenced by FRs.
- [ ] **/contracts/<per-FR-contract>.md** — one per FR that has an I/O boundary.
  - Input shape + validation rules.
  - Output shape + idempotency semantics.
  - Failure modes + retry policy.
  - Test hook: how will `evals/` verify this contract?

## Phase 2 — Implementation plan

<!-- Ordered list of implementation steps. Mark parallel where possible. -->

| # | Step | Depends on | Parallel-with |
|---|---|---|---|
| 1 | ... | — | — |
| 2 | ... | 1 | — |
| 3 | ... | 1 | 2 |

<!-- If complexity warrants, include a C4 diagram here. -->

## Phase 3 — Verification

<!-- Pointer to phase-verification checklist. Populated by /council-post --type status. -->

- [ ] All success criteria validated.
- [ ] Coverage matrix complete.
- [ ] No open [NEEDS CLARIFICATION] markers.

## Risks

<!-- Known risks + mitigations. Surfaces during Council review. -->

| Risk | Impact | Mitigation |
|---|---|---|
| ... | ... | ... |

---

**Plan metadata**:
- Created: <!-- ISO-8601 -->
- Last updated: <!-- ISO-8601 -->
- Gate status: `open` (passes when all Phase 1 contracts have test hooks + all spec FRs represented)
