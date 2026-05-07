---
title: Lane D summary — wave-001
date: 2026-05-06
wave: wave-001
lane: lane-d
topics_committed: 3
status: complete
confidence: HIGH (kit + CE) / MEDIUM (CP cross-walk pending)
---

# Lane D summary — MAD kit + canonical-e foundational mapping

## Topics delivered

| # | Topic | Output file | Confidence |
|---|---|---|---|
| 1 | MAD kit primitives inventory | `docs/04-research/mad-kit-inventory.md` | HIGH |
| 2 | Canonical-e spec foundational mapping | `docs/04-research/canonical-e-inventory.md` | HIGH |
| 3 | Cross-source disposition matrix | `docs/04-research/cross-source-disposition-matrix.md` | MEDIUM (CP source pending) |

## Key counts (verified via Glob + Grep, not estimated)

### MAD kit (K)

| Surface | Count |
|---|--:|
| Skills | 70 |
| Rules + patterns | 96 |
| Hooks | 49 |
| Scripts (.claude/scripts + .mad/scripts) | 175 (101 + 74) |
| Agent personas | 0 (subagent_type tokens, no persona files) |
| Templates + coverage oracles | 41 (29 + 12) |
| Schemas | 0 (live inline; no `.mad/schemas/` directory) |
| Wiki docs | 80 |

### Canonical-e (CE)

| Surface | Count | Briefing-vs-actual |
|---|--:|---|
| Functional Requirements | 49 distinct | Briefing said 48 (43+5); actual = 49 |
| User Stories | 8 (P1×3, P2×4, P3×1) | Matches briefing |
| Success Criteria | 17 | Matches briefing |
| Entities | 19 | Briefing said 16; actual = 19 (3 added late) |
| Event types (numbered top-level) | 12 | Briefing said 24; actual = 12 (briefing likely counted sub-events) |
| Error codes | 72 | Briefing said 24; actual = 72 (briefing significantly undercounted) |
| Implementation phases | 7 (Phase 0..6) | Briefing said 6; actual = 7 (Phase 0 included) |
| Test cases | 88 | Briefing said 80; actual = 88 (8 added late) |
| Analysis findings | 19 | Matches briefing |
| Out-of-scope items | 24 (`[v1 MUST NOT]`) | Briefing said "8 explicitly excluded"; actual = 24 |
| Sanctioned v1.5 deferrals | 11 (3 iter-41 + 8 Cat-B traceable) | Briefing said 5; actual = 11 |

## Disposition summary across all 3 outputs

| Action | K | CE | Combined |
|---|--:|--:|--:|
| keep | ~280 | 38 FRs + 8 USs + 17 SCs + 18 ent + 11 events + 70 errors + 7 phases + 88 TCs | majority |
| change | ~10 | 1 FR (FR-IDENTITY-001 → chain) | ~11 |
| drop | ~50 (LENS-specific) | 6 OoS items + 2 deprecated errors | ~58 |
| defer | ~35 (.NET patterns) | 11 v1.5 sanctioned + 7 OoS deferred | ~53 |
| decision-pending | ~3 | 1 (re-import 7 missing skills) | ~4 |

## Briefing miscount findings (worth surfacing to user)

The lane briefing's CE counts undercounted significantly across multiple surfaces:

| Surface | Briefing | Actual | Delta |
|---|--:|--:|--:|
| FRs | 48 | 49 | +1 |
| Entities | 16 | 19 | +3 |
| Event types | 24 | 12 | -12 (probably counted sub-events) |
| Error codes | 24 | 72 | +48 |
| Phases | 6 | 7 | +1 |
| Test cases | 80 | 88 | +8 |
| OoS items | 8 | 24 | +16 |
| Sanctioned deferrals | 5 | 11 | +6 |

**Implication**: future lane briefings should pull counts from `.mad/scripts/Compute-FrCount.ps1` (or equivalent) rather than carrying inline numbers. The canonical-e spec evolved fast late in iter-41; cached counts go stale within hours.

## Lane C dependency

Topic 3 (cross-source disposition matrix) is **MEDIUM confidence** because Lane C (openclaw-clawpilot inventory) had not committed `clawpilot-features-inventory.md` when Lane D ran. All `[NEEDS LANE C]` rows in `cross-source-disposition-matrix.md` will be folded into a wave-2 cross-walk when Lane C lands.

The K + CE cross-walk (~85% of the matrix surface) is HIGH confidence as both sources were directly enumerated.

## Surfaces where engine MUST build new (no K + no CE)

8 file/directory locations the engine must create:
1. `~/.collab-engine/` (engine runtime persistence root)
2. `<channel-dir>/oauth-grants/<adapter>.json` (per FR-EXT-WRITE-SCOPE-001)
3. `.mad/policy/skills-allowlist.json` (per FR-GOV-001)
4. `.mad/policy/soul.json` (per FR-SOUL-001)
5. `.mad/policy/kill-switches/<change-id>.json` (per FR-KILL-001)
6. `calibration-approvals/<suggestion_id>` touch-file dir (per FR-CALIBRATION-001)
7. `replay-manifests/<run_id>.json` (per FR-REPLAY-001)
8. `.mad/policy/external-write-rates.json` (per FR-EXT-WRITE-RATE-001)

## 7 critical engine-design implications

1. **Most kit primitives transfer cleanly** (~80% domain-neutral). Engine inherits, doesn't fork.
2. **5 anti-pattern hooks are LOAD-BEARING** for engine v1. Without them, the iter-1-41 collab-engine spiral repeats.
3. **Cost is observability-ONLY** — repeating in 4 different files because iter-41 refactor was the load-bearing change. NEVER halt on cost threshold.
4. **Halt-precedence ladder is non-negotiable**: KILL > SOUL > OVERRIDE > GOV > QUOTA > DEGRADE > COST.
5. **5 Cat-B answers shape v1 scope** (Q1, Q3, Q4, Q5, Q6). Without these answers, v1 scope collapses.
6. **The MAD pipeline is the engine's primary contract surface** — engine consumes via Skill tool; canonical-skill-only enforcement is the contract.
7. **Schema directory needs explicit creation** — kit references schemas inline; engine needs `.mad/schemas/` populated for canonical artifact frontmatter checks.

## Open questions surfaced (for backlog)

| # | Question | Source |
|---|---|---|
| Q1 | Schema directory location: `.mad/schemas/` or `schemas/`? | K (no existing dir) |
| Q2 | `mad-teams` vs `council-*`: drop mad-teams? | K (predates council) |
| Q3 | Engine packaging: npm / .NET tool / PowerShell module? | architecture |
| Q4 | Stage Phase 0-3 first then 4-6 in v1.x, or all 7 in v1? | CE phases |
| Q5 | Re-import 7 missing predecessor skills? | CE OoS #12 |

## Files committed by Lane D

3 research files + 1 lane summary = 4 commits:

```
research(kit-and-canonical-e): mad-kit-inventory
research(kit-and-canonical-e): canonical-e-inventory
research(kit-and-canonical-e): cross-source-disposition-matrix
docs(lane-output): lane-d-summary
```

## Wall-clock

Lane D total: ~5 min wall-clock (within budget).

Most expensive operations:
- Initial Glob across 7 paths in parallel: ~5s
- Grep counts (FRs, SCs, error rows, etc.): ~3s sequential
- File writes (3 inventory files + 1 summary): ~10s
- Commits: ~5s sequential
