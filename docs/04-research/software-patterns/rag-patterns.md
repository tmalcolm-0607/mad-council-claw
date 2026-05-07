---
artifact-class: research-finding
source-tag: [R:software-patterns]
confidence: high
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://blog.starmorph.com/blog/rag-techniques-compared-best-practices-guide
  - https://www.tredence.com/blog/top-rag-frameworks
  - https://www.fingoweb.com/blog/what-are-the-best-rag-alternatives/
  - https://lushbinary.com/blog/rag-retrieval-augmented-generation-production-guide/
  - https://medium.com/@reliabledataengineering/rag-is-dead-and-why-thats-the-best-news-you-ll-hear-all-year-0f3de8c44604
  - https://www.firecrawl.dev/blog/best-open-source-rag-frameworks
  - https://learn.microsoft.com/en-us/azure/search/retrieval-augmented-generation-overview
  - https://arxiv.org/html/2506.00054v1
---

# RAG patterns 2026 (when to use, alternatives, hybrid)

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter.

## Load-bearing patterns

- **The RAG taxonomy fractured in 2026**. RAG is no longer a single technique; it's a family with sharp tradeoff curves. The 6 named patterns:
  1. **Naive RAG**: chunk → embed → store → top-K retrieve → feed LLM. 100-500ms latency. Baseline.
  2. **Adaptive RAG (the 2026 best practice)**: query classifier routes each query to the appropriate sub-pipeline based on complexity. The classifier itself is cheap (Haiku-class).
  3. **Agentic RAG**: agent decides what to retrieve, iteratively, with tool calls. Higher cost, much higher quality on multi-step queries.
  4. **GraphRAG**: extracts entities + relationships into a knowledge graph; uses graph traversal for retrieval. Wins on relational queries; loses on simple Q&A.
  5. **Corrective RAG (CRAG)**: quality-checks retrieved docs; rerouts on low-quality retrieval. Often paired with real-time web search as the secondary lookup.
  6. **Self-RAG**: includes self-critique mechanism so the LLM can refuse to answer when retrieval was inadequate.
- **The "RAG is dead" claim is overstated but signals real shifts**. Long-context models outperform RAG on Wikipedia-style Q&A; RAG wins on dialogue, fresh-data, and citation-required scenarios. The right framing: long context + RAG + GraphRAG + CRAG are different tools for different shapes of question. Adaptive RAG IS the meta-pattern.
- **CAG (Cache-Augmented Generation)** as an alternative: preload bounded knowledge into extended context + cache runtime parameters. Eliminates retrieval latency entirely. Works only when the knowledge base is bounded and stable (manuals, policy docs, fixed catalogs).
- **Retrieval is the bottleneck, not generation**. In 2026 production systems, the cost+latency dominator is the retrieval step (vector search + reranking + filtering), not the LLM call. This pushes architectures toward hybrid retrieval (BM25 + dense + reranking) and pre-computed indices.
- **Agent-based alternatives**: when task structure is dynamic (multi-step, decision-driven), agents with tool calls outperform pure embedding-based retrieval. The decision rule: static knowledge → RAG; dynamic decisions + multi-step reasoning → agents with retrieval as one tool.

## Verbatim quotes worth preserving

> "The future isn't choosing between RAG and long context—it's using both intelligently, with emerging architecture patterns using long context for conversation history, RAG for precision and citations, GraphRAG for complex relational analysis, and CRAG (RAG with real-time web search) for fresh regulatory guidance."

> "In 2026, the retrieval step is the critical bottleneck, not generation, pushing RAG beyond basic vector search into hybrid, agentic, and graph-augmented architectures."

## Implications for the engine catalog

The kit currently has no first-class retrieval primitive — context comes via direct file reads + WebFetch + the MCP tools, not via a typed retrieval layer. F-NNN candidates: (a) Adaptive RAG as a default skill (`/retrieve --adaptive` that classifies + routes), (b) GraphRAG primitive for the kit's own knowledge graph (skills → rules → patterns is naturally a graph), (c) CAG-style cached-context for long-stable docs (CLAUDE.md, rules/, foundational specs) so they don't re-cost on every cold session.

## NEW F-NNN candidates

- F-074 retrieval-as-typed-primitive — Engine exposes retrieval as a typed skill surface (`/retrieve` with `--mode {naive|adaptive|agentic|graph|corrective}`); skills declare their retrieval pattern in frontmatter rather than re-implementing — confidence: M
- F-075 graphrag-for-kit-knowledge — The kit's own skills/rules/patterns/templates form a natural knowledge graph (skill → inherits-rules → cites-pattern). A GraphRAG layer over `.claude/` lets queries like "what rules govern PR review under HIGH-confidence council mode?" traverse the graph instead of grepping — confidence: H
- F-076 cag-for-stable-context — Cache-Augmented Generation primitive: kit identifies "stable-bounded" context bundles (CLAUDE.md, foundational rules, glossary, goals.md) and ships them as preloaded cache entries; cold sessions don't re-pay token cost for them — confidence: H
- F-077 retrieval-bottleneck-telemetry — Default-on telemetry distinguishing retrieval latency vs generation latency per skill invocation; surfaces when retrieval dominates so the operator knows to switch retrieval mode — confidence: M
- F-078 hybrid-retrieval-default — Where retrieval is used, default to hybrid (lexical BM25 + dense + reranker) rather than pure vector. Pure-vector retrieval is a 2024-era default; 2026 default is hybrid — confidence: M

## Confidence

HIGH — the taxonomy and "retrieval-is-the-bottleneck" finding are cited consistently across the 6 sources; "RAG is dead" headline is one outlier but its substantive content (long-context wins on some shapes) is corroborated by the arxiv survey.
