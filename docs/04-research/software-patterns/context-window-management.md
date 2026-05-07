---
artifact-class: research-finding
source-tag: [R:software-patterns]
confidence: high
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://atlan.com/know/llm-context-window-limitations/
  - https://redis.io/blog/context-window-overflow/
  - https://www.getmaxim.ai/articles/context-window-management-strategies-for-long-context-ai-agents-and-chatbots/
  - https://redis.io/blog/context-window-management-llm-apps-developer-guide/
  - https://platform.claude.com/docs/en/build-with-claude/context-windows
  - https://www.morphllm.com/llm-context-window-comparison
---

# Context window management as architecture concern

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter.

## Load-bearing patterns

- **Context window IS the architectural budget**. The 2026 reframing: a context window is not "how much fits" but a four-way zero-sum allocation across (1) system instructions, (2) conversation history, (3) retrieved/grounded context, (4) user input + reserved output. Adding tokens to one pool subtracts from another. Treating this as zero-sum is the architectural shift; treating it as elastic is the 2024-era mistake.
- **Context layer (upstream) vs context window (downstream)**. The window is where tokens go; the layer is the infrastructure that decides which tokens go and which don't. The context layer is the load-bearing component — quality, freshness, and relevance of what fills the window dominates the model's effective intelligence.
- **Dynamic budget allocation > fixed slots**. Advanced systems (2026) reallocate context budget per-turn based on current task: a Q&A turn may give 80% to retrieved docs and 10% to history; a follow-up turn flips that. Fixed allocations (e.g. "always 2000 tokens for system + 4000 for history + 8000 for retrieved") are leaving capacity on the floor.
- **Two-tier memory (short + long)**. Short-term = current session inside the window. Long-term = external store (DB, vector store, file system) outside the window, queried on demand. The architectural decision: WHEN does long-term get pulled into short-term? Per-turn? Per-task? Per-sub-agent spawn? Each choice has cost + relevance tradeoffs.
- **MCP as governed context delivery**. Model Context Protocol = standard for sending structured, governed metadata to LLMs. Permissioned, formatted, fewer wasted tokens vs raw doc dumps. MCP is essentially "the context layer formalized as a protocol" — the equivalent of REST for context delivery.
- **Effective context is smaller than nominal context**. Claude Code reserves ~16.5% of the 200K window for internal overhead (per the kit's own `context-guardian.md`). General industry observation: 2026 frontier models lose accuracy on tail-of-window content (the "lost in the middle" effect persists). Budget on effective, not nominal.
- **Context overflow is a runtime failure mode**. Traditional architectures plan for OOM, network timeouts, rate limits; 2026 architectures plan for context overflow as a first-class failure mode with named recoveries (compact, summarize, evict, refuse-and-handoff).

## Verbatim quotes worth preserving

> "Context allocation becomes a zero-sum game: more retrieved documents mean less conversation history, and vice versa."

> "Advanced systems dynamically allocate context budget across different components based on current needs, rather than fixed allocations."

> "External memory architectures separate short-term context from long-term knowledge."

## Implications for the engine catalog

The kit's `context-guardian.md` already implements ADVISORY (50%) / PREPARE (70%) / HALT (85%) thresholds — this is leading-edge by industry standards. Gaps: (a) no per-component budget (system / history / retrieved / user/output) breakdown in telemetry, (b) no dynamic-reallocation primitive (current behavior is "warn at thresholds"; 2026 best practice is "reallocate at thresholds"), (c) no built-in MCP-as-context-layer convention beyond the existing per-server MCP tiering, (d) no first-class "compact-and-resume" automation (currently relies on `/resume-handoff` user invocation).

## NEW F-NNN candidates

- F-079 four-pool-budget-telemetry — Default-on telemetry breaks context usage into the 4 pools (system / history / retrieved / user+output) per turn; surfaces which pool is dominating — confidence: H
- F-080 dynamic-context-reallocation — At PREPARE threshold, instead of just warning, the engine triggers a reallocation: drop low-relevance history, recompact verbose retrieved context, re-budget pools for the next N turns. Configurable per-skill — confidence: M
- F-081 context-overflow-named-recoveries — First-class named recoveries (compact / summarize-history / evict-retrieved / refuse-with-handoff) with declared per-skill preferences. Recovery is mechanical, not a model judgment — confidence: H
- F-082 mcp-as-context-layer-default — Promote MCP from "tier-based optional" to "preferred context-delivery primitive" for governed metadata; raw file-read fallback only when MCP unavailable. Document the MCP-vs-Read decision rule explicitly — confidence: M
- F-083 effective-vs-nominal-context-doc — Add to `context-guardian.md` an explicit "effective vs nominal" computation per provider: Claude reserves 16.5%, OpenAI/Gemini differ. Engine telemetry computes against effective, not nominal — confidence: H

## Confidence

HIGH — zero-sum allocation framing is cited across all 6 sources; MCP-as-context-layer framing is the most novel finding (vs being known just as a tool-discovery protocol).
