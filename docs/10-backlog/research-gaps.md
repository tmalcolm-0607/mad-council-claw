# Research gaps

Topics queued for upcoming waves. Items here become wave research lanes per QG2 (every wave touches at least one Goal G1-G25).

## Schema

```
| ID | Topic | Source (which wave / lane / finding flagged this) | Date | Confidence (HIGH if topic is well-defined; MEDIUM if scope is fuzzy) | Suggested next wave |
```

## Entries

| ID | Topic | Source | Date | Confidence | Suggested next wave |
|---|---|---|---|---|---|
| RG-1 | WorkIQ corpus has NO indexable source-docs for Project Lobster, SCHIE QaaS Governance, MSEC GenAI Bootcamp MCP security, MSR AI Tooling, MAP MCP Strategy Brief, GRAIL MCP onboarding, D365 ERP MCP GA. Need human source(s) (PM contacts / internal Teams channels) to ground the engine's governance plane in named programs. | wave-001 / lane-b topic 10 | 2026-05-07 | MEDIUM | wave-3+ "humans-in-loop" wave (escalate via WorkIQ Teams chat search + Tony's PM network) |
| RG-2 | Native AF (Microsoft Agent Framework) TypeScript samples for workflows are sparse on Microsoft Learn. C# + Python rich; TS gap. Engine targets TS+Electron, so this gap directly blocks F-190 af-typescript-bridge design. | wave-001 / lane-b topic 11 | 2026-05-07 | MEDIUM | wave-3 frontier lane: search MS internal Devdocs + AF GitHub + community examples |
| RG-3 | A2A protocol reference implementation in TypeScript — official spec exists but no canonical TS impl found. Engine needs to dispatch + receive A2A in TS; an official-shaped impl beats hand-rolling. | wave-001 / lane-a topic 12 + lane-b topic 7 | 2026-05-07 | MEDIUM | wave-3 frontier lane: search GitHub for `a2a-protocol typescript`; check MS Agent 365 SDK TS package |
| RG-4 | Anthropic 2026 Agentic Coding Trends Report — full PDF gated behind download; only landing-page summary fetched in wave-1. Lane A produced 4 MEDIUM-confidence findings; full report likely yields 10+ HIGH-confidence findings. | wave-001 / lane-a topic 2 | 2026-05-07 | MEDIUM | wave-3 frontier lane: search for cached/mirrored copies; or escalate via WorkIQ for Microsoft-internal access |
| RG-5 | OpenClaw issue #43367 has NO linked PR fix as of 2026-05-06; v4.0 multi-agent orchestration API surface is conceptual only. Engine cannot lift verbatim until openclaw publishes a concrete API. | wave-001 / lane-c | 2026-05-07 | MEDIUM | wave-3+ ongoing watch (re-fetch openclaw issues + roadmap quarterly per Lane A wave-1 loop-improvement #4) |
| RG-6 | Foundry Agent Service memory plane is in PREVIEW; production stability + breaking changes risk. Engine F-185..F-187 (memory features) inherit that risk. | wave-001 / lane-b topic 9 | 2026-05-07 | MEDIUM | wave-N before F-185..F-187 enter implementation: re-fetch Foundry memory docs; confirm GA status |
| RG-7 | Microsoft AutoGen 2026 lineage (now part of Microsoft Agent Framework) — group-chat orchestration patterns distinct from MCP/A2A. Lane A wave-1 didn't cover; flagged as wave-2 candidate by Lane A loop-improvement. | wave-001 / lane-a loop-improvement #2 | 2026-05-07 | MEDIUM | wave-3 frontier lane (already implicitly running via wave-2 software-patterns lane) |
| RG-8 | LangGraph 2026 supervisor pattern + state-graph primitives — not covered in wave-1; potentially informs F-128 orchestrator-worker-primitive shape. | wave-001 / lane-a loop-improvement #2 | 2026-05-07 | MEDIUM | wave-3 frontier lane |
| RG-9 | Inflection Pi / OpenCode / Codex CLI — the "harness > model" lineage; informs F-022 (kit's harness-not-model discipline) and F-001 engine-bootstrap-loop. | wave-001 / lane-a loop-improvement #2 | 2026-05-07 | MEDIUM | wave-3 frontier lane |
| RG-10 | SWE-bench 2026 + agentic coding benchmarks — empirical validation of the 67%/15% asymmetry; informs F-130 task-clarity-gate calibration. | wave-001 / lane-a loop-improvement #2 | 2026-05-07 | MEDIUM | wave-3 frontier lane |
| RG-11 | Re-fetch sources older than 30 days quarterly — MCP roadmap evolves quarterly; Anthropic publishes new findings monthly. Wave-1 captured fetch-date timestamps; need a re-fetch wave on cadence. | wave-001 / lane-a loop-improvement #4 | 2026-05-07 | HIGH | wave-N=cron (every ~13 waves per L4 quarterly retro cadence) |
| RG-12 | Anthropic 2026 Agentic Coding Trends — 67%/15% asymmetry is the single most-cited 2026 number. Need to corroborate against an independent measurement (not Anthropic-only data). | wave-001 / lane-a topic 10 | 2026-05-07 | MEDIUM | wave-3+ frontier lane: cross-check Anthropic-vs-OpenAI-vs-Microsoft published agent-success-rate numbers |

## Wave-2 / Lane D handoff note

Per Lane A wave-1 loop-improvement #5 ("subgroup the 63 F-NNN candidates by engine-area so Lane B and Lane C produce orthogonal cross-cuts"): wave-3 Lane A should produce a "candidates-promotion priority list" — HIGH confidence + cross-topic convergence + low engine-implementation cost = promote first. The consolidation in `wave-001-new-fnnn-candidates-consolidated.md` is the seed for that priority list.
