# Implementation: Anthropic Claude Code

**What it is:** Anthropic's terminal-based agent for software engineering. Ships with the Task tool for sub-agent delegation, a declarative `/agents` subagent system, and a MCP server integration layer. The platform MAD.Council is most likely to run on.

**Role in MAD.Council:** Native host. Our skills, rules, and coordination primitives run inside Claude Code. When the wiki pattern says "orchestrator," for us that's a Claude Code session delegating via Task.

**Last verified:** 2026-04-17 (iter 3 research).

## Core primitives

### 1. Task tool

Synchronous spawning of a sub-agent from within a session. Fans out in parallel when a single message includes multiple `Task` tool-use blocks.

```
Parent session
    │
    └── Task(description, prompt, subagent_type) ────► Sub-agent (isolated context)
                                                         │
                                                         └── returns final message
```

**Subagent types** are predefined personas: `Explore`, `Plan`, `general-purpose`, plus any custom ones declared in `.claude/agents/*.md` or the top-level `/agents`.

### 2. Subagents (`@agent-name`)

A declarative way to define sub-agents with frontmatter: `name`, `description`, `tools`, `handoffs`, `mcp-servers`. The `@agent-name` syntax in conversation invokes one; the Task tool invokes programmatically.

**File locations** (five standard dirs scanned by `agent-orchestrator`):
- `agents/`
- `.github/agents/`
- `.github/shared/agents/`
- `.claude/agents/`
- `shared/agents/`

### 3. Skills (SKILL.md + slash commands)

Procedures. Frontmatter declares triggers, allowed tools, arg hints. Skills can invoke sub-agents via Task and can reference other skills. They implement what an agent *does*; agents define *who* the agent is.

### 4. MCP (Model Context Protocol)

How external services talk to Claude Code. Frontmatter `mcp-servers:` declares per-agent/per-skill MCP integrations (e.g., ADO, WorkIQ, vendor documentation MCPs, Playwright, custom). Tools surface as `server/tool` names.

## Pros

- **Native parallel Task delegation**. Single message with N Task blocks fans out N isolated sub-agents concurrently. 90.2% measured gain in Anthropic's own research system.
- **Clean context isolation**. Each sub-agent has a fresh context window. Prompt-injection in one doesn't poison another.
- **Declarative agent definitions**. YAML frontmatter keeps agent shape inspectable without code archaeology.
- **Per-agent MCP declaration**. An agent's dependency surface is visible in its frontmatter, not hidden in runtime config.
- **Per-agent tool allowlists**. Frontmatter `tools:` field enforces the minimum-tool-surface principle.
- **Predictable cost**. Sub-agents have a bounded context; no runaway recursion.
- **Skills as procedures, agents as roles**. Canonical separation of concerns (matches CHECKLIST pattern: "Rules files configure behavior; SKILL.md encodes procedures").

## Cons

- **Subagents cannot spawn subagents.** Flat hierarchy by design (see `wiki/anti-patterns.md` §3). Multi-level decomposition must be coordinated from the main session.
- **Sub-agent output is capped** (~32K tokens before silent truncation). Long research returns must be chunked by explicit instruction.
- **`run_in_background: true` is broken.** GitHub issues #17011, #17147, #21352, #32252: output is silently lost. **Use synchronous parallel Task calls** (single message, multiple blocks) instead. Project-level CLAUDE.md explicitly prohibits `run_in_background: true`.
- **Schema drift across subagent types**. `general-purpose` is unconstrained; domain-specific types (`Explore`, `Plan`) have narrower tool surfaces. Readers of the resulting conversation may not notice.
- **Handoff UX is explicit**. The `handoffs:` frontmatter surfaces a button for the user to click; in automated/daemon mode this stalls.
- **Skill-path resolution via globs** when `CLAUDE_PLUGIN_ROOT` isn't set adds latency.

## Do / Don't

**Do**:

- **Use synchronous parallel Task calls** when you need N independent sub-agents. Single message, multiple Task blocks. Claude Code fans out natively.
- **Declare explicit tool allowlists** on every agent. Prefer named tools (e.g., `ado-repo_get_pull_request_by_id`) over wildcards (`ado/*`) when the skill only needs a few.
- **Use `Explore` for codebase discovery** rather than `general-purpose` — it's the specialized retrieval agent.
- **Use `Plan` for planning-only work** — it has no Task/Bash, intentionally, enforcing the "plan, don't execute" pattern.
- **Give each Task call a clean brief**: objective + output format + definition of done + file paths + task boundaries.
- **Instruct long-return sub-agents to chunk**: "split response into ≤30K token segments labeled PART 1/N" for research that may exceed 32K.
- **Use `handoffs:` for user-driven multi-step workflows** (zen-agents pattern). Stalls in daemon mode are acceptable because daemon mode shouldn't drive multi-step user flows.
- **Log per-sub-agent progress** with `📋 Stage N/M` style output before and after Task invocations.

**Don't**:

- **Don't use `run_in_background: true`.** It's broken. Prefer synchronous Task calls.
- **Don't spawn sub-sub-agents.** Flat hierarchy is enforced. Coordinate from the main session.
- **Don't pass the full conversation history to every sub-agent.** Pass a clean brief.
- **Don't use wildcard MCP tool lists** (`ado/*`) when the skill uses 2–3 specific tools. Explicit allowlists reduce blast radius and surface over-privileged skills early.
- **Don't assume sub-agent memory persists**. Each Task invocation gets a fresh context. State must pass through return values or shared files.
- **Don't rely on sub-agent output ordering when parallel**. Fan-out is unordered; don't write code that depends on Task-1 finishing before Task-2.

## Common pitfalls

### Silent truncation at ~32K

A sub-agent producing a long survey report may truncate silently. Symptom: report ends mid-sentence; no error surfaces. **Mitigation:** instruct chunking explicitly; reserve `general-purpose` for bounded tasks; use `Explore` with "quick" thoroughness for codebase scans.

### Background-agent output loss

See CHK-011 (resolved) in `_review-checklist.md`. The issue has persisted through multiple Claude Code versions in 2026. Workaround: synchronous parallel Task calls only.

### MCP dependency leakage

A skill with `mcp-servers: ado` uses a specific ADO instance. If the session is restarted on a machine without that MCP, the skill silently degrades. Mitigation: preflight check (`rules/preflight-dependency-checks.md`) + Context Gaps reporting.

### Skill/agent name collisions

Multiple agents/skills with the same name across linked repos → agent-orchestrator's scoring formula (10pts exact name + 1pt keyword + 3pts domain, top-2-within-1pt → user chooses) handles it, but only when the orchestrator is actually in the loop. Invoking `@name` directly resolves by discovery order.

### Tool declaration drift

A skill's `allowed-tools:` frontmatter narrows tool surface, but runtime resolution may add tools via MCP auto-connect. The declared list should be treated as minimum-surface; adding tools via MCP runtime without declaration is a governance gap.

## How MAD.Council uses this implementation

**Primary execution host.** Every `/council-*` skill is a Claude Code skill. Key mappings:

- `Task` tool → Council role invocation in `/council-review` (spawns Advocate, Skeptic, Architect in parallel).
- Subagent declarations → Advocate/Skeptic/Architect in `MAD/agents/<role>/agent.md` (iter 13).
- MCP per-agent — if a Council role needs external context (vendor/platform documentation MCPs for validation, WorkIQ-style MCPs for org-context), it's declared in that role's frontmatter.
- Slash commands — the 10 `/council-*` commands are Claude Code skills.
- CronCreate polling — Channels-layer background polling uses CronCreate for `/council-check`.

**What MAD.Council does NOT rely on:**
- `run_in_background: true` (explicitly rejected).
- Sub-sub-agent hierarchies (explicitly avoided).
- Cross-session persistent memory beyond the filesystem state (the spec is file-based by design).

## Known issue tracker (as of 2026-04-17)

| Issue | Ref | Impact on MAD.Council |
|---|---|---|
| Background agent output empty | anthropics/claude-code #17011, #17147, #21352, #32252 | MAD.Council already rejects `run_in_background` — no impact. |
| Subagents cannot spawn subagents | #4182 | MAD.Council already assumes flat hierarchy — no impact. |
| Claude Code hangs after Feb 28 update | #29652 | Mitigation: keep Claude Code updated; see project CLAUDE.md recovery protocol. |
| API streaming stall no read timeout | #25979 | Use `/rewind` recovery per CLAUDE.md. |
| Caramelizing hang post-task | #20336 | Known background-process interaction — mitigated by avoiding `run_in_background`. |

## References

- **Claude Code Docs — Subagents** — https://code.claude.com/docs/en/sub-agents
- **Claude Code Docs — Agent Teams** — https://code.claude.com/docs/en/agent-teams
- **Claude API Docs — Subagents in SDK** — https://platform.claude.com/docs/en/agent-sdk/subagents
- **Anthropic — "Building Effective Agents"** — https://www.anthropic.com/research/building-effective-agents
- **Anthropic — Multi-Agent Research System post-mortem** — https://www.anthropic.com/engineering/multi-agent-research-system
- **Anthropic cookbook — orchestrator_workers.ipynb** — https://github.com/anthropics/anthropic-cookbook
- **Claude Code issue tracker** — https://github.com/anthropics/claude-code/issues
- Full link list in `wiki/references.md` §2.

## Related wiki entries

- `wiki/patterns/orchestrator-worker.md` §Claude Code section — the pattern grounded in this implementation.
- `wiki/anti-patterns.md` §3 (nested sub-agents), §4 (run_in_background).
- `wiki/implementations/autogen.md` — contrast with AutoGen's GroupChat approach.
- `wiki/implementations/a2a.md` — how Claude Code sessions bridge out via A2A.
- `wiki/implementations/marketplace-plugins.md` — the agents/skills we extracted patterns from are all Claude Code native.
