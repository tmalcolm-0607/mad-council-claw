# Coding Eval Research

Reference document for lightweight, project-focused coding evaluation approaches for AI assistants. Researched February 2026.

## Key Takeaways

- **Start with 20-50 tasks** drawn from real failures (Anthropic). Small samples suffice when effect sizes are large.
- **Recommended grader combo**: Unit tests (primary) + transcript analysis (quality) + static analysis (linting, types, security).
- **Faster code drafts do NOT shorten delivery** unless reviews, CI/CD, and QA keep pace. PR review time ballooned ~91% despite ~21% individual task gains.
- **Focus on outcomes, not paths** -- checking specific agent steps is too rigid and penalizes creative valid solutions.
- **Cost is the primary constraint** for eval frequency. Track cost-per-scenario alongside pass rate.
- **Most industry AI studies measure copilot-style autocomplete**, not autonomous coding agents. Transfer findings cautiously.
- **Error analysis before eval construction** is the highest-ROI activity. Review 50-100 agent transcripts, categorize failures, build evals targeting those failures.
- **Trap evals** (antipattern scaffolds) are the most likely to produce >30% discrimination for convention-adherence testing.

---

## Table of Contents

1. [Frameworks & Tools](#1-frameworks--tools)
2. [Anthropic's Guidance](#2-anthropics-guidance)
3. [Key Metrics](#3-key-metrics)
4. [Industry Data](#4-industry-data)
5. [Improvement Roadmap](#5-improvement-roadmap)
6. [Excluded Approaches and Rationale](#6-excluded-approaches-and-rationale)
7. [Sources](#7-sources)

---

## 1. Frameworks & Tools

### Claude Code CLI

The eval engine. No external framework dependency needed.

- **Execution**: `claude --print --max-turns 40 --output-format json --dangerously-skip-permissions`
- **Assertions**: Bash/PowerShell checks on JSON output -- file existence, content grep, build success, test pass rate
- **Result format**: JSON schema with `assertion_pass_rate` (0-1), `cost_usd`, `total_tokens`, `duration_seconds`

### DeepEval

Open-source Python framework for LLM testing, inspired by pytest.

- **14+ evaluation metrics** (G-Eval, DAG, Answer Relevancy, Faithfulness, Contextual Recall/Precision, Task Completion, Tool Correctness, Hallucination, Summarization, Bias, Toxicity) **plus benchmark integrations** (HumanEval, MMLU, etc.)
- **Custom metrics** automatically integrated with the ecosystem
- **CI/CD integration**: Pytest integration, parallel execution (`-n` flag), cloud logging via Confident AI
- **Self-hosting**: Metrics run locally; uses LLM-as-a-judge and NLP models on-machine
- **Status**: Evaluated, not adopted -- most eval systems handle this natively.

### Promptfoo

Lightweight, flexible, open-source framework with declarative YAML configuration.

- **100% local execution**, works with any LLM API or language
- **Fast**: live reload and caching
- **Assertions**: `contains-json` (structured output), `cost`/`latency` thresholds, `javascript` (custom), `llm-rubric` (semantic evaluation for multi-file tasks)
- **CI/CD**: `--repeat 3` for variance measurement, cost/latency thresholds for regression detection
- **Status**: Evaluated, not adopted. `llm-rubric` concept is a candidate for LLM-as-Judge phase.

### Other Notable Tools

| Tool | Purpose |
|------|---------|
| **Arize Phoenix** | AI Observability & Evaluation (self-hostable) |
| **OpenAI Evals** | Framework with eval registry |
| **Anthropic Bloom** | Agentic framework for behavioral evaluations |
| **Ragas** | RAG pipeline evaluation |
| **Langfuse** | Self-hosted eval with data residency support |
| **Braintrust** | Eval platform with LLM-as-judge, dataset management |
| **SonarQube** | AI Code Assurance -- detects risks in AI-generated code |

---

## 2. Anthropic's Guidance

### Recommended Scale

> "20-50 simple tasks drawn from real failures is a great start."

Early changes have large effect sizes, so small sample sizes suffice.

### Three Grader Types

| Type | Strengths | Weaknesses |
|------|-----------|------------|
| **Code-based** | Fast, cheap, objective, reproducible | Brittle to valid variations |
| **Model-based** | Flexible, scalable, captures nuance | Non-deterministic, needs calibration |
| **Human** | Gold-standard quality | Expensive, slow; reserved for calibration |

Each grader evaluates some portion of either the transcript or the outcome.

### Task Design Principles

- **Unambiguous**: "Two domain experts would independently reach the same pass/fail verdict"
- **Reference solutions**: Each task includes a known working output that passes all graders
- **Balanced**: Test both positive cases (behavior should occur) and negative cases (shouldn't)
- **Clean environments**: Each trial starts isolated to prevent state-related failures
- **Outcome-focused**: "Focus on what the agent produced, not the path it took"
- **Warning**: "A 0% pass rate across many trials is most often a signal of a broken task, not an incapable agent"

### Coding Agent Specifics

> "Software is generally straightforward to evaluate: does the code run and do the tests pass?"

- Deterministic graders are natural for coding agents
- Recommended combination: unit test verification (primary) + transcript analysis (quality) + static analysis (linting, types, security)
- Convert user-reported failures into test cases for practical relevance

---

## 3. Key Metrics

### Pass@k

- Evaluates functional correctness: does at least one of the top k samples pass predefined unit tests?
- **Original HumanEval k values**: [1, 10, 100]; practical evals often use k in {1, 5, 10}
- **Key advantage**: Focuses on functional correctness rather than text similarity

### HumanEval

- A model-agnostic **benchmark** (not a metric) of 164 programming challenges testing language, algorithms, and mathematics
- Generate code from docstrings, must pass specific unit tests

### Convention Adherence

- Evaluates coding style, naming conventions, and design pattern compliance
- **Quality signals**: Cyclomatic complexity, code coverage, duplication rates, convention adherence
- **Human evaluation remains irreplaceable** for idiomatic, secure, maintainable, extensible code

### Cost Efficiency

- **Cost-per-scenario**: Total API cost for one eval scenario run
- **Cost regression threshold**: Alert when cost-per-scenario exceeds 2x the rolling average
- **Cost-per-assertion**: `cost_usd / assertion_count` -- useful for comparing scenario efficiency
- **Industry context**: 53x cost variation observed across 11 LLMs for identical outcomes

### Code Quality Signals (GitClear -- 211M Changed Lines)

| Metric | Finding |
|--------|---------|
| Copy/pasted code | Rose from 8.3% to 12.3% of changed lines (2020-2024) |
| Code clones | **4x growth** in 2024 |
| Copy/paste vs moved code | Copy/paste exceeded "moved" for the first time ever |
| Refactoring | Dropped from **25% (2021) to <10% (2024)** |

### DORA Metrics

- Lead Time to Change, Deployment Frequency, Mean Time to Restore, Change Failure Rate
- "DORA tells you how efficiently your team moves code from commit to deploy"

### SPACE Framework

- **S**atisfaction, **P**erformance, **A**ctivity, **C**ommunication, **E**fficiency
- Complementary to DORA -- captures what DORA misses

---

## 4. Industry Data

> **Important caveat**: Most studies cited below measure **copilot-style autocomplete** (inline suggestions), not autonomous coding agents. Transfer these findings cautiously.

### The Individual vs Company-Level Paradox

Study of 10,000+ developers across 1,255 teams:

**Individual gains:**
- ~21% more tasks completed
- ~98% more pull requests per developer
- ~47% more PRs touched daily

**Company-level bottlenecks:**
- PR review time ballooned by **~91%** (became the new constraint)
- Average PR size increased up to **150%** with modest 9% rise in bug counts
- **NO measurable improvement in company-wide DORA metrics**
- Experienced developers sometimes took **19% longer** with AI in controlled trials

> "Faster code drafts only shorten delivery when reviews, CI/CD, and QA move at the same pace."

### AI Code Assistant Usage Patterns (669 developers)

Code understanding emerged as the primary use case (contrary to expectations):
- 71.9% used for explaining existing code
- 68.5% answering programming questions
- 55.6% generating code snippets
- Only 2-4% used generated code without changes

### Current State of AI in Code

| Metric | Value | Context |
|--------|-------|---------|
| AI-generated code share | **29%** | Up from ~5% in 2022 |
| Company-wide aggregate productivity gain | **3.6%** | Despite individual task-level gains of ~21% |
| Developers using AI tools | **63%** | Stack Overflow 2024 Survey |
| Developers spending more time debugging AI code | **67%** | "Cancels out efficiency gains" |

### Multi-Model Efficiency Variance (11 LLMs, 5 SE Tasks)

Among models with identical perfect scores:
- **22x variation** in completion time
- **49x variation** in tool efficiency
- **53x variation** in estimated cost
- **No correlation** between tool usage count and success (Pearson r=0.077)

---

## 5. Improvement Roadmap

Phased plan for expanding eval systems.

### Roadmap Summary

| Phase | Description | Effort | Definition of Done |
|-------|-------------|--------|-------------------|
| 1 | LLM-as-Judge | Medium | 3 rubrics running with >80% agreement vs manual review |
| 2 | Repository-Level Scenarios | Medium | 2 new scenarios testing cross-file understanding |
| 3 | Automated Test Generation | Large | AI-generated tests for changed functions on each eval PR |
| 4 | BDD Scenario Expansion | Small | Given-When-Then format for 3+ existing scenarios |
| 5 | Static Analysis Integration | Medium | Security scanning in eval pipeline |
| 6 | Human-in-the-Loop Refinement | Ongoing | Golden rubrics refined from LLM drafts for top 10 scenarios |

### Phase 1: LLM-as-Judge for Quality Assessment

- **Why**: Multi-file tasks need semantic evaluation, not string matching
- **Approach**: Use `llm-rubric` style evaluation for architecture/style quality
- **Cost insight**: Research shows smaller models can match larger ones for judging tasks

### Phase 2: Repository-Level Scenario Expansion

- **Benchmarks for reference**: CoreCodeBench, GitTaskBench, RepoBench
- **Key insight**: "Users should develop their own filtering heuristics for personal repositories"

### Phase 3: Automated Test Generation

- **Approach**: Scan diff on every PR, identify changed functions, auto-generate/update test cases
- **Focus**: Target specific code changes rather than entire codebases

### Phase 4: BDD Scenario Expansion

- **Format**: Given-When-Then test scenarios using natural language
- **Value**: Bridges domain language and test specifications

### Phase 5: Static Analysis Integration

- **Focus**: Security/vulnerability scanning -- complementary to existing review infrastructure
- **Testing**: Test prioritization algorithms, self-healing, predictive failures

### Phase 6: Human-in-the-Loop Refinement

> "An LLM can generate a draft rubric for a given bug, which human experts then review and refine into a 'golden' evaluation standard."

---

## 6. Excluded Approaches and Rationale

### External Framework Dependencies

| Skipped | Reason |
|---------|--------|
| Promptfoo/DeepEval as dependencies | Claude CLI + bash assertions system works; adding a dependency adds complexity for marginal benefit |
| SWE-bench/HumanEval-scale benchmarks | Not lightweight or project-specific |

### Methodology Anti-Patterns

| Skipped | Reason |
|---------|--------|
| Checking specific agent steps | "Too rigid" -- penalizes creative valid solutions |
| Individual performance metrics | Encourages metric gaming over outcomes |
| Acceptance rate as primary metric | Misleading -- developers may accept then heavily rewrite |
| Lines of code / raw PR counts | More code does not equal more value |
| Vendor time-saved metrics | Don't account for downstream bottlenecks |
| Repeated identical runs for variance | Early-phase eval with large effect sizes; statistical rigor deferred to Phase 6 |

---

## 7. Sources

### Start Here (Essential Reading)

- [Demystifying Evals for AI Agents | Anthropic](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) -- Core guidance
- [AI Copilot Code Quality 2025 | GitClear](https://www.gitclear.com/ai_assistant_code_quality_2025_research) -- 211M lines analyzed
- [Measuring AI Code Assistants | DX](https://getdx.com/research/measuring-ai-code-assistants-and-agents/) -- Individual vs company paradox
- [Evaluate Coding Agents | Promptfoo](https://www.promptfoo.dev/docs/guides/evaluate-coding-agents/) -- Practical eval guide
- [Comprehensive Evaluation of LLMs on SE Tasks | arXiv](https://arxiv.org/html/2602.07079) -- 53x cost variation study
- [LLM-as-a-Judge Explained | Confident AI](https://www.confident-ai.com/blog/why-llm-as-a-judge-is-the-best-llm-evaluation-method) -- LLM-as-Judge guide
- [Claude Code: Best Practices | Anthropic](https://www.anthropic.com/engineering/claude-code-best-practices) -- Agent workflow evaluability

### Additional Categories

See the full source list for links covering:
- Evaluation Frameworks & Tools (DeepEval, Promptfoo, Phoenix, OpenAI Evals)
- Anthropic Research & Guidance (Bloom, alignment evaluations)
- Code Quality & Metrics Research (HumanEval, pass@k, GitClear)
- Productivity & ROI Studies (DX, GitLab, AWS perspectives)
- DORA & SPACE Metrics (developer productivity frameworks)
- LLM Evaluation Methods (benchmarks, criteria matrices)
- LLM-as-Judge (calibration, rubric design)
- Code Review & Standards (compliance, enforcement)
- Behavioral Testing (BDD, TDD with AI)
- Diff Coverage & Test Generation (Diffblue, Qodo)
- Repository-Level Benchmarks (CoreCodeBench, RepoBench)
- CI/CD & Automation (pipeline integration)
- Static Analysis & Linting (SonarQube, AI-powered linters)
