# Layer 5 — CI Gate + Continuous Monitoring

The deployment gate. CI/CD merges block on Layer-0-4 eval outcomes; production runs continuously emit metrics that trigger re-evals on drift.

## Scope

**In scope**:
- CI/CD pipeline configuration (GitHub Actions / Azure Pipelines YAML).
- Gate thresholds (branch coverage, perf regression, layer pass rates).
- Continuous monitoring (OpenTelemetry-based; see `metrics/` iter-15).
- Drift detection (signals trigger ad-hoc re-evals).

**Out of scope**:
- Running the underlying tests — those are Layers 0-4.
- Metrics definitions — see `metrics/` iter-15.

## Gate thresholds

A PR merges ONLY if all thresholds pass.

### Per-layer gates

| Layer | Threshold | Hard/Soft |
|---|---|---|
| Layer 0 | 100% fixtures certify | **Hard** — pipeline blocks on any fail |
| Layer 1 | 100% pass + branch coverage ≥95% per skill + **diff-coverage ≥90%** on changed files | **Hard** |
| Layer 2 | 100% pass | **Hard** |
| Layer 3 | 100% pass on pre-release pipeline; 95% on per-commit (some may flake on loaded CI) | Hard for pre-release; soft for commit |
| Layer 4 | 100% locked regression pass | **Hard** — no locked test may regress |
| Layer 5 | N/A (this is the gate itself) | — |

**Diff-coverage primary, overall coverage secondary** (`ADOPT-003`): the ecosystem `testing.md` teaches that overall coverage drifts toward vanity; the metric that actually prevents regressions is coverage of the lines **changed in the current PR**. Gate logic:
- ≥90% of executable lines touched by the PR are exercised by tests ⇒ pass.
- Overall branch coverage ≥95% still required, but is now the secondary gate — a PR that drops overall by <1% while hitting 90% diff-coverage passes; a PR that maintains overall but misses diff-coverage fails.

### Cross-cutting gates

| Gate | Threshold |
|---|---|
| All 5 gates (Layer 0-4) pass | Required |
| No decrease in total test count vs `main` | Required |
| Perf: no skill's 99th-percentile latency regresses >20% | Required |
| Security: no new Rule-1 phrase slips past without being added to ban list | Required |
| Link-check: every `file.md:path/to/other.md` reference resolves | Required |

## Pipeline shape (conceptual)

```yaml
# .github/workflows/mad-council-ci.yml (or ado-pipelines/mad-council.yml)

on:
  pull_request:
    paths:
      - 'MAD/**'
  push:
    branches: [main]

jobs:
  layer-0-certify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup PowerShell 7
        uses: actions/setup-powershell@v1
      - name: Install Pester 5
        run: Install-Module Pester -Force -MinimumVersion 5.0.0
      - name: Certify fixtures
        run: pwsh ./MAD/evals/run-evals.ps1 -Layer 0

  layer-1-unit:
    needs: layer-0-certify
    runs-on: ubuntu-latest
    steps:
      - # same setup
      - name: Run unit tests
        run: pwsh ./MAD/evals/run-evals.ps1 -Layer 1 -Coverage
      - name: Enforce coverage ≥95%
        run: pwsh ./MAD/evals/check-coverage.ps1 -Minimum 95

  layer-2-integration:
    needs: layer-1-unit
    runs-on: ubuntu-latest
    steps:
      - # setup
      - run: pwsh ./MAD/evals/run-evals.ps1 -Layer 2

  layer-3-e2e:
    needs: layer-2-integration
    runs-on: ubuntu-latest
    if: github.event_name == 'push' || contains(github.event.pull_request.labels.*.name, 'run-e2e')
    steps:
      - # setup
      - run: pwsh ./MAD/evals/run-evals.ps1 -Layer 3

  layer-4-adversarial:
    needs: [layer-0-certify, layer-1-unit]    # parallel with integration
    runs-on: ubuntu-latest
    steps:
      - # setup
      - run: pwsh ./MAD/evals/run-evals.ps1 -Layer 4 -LockedOnly

  gate:
    needs: [layer-1-unit, layer-2-integration, layer-4-adversarial]
    runs-on: ubuntu-latest
    steps:
      - name: All layers passed
        run: echo "Gate pass"
```

## Continuous monitoring (production)

Per `metrics/operational-metrics.md` (iter-15 target), production runs emit OpenTelemetry spans + counters. Drift signals trigger re-evals:

| Signal | Trigger |
|---|---|
| `council_post.session_mismatch_total` > baseline × 3 | Spoofing attack in progress — alert + investigate |
| `council_check.circuit_breaker_trip_total` > baseline × 2 | Polling dependency degraded — investigate |
| `council_review.mechanical_escalate_trigger_total{trigger=ensemble_all_disagree}` > N/day | Models disagreeing unusually — could be calibration drift |
| `council_retro.score_self_vs_outcome_gap > threshold` | Self-assessment miscalibrated — prompt-tune upstream |
| `council_post.suspicious_tagged_total` spike | New attack pattern; audit ban list |

Each signal has a runbook under `metrics/runbooks/<signal>.md` (iter-15).

## Fast-lane vs full-lane

Some PR scopes don't need full eval runs:

| Change type | Required layers |
|---|---|
| Doc-only (rules/*.md, wiki/**) | Layer 0 (link-check subset) |
| Skill SKILL.md change | Layer 0, 1, 2 |
| Script change | Layer 0, 1 (for that script) |
| Spec change (mad.council.a2a.md) | Layer 0, 1, 2 |
| New attack test added to Layer 4 | Layer 0, 4 (new test + all locked) |
| Runtime behavior change | Layer 0, 1, 2, 3, 4 (all) |

Fast-lane detection: pipeline inspects changed paths; picks minimum layer set. Pre-merge still requires full run via a `full-eval` label if touched runtime.

## Release cadence

- **Per-commit**: Layers 0, 1, 2, 4 (locked).
- **Pre-release (weekly / on-demand)**: All 5 layers + perf regression check.
- **Per-release candidate**: Full suite + manual smoke-test on real Claude Code host.
- **Quarterly**: Full Layer 4 adversarial audit with new attacks added to catalog.

## Reporting

CI outputs a summary comment on each PR:

```
MAD.Council Evaluation Results
  Layer 0 (certify):    ✅ 368 checks PASS
  Layer 1 (unit):       ✅ 195/195 pass · coverage 96.2%
  Layer 2 (integration): ✅ 155/155 pass
  Layer 3 (e2e):        ⏸ skipped (no e2e trigger on this PR)
  Layer 4 (adversarial): ✅ 208/208 locked pass · 0 new attacks
  
  Gate: ✅ PASS
  
  Perf: all skills within 20% of baseline (p99 latency).
  Link-check: all internal refs resolve.
```

## Bypass / override

Emergency path only:

- **Label** `eval-override` requires 2 approvers from CODEOWNERS list to bypass gate.
- Bypass logs to `evals/override-log.md` for audit.
- Policy: should be rare (<1% of merges). Review in quarterly audit.

## Related

- `metrics/operational-metrics.md` (iter-15) — signals Layer 5 monitors.
- `metrics/runbooks/` (iter-15) — incident response for each drift signal.
- `plans/phase-5-intelligence.md` (iter-16) — long-term continuous-learning improvements.
- `wiki/references.md` §13 — 6-layer harness source.
