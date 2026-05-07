# Retire candidates

Tools / surfaces flagged ACTIVE → OBS or OBS → RETIRED. Per the prior session's `[A:per-item-review.md]`, 12 items were flagged as retire candidates. Wave-1 / Lane D enumerated kit drops (~50 LENS-specific) that inform this list.

Per `no-silent-deferrals.md`: removing user-tracked items requires explicit acknowledgement at periodic interview gate L3.

## Schema

```
| ID | Item | Current state | Proposed transition | Source (which wave/lane/finding flagged this) | Date | Confidence | Rationale |
```

## Entries

| ID | Item | Current state | Proposed transition | Source | Date | Confidence | Rationale |
|---|---|---|---|---|---|---|---|
| RC-1 | LENS-CMS-specific deployment scripts (`Ev2-Deploy.ps1`, `Diagnose-LensDcsDeploy.ps1`, etc. ~50 scripts) in engine kit | ACTIVE | OBS (do NOT lift to engine kit) | wave-001 lane-d kit-inventory ~50 LENS-specific | 2026-05-07 | HIGH | engine is LENS-agnostic; LENS deploy scripts have no place in tmalcolm/mad-council-claw |
| RC-2 | LENS-CMS test infrastructure (`Run-DotnetGates.ps1`, `Test-Api-ACI.sh`, etc.) | ACTIVE | OBS | wave-001 lane-d kit-inventory | 2026-05-07 | HIGH | engine uses Vitest+Playwright (TS), not .NET; LENS test scripts are LENS-CMS-specific |
| RC-3 | `.NET / C# patterns` directory (`.claude/rules/patterns/_dotnet/`) | ACTIVE | DEFERRED (do NOT include in engine v1) | wave-001 lane-d kit-inventory ~32 .NET patterns | 2026-05-07 | HIGH | engine is TypeScript; .NET patterns are kit-only |
| RC-4 | `dgrep-query` skill (Geneva/Microsoft-internal logs) | ACTIVE | DEFERRED | wave-001 lane-d kit-inventory | 2026-05-07 | MEDIUM | engine targets local-first observability (M16 OTel); Geneva is Microsoft-internal, useful for dev but not engine-shipped |
| RC-5 | `cms-demo-case` skill | ACTIVE | OBS | wave-001 lane-d kit-inventory | 2026-05-07 | HIGH | LENS-CMS-specific demo prep script; not engine-relevant |
| RC-6 | `cosmos-provisioning` skill | ACTIVE | DEFERRED | wave-001 lane-d kit-inventory | 2026-05-07 | MEDIUM | engine v1 uses local SQLite or filesystem-only; Cosmos is M9-adjacent (Foundry storage) — keep in deferred queue |
| RC-7 | `coverage-fix` skill | ACTIVE | OBS | wave-001 lane-d kit-inventory | 2026-05-07 | MEDIUM | LENS ADO-specific; engine uses GitHub Actions — needs different cov-fix shape |
| RC-8 | `lens-aspnet-structure` + `lens-pipeline-audit` + `lens-standards-audit` + `lens-telemetry` skills | ACTIVE | OBS | wave-001 lane-d kit-inventory | 2026-05-07 | HIGH | LENS-specific audit skills; engine is non-LENS |
| RC-9 | `check-environment-health` skill (consumer-project Azure/Cosmos health) | ACTIVE | DEFERRED | wave-001 lane-d kit-inventory | 2026-05-07 | MEDIUM | engine has its own health surfaces (M16 telemetry); kit's check-environment-health targets LENS App Service shape |
| RC-10 | `mad-teams` skill (predates council-* skills) | ACTIVE | OBS (per D-16) | wave-001 lane-d Q2 | 2026-05-07 | MEDIUM | redundant with council-* skill family; closure pending D-16 council-review |
| RC-11 | LENS-specific wiki docs (~5 of 80) | ACTIVE | OBS | wave-001 lane-d kit-inventory | 2026-05-07 | HIGH | engine kit imports ~75 of 80 wiki docs; ~5 LENS-CMS deploy / Geneva / etc. drop |
| RC-12 | LENS-specific hooks (count TBD; subset of 49) | ACTIVE | DEFERRED | wave-001 lane-d kit-inventory | 2026-05-07 | MEDIUM | most 49 hooks transfer; LENS-specific subset (deploy-related, ADO-specific) drops; need per-hook audit in M0 wave |
| RC-13 | Canonical-e scope-exclusion items (24 explicit `[v1 MUST NOT]` markers) | per CE | DEFERRED (respect verbatim) | wave-001 lane-d canonical-e-inventory | 2026-05-07 | HIGH | enforced via canonical-e's FR-MUST-NOT-001 grep gate; engine inherits the scope-exclusion list |
| RC-14 | Canonical-e v-next-release sanctioned deferral list (11 items) | per CE | DEFERRED | wave-001 lane-d canonical-e-inventory | 2026-05-07 | HIGH | all 11 have v1 substitute documented; engine respects the postponement list |
| RC-15 | OpenClaw v3.x plugin SDK (predates v4.0 typed SDK) | OBS | RETIRED (do NOT lift; v4.0 reference is canonical) | wave-001 lane-c openclaw-v4-roadmap | 2026-05-07 | MEDIUM | openclaw v4.0 plugin SDK v2 is the forward-looking reference; engine should follow v4.0 conceptual guidance, not v3.x patterns |

## Wave-2 task — superseded

The original "Wave 2 task" instruction here said: "Read `C:\Users\tonym\Repos\MAD - Clean\specs\15-nested-quilt\per-item-review.md` (if it exists), find the 12 retire-flagged items, populate this table." That work is partially done above using wave-1 lane-d kit-inventory output (which enumerated drops). A wave-3+ pass should still cross-check `per-item-review.md` if it exists in the prior session's artifact directory; differences become entries RC-16 onward.

## Confidence rationale

- HIGH = item is unambiguously LENS-specific or canonical-e scope-excluded; no engine-side debate
- MEDIUM = item is partially relevant; needs per-feature audit (e.g., subset of hooks, demo skill)
- The 12 placeholder rows in the prior session's audit are now superseded by RC-1..RC-15 (15 actual entries from wave-1 lane-d evidence).
