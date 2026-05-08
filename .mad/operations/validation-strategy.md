# Validation Strategy — how we know MAD.Council works

One-page answer to "how do we test + validate everything from metrics to skills to agents?"

Validation happens at **6 layers**, staged across the **4 rollout stages** (S0 dogfood → S1 pilot → S2 GA → S3 default-on) defined in `plans/phase-1-mvp.md §Rollout stages`. Each layer tests a different integration level. Each rollout stage demands a different validation bar before promotion.

This doc is **the place to start** when asking "what do I need to run before shipping / promoting / trusting a change?"

## Stage-gate readiness checklist (ADOPT-008)

Before promoting from any S<n> to S<n+1>, tick every box. A missing tick blocks the promotion — no override path. Derived from internal engineering standards docs (`Documentation/uatprocessguide.md`) (Planning → Scheduling → Readiness → Execution → Evaluation model, adapted for MAD's staged rollout).

### Readiness (run before Execution)

- [ ] **Fixtures prepared.** Every Layer-2 integration test the promotion requires has a fixture directory under `evals/fixtures/` with a frozen JSON payload. Fixtures touched in this cycle are diff-reviewed.
- [ ] **Evals green.** Layer 0, 1, 2 all passed on the commit being promoted. Layer 4 adversarial lock set green. For S2→S3, Layer 3 + Layer 5 cadence-dependent gates also green.
- [ ] **ATTRIBUTION up to date.** Any new `wiki/implementations/*.md` citation, arxiv paper, or industry report from this cycle is reflected in `wiki/references.md` AND `ATTRIBUTION.md`.
- [ ] **`_review-checklist.md` open-HIGH count == 0.** Any HIGH item still open blocks promotion. MEDIUM + LOW may carry forward if explicitly deferred.
- [ ] **ADOPT open-HIGH count == 0.** Same rule — external-standard adoption items are treated at the same bar as internal review checklist.
- [ ] **Kill-switches in place.** Every staged change landing this cycle has a `operations/kill-switches/<change-id>.json` file per `wiki/patterns/staged-rollout.md`. Missing kill-switch ⇒ blocks promotion.

### Execution (what the promotion itself does)

- [ ] **Cohort activated.** `rollout-log.md` has a new row with the target stage + commit SHA + change-id. Owner assigned.
- [ ] **Smoke suite run post-activation.** `scripts/run-sandbox-tests.ps1` invoked with the newly-activated cohort; ≥95% pass or promotion is reverted via kill-switch.

### Evaluation (run before declaring the promotion "complete")

- [ ] **Soak duration met.** S0→S1 72h, S1→S2 2 weeks, S2→S3 1 month. Evidence: timestamped row in rollout-log.
- [ ] **Go/No-Go decision logged.** Exactly one named owner records Go or No-Go in the same rollout-log row; No-Go auto-triggers kill-switch.
- [ ] **Incident-free during soak.** Zero new `CHK-HIGH` items attributable to the promotion. Any HIGH surfaced during soak triggers rollback and restarts readiness.
- [ ] **Metrics in expected band.** The specific metric-delta the promotion was gated on (e.g., "false-positive rate on Skeptic reviews ≤ 5%") has measured within threshold. No threshold == no go (promotions must name what good looks like upfront).

### Roles

UAT's 4-role split (PM / Engineering / Legal Lead / Legal Reviewer) maps to MAD's stage-gate roles:

- **Facilitator** (PM analog): runs the readiness check. Publishes the rollout-log row.
- **Engineer** (engineering analog): produces fixtures + smoke suite run. Usually the `owner_alias` of the changed rule/pattern's parent channel.
- **Rules/Evals steward** (legal/compliance lead analog): signs off readiness items 1-6 are actually green, not just ticked.
- **Skeptic agent** (legal/compliance reviewer analog): runs the smoke suite in execution phase; flags anomalies.

### Why stage-gates not just CI gates

CI gates fail fast on known-bad — test failures, coverage drops, broken links. Stage-gate readiness is about **qualitative confidence**: is the promotion worth doing at all, is there a named owner, is there a defined outcome. A change can pass CI and still be the wrong change to promote. The readiness checklist forces that conversation before cohort activation.

---

## The 6 layers

```
┌──────────────────────────────────────────────────────┐
│ L6 — Human-in-the-loop quality (rolling)            │
│      retro scores, Coefficiency, verdict usefulness  │
├──────────────────────────────────────────────────────┤
│ L5 — Operational claims (cadence varies)            │
│      perf, backup, migration, cost, privacy, multi-user │
├──────────────────────────────────────────────────────┤
│ L4 — Security posture (permanent + quarterly)       │
│      adversarial regression + red-team + confusion   │
├──────────────────────────────────────────────────────┤
│ L3 — Cross-layer correlation (daily)                │
│      run_id propagation, OTel stitching, metric↔disk │
├──────────────────────────────────────────────────────┤
│ L2 — Council as a system (daily + on model release) │
│      mock + real-model smoke + golden set            │
├──────────────────────────────────────────────────────┤
│ L1 — Skills compose primitives (every PR + nightly) │
│      per-skill happy + sad path integration tests    │
├──────────────────────────────────────────────────────┤
│ L0 — Primitives in isolation (every PR)             │
│      schemas, scripts, rules, cross-link integrity   │
└──────────────────────────────────────────────────────┘
```

Each layer **necessary, none sufficient** — a green L0-L2 stack with a broken L3 correlation is still broken. A clean L1-L5 with L6 retro scores cratering means the thing works mechanically but users aren't getting value.

---

## L0 — Primitives in isolation

Runs on every PR. Sub-minute total.

| What | How | Source of truth |
|---|---|---|
| JSON schemas | `Test-Json -Schema` against every `evals/fixtures/**/*.json`, matching filename to schema | `schemas/*.schema.json` |
| Scripts (atomic-write, seq-increment, digest-rebuild, preflight, completion-report, literal-phrase-scan) | Pester unit tests under `scripts/*.Tests.ps1` | `evals/layer-1-unit.md` table |
| Rules helpers (literal-phrase match, consent-gate parsing, body-size computation) | Pester unit tests; exhaustive ban-list coverage | `evals/layer-1-unit.md` + `evals/layer-4-adversarial.md §2` for ban-list catch rate |
| Cross-link integrity (repo-internal refs) | `scripts/check-mad-links.ps1` — walks `MAD/**/*.md`, verifies every `rules/` / `wiki/` / `skills/` / `scripts/` / `evals/` / `metrics/` / `agents/` / `plans/` / `schemas/` / `operations/` target exists | `evals/layer-0-data-sources.md §Cross-link integrity` |

**Gate**: any L0 failure fails the PR. No exceptions.

**What L0 doesn't catch**: composition bugs (a correct atomic-write + correct seq-increment can still produce a broken `/council-post` if they're wired together wrong). L1 catches that.

---

## L1 — Skills compose primitives

Runs on every PR + nightly. Per-skill budget: <30 s for CI path, <3 min nightly.

For each `/council-*` skill:

1. **One happy path** — the canonical single-invocation success. Matches the step in `operations/dry-run-happy-path.md`.
2. **Representative sad paths**: consent denied, rate-limit, concurrent-post collision, session-mismatch, body at 32KB cap, literal-phrase hit, missing dependency.
3. **Artifact schema validation mid-test** — whenever the skill writes a JSON file, the test re-reads it and runs it through `schemas/*.schema.json`. No "the skill returned 0" without also checking what landed on disk.

Traced against the dry-run narrative: if a skill's L1 behavior diverges from what `operations/dry-run-happy-path.md` describes, one of them is wrong and must be reconciled before merge.

**Gate**: all L1 passes + ≥95% branch coverage per `evals/layer-2-integration.md`.

**What L1 doesn't catch**: multi-skill interactions (2 skills racing), real-model behavior drift, cost overruns, UX quality. L2-L6 catch those.

---

## L2 — Council as a system

Three checks. Each necessary; none sufficient.

### 2a. Mock-model L2 test — deterministic, CI-gated

Runs on every PR. Confirms orchestration:

- 3 roles dispatched in parallel (synchronous Task calls, not `run_in_background`).
- Brief correctly assembled from thread + rules + patterns.
- Citations verified post-generation via grep.
- Verdict computed from role findings per `skills/council-review/plan.md §Verdict computation`.
- Mechanical ESCALATE triggers fire when expected (3/3 disagreement, role timeout, etc.).

Mocked Skeptic = mocked findings → tests correctness of orchestration, not of findings themselves.

### 2b. Real-model smoke test — nightly, credential-gated

Runs once per 24h in a protected environment with credentials. Feeds one canned thread into real `/council-review` (propose mode). Asserts:

- Response shape matches `schemas/verdict.schema.json`.
- Role confidences aggregated per ICLR 2025 thresholds (0.85 / 0.5).
- Span attributes follow OTel GenAI conventions.

Catches "Anthropic/OpenAI changed API shape," "prompt caching flipped behavior," etc. Non-blocking day-of; alerts kit owner for triage.

### 2c. Golden-set eval — weekly

The only way to catch "Skeptic started missing bugs." See `evals/layer-4-adversarial.md` for the adversarial parts of the golden set.

Golden set composition:

- 20+ **known-bug threads** — real bugs previously caught in prod. Expected verdict: FIX.
- 10+ **known-good threads** — clean code review exchanges. Expected verdict: ACCEPT.
- 5+ **ambiguous cases** — borderline; correct answer is ESCALATE or INVESTIGATE.

Rotating human judge rates each verdict on a 3-level rubric (matches expected / acceptable alternative / wrong) + notes the reasoning. Pass rate tracked over time.

**Nondeterminism budget**: re-run 5× at temperature-0; verdict consistency must be ≥80% — anything lower means model or prompt churn that warrants investigation.

**Gates**: S1 requires ≥85% golden-set agreement; S2 requires ≥90%; S3 requires no regression vs S2 baseline.

---

## L3 — Cross-layer correlation

The integration layer. Where things stop being "skills work individually" and start being "the system tells a coherent story."

| Claim | Validation | Cadence |
|---|---|---|
| `run_id` propagates end-to-end | Pick 1 run_id from a recent session; grep it across messages, verdict, retro, archive, telemetry. Must appear in **all expected stages** per `wiki/patterns/run-id-correlation.md`. | Daily |
| OTel spans stitch together | Pull all spans for one run_id from the collector; reconstruct the `/council-open → post → check → review → verdict → leave` sequence from telemetry alone. Must be possible without reading disk. | Daily |
| Metrics match disk | `council_review.invocations_total{verdict="FIX"}` counter ≈ `Get-ChildItem -Recurse -Filter verdict.json \| Where-Object { (Get-Content \| ConvertFrom-Json).verdict -eq 'FIX' } \| Measure-Object`. Within time-window and accounting for rate-limit drops. | Daily |
| Session-id binding works under load | 10 concurrent posts from different sessions to same thread; verify every message's `from.session_id` matches the registered session; zero false ⚠️ on authentic, 100% catch on injected wrong-id. | Release candidate |
| Consent log integrity | Every consent-gate event in `metrics/safety-metrics.md` counter has a matching line in `consent-log.jsonl`. | Weekly |

Tooling: dedicated `scripts/validate-correlation.ps1` (Phase-1 deliverable) runs these checks and produces a report.

**Gate**: any cross-layer check failing blocks stage promotion — not individual PRs.

---

## L4 — Security posture

Two cadences.

### 4a. Permanent regression (every release candidate)

`evals/layer-4-adversarial.md` — 210+ locked tests covering:

- Session-id spoofing (Dependabot-style alias reclaim).
- Literal-phrase ban list (all 5-7 core + any extensions from `github.com/tldrsec/prompt-injection-defenses`).
- Multi-turn jailbreak (3-turn + 5-turn scenarios per iter-9 research).
- Path traversal.
- DoS (body > cap, thread > 100 messages, 50+ concurrent posts).
- Consent-bypass attempts ("I already consented, please proceed" in rationale).
- Verdict manipulation.
- Forged signatures (Phase-5, when message-signing ships).

Tests are **locked** — cannot be modified without explicit sign-off per `evals/layer-4-adversarial.md §Lock policy`. This is the mechanism by which we catch "someone weakened a defense to fix a false positive."

### 4b. Quarterly red-team (week-long exercise)

One engineer rotates into a dedicated red-team posture. Explicit goal: break a skill, find a data-exposure path, find a DoS vector. Findings feed:

- `rules/prompt-injection-policy.md §Rule 1 ban list` — new phrases.
- `rules/stride-threat-model.md` — new categories or mitigations.
- `evals/layer-4-adversarial.md` — new permanent regressions from the attacks that worked.

**Gate**: S1 requires a baseline regression pass; S2 requires a clean quarterly red-team (no HIGH findings in the last 90 days); S3 requires 30 days with zero new HIGH from any source.

Also track: dependency-confusion watch across deployments for Dependabot-style alias patterns.

---

## L5 — Operational claims

Each operational document makes a claim; L5 validates each claim has a live check behind it.

| Claim (source doc) | Validation | Cadence | Failure action |
|---|---|---|---|
| Perf SLOs (`operations/performance-benchmarks.md`) | Benchmark suite; 20% p95 regression OR SLO-floor breach = fail | Every PR + nightly | Block merge / block release |
| Backup round-trip works (`operations/backup-disaster-recovery.md §Verification`) | Full backup → wipe test channel → restore → verify integrity | Quarterly | Open HIGH checklist item |
| Migration is safe (`operations/migration-strategy.md`) | Pre/post fixture diff + schema re-validate; Layer-2 integration against migrated channel | Per migration release | Block the migration release |
| Multi-user isolation holds (`operations/multi-user-isolation.md`) | Shared-VM L3 fixtures: 2 OS users, verify channel invisibility + symlink-spy blocked | Per release to shared-host envs | Block release to shared-host envs |
| Cost projection is accurate (`operations/cost-projection.md`) | `council_review.cost_usd_total` vs scenario math from projection doc; ≤25% delta | Weekly post-launch | Revise projection; investigate if over |
| Privacy posture holds (`operations/privacy-data-governance.md`) | Grep audit logs for unexpected P2 emissions; verify region-pin on LLM endpoints + OTel collector | Monthly | Fire incident-response playbook |
| Rate-limit ladder works (`operations/rate-limits.md`) | Layer-3 fault-injection per verification list | Per release | Rework ladder |

Tooling: `scripts/ops-validation-suite.ps1` (Phase-2 deliverable) bundles the above into a single runnable report.

---

## L6 — Human-in-the-loop quality

The stuff that only surfaces in real use. Low-frequency sampling, high-signal.

| Signal | Source | Target | Action on miss |
|---|---|---|---|
| Retro scores (5 axes) avg | `council_retro.scores` histogram | ≥3/5 per axis rolling 30-day | Team-level investigation via `plugins/retro-bar-raiser/` pattern |
| Coefficiency Index | `reliability-metrics.md §Coefficiency` | ≥ baseline established in S0 | Investigate cause — prompt churn? skill-gap? |
| Verdict usefulness | % of FIX verdicts acted on without user modification (derived metric) | >70% | If <50%: Skeptic is finding noise; if 50-70%: calibrate severity rubric |
| Self-vs-outcome calibration gap (Phase-5) | `reliability-metrics.md §Self-vs-outcome` | |gap| ≤ 0.15 across high-confidence verdicts | Adjust confidence thresholds or re-prompt |
| Time-to-resolution (A/B) | MAD-on teams vs MAD-off teams at S1 | MAD-on ≤ MAD-off at parity on severity | If MAD-on is slower: investigate friction; fast-path simple reviews |
| Improvisation-needed rate | `council_retro.improvisation_needed_total` | <30% of retros | >30%: skill gap — what's missing? |

**Not all signals make sense at every stage.** Retro scores start meaningful at S1 (need volume); A/B starts meaningful at S1 (need diverse teams); calibration gap needs Phase-5 tooling.

---

## Staged promotion gates

Every rollout stage has a specific validation bar. A stage is **promoted** when all bars are green for the stage's hold period.

| | S0 dogfood | S1 pilot | S2 GA | S3 default-on |
|---|---|---|---|---|
| **L0-L1** | ✅ 95% branch cov | ✅ | ✅ | ✅ |
| **L2 mock** | ✅ | ✅ | ✅ | ✅ |
| **L2 real-model smoke** | — | ✅ nightly green | ✅ | ✅ |
| **L2 golden-set** | — | ≥85% agreement | ≥90% agreement | no regression vs S2 baseline |
| **L3 correlation** | smoke | ✅ | ✅ | ✅ |
| **L4 permanent** | baseline pass | ✅ | ✅ | ✅ |
| **L4 red-team** | — | 1 round done | quarterly clean | 30 days no new HIGH |
| **L5 perf** | SLO met on reference hw | ✅ + CI regression check | ✅ + nightly full suite | ✅ |
| **L5 backup** | — | 1 exercise done | quarterly ✅ | ✅ |
| **L5 cost** | — | projection built | weekly ≤25% delta | ✅ |
| **L6 retro** | — | avg ≥3/5 for 1 week | avg ≥3/5 rolling 30d, usefulness >70% | + Coeff ≥ baseline, A/B favorable |
| **Hold period** | 1 week no P0 | 1 week clean metrics | 30 days clean | continuous |

Stages promote forward. **Demotion** happens automatically if gates regress — `/council-open` starts refusing new channels at the demoted stage until signals recover. See `plans/phase-1-mvp.md §Rollback criteria` for the rollback triggers.

---

## Failure modes explicitly hunted

These are the known failure modes the layers above are specifically designed to catch. If we discover a new one, it gets added here + a layer tasked with catching it.

| # | Failure mode | Layer(s) that catch it | Example symptom |
|---|---|---|---|
| 1 | Silent schema drift | L0 schemas + cross-link check | New field added to `verdict.json` in code but not in schema; fixtures pass by accident. |
| 2 | Model drift | L2 golden-set + nondeterminism budget | Skeptic suddenly flags all code as CRITICAL → golden-set agreement plummets. |
| 3 | Metric silence | L3 metric-to-file correlation | Counter stops incrementing while skill runs fine → collector config broke. |
| 4 | Adversarial regression | L4 permanent tests | Ban-list phrase no longer caught because normalization regressed. |
| 5 | Perf regression | L5 benchmarks in CI | Digest-rebuild p95 doubled after a "refactor" — blocked at PR. |
| 6 | Hallucinated citations | L0 cross-link + evidence-beats-assertion post-gen verification | Finding cites `src/handler.ts:999` which doesn't exist. |
| 7 | Prompt-injection in the wild | L4 adversarial + `safety-metrics.md` `policy.prompt_injection.detected_total` | Ban list needs a new phrase family; catch rate declines on L4. |
| 8 | Cost overrun | L5 cost weekly delta + Phase-5 budget gates | Auto-mode usage creeps from 20% to 60% → monthly cost 1.8×. |
| 9 | Consent bypass | L4 adversarial + consent-log correlation | Rationale contains "I already consented" and gate mistakenly skips → permanent regression lock. |
| 10 | Cross-project leak | L3 session-binding + L4 fixture | Alice's message renders in Bob's unrelated-project channel → alias reclaim attack or permissions bug. |
| 11 | Nondeterminism creep | L2 nondeterminism budget | Same thread re-reviewed produces different verdicts 40% of the time → drift. |
| 12 | Retro-signal decay | L6 improvisation-needed + avg score | Avg drops from 4.1 to 3.2 over a month → retrospective investigation. |
| 13 | Migration corruption | L5 migration verification | Post-migration fixture diff fails → migration script blocks release. |

---

## How to run the whole validation

### "I changed a skill" — PR-level

```bash
# L0 + L1 + L2 mock-model + L5 perf-in-CI + L3 smoke
# (matches what CI runs automatically)
pwsh evals/run-all.ps1 --layers 0,1,2-mock,3-smoke,5-perf-ci
```

### "I'm cutting a release candidate" — pre-release

```bash
# Add: full L4 permanent regression, L5 backup exercise, L2 real-model smoke
pwsh evals/run-all.ps1 --layers 0,1,2,3,4-permanent,5 --release-candidate
```

### "I'm promoting S1 → S2" — gate check

```bash
# Add: L2 golden-set, L4 red-team cycle, L6 retro roll-up, cost delta report
pwsh evals/run-all.ps1 --layers all --stage-gate s2
# Plus manual: review golden-set agreement trend, red-team report, retro summary
```

### "I suspect something broke in prod" — diagnostic

```bash
# Correlation checks first — they surface systemic issues fastest
pwsh scripts/validate-correlation.ps1 --window-hours 24
# Then targeted per-claim
pwsh scripts/ops-validation-suite.ps1 --claim cost --window-days 7
pwsh scripts/ops-validation-suite.ps1 --claim privacy --window-days 30
```

---

## What this doesn't cover

- **Emergent behavior from real long-term use.** No test predicts what happens when a team uses MAD for 6 months straight. L6 retro signals + self-vs-outcome gap catch this empirically; no pre-ship check does.
- **Third-party SDK bugs.** Claude Code's `AskUserQuestion` timeout changing, CronCreate scheduler flaking, etc. — caught only when we see symptom in L3 or L6. Mitigation: version-pin host runtime per `rules/verification-protocol.md`.
- **User-specific workflows.** Each team will bend the kit their way; L1-L6 test the kit, not the bends. Retros surface the bend; if a bend is common, it becomes a new Phase-5 feature.
- **"Is the spec right?"** If the spec says the wrong thing, tests against it will pass and the world will still be wrong. `operations/dry-run-happy-path.md` is the closest thing to a spec-reality check; if reading it aloud doesn't make sense, the spec needs review before the tests do.

---

## Related

- `evals/README.md` — the 6-layer test harness structure this validation strategy invokes.
- `evals/layer-{0..5}*.md` — per-layer plans.
- `plans/phase-1-mvp.md §Rollout stages + §Rollback criteria` — the stages this gates.
- `operations/performance-benchmarks.md` — L5 perf claims this validates.
- `operations/backup-disaster-recovery.md §Verification` — L5 backup claim this validates.
- `operations/rate-limits.md §Verification` — L5 rate-limit claim this validates.
- `operations/privacy-data-governance.md` — L5 privacy claim this validates.
- `operations/cost-projection.md` — L5 cost claim this validates.
- `operations/multi-user-isolation.md` — L5 isolation claim this validates.
- `operations/dry-run-happy-path.md` — narrative spec the L1 tests trace against.
- `operations/migration-strategy.md` — L5 migration claim this validates.
- `metrics/reliability-metrics.md` — L6 signals source.
- `wiki/patterns/evidence-beats-assertion.md` — underpins the "tests must produce evidence, not just pass" posture.
