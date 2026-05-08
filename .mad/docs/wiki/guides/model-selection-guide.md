# Model Selection Guide

Reference material for model selection decisions. Moved from `.claude/rules/model-selection.md` to reduce universal rule context size. The quick reference and agent mappings remain in the rule file.

---

## Decision Guide

| Question | If YES |
|----------|--------|
| Requires judgment/analysis? | Opus |
| Following established patterns? | Sonnet |
| Mechanical/rule-based? | Haiku |
| High stakes/security? | Opus |
| High volume/batch? | Haiku |

---

## Model Selection Rationale

### Per-Agent Rationale

| Agent | Model | Rationale |
|-------|-------|-----------|
| **Core Workflow** | | |
| code-investigator | Opus | Complex code analysis requires deep reasoning to understand patterns, trace execution flows, and document findings with precision. Must synthesize information from multiple files. |
| code-implementer | Opus | TDD implementation demands architectural judgment, understanding of testing patterns, and ability to write idiomatic code. Quality over speed. |
| code-reviewer | Opus | Thorough review requires nuanced analysis of code quality, security implications, and maintainability. Catches subtle issues that simpler models miss. |
| feature-verifier | Opus | Structural verification needs careful reasoning to interpret test results in context and distinguish real failures from acceptable outcomes. |
| work-planner | Opus | Planning requires understanding complex requirements, breaking them into tasks, and identifying dependencies. Poor planning compounds downstream. |
| **Research Pipeline** | | |
| research-scout | Sonnet | Breadth-first discovery prioritizes coverage over depth. Cost-effective for gathering many sources before curation. |
| research-curator | Opus | Truth-gating requires careful judgment to assess claim validity, assign confidence levels, and filter weak evidence. |
| research-reviewer | Opus | Adversarial analysis needs deep reasoning to identify hidden assumptions, propose safeguards, and challenge conclusions. |
| parallel-researcher | Opus | Runs curator and reviewer logic internally — requires deep reasoning to validate claims and challenge own findings within a single agent. |
| pattern-discoverer | Opus | Extract reusable patterns from code requires deep analysis to identify abstractions, trace implementation patterns, and document architectural decisions. |
| pr-pattern-miner | Opus | Mining patterns from PR diffs requires nuanced analysis to distinguish intentional patterns from one-off changes and document evolution rationale. |
| domain-reviewer | Opus | Multi-domain review requires nuanced judgment to classify severity, identify cross-cutting concerns, and challenge other reviewers' findings. |
| **Adversarial Review** | | |
| advocate | Opus | Defense requires nuanced judgment to distinguish intentional design from genuine flaws, trace trust boundaries, and articulate trade-offs with evidence. |
| architect | Opus | Architectural evaluation requires broad reasoning to assess system-wide impact, pattern fitness, coupling trajectories, and scope-vs-correctness trade-offs. |
| skeptic | Opus | Attack-mindset review requires deep reasoning to trace data flow across function boundaries, identify subtle failure modes, and distinguish real bugs from false positives. |
| **Composite Agents** | | |
| investigate-and-implement | Opus | Orchestrates investigation and implementation loop internally, requires full Opus capability to maintain quality across multi-step workflow. |
| review-and-fix | Opus | Orchestrates review and automated fix cycle, requires Opus-level judgment to distinguish real issues from noise and apply appropriate fixes. |
| coverage-loop | Opus | Iterative coverage gap closure requires deep reasoning to identify meaningful gaps, prioritize test cases, and verify comprehensive coverage. |
| **Code Quality** | | |
| security-auditor | Sonnet | Security scanning follows established patterns (OWASP). Sonnet handles pattern matching well at lower cost. |
| performance-analyzer | Sonnet | Performance analysis uses metrics and heuristics. Deep reasoning less critical than systematic checking. |
| accessibility-checker | Sonnet | WCAG compliance follows rules-based checking. Sonnet handles checklist validation efficiently. |
| test-runner | Sonnet | Test execution and result interpretation are systematic. Does not require complex reasoning. |
| test-selector | Sonnet | Test tier selection based on git diff analysis follows heuristic rules. Sonnet handles file mapping and impact analysis efficiently. |
| debugger | Sonnet | Step-through debugging is methodical. Sonnet handles trace analysis adequately. |
| **Specialized** | | |
| api-designer | Sonnet | API design follows REST/OpenAPI conventions. Sonnet handles standard patterns well. |
| error-handler | Sonnet | Error taxonomy and handling follows established patterns. Systematic rather than creative. |
| refactoring-specialist | Sonnet | Refactoring follows established patterns (Extract Method, etc.). Pattern application over invention. |
| **Language Experts** | | |
| lang-typescript-expert | Sonnet | TypeScript patterns and React integration follow established conventions. Sonnet handles type system and framework patterns efficiently. |
| **Utility** | | |
| janitor | Haiku | Simple cleanup tasks (delete old files, archive logs). Minimal reasoning, maximum cost efficiency. |
| git-workflow | Sonnet | Git operations follow conventions. Branch/merge strategies are rule-based. |

---

## Selection Criteria Matrix

Use this matrix to select models for new agents:

| Criterion | Haiku | Sonnet | Opus |
|-----------|-------|--------|------|
| **Reasoning Depth** | Shallow | Moderate | Deep |
| **Pattern Matching** | Basic | Strong | Excellent |
| **Creative Problem Solving** | Limited | Good | Excellent |
| **Multi-file Analysis** | Poor | Good | Excellent |
| **Nuanced Judgment** | Limited | Moderate | Excellent |
| **Cost Efficiency** | Highest | Good | Lowest |
| **Speed** | Fastest | Fast | Slowest |

### When to Use Each Model

**Haiku** (cost: ~$0.0005/1K tokens):
- Simple, repetitive tasks
- File cleanup, formatting
- Basic validation
- High-volume, low-stakes operations

**Sonnet** (cost: ~$0.006/1K tokens):
- Pattern-based analysis
- Following established conventions
- Systematic checking
- Balanced cost/capability

**Opus** (cost: ~$0.03/1K tokens):
- Complex reasoning
- Architectural decisions
- Quality-critical paths
- Multi-file synthesis
- Judgment calls

---

## Cost/Quality Tradeoffs

### Total Cost by Model Mix

| Scenario | Model Mix | Est. Cost (100K tokens) |
|----------|-----------|-------------------------|
| All Opus | 100% Opus | $3.00 |
| Balanced | 20% Opus, 60% Sonnet, 20% Haiku | $0.73 |
| Cost-optimized | 10% Opus, 40% Sonnet, 50% Haiku | $0.37 |

### Recommended Strategy

1. **Critical Path** -> Opus
   - Planning, implementation, review, verification
   - Errors here multiply downstream

2. **Supporting Tasks** -> Sonnet
   - Research scouting, specialized analysis
   - Quality matters but stakes are lower

3. **Maintenance** -> Haiku
   - Cleanup, simple validation
   - Volume over precision

### Upgrade/Downgrade Guidelines

| Upgrade to Opus if... | Downgrade to Haiku if... |
|-----------------------|--------------------------|
| Task involves security | Task is purely mechanical |
| Multiple files interact | Single file, simple change |
| Architectural impact | No business logic |
| User-facing quality | Internal/temporary |
