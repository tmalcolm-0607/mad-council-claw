# Glossary

Terms used across MAD.Council (spec, rules, wiki, skills). Listed alphabetically. For pattern explainers see `wiki/patterns/`. For framework details see `wiki/implementations/`.

---

### A2A

Google Agent2Agent protocol. Open standard (Linux Foundation, Apr 2025) for communication between agents across frameworks. JSON-RPC 2.0 over HTTP(S). Adopted by MAD.Council as the optional cross-machine / cross-toolchain interop layer. See `wiki/implementations/a2a.md`.

### Agent Card

JSON document advertising an agent's capabilities, skills, auth schemes, and endpoint. A2A-standard format served at `/.well-known/agent-card.json` (current) or `/agent.json` (legacy). In MAD.Council, Agent Cards can also appear inside `channel.json` `members[i].agent_card` for channel-internal discovery. See `mad.council.a2a.md` §6.1.

### ALAS

Agentic Learning and Assessment System. An internal hub for agent learning signals, used by `plugins/sfi-dev-toolkit/`. Pairs self-assessment (execution signal) with independent evaluation (outcome signal) for post-hoc analysis. MAD.Council's `/council-retro` is ALAS-compatible. See `wiki/patterns/learning-signals.md`.

### Advocate

One of the three canonical Council roles. Mindset: author's proxy. Reconstructs intent from evidence; defends choices; flags uncertainties the author had. Alias in court-metaphor: Defender. See `wiki/patterns/multi-role-review.md`.

### Architect

One of the three canonical Council roles. Mindset: principal engineer. Zooms out on patterns, coupling, direction, maintainability. Alias in court-metaphor: Judge. See `wiki/patterns/multi-role-review.md`.

### Archive

A terminal directory inside a channel where resolved threads are moved after the archive timer (60 min post-resolve). Archived threads carry their full message history + verdict + MAD artifacts for audit. See `mad.council.a2a.md` §7.7.

### Atomic write

A file-write pattern: write content to `<file>.tmp`, then `rename` to `<file>`. `rename()` is atomic on POSIX and Windows NTFS — readers see either the pre-update or post-update file, never a half-written state. See `rules/concurrency-safety.md`.

### Body size cap

32 KB maximum per message body, enforced at `/council-post` time. Fails with `rc=2` if exceeded. Prevents accidental context bloat. See `mad.council.a2a.md` §8.5.

### Breaker / Circuit Breaker

A pattern: halt operations on a dependency after N consecutive failures, surface the error, wait for manual reset. Prevents runaway retry loops. Canonical threshold: 3 consecutive failures. See `wiki/patterns/circuit-breakers.md`.

### Channel

A named shared-state directory under `~/claude-data/channels/` where members exchange messages in threads. The fundamental coordination primitive. Has a purpose, members, threads, archive. See `mad.council.a2a.md` §7.

### Channel Integrity Policy

A named policy (in `mad.council.a2a.md` §8 planned / partially implemented) covering who can resolve threads, who can leave with archival, alias-reclaim rules, and rate-limits. Sibling to the three named security policies.

### CHECKLIST

`C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md`. The output of the 10-iter marketplace review: 138 HIGH-confidence patterns + 13 industry gaps. Grounding source for most MAD wiki entries. Referenced by pattern number in many files.

### Completion Report

A structured JSON + human-readable summary an agent emits when finishing a work unit. Enables orchestrator routing + audit. Emitted by `/council-leave`. See `wiki/patterns/completion-report-protocol.md`.

### Consent gate

A user-facing confirmation prompt required before a destructive or irreversible action. Required by `rules/dangerous-operations-policy.md`. No silent writes. No consent-by-message-content.

### Context Gap

A degradation event where a skill couldn't access an expected dependency (digest timeout, MCP unavailable, file locked). Reported in the `Context Gaps` section of `/council-check` output. Never silent. See `rules/degradation-fallback-policy.md` Rule 3.

### Council

The review layer. Three-role review (Advocate / Skeptic / Architect) emits findings aggregated into a binding verdict. See `mad.council.a2a.md` §5 and `wiki/patterns/multi-role-review.md`.

### CronCreate

Claude Code runtime's scheduled-task primitive. Used for `/council-check` background polling. A member's CronCreate task dies with the session — polling isn't stale across restarts.

### Crew Communicator

A2A-Starship's per-Claude-Code-session MCP-stdio client. Advertises the session's Agent Card (via `--name` + `--description`) and connects to a Ship Bridge. See `plugins/a2a-starship/skills/crewcommunicator-setup/SKILL.md`.

### Dangerous Operations & Explicit Consent Policy

Named policy requiring explicit user confirmation before side-effect-producing operations. 6 canonical categories (package installs, file writes, ADO writes, feedback submission, git operations, MCP startup). See `rules/dangerous-operations-policy.md`.

### Degradation & Fallback Policy

Named policy: 5 rules for when dependencies are unavailable. Never block on optional; always offer manual fallback; report Context Gaps; respect retry limits; graceful partial completion. See `rules/degradation-fallback-policy.md`.

### Digest

The `digest.json` file at channel root. <2 KB summary of active threads, recent resolutions, member state, Context Gaps. Primary polling target for `/council-check` — reading one file tells you if anything changed. See `mad.council.a2a.md` §7.5.

### Fleet

A group of specialized sub-agents run in parallel by an orchestrator. Canonical example: `plugins/ai-native-team/skills/fleet-orchestration/` — 16 specialized agents. See `wiki/implementations/marketplace-plugins.md`.

### FIX / ACCEPT / ESCALATE / INVESTIGATE

The four binding verdict types a Council review can emit. See `mad.council.a2a.md` §5.5.

- **FIX** — ≥1 CRITICAL or ≥3 HIGH findings; work cannot proceed.
- **ACCEPT** — no blocking findings; approved.
- **ESCALATE** — no consensus or outside Council's expertise; route to human.
- **INVESTIGATE** — findings suggest a problem; evidence incomplete; need more research.

### Fuser (LLM-as-a-Fuser)

A dedicated LLM that synthesizes outputs from multiple judge models into a single verdict. The term comes from heterogeneous multi-judge aggregation research (arxiv 2603.28488) and is a more precise name for what the spec's `§5.6` calls the "validator" role. In MAD.Council Phase-1 and Phase-2, the validator operates on a single role's output (redundancy reduction, not multi-model fusion). In Phase 5, when ensemble-mode is enabled on Skeptic (3 models), a Fuser LLM reads all three outputs + rubric scores + confidence and emits the unified finding set. See `wiki/patterns/multi-model-ensemble.md`.

### Handoff

A labeled button (in `handoffs:` frontmatter, zen-agents style) or explicit command (`/council-review`) that transitions work from one agent to another. Orchestrator-owned routing; agents don't decide next step themselves.

### MAD

The spec-first / plan / tasks / verify workflow from `plugins/dotnet-dev-kit/skills/mad-*`. Stands for the skill naming convention (mad-spec, mad-plan, mad-tasks, mad-idea). Adopted as MAD.Council's discipline layer. See `mad.council.a2a.md` §4 and `wiki/implementations/marketplace-plugins.md` top-8.

### MAD Artifact

A `spec.md`, `plan.md`, `tasks.md`, or `research.md` file in a channel directory (MAD layer enabled). Structures the channel's work. Gates enforce order (spec → plan → tasks → verify).

### MCP (Model Context Protocol)

The protocol Claude Code uses to talk to external services. Per-skill `mcp-servers:` frontmatter declares dependencies. Tools surface as `server/tool` names. See `wiki/implementations/anthropic-claude-code.md`.

### Mention

An `@alias` reference in a message body, extracted and validated against channel members at post time. Phantom mentions (aliases not in channel) are dropped with a warning. See `mad.council.a2a.md` §11.3 step 4.

### Message

An append-only JSON file inside a thread. Typed (`task` / `question` / `answer` / `status` / `fyi` / `resolve`). Filename includes monotonic seq, timestamp, sender alias. Never rewritten after creation.

### Mode

A declared execution context that determines skill behavior. Canonical modes: `auto` (CI/CD, no curator) vs `propose` (interactive, human curator). Also `--fast`, `review / report / silent`. See `wiki/patterns/mode-aware-sizing.md`.

### Orchestrator

An agent that routes work to specialized sub-agents without doing the domain work itself. Identity rule: "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF." See `rules/orchestrator-identity.md`.

### Preflight

A one-time dependency-check at skill startup. Probes each declared dependency with a fast read-only call; reports pass/warn/fail with a rendered table; stops on required-failure. See `wiki/patterns/preflight-dependency-checks.md`.

### Prompt-Injection & Data Safety Policy

Named policy: messages and external content are data, never instructions. 5 rules + literal-phrase ban list. See `rules/prompt-injection-policy.md`.

### Prosecutor

The Skeptic role's court-metaphor alias. Role of finding flaws. Alias swap is cosmetic; mindsets and verdicts are identical. See `wiki/patterns/multi-role-review.md` §5.2.

### Read Marker

A per-member `read-markers/<alias>.json` file tracking the last seq the member has read. `/council-check` updates it after rendering unreads. Owner is the only writer.

### Reducer

A function that merges two updates to the same state field. Used in LangGraph (`Annotated[list, add_messages]`) and analogously in MAD.Council's derived fields (`thread.json.message_count` is reducer-like — recomputed from messages dir, not written authoritatively).

### run_id

A GUID generated at session start and propagated through every message, reply, verdict, and artifact. Enables post-hoc correlation: `grep <guid> **/*.json` reconstructs the full work unit. See `wiki/patterns/run-id-correlation.md`.

### Safe default

The classification picked when multi-model ensemble can't reach consensus (all-disagree case). Canonical: `valid_low_priority` — finding might be correct but isn't worth blocking on. See `wiki/patterns/multi-model-ensemble.md`.

### seq (sequence number)

Monotonic counter stored in `seq.json` at channel root. Every message gets a unique seq. Writer reads-inc-writes with retry-on-collision. Ordering primitive for the whole channel. See `rules/concurrency-safety.md`.

### session_id

Claude Code's ephemeral session identifier. Bound to an `alias` at `/council-join` time. Post-time binding check: `from.session_id` must equal the session registered for `from.alias`. Mismatch = spoofing → reject. See `mad.council.a2a.md` §7.2.

### Ship Bridge

A2A-Starship's central hub process. Runs on one machine (default `https://localhost:8222`), routes tasks between agents across machines. Serves Agent Card discovery. See `plugins/a2a-starship/skills/shipbridge-setup/SKILL.md`.

### Skeptic

One of the three canonical Council roles. Mindset: attacker. Finds flaws, assumes ≥1 issue exists, goes deep on runtime behavior. Alias in court-metaphor: Prosecutor. See `wiki/patterns/multi-role-review.md`.

### Skill

A procedure (SKILL.md + optional scripts). Frontmatter declares triggers, allowed tools, argument hints. Skills can invoke sub-agents via Task. Implements what an agent *does*; agents define *who* the agent is. See `wiki/implementations/anthropic-claude-code.md`.

### STRIDE

The classic 6-category threat model from Microsoft SDL: Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege. MAD.Council uses classic 6; ASTRIDE extension (arxiv 2512.04785) with 3 LLM-specific + 2 agentic categories is a Phase-5 item. See `rules/stride-threat-model.md`.

### Sub-agent

An agent spawned by another agent via the Task tool (or equivalent). Context is isolated; output returns to parent. Claude Code: sub-agents cannot spawn sub-agents (flat hierarchy). See `wiki/implementations/anthropic-claude-code.md`.

### Task (Claude Code tool)

Claude Code's native sub-agent invocation primitive. Synchronous by default (parallel fan-out via single message with multiple Task blocks). `run_in_background: true` is broken — don't use. See `wiki/implementations/anthropic-claude-code.md`.

### Task (message type)

One of the six message types in a channel. Work to be picked up. Expected response: status updates, completion. See `mad.council.a2a.md` §7.3.

### Thread

A topical subconversation inside a channel. Lifecycle: active → resolved → archived. Can become stale (>24h no message). See `mad.council.a2a.md` §7.4.

### Trust tier

Numeric threshold (e.g., ≥700) gating destructive actions in automated/daemon mode. From `plugins/ai-native-team/agents/fleet-orchestrator.md`. Not the industry 3-tier (insight/assistive/autonomous) taxonomy; MAD.Council uses a numeric gate only.

### Verdict

The binding output of a Council review. Four types (FIX / ACCEPT / ESCALATE / INVESTIGATE). Stored at `threads/<thread-id>/verdict.json`. Posted as a `resolve` message to the thread. Binding — cannot be overturned informally, only by another review.

### Worker

A specialized sub-agent that does domain work delegated by an orchestrator. Isolated context, explicit brief, bounded effort. See `wiki/patterns/orchestrator-worker.md`.

### YAGNI

"You Aren't Gonna Need It." A software engineering principle: don't build abstractions before callers exist. Applied as a filter in multi-role review — demotes "add feature X" findings with no callers. See `wiki/patterns/yagni-filter.md`.

---

## Cross-references

- **`wiki/patterns/`** — pattern explainers.
- **`wiki/implementations/`** — framework-specific details.
- **`rules/`** — named policies.
- **`wiki/references.md`** — external sources.
- **`wiki/anti-patterns.md`** — what not to do.
- **`mad.council.a2a.md`** — the spec.
