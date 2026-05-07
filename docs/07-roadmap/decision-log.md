# Decision log — milestone-level transitions

Tracks every RED → GREEN feature transition with commit SHA + wave + date for fast audit.

Rules:
- Append-only. Never rewrite past entries.
- One row per transition. If the feature later regresses, log a NEW row (don't edit the original).
- Cross-references commit SHAs and the wave / lane that landed the transition.

## Schema

| F-NNN | Slug | Milestone | Transition | Wave / lane | Date | Impl commit SHA | Catalog/roadmap commit SHA | Examples-proof | Notes |

## Entries (as of wave-011 / 2026-05-07)

| F-NNN | Slug | Milestone | Transition | Wave / lane | Date | Impl commit | Catalog/roadmap commit | Examples-proof | Notes |
|---|---|---|---|---|---|---|---|---|---|
| F-001 | engine-bootstrap-loop | M0 (bootstrap) | RED → 🟢 GREEN | wave-005 / lane-d | 2026-05-07 | `e83f0b9` (`feat(M0): F-001 engine-bootstrap-loop GREEN — minimal lifecycle + hash-chained audit`) | `159449` ledger; `077895f` roadmap | `docs/09-examples-proof/F-001/` | First feature transition in repo. ~95 LOC; 3/3 acceptance scenarios. |
| F-001 | engine-bootstrap-loop | M0 (bootstrap) | 🟢 GREEN → 🔒 LOCKED | wave-011 / lane-b | 2026-05-07 | N/A (no source changed) | `4519cd6` review; `f13ff71` ledger; `5796949` roadmap; `6f0a3a0` confidence-ledger | `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` | **FIRST LOCKED transition in the repo.** Council review verdict ACCEPT (Verdict consensus: APPROVE; median confidence 88; 0 CRITICAL / 0 MAJOR / 3 MINOR / 3 PRAISE). Proves RED → GREEN → LOCKED state machine end-to-end. |
| F-002 | per-agent-identity-runid | M0 (bootstrap) | RED → 🟢 GREEN | wave-006 / lane-d | 2026-05-07 | `5a0eb21` (`feat(M0): F-002 per-agent-identity-runid GREEN — UUID v7 + spawn correlation + IDENTITY_MISSING rejection`) | `48b5d4b` ledger; `3413cfb` roadmap | `docs/09-examples-proof/F-002/` | Second feature; UUID v7 monotonic-prefix flake noted. ~110 LOC. |
| F-014 | pre-close-retro-signal | M2 (governance triad) | RED → 🟢 GREEN | wave-008 / lane-a | 2026-05-07 | `ba54036` (`feat(M2): F-014 pre-close-retro-signal GREEN — closeSession + RetroSignal + RetroMissingError`) | `5b98d29` ledger; `4404cf8` roadmap; `2e1398b` examples-proof | `docs/09-examples-proof/F-014/` | First M2 feature. ~180 LOC; 8/8 scenarios. RED test commit `d896ecb`. |
| F-015 | hash-chained-audit-log | M2 (governance triad) | RED → 🟢 GREEN | wave-008 / lane-b | 2026-05-07 | `23f4475` (`feat(F-015): GREEN impl for hash-chained audit log`) | `2545036` ledger + roadmap + confidence-ledger + examples-proof combined | `docs/09-examples-proof/F-015/` | Second M2 feature. ~165 LOC; AuditEntry → AuditLogEntry rename to avoid collision with F-001's existing AuditEntry interface. RED test `3d91a72`. |

## Wave-9 / Lane D note

This decision log was created in wave-9 / lane-d as a backlog-intake side-effect (the brief's step 5). Future GREEN transitions should append a row here AT THE TIME OF THE TRANSITION (not retroactively). Lane summary lives at `docs/06-agent-team-outputs/wave-009/lane-d-summary.md`.
