# Confidence ledger

Per kit's `verification-protocol.md` and the user directive "as new items get added to the loop. we should keep medium and high confidence items": every finding's confidence over time. HIGH ↔ MEDIUM transitions captured.

## Schema

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|

## Entries — Wave 1 (introduced 2026-05-07)

### Lane A — Frontier whitepapers (63 raw → 33 after dedup)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-A-cluster-1 (4-way convergence: handoff-as-tool / dispatch / capability-negotiation) | F-002 + F-021 + F-029 + F-040..F-044 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Multi-source convergence (Anthropic + OpenAI + MCP + Cursor) IS the validation; allocated as F-129 |
| Lane-A-cluster-2 (3-way convergence: orchestrator-worker / handoff / opaque-collab) | F-010 + F-021 + F-058 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-128 |
| Lane-A-cluster-3 (3-way convergence: 3-tier-evals / evals-first-scaffold) | F-013 + F-053 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-127 |
| Lane-A-cluster-4 (3-way convergence: monitor-not-approve / agentic-mode / task-clarity) | F-018 + F-044 + F-049 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-130; load-bearing 67%/15% asymmetry |
| Lane-A-cluster-5 (cross-cutting infra: OTel-default-tracing) | F-035 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-145; reinforced by Lane B Topic 8 |
| Lane-A-cluster-6 (durable-checkpoint-resume) | F-014 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-131; kit gap |
| Lane-A-cluster-7 (agent-card-publishing) | F-057 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-132; A2A discoverability |
| Lane-A-cluster-8 (BYOK-multi-provider / model-routing) | F-034 + F-050 | HIGH | wave-001 / lane-a | wave-002 / lane-d | Merged into existing F-124 |
| Lane-A-residual (~25 single-source candidates) | F-001..F-063 misc | MEDIUM | wave-001 / lane-a | wave-002 / lane-d | Allocated as F-127..F-159 in consolidation; promote to HIGH after corroboration wave |
| Lane-A-trends-PDF | anthropic-2026-agentic-coding-trends.md | MEDIUM | wave-001 / lane-a | wave-002 / lane-d | Source gated; tracked as RG-4 |

### Lane B — Microsoft 2026 (34 candidates → 30 after dedup)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-B-cluster-1 (Activity Protocol everywhere) | Topics 4 + 5 + 6 + 8 | HIGH | wave-001 / lane-b | wave-002 / lane-d | Allocated as F-175; 3-Microsoft-surface convergence |
| Lane-B-cluster-2 (A2A as cross-boundary lingua franca) | Topics 1 + 3 + 7 | HIGH | wave-001 / lane-b | wave-002 / lane-d | Reinforces F-122; allocated F-178..F-181 |
| Lane-B-cluster-3 (OTel GenAI conventions) | Topics 1 + 3 + 5 + 8 | HIGH | wave-001 / lane-b | wave-002 / lane-d | Reinforces F-123; allocated F-182..F-184 |
| Lane-B-cluster-4 (Per-agent isolation boundary) | Topics 2 + 3 + 9 | HIGH | wave-001 / lane-b | wave-002 / lane-d | Reinforces Lane C L1 |
| Lane-B-cluster-5 (Foundry memory PREVIEW) | Topic 9 | MEDIUM | wave-001 / lane-b | wave-002 / lane-d | RG-6 + D-19; F-185..F-187 inherit preview risk |
| Lane-B-cluster-6 (TS samples sparse for AF) | Topic 11 | MEDIUM | wave-001 / lane-b | wave-002 / lane-d | RG-2; D-9; F-190 ledger blocked on resolution |
| Lane-B-cluster-7 (WorkIQ corpus thin) | Topic 10 | MEDIUM | wave-001 / lane-b | wave-002 / lane-d | RG-1; F-188..F-189 still authorable from Microsoft Learn evidence |
| Lane-B-residual (~22 single-topic candidates) | F-160..F-189 | MEDIUM | wave-001 / lane-b | wave-002 / lane-d | Allocated in consolidation; promote after second-source corroboration |

### Lane C — Clawpilot/openclaw (15 lessons L1..L15; 0 net-new F-NNN)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| L1 (per-agent FS isolation) | clawpilot ~/.copilot + openclaw issue F2 | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-008 |
| L2 (refresh-token-per-role) | openclaw issue F3 + clawpilot §11 | HIGH | wave-001 / lane-c | wave-002 / lane-d | D-20 closed HIGH; tightens F-002 |
| L3 (parent-child supervision) | openclaw issue F4 | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-028..F-031 |
| L4 (IPC contract single source-of-truth) | clawpilot ipc-contract.ts + openclaw v4 plugin SDK v2 | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-007 |
| L5 (default-deny capabilities) | clawpilot permission tiers + canonical-e FR-CAP-001 | HIGH | wave-001 / lane-c | wave-002 / lane-d | Reinforces F-018, F-020, F-022 |
| L6 (IBackendProvider with lint-enforced invariants) | clawpilot adapter pattern | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-009; informs D-1 |
| L7 (IMemoryProvider abstraction) | clawpilot memory shape | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-185..F-187 |
| L8 (IPlatformAdapter) | clawpilot Electron+headless dual-mode | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-001 + F-028 |
| L9 (bounded retry + circuit breaker) | clawpilot heartbeat + canonical-e degradation policy | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-021 + F-023..F-027 |
| L10 (operator-visible state) | clawpilot info-panel + canonical-e UX | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-035..F-043 (M5 desktop) |
| L11 (multi-agent first / production-grade day 1) | openclaw lessons + canonical-e M2 priority | HIGH | wave-001 / lane-c | wave-002 / lane-d | Reinforces F-014..F-022 |
| L12 (beta+stable release channels) | clawpilot release pattern + openclaw v2026.5.x | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-104..F-109 |
| L13 (per-feature telemetry tests) | canonical-e test plan | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-110..F-113 |
| L14 (cross-platform Windows-first) | clawpilot platform support | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-104..F-109 |
| L15 (governance triad: audit-log + signed-verdicts + cost-ledger) | canonical-e M2 + Lane B Topic 10 | HIGH | wave-001 / lane-c | wave-002 / lane-d | Tightens F-014..F-022 |

### Lane D — Kit + canonical-e (cross-source disposition; 0 net-new F-NNN)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-D-impl-1 (~80% kit primitives transfer cleanly) | mad-kit-inventory.md | HIGH | wave-001 / lane-d | wave-002 / lane-d | Engine inherits, doesn't fork |
| Lane-D-impl-2 (5 anti-pattern hooks load-bearing) | mad-kit-inventory.md | HIGH | wave-001 / lane-d | wave-002 / lane-d | Without these, iter-1-41 spiral repeats |
| Lane-D-impl-3 (cost = observability-ONLY) | canonical-e M2 + iter-41 lessons | HIGH | wave-001 / lane-d | wave-002 / lane-d | D-22 closed HIGH |
| Lane-D-impl-4 (halt-precedence ladder) | canonical-e Phase 0 + Phase 2 | HIGH | wave-001 / lane-d | wave-002 / lane-d | D-23 closed HIGH |
| Lane-D-impl-5 (5 Cat-B answers shape v1 scope) | canonical-e Cat-B traceable list | HIGH | wave-001 / lane-d | wave-002 / lane-d | Q1, Q3, Q4, Q5, Q6 in lane-d-summary; closure pending |
| Lane-D-impl-6 (MAD pipeline = engine's primary contract surface) | canonical-skill-only.md + cross-source-disposition-matrix.md | HIGH | wave-001 / lane-d | wave-002 / lane-d | Engine consumes via Skill tool |
| Lane-D-impl-7 (schema directory needs explicit creation) | mad-kit-inventory.md (no `.mad/schemas/`) | HIGH | wave-001 / lane-d | wave-002 / lane-d | D-15 (location TBD) |
| Lane-D-briefing-miscount (CE counts in brief vs actual) | canonical-e-inventory.md | HIGH (now corrected) | wave-001 / lane-d | wave-002 / lane-d | Future briefings should pull counts from scripts, not inline |
| Lane-D-CP-pending (cross-source matrix CP rows pending Lane C) | cross-source-disposition-matrix.md | MEDIUM (now resolved) | wave-001 / lane-d | wave-002 / lane-d | Lane C committed during wave-1; consolidation in wave-002/lane-d closes the dependency |

## Transitions

- MEDIUM → HIGH: requires evidence-gathering wave per QG2 (cite at least one source)
- HIGH → MEDIUM: requires explicit re-review (a contradicting finding from a later wave)
- HIGH → DROPPED: requires user acknowledgement at periodic interview gate L3 per `no-silent-deferrals.md`
- MEDIUM → DROPPED: rationale logged to `docs/10-backlog/dropped-with-rationale.md`

## Wave-2 / Lane D actions taken

- 8 Lane-A clusters logged at HIGH (multi-source convergence)
- 1 Lane-A residual cluster + 1 trends-PDF gap logged at MEDIUM
- 7 Lane-B clusters: 4 HIGH (multi-Microsoft-surface convergence), 3 MEDIUM (preview / sparse / thin source)
- 1 Lane-B residual cluster at MEDIUM
- 15 Lane-C lessons L1..L15 all HIGH (single source clear; openclaw + clawpilot + canonical-e all corroborate)
- 9 Lane-D structural findings logged (8 HIGH + 1 now-resolved MEDIUM)

Total wave-1 confidence-ledger rows: **~42** finding clusters/lessons (vs. ~120 raw findings before clustering). Cluster-shaped because that's what survives consolidation; per-finding tracking would inflate the ledger without adding signal.

## Entries — Wave 2 (introduced 2026-05-07)

### Lane A — Software-build patterns (8 topics)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-A-w2-cluster-1 (orchestrator-worker reinforced) | software-patterns/orchestrator-worker-pattern.md (7 sources, anthropic.com canonical) | HIGH | wave-002 / lane-a | wave-003 / lane-d | Reinforces F-128 (wave-1 Lane A 4-way convergence) |
| Lane-A-w2-cluster-2 (multi-tier model routing Haiku/Opus established) | software-patterns/multi-tier-model-routing.md (6 sources) | HIGH | wave-002 / lane-a | wave-003 / lane-d | Reinforces F-124 (NEW from research) |
| Lane-A-w2-cluster-3 (RAG patterns 2026 baseline) | software-patterns/rag-patterns.md (8 sources incl. msft-learn + arxiv) | HIGH | wave-002 / lane-a | wave-003 / lane-d | F-074..F-078 surfaced; M1+M11 dependencies |
| Lane-A-w2-cluster-4 (context window management baseline) | software-patterns/context-window-management.md (6 sources incl. claude docs) | HIGH | wave-002 / lane-a | wave-003 / lane-d | Reinforces F-126 (NEW from research) |
| Lane-A-w2-cluster-5 (agent autonomy + sandboxing baseline) | software-patterns/agent-autonomy-sandboxing.md (8 sources incl. arxiv) | HIGH | wave-002 / lane-a | wave-003 / lane-d | Reinforces F-D-012 (deferred sandboxing) at HIGH |
| Lane-A-w2-cluster-6 (spec-driven development / SpecKit) | software-patterns/spec-driven-development.md (8 sources incl. github.blog + msft developer) | HIGH | wave-002 / lane-a | wave-003 / lane-d | Closes Goal G14 evidence baseline |
| Lane-A-w2-cluster-7 (AI-native architecture 2026 baseline) | software-patterns/ai-native-architecture-2026.md (6 sources) | HIGH | wave-002 / lane-a | wave-003 / lane-d | F-064..F-068 surfaced |
| Lane-A-w2-cluster-8 (2026 emerging patterns gap analysis) | software-patterns/2026-emerging-patterns.md (8 sources) | MEDIUM | wave-002 / lane-a | wave-003 / lane-d | "Digital assembly line" returned no strong 2026 sources; concept maps to Pipeline pattern. F-099..F-104 inherit MEDIUM until corroborated. |

### Lane B — M0-M2 catalog drop (22 ledgers)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-B-w2-ledger-shape | All 22 ledgers + 3 milestone READMEs | HIGH | wave-002 / lane-b | wave-003 / lane-d | Per-feature ledger frontmatter contract established; status-history list, status-since, generated-by, generated-by-version, feature-id, milestone, provenance.surfaces, fr-coverage, test-files. All subsequent ledgers inherit this shape. |
| Lane-B-w2-22-RED-ledgers | F-001..F-022 | HIGH | wave-002 / lane-b | wave-003 / lane-d | All 22 in RED state; tests + impl deferred to subsequent waves. Behavior contract + acceptance scenarios authored per ledger. |

### Lane C — Copilot CLI design review (partial)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-C-w2-gpt5-review | docs/05-design-reviews/copilot-cli-design-reviews/2026-05-XX-foundation-review.md | HIGH | wave-002 / lane-c | wave-003 / lane-d | gpt-5.5 voice delivered (5 critical findings tagged HARD-BLOCK pending opus voice in wave-3 retry); 8 NEW F-NNN candidates F-127..F-134 surfaced (already merged into wave-1 Lane D consolidation as part of F-127..F-204) |
| Lane-C-w2-opus-timeout | dispatcher log | MEDIUM | wave-002 / lane-c | wave-003 / lane-d | Opus voice timed out at default timeout. Retry target wave-3 Lane E with 600s opus timeout. |

### Lane D — Wave-1 consolidation + backlog hygiene

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-D-w2-78-FNNN-allocation | wave-001-new-fnnn-candidates-consolidated.md | HIGH | wave-002 / lane-d | wave-003 / lane-d | ~78 unique allocations as F-127..F-204; ~19 dedup'd as merged-into-existing |
| Lane-D-w2-3-D-closures (D-20 + D-22 + D-23) | design-decisions-pending.md | HIGH | wave-002 / lane-d | wave-003 / lane-d | First 3 design decisions closed at HIGH; cost-ledger=observability-only; halt-precedence ladder; refresh-token-per-role |
| Lane-D-w2-12-RG-entries | research-gaps.md | MEDIUM | wave-002 / lane-d | wave-003 / lane-d | RG-1..RG-12 (12 research gaps surfaced); wave-3 Lane A targets RG-7..RG-12 |

## Entries — Wave 3 (introduced 2026-05-07)

### Lane C — RED test scaffold + toolchain

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-C-w3-RED-scaffold | tests/unit/F-001-engine-bootstrap-loop.test.ts + vitest.config.ts + tsconfig.json + packages/engine-core/ | HIGH | wave-003 / lane-c | (current) | First runnable RED test in repo; 3 assertions match F-001 ledger acceptance contract (lifecycle order, cycle cap, halt-path shape). FETCH BEFORE CITE win — Lane C deviated from brief to match the ledger. |

### Lane D — roadmap + wave-002 close + wave-003 setup (this lane)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-D-w3-roadmap | roadmap.md (repo root) | HIGH | wave-003 / lane-d | wave-005 / lane-d | Navigable view of M0..M19 + 144 catalog items + dependency graph. Auto-update protocol documented. Closes foundational-plan "Self-improvement scaffolding" gap. F-001 row first GREEN transition logged 2026-05-07. |
| Lane-D-w3-wave2-close | docs/11-loop-state/wave-history/wave-002.md | HIGH | wave-003 / lane-d | (current) | Wave-2 sealed atomically; ~43 commits across 4 lanes; loop-improvement proposal applied to wave-3. |

## Entries — Wave 5 (introduced 2026-05-07)

### Lane D — F-001 RED → GREEN (this lane)

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|
| Lane-D-w5-F-001-GREEN | packages/engine-core/src/index.ts + tests/unit/F-001-engine-bootstrap-loop.test.ts + docs/09-examples-proof/F-001/ | HIGH | wave-005 / lane-d | (current) | First feature transition RED → GREEN in the repo. ~95 LOC impl satisfies all 3 acceptance scenarios from the F-001 ledger (lifecycle order, cycle cap, halt-path shape). Vitest 3/3 PASS. Closes Goal G37 (immediate working product) for the engine kernel. |
| Lane-D-w5-toolchain-hops | pnpm-workspace.yaml + package.json devDep + test:unit script | HIGH | wave-005 / lane-d | (current) | Three small toolchain fixes landed alongside F-001 GREEN: (1) pnpm-workspace.yaml because pnpm v10+ ignores the `workspaces` field in package.json; (2) added `@mad-council-claw/engine-core: workspace:*` devDep on root so the package is resolvable from the test suite; (3) `test:unit` script switched from broken `vitest run --project unit` to working `vitest run tests/unit` (vitest 2.1.9 project-filter quirk). All three are minimum-change fixes per `minimum-change.md`. |
