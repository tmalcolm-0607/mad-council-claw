# Design decisions pending

Per `foundational-plan.md` — the prior session enumerated D-1..D-8 design decisions awaiting closure. Each requires deliberate review (likely council-review) before implementation work depends on it. Wave-1 surfaced D-9..D-16 (this file extends).

## Schema

```
| ID | Decision | Options under consideration | Source | Date opened | Confidence (HIGH if well-scoped; MEDIUM if depends on research) | Suggested closure path |
```

## Entries

| ID | Decision | Options | Source | Date opened | Confidence | Suggested closure path |
|---|---|---|---|---|---|---|
| D-1 | Backend SDK provider abstraction shape | (a) thin adapter only, (b) full event normalization layer, (c) opaque pass-through | foundational-plan.md M1 | 2026-05-06 | MEDIUM | council-review at end of wave that drafts F-009..F-013 ledgers |
| D-2 | Where the "soul boundary" enforcement lives | (a) in IBackendProvider, (b) in orchestration plane, (c) in tool plane via permission gates | foundational-plan.md M11 | 2026-05-06 | MEDIUM | council-review during M11 design wave |
| D-3 | MCP tool-cap default value | per-workspace cap of 10 (per WorkIQ tool-explosion lesson); is 10 right? | foundational-plan.md F-125 | 2026-05-06 | MEDIUM | research wave to ground in Microsoft 2026 internal data |
| D-4 | Multi-tier model routing default policy | when does Haiku get used vs Opus? rules-based vs ML-routed? | foundational-plan.md F-124 | 2026-05-06 | LOW | research wave (frontier 2026) before deciding |
| D-5 | Storage encryption: BYOK vs system-managed default | which is the v1 default? | foundational-plan.md M8 | 2026-05-06 | MEDIUM | user input + threat-model review |
| D-6 | Headless CLI subcommand surface | which subcommands are v1 vs deferred? | foundational-plan.md M4 | 2026-05-06 | MEDIUM | catalog wave + user input |
| D-7 | Replay scrubber UI shape | timeline-only vs timeline + diff overlay vs timeline + intervention markers | foundational-plan.md M12 | 2026-05-06 | LOW | UX design wave |
| D-8 | Daily briefing destination(s) | email, Teams DM, OneNote, all three? per-user preference? | foundational-plan.md F-103 | 2026-05-06 | LOW | research wave + user input |
| D-9 | Microsoft Agent Framework: TypeScript bridge vs Python/C# reimplement vs hand-rolled TS | (a) wrapper over Python/C# AF via IPC, (b) reimplement AF workflows in TS, (c) hand-roll orchestration patterns from scratch (Sequential/Concurrent/Handoff/Group/Magentic) | wave-001 / lane-b topic 1 + topic 11 + RG-2 | 2026-05-07 | MEDIUM | wave-N research lane (close RG-2 first) + council-review |
| D-10 | Activity Protocol adoption priority | (a) Phase 0 v1 must-have (M9 lane priority), (b) Phase 4 alongside other M365 adapters, (c) postpone to v-next release | wave-001 / lane-b topic 6 (3-Microsoft-surface convergence) | 2026-05-07 | MEDIUM | council-review: ROI of single endpoint shape covering 4 Microsoft surfaces |
| D-11 | OTel GenAI semantic conventions adoption depth | (a) full convention compliance from M0 day 1 (every span follows), (b) opt-in via config (default off; turn on per-feature), (c) Microsoft OTel distro bundle only (Geneva-compatible) | wave-001 / lane-b topic 8 + F-145 + F-182..F-184 | 2026-05-07 | MEDIUM | M16 telemetry wave council-review |
| D-12 | Engine packaging (which delivery shape) | (a) npm package, (b) electron-builder bundle, (c) standalone .NET tool, (d) PowerShell module wrapper | Lane D summary Q3 | 2026-05-07 | MEDIUM | M15 build/packaging wave |
| D-13 | Phase staging in v1 | (a) Phase 0-3 first then 4-6 in v1.x, (b) all 7 phases in v1, (c) Phase 0-6 with Phase 4 (M365 adapters) postponed | Lane D summary Q4 + canonical-e phases | 2026-05-07 | MEDIUM | user input + council-review |
| D-14 | Re-import 7 missing predecessor skills (canonical-e scope-excluded #12) | (a) re-import from origin source, (b) rewrite per current standards, (c) leave dropped per canonical-e scope-exclusion list | Lane D summary Q5 | 2026-05-07 | MEDIUM | user input |
| D-15 | Schema directory location | (a) `.mad/schemas/` (kit-aligned), (b) `schemas/` at engine root (engine-distinct), (c) inline JSON Schemas embedded in entity .md files (kit pattern today) | Lane D summary Q1 + cross-source-disposition-matrix.md | 2026-05-07 | MEDIUM | M0 bootstrap wave (before any entity ledger needs a schema) |
| D-16 | mad-teams skill: drop or keep? | (a) drop (predates council-* skills; redundant), (b) keep as legacy alias, (c) refactor into council-* | Lane D summary Q2 | 2026-05-07 | MEDIUM | M0 bootstrap wave + council-review |
| D-17 | Handoff primitive shape: typed-tool vs separate API | F-129 handoff-as-tool (4-way Anthropic+OpenAI+MCP+Cursor convergence) vs distinct-API approach | wave-001 / lane-a F-002 + F-021 + F-058 | 2026-05-07 | MEDIUM | M2 governance triad wave council-review |
| D-18 | Task-clarity-gate (F-130) confidence threshold | what % confidence triggers escalation? (Anthropic data: 67% well-defined success; 85% ambiguous failure) | wave-001 / lane-a F-018 + F-044 + F-049 | 2026-05-07 | MEDIUM | M2 governance triad wave council-review (close after RG-12 corroborates) |
| D-19 | Memory plane PREVIEW risk: build on Foundry preview or local-only first? | (a) Foundry Agent Service memory (PREVIEW), (b) local IMemoryProvider only in v1; Foundry in v-next release, (c) hybrid (local primary; Foundry sync optional) | wave-001 / lane-b topic 9 + RG-6 | 2026-05-07 | MEDIUM | M11 wave council-review (close after RG-6 confirms Foundry GA status) |
| D-20 | Per-agent vs per-user identity scoping | (a) one MSAL refresh-token per logged-in-user (clawpilot today), (b) one MSAL cache per agent role (Lane C L2 recommendation), (c) hybrid | wave-001 / lane-c L2 | 2026-05-07 | HIGH | F-002 ledger council-review (high-confidence: openclaw issue #43367 F3 + Lane C L2 both point to per-role) |
| D-21 | Worktree-per-feature vs branch-per-feature for engine work | (a) git worktree per F-NNN, (b) branch-only, (c) hybrid by milestone | foundational-plan.md § Branch + PR strategy | 2026-05-07 | MEDIUM | wave-N before F-001 enters implementation |
| D-22 | Cost-ledger observability-only enforcement: how to prevent halt-on-cost regression | per Lane D's "Cost is observability-ONLY — repeating in 4 different files because iter-41 refactor was the load-bearing change" | Lane D summary §critical-engine-design-implication 3 | 2026-05-07 | HIGH | M2 wave council-review + hook discipline (block any code that conditions execution on cost-threshold) |
| D-23 | Halt-precedence ladder: codify as runtime check or rule-only | precedence: KILL > SOUL > OVERRIDE > GOV > QUOTA > DEGRADE > COST | Lane D summary §critical-engine-design-implication 4 | 2026-05-07 | HIGH | M2 wave council-review |

## Confidence rationale

- HIGH would mean the option set is well-defined AND we have evidence enough to pick. D-20, D-22, D-23 are at HIGH (multi-source convergence on the "right" answer).
- MEDIUM = option set is well-defined but evidence is incomplete. Can be promoted to HIGH after a research wave.
- LOW = option set itself isn't yet enumerated. Needs a research wave first.

## Wave-2 / Lane D update

D-9..D-23 added from wave-1 lane synthesis. Of the new entries, D-20 / D-22 / D-23 promoted directly to HIGH because the wave-1 evidence is unambiguous (Lane C L2 + canonical-e iter-41 lessons). Others remain MEDIUM pending closure waves.

## Wave-2 / Lane C update — Copilot CLI design review architectural decisions

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md`. Three architectural decisions surfaced (single-model only — Opus timeout means none reach HIGH yet, but evidence is unambiguous):

| ID | Decision | Options | Confidence | Notes |
|---|---|---|---|---|
| D-24 | Drop "all 7 phases in v1" target | (a) freeze foundation around M0..M11 + packaging minimum; M12..M14 + M18 marketplace post-foundation; (b) keep 7-phase target unchanged; (c) hybrid — ship 7-phase scaffolds RED but only M0..M11 GREEN | **HIGH** (escalated from MEDIUM by wave-3 cross-model corroboration) | Per design review M-I (gpt-5.5) + M6 (Opus): both flag 7-phase-v1 as unsound. Wave-3 retry confirms cross-model agreement at MUST-FIX severity. Closure path: M0 wave council-review with option (a) as default. |
| D-25 | M2 rename to "Governance kernel" (label-only) | (a) rename M2 = Governance kernel; (b) keep "Governance triad" label | MEDIUM (single-model gpt-5.5 m4 only; Opus does not flag) | Cosmetic, single-model, low-stakes; promote at next M0 wave council-review without further cross-model verification. |
| D-26 | Soul boundary enforcement mechanism | (a) compile-time package-boundary enforcement (separate modules + lint import-ban + test fixture attempting forbidden imports) + runtime check as defense-in-depth; (b) runtime check only (current FR-SOUL-001); (c) capability-based (object-capability model) | **HIGH** (escalated from MEDIUM by wave-3 cross-model corroboration) | Per design review M-J (gpt-5.5) + C1 (Opus, recommends eslint-plugin-boundaries): both flag runtime-only as too weak. Wave-3 retry: Opus C1 escalates to Critical. Closure path: M0 wave council-review with option (a) compile-time + runtime defense-in-depth as default. Capability model (c) deferred to v-next as M11 reinforcement. |

## Wave-3 / Lane B update — Copilot CLI design review retry

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md` § Wave-3 retry resolution + § Cross-model agreement table.

Wave-3 retry (Opus succeeded at ~94s with TimeoutSeconds=1200) populated the cross-model agreement table. D-24 and D-26 promoted to HIGH (above). 7 NEW HARD BLOCK F-NNNs (F-127..F-131, F-134; F-128/F-129 sev escalation) require council-review verdict at M0 wave; tracked under feature-promotions.md (single decision is "approve all 7 HARD BLOCK F-NNNs as M0/M2 entries with milestone updates" — no separate D-NN entry needed unless options diverge).

| ID | Decision | Options | Confidence | Notes |
|---|---|---|---|---|
| D-27 | F-009 IBackendProvider granularity split | (a) split into IChatBackend + IToolDispatchBackend + IIdentityBackend per Opus C2; (b) keep single IBackendProvider per current spec; (c) hybrid — single provider with optional sub-interfaces | **HIGH** (Opus C2 Critical + gpt-5.5 M-A Major; root convergence) | Both models flag Anthropic content_block_delta vs Copilot turn-based shape divergence. Anthropic-only F-124 multi-tier-routing already coupled. Closure path: wave-4 M1 design-spec lane council-review with (a) as default. |
| D-28 | Dispatcher retry-once-on-timeout | (a) add `-MaxRetries 1` + `-RetrySleepSeconds 60` to `Invoke-CopilotMultiModel.ps1` default-on for cross-model lanes; (b) opt-in only via flag; (c) keep current behavior — manual wave retry | HIGH (RG-16) | Wave-2 600s timeout was transient (wave-3 retry succeeded at ~94s same brief). Closure path: wave-4 dispatcher upgrade lane. |
| D-29 | F-NNN shape for MCP OAuth 2.1 + TLS pin | (a) standalone F-135; (b) fold into F-122 hardening; (c) split — F-135 internal MCP OAuth 2.1; F-122 hardened external A2A | MEDIUM (Opus G5 + gpt-5.5 G8 cross-model agreement on gap; F-NNN shape divergent) | Closure path: wave-4 spec lane after M0 freeze. |

## Wave-9 / Lane D update — Microsoft 2026 frontier cross-cutting decisions

Five cross-cutting decisions surfaced from the wave-4 Lane C Microsoft 2026 research bundle. Each has multi-source convergence; closure target is M0 / M1 / M2 council-review per row.

| ID | Decision | Options | Source | Date opened | Confidence | Suggested closure path |
|---|---|---|---|---|---|---|
| D-30 | A2A v1.0 default-binding choice (HTTP+JSON vs JSON-RPC) for engine + WorkIQ compatibility | (a) HTTP+JSON default per A2A v1.0 (Microsoft's chosen migration), (b) JSON-RPC for legacy compat, (c) both via `MapA2AHttpJson` + `MapA2AJsonRpc` (declared at startup) | `workiq-a2a-impl-patterns.md` § Migration cliffs (wave-4 lane-c) | 2026-05-07 | HIGH | M9 wave council-review; default to (a) per Microsoft alignment |
| D-31 | Microsoft Agent Framework TS bridge approach | (a) gRPC bridge to .NET/Python AF host, (b) reimplement workflow primitives in TS, (c) skip and hand-roll (no AF integration) | `agent-framework-typescript-bridge.md` § Bridge options + RG-2 + RG-19 | 2026-05-07 | MEDIUM | M0/M2 council-review; close after RG-19 ROI table |
| D-32 | Anthropic-Claude-on-Agent-365 sanctioned path adoption | (a) adopt `@microsoft/agents-a365-claude` as IBackendProvider Claude lane, (b) hand-roll Claude SDK adapter independent of Agent 365, (c) hybrid (Agent 365 wrapper at boundary; thin internal adapter) | `agent-365-sdk-typescript.md` § Claude integration + F-D-130 + F-D-147 | 2026-05-07 | HIGH | M1 backend-provider design wave |
| D-33 | Protocol-first vs SDK-first integration philosophy | (a) protocol-first (A2A / MCP / Activity / OTel GenAI as first-class contracts; SDKs are convenience layers), (b) SDK-first (depend on `@microsoft/agents-a365-*` family + AF SDK; protocols implicit), (c) hybrid (protocol-first for cross-boundary; SDK-first for in-process) | Cross-cutting (5 wave-4 lane-c files) + F-D-148 | 2026-05-07 | HIGH | M0 wave architectural review (option (a) is the recommendation) |
| D-34 | Foundry hybrid TS-Python deployment pattern adoption | (a) hybrid (TS control plane + Python Foundry worker via IPC) is the canonical M15 packaging shape, (b) keep Foundry integration out of v1 (RG-6 PREVIEW risk), (c) Python-only Foundry adapter as separate plugin | `foundry-agent-service.md` § Hybrid pattern + F-D-136 + F-D-149 + RG-18 | 2026-05-07 | HIGH | M11/M15 wave council-review; close after RG-18 IPC contract spec |



## Wave-016 / Lane D update — M0+M1+M2 implementation review HARD BLOCKs

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-016-impl-review.md` (multi-model: claude-opus-4.7 + gpt-5.5).

| ID | Decision | Options | Source | Date opened | Confidence | Suggested closure path |
|---|---|---|---|---|---|---|
| D-35 | F-138 engine-cycle-orchestrator scope | (a) full composition layer (startSession → [sendPrompt → observeEvent → recordCost → checkQuota → checkHalt → audit → redact]* → closeSession(retro)) as a single feature; (b) split into F-138a (event bus) + F-138b (governance pipeline); (c) defer to M3 implementation iteration without a pre-impl spec | wave-016 / lane-d C-1 (Opus) + cycle-orchestration-not-wired (gpt-5.5) | 2026-05-07 | **HIGH** (both models agree: 18 standalone primitives have no composition layer; this is THE central design gap) | M3 pre-impl wave council-review; default to (a) full composition spec before any M3 feature lands |
| D-36 | F-139 backend-event-usage-variant addition timing | (a) add `usage` variant to BackendEvent now (M3 pre-impl) so F-019 cost ledger has an event source; (b) wait for real SDK integration (F-010/F-011 with @anthropic-ai/sdk and Copilot CLI) and add then; (c) keep BackendEvent at 4 variants and require callers to compute usage manually | wave-016 / lane-d C-2 (Opus only) + cost.ts:6 contract claim | 2026-05-07 | MEDIUM (single-model Opus Critical; gpt-5.5 didn't flag separately but F-019 is broken without it) | M3 pre-impl wave; default to (a) — F-131 fanout-budget-governor cannot be built without it |
| D-37 | F-141 governance-kernel-extract: split RunHaltedVerdict from halt.ts | (a) extract RunHaltedVerdict + HaltTrigger into `verdict.ts`; halt.ts shrinks to F-018 logic only; (b) keep halt.ts as TYPE HUB; document explicitly as "verdict shape owner"; (c) fold all five governance features (halt + cost + quota + degradation + killswitch) into a `GovernanceKernel` namespace | wave-016 / lane-d F3 (gpt-5.5 Major) + F-127 candidate from wave-002 | 2026-05-07 | MEDIUM (gpt-5.5 frames halt.ts expansion as kernel-class problem; Opus reframes as praise) | M3 wave council-review |
| D-38 | StubBackend halt-contract alignment | (a) align StubBackend.halt() with AnthropicBackend/CopilotBackend (keep session, mark halted, yield finish/error on subsequent sendPrompt); (b) keep current divergent behavior + document; (c) remove StubBackend entirely (force tests to use real backends with mocked transport) | wave-016 / lane-d C-3 (Opus only) | 2026-05-07 | MEDIUM (single-model Opus Critical; concrete contract bug with downstream test risk) | wave-17 fix lane; default to (a) |
| D-39 | engine-core public API boundary | (a) add `public-api.ts` re-exporting only consumer-facing surface; keep `index.ts` for internal; (b) annotate every export with `@internal`/`@public` JSDoc; CI rule rejects PRs that change `@public` without bump; (c) accept current `export *` and rely on documentation | wave-016 / lane-d M-2 (Opus) + Major (gpt-5.5) | 2026-05-07 | **HIGH** (both models flag) | M3 wave; default to (a) + (b) combined |
| D-40 | F-129..F-134 wave-002 candidates milestone assignment | each of F-129/F-130/F-131/F-132/F-133/F-134 needs a definitive milestone home before M3 entry | (per-candidate; see wave-001 review § F-NNN candidates) | wave-016 / lane-d F7 (both models) | 2026-05-07 | **HIGH** (both models flag drift; concrete tracking issue) | M3 wave council-review with explicit milestone-per-candidate decision |

