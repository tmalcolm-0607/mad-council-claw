# MAD.Council Evaluations

The test harness for MAD.Council. Organized as a **6-layer stack** per the canonical pattern from `atlan.com/know/how-to-test-ai-agent-harness/` (iter-6 research, `wiki/references.md` §13):

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 5 — CI Gate                                            │
│   CI/CD merges block on eval score; continuous monitoring.   │
├──────────────────────────────────────────────────────────────┤
│ Layer 4 — Adversarial / Red Team                             │
│   Jailbreak, prompt injection, spoofing, spoofing, DoS.     │
├──────────────────────────────────────────────────────────────┤
│ Layer 3 — End-to-End + Fault Injection                       │
│   Realistic multi-agent scenarios; kill-process / disk-fill. │
├──────────────────────────────────────────────────────────────┤
│ Layer 2 — Integration                                        │
│   Multi-step workflows; skill-to-skill flow; context retention│
├──────────────────────────────────────────────────────────────┤
│ Layer 1 — Unit                                               │
│   Individual function tests; deterministic assertions.       │
├──────────────────────────────────────────────────────────────┤
│ Layer 0 — Data Source Certification                          │
│   Every fixture input, every external dependency, verified.  │
└──────────────────────────────────────────────────────────────┘
```

Every skill's `tests.md` already enumerates its fixtures + test matrix across these 5 upper layers. This folder materializes the harness + fixture structure.

## Directory layout

```
MAD/evals/
  README.md                           ← this file
  layer-0-data-sources.md             ← fixture + dependency certification plan
  layer-1-unit.md                     ← unit test index + runner
  layer-2-integration.md              ← integration test index + runner
  layer-3-e2e-fault-injection.md      ← E2E + fault injection scenarios
  layer-4-adversarial.md              ← adversarial test library + regression lock
  layer-5-ci-gate.md                  ← CI/CD gate configuration + thresholds
  fixtures/                           ← all fixture files (per-skill subdirs)
    README.md                         ← fixture naming convention + inventory
    council-open/                     ← from skills/council-open/tests.md
    council-join/
    council-post/
    council-check/
    council-leave/
    council-list/
    council-review/
    council-verdict/
    council-resolve/
    council-retro/
    scripts/                          ← fixtures for scripts/*.ps1 tests
    shared/                           ← cross-skill shared fixtures (e.g., spoofing scenarios)
```

## Conventions

### Test framework

- **PowerShell**: Pester 5.x (for `scripts/*.ps1`).
- **Shell integration**: bash/pwsh harnesses for end-to-end tests.
- **Assertion style**: explicit `Should -Be` (Pester) or `assert_eq` (if we add a shell-native framework).
- **Fixture-based**: each test case references a fixture dir under `fixtures/` rather than inlining setup.

### Test case naming

`<layer>-<skill>-<scenario>.test.md` (or `.Tests.ps1` for Pester).

Example:
- `layer-1-council-post-parse-args.Tests.ps1`
- `layer-2-council-post-happy-path.test.md`
- `layer-4-council-post-session-hijack.test.md`

### Test case structure (per-file)

```markdown
# Test: <layer>-<skill>-<scenario>

**Layer:** <0-5>
**Skill:** <name>
**Fixture:** `fixtures/<skill>/<fixture-name>/`
**References:**
  - Skill tests.md row: T<layer>-<N>
  - Related patterns: `wiki/patterns/...`

## Setup

[steps to prepare the fixture]

## Execute

[exact invocation under test]

## Expect

[expected outcome — rc code, artifact state, output]

## Cleanup

[reset state for next test]

## Metrics emitted

[what OpenTelemetry spans should be recorded]
```

## Quality thresholds

Per `mad.council.a2a.md` §13.5 + iter-6 industry research:

- **Branch coverage**: ≥95% per skill (matches test-sentinel 95% critical-system threshold).
- **Return-code coverage**: 100% — every declared rc code has ≥1 test that reaches it.
- **Adversarial regression**: 100% — every Layer-4 test is permanent locked fixture.
- **Layer-3 fault injection**: ≥3 scenarios per skill that touches mutable state.
- **Perf budget**: each skill's 99th-percentile latency within documented target (see per-skill tests.md).

## Running the full suite

(Scaffolding — actual runner scripts belong in iter-15 metrics/ or a future devops pass.)

```
# Run all layers, all skills:
./run-evals.ps1 -All

# Run one layer:
./run-evals.ps1 -Layer 2

# Run one skill:
./run-evals.ps1 -Skill council-post

# Run with verbose reports:
./run-evals.ps1 -All -Verbose
```

## Test data conventions

All fixture data is UTF-8 text. No binary blobs. No secrets. No PII.

- Fixture JSON files go in `fixtures/<skill>/<scenario>/`.
- Mock tools (e.g., `mock-croncreate.ps1`) go in the same fixture dir as the scenario they serve.
- Fixtures are version-controlled and diff-able.

## Relation to `wiki/` + `rules/`

- Every test that exercises a security rule (Prompt-Injection Policy, Dangerous Ops, etc.) lives in Layer 4.
- Every test that exercises a `wiki/patterns/*` pattern cites the pattern file in its test-case markdown.
- Every skill's Completion Report is validated by a Layer-2 integration test.

### LLM-as-judge bias mitigation (when using model-graded assertions)

Several eval layers (notably Layer 4 adversarial and Layer 5 quality-scoring) use an LLM as a judge — scoring a finding's severity, comparing two outputs, or grading open-ended quality. Known biases (iter-6 research, `wiki/references.md §13`):

1. **Narrow scale with behavioral anchors.** Use 3–5 point scales with explicit anchor text per level ("1 = fabricated citation; 3 = real file but wrong line; 5 = exact file:line match"). Wider scales produce compressed distributions; unanchored scales produce drift.
2. **Randomize option order in pairwise comparisons.** Models exhibit positional bias favoring the first option presented; shuffling defeats it.
3. **Watch for verbosity and stylistic biases.** Longer / more formal / more hedged responses score higher even when content is weaker. Mitigate by including "score only on content; ignore length and formality" in the judge prompt; spot-check via length-controlled pairs.
4. **Use Cohen's Kappa or Krippendorff's Alpha for inter-judge reliability.** When two models disagree, raw agreement rate overstates reliability. Cohen's κ for two judges, Krippendorff's α for three or more; report both the score and the κ/α.
5. **Judge ≠ arbiter of truth.** Judge scores are signals, not ground truth. For every judged dimension there must be at least one human-spot-check rubric + a small ground-truth gold set to detect judge drift over time.

When a judge is used, the `eval/<test>.md` file must declare: (a) the model used, (b) the prompt version, (c) the scale + anchors, (d) the κ/α target, and (e) the ground-truth gold-set reference.

### `[UNVERIFIED]` tag handling

`rules/verification-protocol.md` permits skills and plans to emit `[UNVERIFIED: claim]` markers when a fact can't be grounded at write time. The evaluation harness treats these as **non-blocking but notable**:

- Layer 1-3 pass as long as functional assertions hold; `[UNVERIFIED]` markers in fixture prose do not fail the run.
- Layer 5 CI emits a **count** of `[UNVERIFIED]` markers per run to the `mad_council.unverified_claims_total` counter (see `metrics/safety-metrics.md`).
- Counts drifting upward over time is a signal that research/grounding discipline is decaying; the trend is watched on a weekly cadence.
- Layer 4 (adversarial) explicitly rejects `[UNVERIFIED]` markers inside Council verdict evidence fields — verdicts must cite grounded `file:line` evidence or demote to OBSERVATION (see `wiki/patterns/evidence-beats-assertion.md`).

## Status

(Iter 14 scaffold — test plans populated, fixtures not yet populated.)

| Layer | Plan status | Fixtures populated |
|---|---|---|
| Layer 0 | ✅ (this iter) | ⏸ |
| Layer 1 | ✅ (this iter) | ⏸ |
| Layer 2 | ✅ (this iter) | ⏸ |
| Layer 3 | ✅ (this iter) | ⏸ |
| Layer 4 | ✅ (this iter) | ⏸ |
| Layer 5 | ✅ (this iter) | ⏸ |

Fixture population happens during Phase 1 implementation of each skill.

## References

- `wiki/references.md` §13 — eval framework research.
- `wiki/references.md` §14 — observability (OpenTelemetry GenAI conventions for test metrics).
- Each skill's `tests.md` — the matrix this folder materializes.
- `scripts/README.md` — shared helpers that tests exercise.
