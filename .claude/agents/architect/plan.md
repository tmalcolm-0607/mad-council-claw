# Implementation Plan: Architect agent

Target: MAD.Council Phase 2 Council Layer. Required by `/council-review`.

## Deliverables

1. `agent.md` ✅ (this iter).
2. `scripts/role-prompts/architect.prompt.md` (future) — the prompt template.
3. Pester tests + schema validator.
4. Golden fixtures.

## Implementation steps

### 1. Prompt engineering

Components:

- **Role mindset** (§Mindset) — verbatim.
- **Input contract** explanation.
- **Output contract** — strict JSON with `trade_off` field required per finding.
- **Big-picture checklist** — coupling, duplication, consistency, premature abstraction, single-source-of-truth, direction, boundaries. Prompt explicitly demonstrates what each looks like.
- **Core-vs-others boundary** — guidance on when to defer to Skeptic/Advocate rather than duplicate coverage.
- **Evidence standard** — cross-site patterns, not single-site; 2+ references per finding.
- **Severity rubric + Architect skew toward MEDIUM.**
- **Anti-patterns** — no editorializing, no style, no single-site flags.
- **5-shot examples**:
  - Clean work with 0-1 Architect findings + high role_confidence.
  - Duplication finding citing 3 sites.
  - Premature abstraction (new interface, 1 caller).
  - Consistency drift (error handling varies across 4 message types).
  - Direction finding — work is locally correct but pushes long-term complexity higher.

### 2. Schema validator

At `evals/fixtures/shared/schemas/architect-output.json`:

- Required: role="Architect", role_confidence, findings[].
- Each finding: id, severity, category (enum from the 6 categories above), evidence, title, description, confidence, `trade_off`.
- Optional: annotations, evidence_incomplete.

### 3. Golden fixtures

Under `evals/fixtures/shared/council-review/golden-architect/`:

- `clean-thread-architect-output.json` — simple work; 0-1 findings; high role_confidence.
- `duplication-thread-architect-output.json` — HIGH finding citing 3 duplicated sites.
- `premature-abstraction-thread-architect-output.json` — MEDIUM finding on 1-caller abstraction.
- `direction-misaligned-thread-architect-output.json` — MEDIUM finding on long-term trajectory.
- `injection-in-thread-architect-output.json` — thread content tries to override mindset; Architect continues analysis.

### 4. Tests

At `evals/fixtures/agents/architect/`:

- **T1 unit**: schema validation (including trade_off required).
- **T1 unit**: category enum validation.
- **T2 integration**: invoke Claude Opus with prompt + fixture; structural match.
- **T4 adversarial**: thread with "ignore systems-level concerns" injection → rejected.
- **T4 adversarial**: thread pushes Architect to find single-site bugs → Architect stays in-role (big picture), notes briefly that single-site bug is Skeptic's territory.
- **T4**: boundary test with a thread that's ambiguously Skeptic-vs-Architect (race condition that's also systemic) — Architect flags the systemic aspect; Skeptic flags the single-site aspect; both contributions valid.

### 5. Metrics

- `invoke_agent architect` span with duration, tokens, role_confidence, finding_count.
- `agent.architect.findings_by_category` histogram (coupling / duplication / etc.).
- `agent.architect.findings_by_severity` — tracks the MEDIUM-skew hypothesis.
- `agent.architect.cross_site_citations_per_finding` — measures "evidence beats assertion" compliance.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| Claude Opus 4.7 | Claude Code host | ✅ |
| `rules/minimum-change.md` (3-callers rule) | rules/ | ✅ |
| `wiki/patterns/scope-discipline.md` | wiki/ | ✅ |
| `wiki/patterns/multi-role-review.md` | wiki/ | ✅ |

## Estimated effort

| Step | Hours |
|---|---|
| architect.prompt.md (5-shot examples) | 8 |
| Schema + validator | 2 |
| Golden fixtures | 4 |
| Tests | 5 |
| Prompt-tuning | 6 |
| **Total** | **~25 hours (~3 working days)** |

Same effort as Advocate; simpler than Skeptic (no ensemble mode).

## Risks

| Risk | Mitigation |
|---|---|
| Architect overreaches into Skeptic territory (single-site bugs) | Core-vs-others boundary section in prompt; tests verify Architect stays in big-picture lane |
| Architect under-reports because "nothing at systems level to flag" | Low role_confidence + 0 findings is a valid outcome; don't force findings |
| Duplication-flag noise on minor repetition | Require 2+ citations minimum; 3+ for HIGH severity |
| "Direction" findings become editorializing | Require concrete trade_off field with both sides (what's enabled + what's introduced) |
| Model refuses to find systems-level issues ("I don't have enough context") | Tune with 5-shot examples that show Architect working with limited context and reporting evidence_incomplete=true |

## Design decisions

- **Why fewer findings (8-10) vs Skeptic's 10-12**: Architect findings are typically broader, slower-to-compose, higher-stakes. Volume isn't the goal.
- **Why `trade_off` is required**: prevents "this is bad" reactions without accompanying systems-level analysis. Forces the role to think through both sides.
- **Why MEDIUM-skew is expected**: direction issues are real but rarely immediately-breaking. CRITICAL from Architect would need to be "this architecture is fundamentally broken" — rare, and usually escalates to a bigger conversation.

## Forward-links

- `evals/fixtures/agents/architect/` — tests.
- `evals/fixtures/shared/council-review/golden-architect/` — golden outputs.
- `scripts/role-prompts/architect.prompt.md` — prompt.
- `skills/council-review/tests.md` — parent integration.
