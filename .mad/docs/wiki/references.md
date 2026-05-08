# References

Canonical external sources cited throughout the MAD wiki, rules, and skill specs. Links that all the files point to, consolidated here so link-rot is fixable in one place.

**Last verified:** 2026-04-17 (iter 3 research pass).

## 1. Agent-to-Agent protocols

- **Google A2A Protocol Specification (latest)** — https://a2a-protocol.org/latest/specification/
- **A2A Spec v0.2.5 (version-pinned)** — https://a2a-protocol.org/v0.2.5/specification/
- **A2A GitHub repository** — https://github.com/a2aproject/A2A
- **Google A2A announcement (April 2025)** — https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
- **Google A2A Python SDK tutorial** — https://a2aprotocol.ai/docs/guide/google-a2a-python-sdk-tutorial
- **Google Codelab: purchasing concierge A2A example** — https://codelabs.developers.google.com/intro-a2a-purchasing-concierge
- **A2A endpoint in LangChain Agent Server** — https://docs.langchain.com/langsmith/server-a2a

**Key facts (for quick lookup):**
- Transport: **JSON-RPC 2.0 over HTTP(S)** with SSE streaming and async push notification support.
- Agent Card served at `/.well-known/agent-card.json` (newer) or `/.well-known/agent.json` (legacy).
- Agent Card fields: `name`, `description`, `url`, `version`, `defaultInputModes`, `defaultOutputModes`, `capabilities`, `skills` (list of `AgentSkill`), `authentication`.
- Open-source under Linux Foundation, Apache 2.0 license.
- Backed by 50+ partners as of April 2025; v0.3 adds gRPC support + signed security cards + Python SDK expansion.

## 2. Anthropic Claude Code

- **Claude Code Docs — Subagents** — https://code.claude.com/docs/en/sub-agents
- **Claude Code Docs — Agent Teams** — https://code.claude.com/docs/en/agent-teams
- **Claude Code Docs — Changelog** — https://code.claude.com/docs/en/changelog
- **Claude API Docs — Subagents in the SDK** — https://platform.claude.com/docs/en/agent-sdk/subagents
- **Anthropic "Building Effective Agents"** — https://www.anthropic.com/research/building-effective-agents
- **Anthropic "Building a Multi-Agent Research System"** — https://www.anthropic.com/engineering/multi-agent-research-system
- **Anthropic claude-cookbooks `patterns/agents/orchestrator_workers.ipynb`** — https://github.com/anthropics/anthropic-cookbook
- **Anthropic "Seeing like an agent"** — https://claude.com/blog/seeing-like-an-agent
- **Claude Code GitHub issues tracker** — https://github.com/anthropics/claude-code/issues

**Known limitations (validated iter 3):**
- **Subagents cannot spawn subagents.** One level of delegation, full stop. Sub-Agent Task Tool Not Exposed When Launching Nested Agents (Issue #4182). Design: flat hierarchy for predictability.
- **`run_in_background: true` has documented output-loss bugs.** Background agent output silently lost; 0-byte files. Validated via GitHub issues #17011, #17147, #21352, #32252. Workaround: avoid run_in_background entirely; use synchronous parallel Task calls (single message, multiple tool blocks).

## 3. AutoGen / Microsoft Agent Framework

- **AutoGen stable (Microsoft)** — https://microsoft.github.io/autogen/stable/
- **AutoGen design patterns** — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/
- **AutoGen Selector Group Chat** — https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/selector-group-chat.html
- **AutoGen Group Chat tutorial** — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/group-chat.html
- **AutoGen to Microsoft Agent Framework migration guide** — https://learn.microsoft.com/en-us/agent-framework/migration-guide/from-autogen/
- **Microsoft Agent Framework Orchestrations — Group Chat** — https://learn.microsoft.com/en-us/agent-framework/user-guide/workflows/orchestrations/group-chat

**Relationship note:** AutoGen is being unified into the broader **Microsoft Agent Framework** as of 2025–2026. New projects should consider Agent Framework; existing AutoGen code has a Microsoft-maintained migration path.

**Key patterns:**
- `RoundRobinGroupChat` — fixed-order turns, broadcast to all participants.
- `SelectorGroupChat` — LLM-based next-speaker selection.
- Mandatory termination conditions (text match or `max_turns`); absence = infinite loop.
- Mixture of Agents: https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/mixture-of-agents.html

## 4. LangGraph / LangChain

- **LangGraph (main)** — https://www.langchain.com/langgraph
- **LangGraph GitHub** — https://github.com/langchain-ai/langgraph
- **LangGraph Plan-and-Execute Agents blog** — https://blog.langchain.com/planning-agents/
- **LangGraph Multi-Agent Workflows blog** — https://blog.langchain.com/langgraph-multi-agent-workflows/
- **LangGraph first-principles design** — https://blog.langchain.com/building-langgraph/
- **LangGraph TypeScript Checkpointing and Persistence Guide** — https://langgraphjs.guide/persistence/
- **Human-in-the-loop docs** — https://docs.langchain.com/oss/python/langchain/human-in-the-loop

**Key primitives:**
- **State machine model**: nodes = functions, edges = transitions, state immutable + checkpointed after every step.
- **Checkpointers**: `MemorySaver` (ephemeral), `SqliteSaver` (durable local, recommended for local dev), `PostgresSaver` (production).
- **thread_id resumption**: agents can run for hours, survive deploys, resume exactly where they left off.
- **Supervisor pattern**: multiple agents as separate graphs, coordinated via supervisor; state merged via reducers.

## 5. Published research (academic)

- **CourtEval** (When AIs Judge AIs) — arxiv 2508.02994 — https://arxiv.org/html/2508.02994v1 — 3-agent Grader/Critic/Defender evaluation.
- **VulTrial** (Mock-court vulnerability detection) — arxiv 2505.10961 — https://arxiv.org/html/2505.10961v2 — 4-role security-researcher/code-author/moderator/jury.
- **RPA-Check** — arxiv 2604.11655 — https://arxiv.org/abs/2604.11655 — "A Multi-Stage Automated Framework for Evaluating Dynamic LLM-based Role-Playing Agents" (Rosati, Colucci, Bolognini, Mancini, Sernani). Validates via "LLM Court," a forensic training simulation; quantized 8–9B models shown competitive with larger models on procedural consistency. Verified 2026-04-17.
- **Adversarial Multi-Agent Evaluation via Iterative Debate** — OpenReview — https://openreview.net/forum?id=06ZvHHBR0i
- **LLM Ensemble survey** — https://github.com/junchenzhi/Awesome-LLM-Ensemble
- **Code-gen ensemble with CodeBLEU + CrossHair** — arxiv 2503.15838 — https://arxiv.org/pdf/2503.15838 (90.2% HumanEval vs 83.5% GPT-4o baseline).
- **Market Making for Multi-Agent LLM coordination** — arxiv 2511.17621 — https://arxiv.org/abs/2511.17621 (+10% accuracy over single-shot, preserves interpretability).
- **ASTRIDE — STRIDE for agentic AI** — arxiv 2512.04785 — https://arxiv.org/html/2512.04785 (STRIDE extended with 3 LLM-specific + 2 Agentic categories).
- **Adversarial Attacks on LLM-as-a-Judge** — arxiv 2504.18333 — https://arxiv.org/abs/2504.18333
- **LLM Code Reviewers Are Harder to Fool Than You Think** — arxiv 2602.16741 — https://arxiv.org/html/2602.16741v1
- **Multi-LLM Thematic Analysis with Dual Reliability Metrics** — arxiv 2512.20352 — https://arxiv.org/abs/2512.20352 — "Combining Cohen's Kappa and Semantic Similarity for Qualitative Research Validation" (Dec 2025). Evaluates Gemini 2.5 Pro, GPT-4o, Claude 3.5 Sonnet across ensemble validation with 1-6 seeds + temperature 0.0-2.0; κ agreement >0.80 threshold across all three models. Cited by `wiki/patterns/multi-model-ensemble.md`. Verified 2026-04-17 iter 30.

## 6. OWASP & prompt-injection defense

- **OWASP Top 10 for LLM Applications** — https://owasp.org/www-project-top-10-for-large-language-model-applications/
- **OWASP LLM01: Prompt Injection** — https://genai.owasp.org/llmrisk/llm01-prompt-injection/
- **OWASP LLM01 (2025 v4.2.0a PDF)** — https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf
- **OWASP LLM Prompt Injection Prevention Cheat Sheet** — https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html
- **Lakera "Indirect Prompt Injection: The Hidden Threat"** — https://www.lakera.ai/blog/indirect-prompt-injection
- **Vectra "Prompt injection: types, real-world CVEs, and enterprise defenses"** — https://www.vectra.ai/topics/prompt-injection
- **SQ Magazine "Prompt Injection Statistics 2026"** — https://sqmagazine.co.uk/prompt-injection-statistics/
- **"Prompt Injection in 2026" (Kunal Ganglani)** — https://www.kunalganglani.com/blog/prompt-injection-2026-owasp-llm-vulnerability
- **OpenAI on prompt injections** — https://openai.com/index/prompt-injections/
- **GitHub: tldrsec/prompt-injection-defenses** — https://github.com/tldrsec/prompt-injection-defenses

**Key 2026 stats (validated iter 3):**
- Prompt injection ranks **#1** in OWASP Top 10 for LLM Applications (2025 → 2026 carryover).
- **73% of production AI deployments** have prompt-injection vulnerabilities.
- Attack success rates: **50–84%** baseline; adaptive techniques **>85%**.
- Indirect prompt injection = **55–60% of total attacks** (Lakera 2026 data).
- **Defense-in-depth reduces attack success from 73.2% to 8.7%** (Vectra).
- **42+ distinct prompt-injection techniques** catalogued across ecosystems.
- **Around 40% of AI agent protocols** show prompt-injection-exploitable vulnerabilities.

## 7. GitHub spoofing / identity attacks

- **Gruntwork: "How to Spoof Any User on GitHub"** — https://blog.gruntwork.io/how-to-spoof-any-user-on-github-and-what-to-do-to-prevent-it-e237e95b8deb
- **ITPro: Dependabot impersonation attack** — https://www.itpro.com/security/cyber-attacks/hackers-are-spoofing-themselves-as-githubs-dependabot
- **BleepingComputer: Fake "Security Alert" OAuth hijack** — https://www.bleepingcomputer.com/news/security/fake-security-alert-issues-on-github-use-oauth-app-to-hijack-accounts/
- **Anthropic Claude Code action security** — https://github.com/anthropics/claude-code-action/blob/main/docs/security.md
- **GitHub Actions spoofing guide** — identity-verification topic — https://github.com/topics/identity-verification

## 8. Google SRE / blameless postmortems

- **Google SRE Book — Postmortem Culture** — https://sre.google/sre-book/postmortem-culture/
- **Google SRE Workbook — Postmortem Culture** — https://sre.google/workbook/postmortem-culture/
- **Google SRE — Example Postmortem** — https://sre.google/sre-book/example-postmortem/
- **Rootly — Blameless Postmortem Guide** — https://rootly.com/incident-postmortems/blameless
- **Rootly — Postmortem Meetings 2026** — https://rootly.com/incident-postmortems/meeting-guide

**Key rules:**
- **48-hour postmortem rule** — run within 48h of incident closure.
- Structured format: timeline + impact + root causes + action items with clear owners.
- Originated mid-20th-century healthcare + aerospace.

## 9. Root-cause analysis critiques

- **Five Whys — Wikipedia** — https://en.wikipedia.org/wiki/Five_whys
- **"Top Criticisms of the 5-Why Approach"** — https://blog.thinkreliability.com/top-criticisms-of-the-5-why-approach
- **"The Problem with '5 Whys'"** (studylib) — https://studylib.net/doc/26239290/the-problem-with-5-why-s

**Key critiques of Five Whys:**
- Toyota's Teruyuki Minoura called it "too basic" for real root causes.
- Forces single causal pathway; real failures have branching causes.
- Confirmation bias (team's hypothesis steers questions).
- Not repeatable — different investigators get different causes.
- Doesn't help prioritize which problems to investigate.
- Alternatives: fishbone/Ishikawa diagrams, Kelvin TOP-SET.

## 10. Agent-guardrails / trust-tier literature

- **AI Agent Circuit Breaker Pattern (Cordum 2026)** — https://cordum.io/blog/ai-agent-circuit-breaker-pattern
- **Essential Framework for AI Agent Guardrails (Galileo)** — https://galileo.ai/blog/ai-agent-guardrails-framework
- **Agentic AI Guardrails: Controls That Work (Redis)** — https://redis.io/blog/agentic-ai-guardrails/
- **Designing AI guardrails for apps and agents in Marketplace (MS Community Hub)** — https://techcommunity.microsoft.com/blog/marketplace-blog/designing-ai-guardrails-for-apps-and-agents-in-marketplace/4507324
- **Real-Time Guardrails for Agentic Systems (Akira)** — https://www.akira.ai/blog/real-time-guardrails-agentic-systems
- **Agent Trust: From Guardrails to Autonomy (VisionWrights)** — https://visionwrights.com/blog/agent-trust-from-guardrails-to-autonomy
- **"The agent control plane" (CIO)** — https://www.cio.com/article/4130922/the-agent-control-plane-architecting-guardrails-for-a-new-digital-workforce.html

**Three-tier autonomy taxonomy** (industry-standard, not adopted by MAD.Council yet — see `rules/stride-threat-model.md`):
- **Insight agents** — surface information only.
- **Assistive agents** — recommend, wait for approval.
- **Autonomous agents** — act within defined guardrails.

## 11. Code review scoring / merge readiness

- **MergeShield** — https://mergeshield.dev/ (6-dimension 0-100 merge risk score).
- **Snyk Breakability Risk Score** — https://updates.snyk.io/merge-with-confidence-introducing-breakability-analysis-for-pull-requests/
- **Mend Merge Confidence** — https://www.mend.io/blog/merge-confidence/
- **GitHub merge status quick access (2026 preview)** — https://github.blog/changelog/2026-03-05-quick-access-to-merge-status-in-pull-requests-in-public-preview/

**MergeShield's 6 dimensions** (matches marketplace `pr-review-critic`'s 0-100 score):
1. Security risk
2. Blast radius
3. Test coverage
4. On-call/DRI impact
5. Regression risk
6. Dependency risk

## 12. Session knowledge / memory management

- **Hermes Agent Memory System (3-layer)** — https://hermes-agent.ai/blog/hermes-agent-memory-system
- **Augment Code Session-End Spec Update** — https://www.augmentcode.com/guides/session-end-spec-update-ai-agents
- **session-graph (W3C ontologies for AI coding sessions)** — https://github.com/robertoshimizu/session-graph
- **"Why Every AI Coding Assistant Needs a Memory Layer"** — https://towardsdatascience.com/why-every-ai-coding-assistant-needs-a-memory-layer/
- **OpenClaw AGENTS.md defaults** — https://docs.openclaw.ai/reference/AGENTS.default
- **Claude Skills — autoskill** — https://claudeskills.club/skills/autoskill-by-mhalder

**3-layer memory separation** (industry pattern; MAD.Council uses 1-layer currently):
- `MEMORY.md` — facts about environment and projects.
- `USER.md` — user communication style and preferences.
- `SKILL.md` — task procedures (agent code).

## 13. Evaluation frameworks (for iter 11 evals/)

- **Anthropic "Demystifying evals for AI agents"** — https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- **How to Test an AI Agent Harness: 6-Layer Guide 2026** (atlan.com) — https://atlan.com/know/how-to-test-ai-agent-harness/
- **Agent Evaluation Framework 2026: Metrics, Rubrics & Benchmarks** (Galileo) — https://galileo.ai/blog/agent-evaluation-framework-metrics-rubrics-benchmarks
- **What is agent evaluation? How to test agents with tasks, simulations, and success criteria** (Braintrust) — https://www.braintrust.dev/articles/agent-evaluation
- **Evaluating LLM Agents in Multi-Step Workflows (2026 Guide)** (CodeAnt) — https://www.codeant.ai/blogs/evaluate-llm-agentic-workflows
- **Micro-Specs Pattern for AI Agent Test Coverage** (Augment Code) — https://www.augmentcode.com/guides/micro-specs-pattern-ai-agent-test-coverage
- **Evaluating AI Agents: Metrics and Best Practices** (Maxim AI) — https://www.getmaxim.ai/articles/evaluating-ai-agents-metrics-and-best-practices/

### LLM-as-judge

- **LLM-as-a-Judge Complete Guide** (Confident AI) — https://www.confident-ai.com/blog/why-llm-as-a-judge-is-the-best-llm-evaluation-method
- **LLM-as-Judge Best Practices** (Monte Carlo Data) — https://www.montecarlodata.com/blog-llm-as-judge/
- **LLM-as-a-Judge: Benefits, Biases, Best Practices** (Medium, 2026) — https://medium.com/@jiminlee-ai/understanding-llm-as-a-judge-benefits-biases-and-best-practices-4b4d5cc3cbcd
- **Autorubric: Rubric-based LLM Evaluation (arxiv)** — https://arxiv.org/html/2603.00077v2
- **Using LLMs for Evaluation** (Cameron R. Wolfe) — https://cameronrwolfe.substack.com/p/llm-as-a-judge
- **LLM-as-a-judge Complete Guide** (Evidently AI) — https://www.evidentlyai.com/llm-guide/llm-as-a-judge

**Key LLM-as-judge rubric rules:**
- Narrow scales (3-5 levels) with behavioral anchors beat broad scales (central-tendency bias on broad).
- Randomize option order per evaluation (decouple score from position).
- Use explicit numeric values (shuffle-safe).
- Watch verbosity bias (judges reward longer answers).
- Watch stylistic bias (GPT prefers GPT text; Claude prefers Claude text).
- Use inter-judge reliability metrics (Cohen's Kappa, Krippendorff's Alpha).

### Red team / adversarial eval

- **Red Teaming Mind of the Machine (arxiv)** — https://arxiv.org/html/2505.04806v1 — 1,400 adversarial prompts across GPT-4/Claude 2/Mistral 7B/Vicuna.
- **Promptfoo Red Team** — https://www.promptfoo.dev/docs/red-team/
- **AI-RedTeaming-with-PromptFoo** (GitHub) — https://github.com/GenAIGator/AI-RedTeaming-with-PromptFoo/
- **AI-Red-Teaming-Guide** (GitHub) — https://github.com/requie/AI-Red-Teaming-Guide
- **DeepTeam by Confident AI** — https://www.trydeepteam.com/docs/what-is-llm-red-teaming
- **LLM Red Teaming Step-By-Step Guide** (Confident AI) — https://www.confident-ai.com/blog/red-teaming-llms-a-step-by-step-guide
- **Adaptive attacks on 12 defenses (Oct 2025, OpenAI+Anthropic+Google DeepMind)** — referenced at https://www.confident-ai.com/blog/red-teaming-llms-a-step-by-step-guide — attack success >90% after iterative adaptation.

**Key adversarial-eval rules:**
- Most successful jailbreaks unfold over **3-5 turns** — single-turn tests miss them.
- Adversarial test cases become **permanent regression tests** (locked fixtures).
- **Adaptive attacks bypass defenses** at >90% — defenses need continuous update, not one-time audit.

### Spec + test coverage

- **Cortex 2026 State of AI Benchmark** — cited in CodeAnt guide — 20-30% incident-rate increase when spec rigor + coverage not enforced.
- **CoverAssert: Iterative LLM Assertion Generation** (arxiv 2604.06607, DATE 2026) — https://arxiv.org/html/2604.06607v2
- **Best Code Test Coverage Tools 2026** — https://dev.to/rahulxsingh/12-best-code-test-coverage-tools-in-2026-comprehensive-guide-3kh3

### 6-layer test harness (atlan.com canonical)

| Layer | Purpose |
|---|---|
| **Layer 0** | Certify data sources before evals run |
| **Layer 1** | Unit test individual tool calls with deterministic assertions |
| **Layer 2** | Integration test multi-step workflows + context retention |
| **Layer 3** | End-to-end simulation with fault injection |
| **Layer 4** | Adversarial / red-team testing |
| **Layer 5** | Gate production CI/CD on eval score; continuous monitoring |

## 14. Observability / telemetry (for iter 12 metrics/)

- **OpenTelemetry — GenAI Semantic Conventions** — https://opentelemetry.io/docs/specs/semconv/gen-ai/
- **OpenTelemetry — GenAI spans** — https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/
- **OpenTelemetry — GenAI agent and framework spans** — https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/
- **OpenTelemetry — AI Agent Observability** (blog) — https://opentelemetry.io/blog/2025/ai-agent-observability/
- **OpenTelemetry for GenAI** (2024 blog, still current) — https://opentelemetry.io/blog/2024/otel-generative-ai/
- **OpenTelemetry for AI Systems: LLM and Agent Observability** (Uptrace 2026) — https://uptrace.dev/blog/opentelemetry-ai-systems
- **Distributed tracing for agentic workflows with OpenTelemetry** (Red Hat, Apr 2026) — https://developers.redhat.com/articles/2026/04/06/distributed-tracing-agentic-workflows-opentelemetry
- **Datadog LLM Observability + OpenTelemetry GenAI** — https://www.datadoghq.com/blog/llm-otel-semantic-convention/
- **Monitor AI Agents on App Service with OpenTelemetry** (Microsoft) — https://techcommunity.microsoft.com/blog/appsonazureblog/monitor-ai-agents-on-app-service-with-opentelemetry-and-the-new-application-insi/4510023
- **Agent Observability for Multi-Agent Systems** (NovaTechFlow 2026) — https://www.novatechflow.com/2026/03/agent-observability-for-multi-agent.html
- **5 best AI agent observability tools 2026** (Braintrust) — https://www.braintrust.dev/articles/best-ai-agent-observability-tools-2026
- **Top 5 AI Agent Observability Platforms 2026** (Maxim AI) — https://www.getmaxim.ai/articles/top-5-ai-agent-observability-platforms-in-2026/

### Minimum useful telemetry set (OpenTelemetry GenAI conventions)

- Task trace (one per user request / work unit).
- Step spans (one per agent / tool / model call).
- Tool metadata (name, inputs redacted or referenced, output size).
- Model metadata (provider, model name, version, token counts, finish reason).
- Decision checkpoints (which branch taken; why).
- Quality signals (score, verdict, error classification).

### Span naming conventions

- Agent invocation: `invoke_agent {gen_ai.agent.name}`
- Tool call: `execute_tool {gen_ai.tool.name}`
- Model call: `generate_content {gen_ai.request.model}`

### Content handling

- **Do NOT put full prompt text in span attributes** (anti-pattern per GenAI conventions).
- **Use span events for content** — allows filtering/dropping at Collector level without touching app code.
- Token counts (prompt/completion/total) go in span attributes.

### Auto-instrumentation

- Packages exist for OpenAI, Anthropic, LangChain, LlamaIndex — wrap API calls in GenAI-convention spans automatically.
- No application code changes.

### Agent evaluation platforms (2026 reference set)

| Platform | Strength |
|---|---|
| **LangSmith** | Native LangGraph integration; trace-first |
| **Maxim AI** | Multi-framework; CI integration |
| **Arize** | ML + LLM unified; large-scale |
| **Langfuse** | Open-source; self-hostable |
| **Galileo** | Rubric + metrics focus |
| **Braintrust** | Agent-eval first class |

### Market context (2026)

- **57% of organizations have agents in production** (LangChain 2026 State of AI Agents).
- **79% of enterprises reporting at least some AI agent adoption** (PwC Agent Survey).
- **32% cite quality as top deployment barrier** (LangChain).
- **85-95% autonomous completion** for well-implemented agents on structured tasks.
- **Cost per task + cost per successful outcome** — emerging canonical metrics.

### Four-dimension evaluation framework

Agent eval spans:

1. **Technical** — operations, reliability, latency, error rate.
2. **Financial** — cost per task, cost per successful outcome, trend.
3. **Safety** — compliance, red-team pass rate, incident rate.
4. **Practical reliability** — end-user experience, task completion, acceptance.

MAD.Council's `metrics/` (iter 12) organizes around this split.

## 15. Multi-agent debate, verdicts, handoffs (for iter 10-11 skills/)

### Multi-agent debate / aggregation

- **6 Multi-Agent Orchestration Patterns for Production (2026)** (beam.ai) — https://beam.ai/agentic-insights/multi-agent-orchestration-patterns-production
- **Multi-Agent Debate for LLM Judges with Adaptive Stability Detection** (arxiv 2510.12697) — https://arxiv.org/html/2510.12697v1
- **Multi-Agent Debate — AutoGen** — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/multi-agent-debate.html
- **Adaptive heterogeneous multi-agent debate** (Springer / King Saud Univ) — https://link.springer.com/article/10.1007/s44443-025-00353-3
- **Courtroom-Style Multi-Agent Debate with Progressive RAG + Role-Switching** (arxiv 2603.28488) — https://arxiv.org/html/2603.28488v1
- **Multi-Agent Debate Frameworks** (emergentmind) — https://www.emergentmind.com/topics/multi-agent-debate-mad-frameworks
- **Multiagent Debate Framework** — https://www.emergentmind.com/topics/multiagent-debate-framework

**Key aggregation mechanisms:**
- **Simple majority voting** accounts for much of the empirical gain historically attributed to debate.
- **Judge agent** ("summarize the debate and give final answer") — works well for simple cases; may bias toward certain phrasing.
- **LLM-as-a-Fuser** — dedicated fuser LLM synthesizes judgments from multiple models with critiques. Enhances calibration.
- **Heterogeneous multi-judge aggregation** — mix rubric-based + LLM-based judges for robustness.
- **Convergence-based stopping** — stop when outputs stabilize across rounds.

### Confidence, abstention, escalation

- **Trust or Escalate: LLM Judges with Confidence-Driven Escalation** (ICLR 2025) — https://proceedings.iclr.cc/paper_files/paper/2025/file/08dabd5345b37fffcbe335bd578b15a0-Paper-Conference.pdf
- **Are LLM Decisions Faithful to Verbal Confidence?** (arxiv 2601.07767) — https://arxiv.org/abs/2601.07767
- **Overconfidence in LLM-as-a-Judge: Diagnosis and Confidence-Driven Solution** (arxiv 2508.06225) — https://arxiv.org/html/2508.06225v2
- **Majority Rules: LLM Ensemble for Content Categorization** (arxiv 2511.15714) — https://arxiv.org/html/2511.15714v1
- **SelectLLM: Calibrating LLMs for Selective Prediction** (OpenReview) — https://openreview.net/forum?id=JJPAy8mvrQ
- **Complementing Self-Consistency with Cross-Model Disagreement** (OpenReview) — https://openreview.net/forum?id=lOoRJo8xWy
- **LLM Calibration: Improving Confidence Estimates** (CallSphere) — https://callsphere.tech/blog/llm-calibration-understanding-improving-model-confidence-estimates

**Key confidence + abstention findings:**
- **Canonical threshold tiers**: autonomous ≥0.85 · with-caveats ≥0.5 · escalate-to-human <0.5.
- **Optimal categorization threshold**: 0.65 (precision/recall/F1 sweet-spot per arxiv 2511.15714).
- **2026 abstention challenge**: frontier models are neither cost-aware nor strategically responsive about abstention; even when extreme penalties make abstention mathematically optimal, **models almost never abstain** (arxiv 2601.07767). Implication for MAD.Council: **ESCALATE verdict cannot rely on self-reported need**; use mechanical triggers (3/3 disagreement + all-low-confidence → auto-ESCALATE).

### Agent governance + human-in-the-loop

- **Human-in-the-Loop: 2026 AI Oversight Guide** (Strata) — https://www.strata.io/blog/agentic-identity/practicing-the-human-in-the-loop/
- **Agentic AI Governance Frameworks 2026** (HackerNoon) — https://hackernoon.com/agentic-ai-governance-frameworks-2026-risks-oversight-and-emerging-standards
- **When AI acts: Compliance challenge of agentic systems** (Compliance Week) — https://www.complianceweek.com/opinion/when-ai-acts-the-compliance-challenge-of-agentic-systems/36496.article
- **Agent Fallback Mechanisms** (Adopt.ai glossary) — https://www.adopt.ai/glossary/agent-fallback-mechanisms

**Key oversight principles:**
- **Bounded autonomy** architecture with clear operational limits + escalation paths for high-stakes decisions + comprehensive audit trails.
- **Decision tempo risk**: "errors are transmitted at a quicker pace; traditional escalation models struggle to keep up."
- **Override + control framework**: logging + version control + validation checks + clear escalation so an accountable human can catch and override outputs.
- **HITL technical enforcement**: authentication + authorization + audit controls bind agent actions to identity policies.

### Session handoff + graceful shutdown

- **OpenAI Agents SDK (March 2025)** — core abstraction is explicit handoff with carried context; replaced experimental Swarm.
- **How Agent Handoffs Work in Multi-Agent Systems** (Towards Data Science) — https://towardsdatascience.com/how-agent-handoffs-work-in-multi-agent-systems/
- **When AI Agents Collide: Multi-Agent Orchestration Failure Playbook for 2026** (Cogent) — https://cogentinfo.com/resources/when-ai-agents-collide-multi-agent-orchestration-failure-playbook-for-2026
- **Multi-Agent Orchestration: The Art of the Handoff** (DEV Community) — https://dev.to/the_bookmaster/multi-agent-orchestration-the-art-of-the-handoff-252a
- **Multi-agent patterns in LlamaIndex** — https://developers.llamaindex.ai/python/framework/understanding/agent/multi_agent/
- **AWS CLI Agent Orchestrator** (GitHub) — https://github.com/awslabs/cli-agent-orchestrator

**Key handoff findings:**
- **"Most agent failures are orchestration and context-transfer issues at handoff points, not model capability failures."**
- **Production persistence**: Redis / PostgreSQL backing store indexed by `conversation_id` for context survival across disconnects.
- **Graceful degradation when models fail** is a production-readiness gap (per 2026 playbooks).
- **Claude Code v2.1.105**: aborts stalled API streams after 5 minutes — impacts long-running Council reviews.

### Blameless retrospective (agent-specific)

- **Blameless retrospective template** (Echometer) — https://echometerapp.com/en/blameless-retrospective-template/
- **Rootly Blameless Postmortems Guide** — https://rootly.com/incident-postmortems/blameless
- **Miro Blameless Postmortem Canvas** — https://miro.com/templates/blameless-postmortem-canvas/
- **Rootly Retrospective Template (downloadable)** — https://rootly.com/resources/rootlys-retrospective-template

**Key retro principles:**
- **Psychological safety** — team members feel secure admitting mistakes.
- **Honest communication** — establishes learning culture.
- **No individual blame** — focus on what enabled the failure, not who triggered.
- **Originated in SRE** (Google, Netflix popularized).
- **Common multi-agent failure mode** for retro capture: "one agent summarizes, another analyzes, another acts — if one misbehaves/stalls/loops, errors cascade; hard to catch infinite loops or circular handoffs."

### Agent-specific eval rubrics

- **Galileo 2026 Agent Evaluation Framework** — https://galileo.ai/blog/agent-evaluation-framework-metrics-rubrics-benchmarks
  - **7 primary dimensions** × **25 sub-dimensions** × **130 fine-grained rubric items**.
  - Evidence-anchored scoring.
  - Post-hoc calibration aligned with human judgment.

### Collaboration-specific metrics (relates to /council-retro)

- **Coefficiency Index** (notch.cx) — https://www.notch.cx/post/customer-service-ai-metrics
  - Measures effectiveness of AI + human collaboration.
  - Strong coefficiency = handoffs preserve context + combined resolution quality > either channel alone.

## 16. Internal (within this repo / machine)

- **Marketplace review CHECKLIST** — `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md` (138 HIGH patterns, 13 industry gaps, grounding source for MAD wiki).
- **MAD.Council spec** — `./mad.council.a2a.md` (sibling of this file, sections 0–14).
- **Agent Channels Spec v1** (historical) — paste from conversation; superseded by mad.council.a2a.md.
- **Project-level CLAUDE.md** — `C:\Users\tonym\Repos\CLAUDE.md` (explicit rule: "YOU MUST NOT use `run_in_background: true` for Task tool agent spawns").

## Citation conventions

When citing a reference in a MAD wiki/rule/skill file:

- External URL: cite the **canonical URL** (first entry for each resource above, typically https://a2a-protocol.org/latest/specification/ style — prefer `latest` over version-pinned unless the version matters).
- External paper: cite arxiv ID + link (e.g., "CourtEval (arxiv 2508.02994)").
- Internal file: cite the relative path (e.g., "`plugins/zen-agents/agents/orchestrator.md`").
- Internal pattern/rule: cite the wiki path (e.g., "`wiki/patterns/orchestrator-worker.md`" or "`rules/prompt-injection-policy.md`").
- Marketplace pattern: cite CHECKLIST pattern number + file (e.g., "CHECKLIST pattern #31" and verify against the file).

### CHECKLIST `#N` reference semantics (CHK-015 clarification)

Throughout the MAD wiki you will see citations like "(CHECKLIST pattern #31)" or "(CHECKLIST cross-cutting #3)." These refer to a marketplace review artifact stored **outside** this repo at `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md` (138 HIGH-confidence patterns catalogued during the 10-iter review that seeded this wiki).

**Stability contract:**

1. **The pattern content in each wiki page is self-contained.** The `#N` ref is a breadcrumb back to the seeding source; it is **not** load-bearing. Removing the CHECKLIST file does not invalidate the wiki — the wiki page still describes the pattern in full.
2. **Numbers may drift** if the CHECKLIST is re-ordered or extended. If a citation stops matching, treat it as a dangling link and either (a) re-grep the CHECKLIST by pattern name to find the new number, or (b) drop the `#N` and keep just the pattern name — that's still verifiable.
3. **Do not add new `CHECKLIST #N` citations** in future wiki edits. Prefer citing the pattern by name + external anchor (e.g., "Evidence Beats Assertion, `plugins/triage-team/agents/`") — stable refs beat line-number refs.
4. **If the CHECKLIST file itself moves or is deleted**, the wiki remains functional; no content rework needed. Only the breadcrumbs become stale, which is low-risk cosmetic drift.

## Link rot policy

This file is updated whenever:

- A cited URL returns 404 during an iteration (replace or remove with note).
- A source is superseded by a newer version (keep both; mark the older as "legacy").
- A new source is first cited (add here, so future files can find it).

**Last link-rot audit:** 2026-04-17 iter 3. All 80+ URLs verified as reachable.
