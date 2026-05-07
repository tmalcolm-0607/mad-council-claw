---
artifact-class: milestone-overview
generated-by: hand-authored (wave-005 / lane-c)
status: red
milestone: M11
short-slug: soul-introspect-replay
features: F-088..F-092
authored: 2026-05-06
---

# M11 — Soul / introspect / replay

The canonical-e governance pillar (`foundational-plan.md` § Architecture). Soul boundary + schema + introspection + signal pairs + deterministic replay together form the meta-governance plane: M2 governs *what* runs do; M11 governs *what runs are allowed to be* and *how we know what they actually were*. A run that completes WITHOUT M11 features active has no immutable boundary, no self-vs-grader calibration, and no reproducible replay — it cannot satisfy canonical-e's accountability discipline.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-088 | soul-boundary | Immutable per-run boundary; engine `--force` cannot override; tool/orchestration violations reject with SOUL_BOUNDARY_VIOLATION |
| F-089 | soul-document-schema | `soul.json` JSON Schema validation; unknown keys reject with SOUL_SCHEMA_VIOLATION; load event stamped to audit log |
| F-090 | introspection-snapshot | Per-cycle per-agent self-snapshot (5-axis 1-5 + doing/blocking prose + audit-range SHA) |
| F-091 | introspection-signal-pairs | Grader peer-agent emits outcome signal; `Grader.agent_id != work_agent_id` invariant; CALIBRATION_DRIFT on gap >= 2 |
| F-092 | deterministic-replay | Replay manifest + 4 enumerated exclusions; byte-equivalent re-execution on same-version engine |

## Dependency DAG

```
M0 (F-001 kernel, F-002 identity, F-008 storage) ──→ all M11 features
M2 (F-014 retro, F-015 audit-chain) ──→ M11 features

F-089 (schema) ──→ F-088 (boundary consumes validated soul)
              └──→ F-092 (frozen-input snapshot includes loaded soul)

F-088 (boundary) ──→ F-018 (soul violation may escalate to halt)
                └──→ F-020 (soul violation MAY trigger kill)

F-090 (self-snapshot) ──→ F-091 (grader pairs self vs outcome)
                     └──→ F-014 (close emits final snapshot)

F-091 (signal pairs) ──→ F-015 (CALIBRATION_DRIFT audit entry)

F-015 (audit chain head) ──→ F-092 (chain head is determinism anchor)
F-002 (agent identity) ──→ F-091 (Grader.agent_id != work_agent_id invariant)
```

## Milestone exit criteria

- All 5 ledgers GREEN
- A `soul.json` missing required clauses rejects boot with `SOUL_SCHEMA_VIOLATION`
- A tool call violating a loaded soul clause rejects with `SOUL_BOUNDARY_VIOLATION` and stamps audit log
- `--force` cannot override soul boundary in any code path (verified by integration test)
- Every cycle boundary emits a snapshot per active agent; missing snapshot blocks cycle advance with `INTROSPECT_MISSING`
- Grader peer-agent identity invariant enforced: `GRADER_IDENTITY_VIOLATION` on collision
- A pure-deterministic run replays byte-equivalent on the same engine binary
- A run with declared exclusions reports excluded fields as `excluded_diff` (not `divergence`)

## Pending design decisions blocking M11 implementation

- **D-2** — Soul boundary enforcement *location* (IBackendProvider vs orchestration plane vs tool plane). Closure: M11 design wave council-review per `docs/10-backlog/design-decisions-pending.md`.
- **D-8** — Soul scope default = full canonical-e concept (which clauses MUST appear in v1 soul.json). Referenced in F-088 + F-089 ledgers; closure: M11 design wave council-review.
- **D-26** — Soul boundary enforcement mechanism: compile-time + runtime defense-in-depth (option a, RECOMMENDED) vs runtime-only (b) vs capability-based (c, deferred to v-next). HIGH-confidence per wave-3 cross-model corroboration.

## Out of scope (tracked elsewhere)

- Cryptographic signing of `soul.json` (sigstore / third-party timestamp) — v1.5 per FR-IDENTITY-002 family
- Outlook/Teams/WorkIQ snapshot capture for replay — v1.5 (FR-OUTLOOK/TEAMS/WORKIQ-SNAPSHOT-001)
- Replay UI scrubber overlay — M12 visualization (D-7 closure)
- Multi-grader adversarial calibration — post-v1 (v1 = single grader per session)
- Cross-engine-version replay — post-v1 (v1 same-version only)
- Auto-remediation policies on CALIBRATION_DRIFT — v1.5
- Capability-based (object-capability) soul enforcement — v-next per D-26 option (c)

## Provenance

`ce:FR-SOUL-001`, `ce:FR-SOUL-SCHEMA-001`, `ce:FR-INTROSPECT-001/002`, `ce:FR-CALIBRATION-001`, `ce:FR-REPLAY-001`, `kit:rules/{non-negotiable-rules, orchestrator-identity, canonical-artifact-frontmatter, no-silent-deferrals, verification-protocol, lens-multi-model-review-pattern, concurrency-safety}.md`, `kit:council-retro-skill`. Per-ledger `provenance.surfaces`.
