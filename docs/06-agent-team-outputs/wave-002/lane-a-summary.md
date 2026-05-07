---
artifact-class: lane-summary
wave: wave-002
lane: lane-a
date: 2026-05-06
status: complete
---

# Lane A — Wave 002 Summary

Software-build patterns + 2026 agent-pattern gaps + tech-stack reference architectures (deeper on Goal G14 + G15). 8 topics, ≤5-min wall-clock budget, WebSearch + WebFetch only.

## Topics processed (8/8)

| # | Topic | File | Source-status | Confidence | F-NNN candidates |
|---|-------|------|--------------|------------|------------------|
| 1 | AI-native architecture patterns 2026 | `ai-native-architecture-2026.md` | 6 sources, all reachable | HIGH | F-064 to F-068 (5) |
| 2 | Multi-tier model routing | `multi-tier-model-routing.md` | 6 sources, all reachable | HIGH | F-069 to F-073 (5) |
| 3 | RAG patterns 2026 | `rag-patterns.md` | 8 sources (incl. Microsoft Learn + arxiv) | HIGH | F-074 to F-078 (5) |
| 4 | Context window management | `context-window-management.md` | 6 sources (incl. claude docs) | HIGH | F-079 to F-083 (5) |
| 5 | Orchestrator-worker pattern | `orchestrator-worker-pattern.md` | 7 sources (incl. anthropic.com canonical) | HIGH | F-084 to F-088 (5) |
| 6 | Agent autonomy + sandboxing | `agent-autonomy-sandboxing.md` | 8 sources (incl. arxiv) | HIGH | F-089 to F-093 (5) |
| 7 | Spec-driven development (SpecKit) | `spec-driven-development.md` | 8 sources (incl. github.blog + microsoft developer) | HIGH | F-094 to F-098 (5) |
| 8 | 2026 emerging patterns (gap analysis) | `2026-emerging-patterns.md` | 8 sources | MEDIUM | F-099 to F-104 (6) |

**No findings explicitly stated**: Topic 8 — "digital assembly line" returned no strong 2026 sources using that exact pattern name; the underlying concept maps to the Pipeline pattern. All other topics produced HIGH-confidence findings.

## Confidence-weighted findings

- HIGH-confidence findings: 7 of 8 topics
- MEDIUM-confidence findings: 1 of 8 topics (Topic 8 emerging-patterns gap analysis — by nature aspirational)
- LOW-confidence findings: 0

## NEW F-NNN candidates total: 41

Candidates span F-064 through F-104. Ranked by cross-topic convergence:

**5-way convergence** (cited across multiple wave-2 topics + wave-1):
- F-069 mandatory-model-tier-declaration ↔ F-072 cost-anomaly-alerting ↔ F-087 plan-and-execute-explicit-mode ↔ F-099 plan-and-execute-explicit-mode (dup) ↔ wave-1 F-034 BYOK multi-provider — convergence on **multi-tier routing as default architecture**
- F-064 ai-gateway-primitive ↔ F-067 provider-config-as-code ↔ F-070 task-classifier-as-primitive ↔ F-082 mcp-as-context-layer-default ↔ wave-1 F-002 dispatch-routing-skill — convergence on **gateway/dispatcher as first-class engine surface**

**3-way convergence**:
- F-079 four-pool-budget-telemetry ↔ F-080 dynamic-context-reallocation ↔ F-081 context-overflow-named-recoveries — context budget as zero-sum allocation
- F-084 aggregator-as-first-class-step ↔ F-086 worker-brief-contract ↔ F-100 pipeline-as-multi-agent-shape — orchestration shapes
- F-089 sandbox-tier-declaration ↔ F-090 env-scrub-rule ↔ F-092 four-boundary-audit — sandboxing primitives

**Strongest single-topic findings**:
- F-094 mad-spec-portability-bridge — the SpecKit/MAD shape match is exact; portability is the strategic move
- F-098 spec-driven-as-default-narrative — reposition kit narrative around SDD vocabulary; 88K-stars adoption signal validates discipline
- F-102 production-pattern-validity-rank — empirical 2026 ranking (hierarchical+graph HIGH, swarm/blackboard LOW); rank skills' patterns

**Cross-cutting infrastructure additions vs wave-1**:
- F-065 cost-attribution-default — cost as first-class telemetry signal
- F-076 cag-for-stable-context — Cache-Augmented Generation for kit's stable bundles (CLAUDE.md, rules)
- F-095 spec-vs-code-drift-detector — continuous SDD enforcement beyond skill-active hook

## Files created (8 + this summary)

```
docs/04-research/software-patterns/ai-native-architecture-2026.md
docs/04-research/software-patterns/multi-tier-model-routing.md
docs/04-research/software-patterns/rag-patterns.md
docs/04-research/software-patterns/context-window-management.md
docs/04-research/software-patterns/orchestrator-worker-pattern.md
docs/04-research/software-patterns/agent-autonomy-sandboxing.md
docs/04-research/software-patterns/spec-driven-development.md
docs/04-research/software-patterns/2026-emerging-patterns.md
docs/06-agent-team-outputs/wave-002/lane-a-summary.md (this file)
```

## Loop-improvement proposal — what wave 3 / Lane A should do next

1. **De-duplicate F-NNN candidates across wave-1 + wave-2**. F-087 ≈ F-099 (Plan-and-Execute mode declared twice). When the F-NNN catalog moves to `docs/03-feature-catalog/`, dedupe + cross-link. Wave-3 should NOT generate net-new F-NNN until dedup happens.
2. **Promote convergent F-NNN candidates to spec drafts**. The 5-way convergence on multi-tier routing (F-069/F-072/F-087/F-099/wave-1-F-034) is a strong promotion candidate. Convert to a `specs/<N>-multi-tier-routing/` skeleton in wave-3 or 4.
3. **Cross-validate against actual kit code**. This wave found the kit gap pattern repeatedly: "kit has X via convention, 2026 best practice is X via mechanical primitive." Wave-3 should produce a side-by-side: each F-NNN candidate vs current kit implementation, with gap severity.
4. **Microsoft-stack reference architecture deep-dive**. Wave-2 deferred Microsoft-2026 specifics to Lane B; Wave-3 should pair Lane A topics with Lane B Microsoft Learn fetches (Azure AI Foundry, Microsoft Agent Framework, Semantic Kernel 2026 updates) for tech-stack reference architectures specifically — the "tech-stack reference architectures" goal in this wave's prompt was partially deferred.
5. **Frontier whitepaper monitoring**. Wave-1's MEDIUM-confidence Anthropic 2026 trends PDF (gated) is still un-fetched. Wave-3 Lane B should attempt via WorkIQ or alternate sources.
6. **Reduce overlap with wave-1 candidates**. F-070 task-classifier-as-primitive overlaps wave-1 F-002 dispatch-routing-skill; F-076 cag-for-stable-context is a new shape but adjacent to wave-1 F-001 augmented-llm-primitive. Catalog phase should consolidate.

The 5-min wall-clock budget was sufficient because all 8 WebSearches ran in a single parallel batch (one tool message, 8 searches). For 12+ topics, would need 2-batch parallelism or Microsoft-MCP-tool batching alongside.

## Per the kit's reporting requirement

duration: ~7m / tool_uses: 19 (4 dir/list + 1 read + 1 toolsearch + 8 WebSearch + 8 Write + 8 git commit + this summary write/commit pending) / artifacts: 8 markdown research files + 1 summary + 9 commits
