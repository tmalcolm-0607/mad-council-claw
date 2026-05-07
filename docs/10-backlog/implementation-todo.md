# Implementation TODO

F-NNN features waiting for implementation (RED state). Filled from `docs/03-feature-catalog/` once feature ledgers are authored.

Wave-2 / Lane D bootstrapped this list with the M0..M2 implementation slate that should be authored first per Lane B wave-2's catalog drop. Until ledgers exist, this file lists the F-NNN identifiers + milestone + provenance. Implementation cannot start on an F-NNN until its ledger is written + its RED test exists.

## Schema

```
| F-NNN | Title | Milestone | Source citations | Confidence | Blocking decisions (D-N) | Status |
```

## Entries — M0 (Project bootstrap)

| F-NNN | Title | Milestone | Source | Confidence | Blocking | Status |
|---|---|---|---|---|---|---|
| F-001 | engine-bootstrap-loop | M0 | foundational-plan.md M0 + Lane C L1 (per-agent isolation) + Lane C L4 (IPC contract) | HIGH | none | RED — ledger exists at `[A:features/F-001-engine-bootstrap-loop.md]`; awaiting copy into mad-council-claw repo |
| F-002 | per-agent-identity | M0 | foundational-plan.md M0 + Lane C L2 (refresh-token-per-role) + D-20 (resolved HIGH) | HIGH | D-20 (closed) | RED — needs ledger drafted |
| F-003 | scaffolding-typescript | M0 | foundational-plan.md M0 (TS+Electron+Vitest) + V:3 | HIGH | none | RED — needs ledger drafted |
| F-004 | vitest-playwright-harness | M0 | foundational-plan.md M0 + Lane C clawpilot vitest.config.ts | HIGH | none | RED — needs ledger drafted |
| F-005 | dependency-management | M0 | foundational-plan.md M0 | HIGH | none | RED — needs ledger drafted |
| F-006 | structured-logging | M0 | foundational-plan.md M0 + Lane B Topic 8 (OTel) | HIGH | D-11 (OTel adoption depth) | RED — needs ledger drafted |
| F-007 | ipc-contract | M0 | foundational-plan.md M0 + Lane C L4 | HIGH | none | RED — needs ledger drafted |
| F-008 | storage-layout | M0 | foundational-plan.md M0 + Lane C L1 (per-agent FS isolation) | HIGH | D-15 (schema dir location) | RED — needs ledger drafted |
| F-127 | three-tier-eval-harness | M0 | wave-001 consolidated F-127 (4-way convergence Lane A F-013 + F-053) | HIGH | none | RED — needs ledger drafted; load-bearing per "evals first" discipline |
| F-167 | blueprint-as-kit-config | M0 | wave-001 consolidated F-167 (Lane B Topic 3) | MEDIUM | D-15 | RED — needs ledger drafted |
| F-171 | agent-builder-import | M0 | wave-001 consolidated F-171 (Lane B Topic 4) | MEDIUM | D-15 | RED — deferred until M0 baseline exists |

## Entries — M1 (Pluggable backend)

| F-NNN | Title | Milestone | Source | Confidence | Blocking | Status |
|---|---|---|---|---|---|---|
| F-009 | ibackend-provider-interface | M1 | foundational-plan.md M1 | HIGH | D-1 (provider abstraction shape) | RED — needs ledger drafted |
| F-010 | anthropic-sdk-adapter | M1 | foundational-plan.md M1 | HIGH | D-1 | RED — needs ledger drafted |
| F-011 | copilot-sdk-adapter | M1 | foundational-plan.md M1 | HIGH | D-1 | RED — needs ledger drafted |
| F-012 | provider-factory | M1 | foundational-plan.md M1 | HIGH | D-1 | RED — needs ledger drafted |
| F-013 | event-normalization | M1 | foundational-plan.md M1 | HIGH | D-1 | RED — needs ledger drafted |
| F-124 | multi-tier-routing | M1 | foundational-plan.md F-124 (already allocated) + wave-001 4-way convergence | HIGH | D-4 (LOW; needs research wave first) | RED — pending D-4 closure |
| F-133 | extended-thinking-budget | M1 | wave-001 consolidated F-133 | MEDIUM | D-1 | RED — needs ledger drafted |
| F-139 | handoff-context-shaping | M1 | wave-001 consolidated F-139 | MEDIUM | D-1 + D-17 | RED — needs ledger drafted |
| F-144 | byok-multi-provider | M1 | wave-001 consolidated F-144 | MEDIUM | D-5 (storage encryption) | RED — needs ledger drafted |
| F-168 | claude-code-sdk-bridge | M1 | wave-001 consolidated F-168 | MEDIUM | D-1 | RED — needs ledger drafted |
| F-190 | af-typescript-bridge | M1 | wave-001 consolidated F-190 | MEDIUM | RG-2 (research gap) + D-9 | RED — pending RG-2 closure |
| F-191 | backend-adapter-registry | M1 | wave-001 consolidated F-191 | MEDIUM | D-1 | RED — needs ledger drafted |

## Entries — M2 (Governance triad)

| F-NNN | Title | Milestone | Source | Confidence | Blocking | Status |
|---|---|---|---|---|---|---|
| F-014 | pre-close-signal | M2 | foundational-plan.md M2 | HIGH | none | RED — needs ledger drafted |
| F-015 | hash-audit-log | M2 | foundational-plan.md M2 + canonical-e FR-AUDIT-001 | HIGH | none | RED — needs ledger drafted |
| F-016 | query-audit | M2 | foundational-plan.md M2 + canonical-e FR-AUDIT-002 | HIGH | none | RED — needs ledger drafted |
| F-017 | pii-redaction | M2 | foundational-plan.md M2 + canonical-e FR-AUDIT-PRIVACY-001 | HIGH | none | RED — needs ledger drafted |
| F-018 | failure-pattern-halt | M2 | foundational-plan.md M2 (validated industry-default per Lane A F-018) | HIGH | none | RED — needs ledger drafted |
| F-019 | cost-ledger | M2 | foundational-plan.md M2 + D-22 (HIGH; observability-only) | HIGH | D-22 (closed HIGH) | RED — needs ledger drafted |
| F-020 | kill-switch | M2 | foundational-plan.md M2 + canonical-e FR-KILL-001 + D-23 (precedence ladder) | HIGH | D-23 (closed HIGH) | RED — needs ledger drafted |
| F-021 | degradation-mode | M2 | foundational-plan.md M2 | HIGH | D-23 | RED — needs ledger drafted |
| F-022 | tool-quota | M2 | foundational-plan.md M2 + D-3 + tightened by Lane B | HIGH | D-3 (cap default value) | RED — needs ledger drafted |
| F-128 | orchestrator-worker-primitive | M2 | wave-001 consolidated F-128 (3-way convergence) | HIGH | D-17 | RED — needs ledger drafted |
| F-129 | handoff-as-tool | M2 | wave-001 consolidated F-129 (4-way convergence) | HIGH | D-17 | RED — needs ledger drafted |
| F-130 | task-clarity-gate | M2 | wave-001 consolidated F-130 (load-bearing 67%/15% asymmetry) | HIGH | D-18 + RG-12 (corroboration) | RED — needs ledger drafted; load-bearing per Lane A wave-1 finding #1 |
| F-134 | parallel-tool-call-fan-out | M2 | wave-001 consolidated F-134 | MEDIUM | none | RED — needs ledger drafted |
| F-138 | autonomy-level-tag | M2 | wave-001 consolidated F-138 | MEDIUM | none | RED — needs ledger drafted |
| F-149 | aider-architect-mode | M2 | wave-001 consolidated F-149 | MEDIUM | none | RED — needs ledger drafted |
| F-151 | cline-act-vs-plan-toggle | M2 | wave-001 consolidated F-151 | MEDIUM | none | RED — needs ledger drafted |
| F-161 | orchestration-pattern-selector | M2 | wave-001 consolidated F-161 | MEDIUM | D-9 (TS bridge resolution) | RED — needs ledger drafted |
| F-174 | connected-agent-governance-checklist | M2 | wave-001 consolidated F-174 | MEDIUM | D-10 (Activity Protocol priority) | RED — needs ledger drafted |
| F-188 | agent-governor-component | M2 | wave-001 consolidated F-188 | MEDIUM | none | RED — needs ledger drafted |
| F-189 | capability-token-mint | M2 | wave-001 consolidated F-189 | MEDIUM | none | RED — needs ledger drafted |
| F-192 | fan-out-template-helper | M2 | wave-001 consolidated F-192 | MEDIUM | none | RED — needs ledger drafted |

## Pickup convention

Per the multi-instance pickup protocol in `docs/11-loop-state/README.md`: any instance can claim an F-NNN here by appending to the claim table in `current-wave.md`, then commit the implementation per micro-session discipline (≤1 feature per PR; behavior contract + acceptance scenarios + RED test before; GREEN after; status table evidence).

**Order of operations**:
1. Author the ledger file under `docs/03-feature-catalog/M<n>-*.md` (or `specs/features/F-NNN-*.md` per the foundational plan's repo bootstrap shape).
2. Author the RED test under `tests/unit/F-NNN-*.test.ts`.
3. Confirm RED state (test fails as expected).
4. Implement minimum viable behavior under `packages/<scope>/`.
5. Confirm GREEN state.
6. Council-review per `review-gate-protocol.md`.
7. Mark LOCKED in feature ledger; commit + PR per micro-session discipline.

## Wave-2 / Lane D handoff note

This file lists ~50 F-NNN ready for ledger drafting (M0 + M1 + M2). Wave-2 / Lane B (the catalog drop wave running in parallel) authors the ledger files for M0..M2; this file gets cross-walked when those ledgers land. Many "Blocking" rows reference D-N decisions which themselves depend on closure waves; the dependency chain is:

```
RG-N research-gap → wave-N research lane → D-M decision closure → F-NNN ledger draft → RED test → impl → GREEN → LOCKED
```

The longest blocking chain currently: F-130 task-clarity-gate ← D-18 confidence threshold ← RG-12 corroboration of 67%/15% asymmetry ← wave-3+ frontier lane.
