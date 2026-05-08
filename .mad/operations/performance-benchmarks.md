# Performance Benchmarks

MAD.Council makes a handful of performance assertions in skill plans ("digest rebuild <500ms", "council-check fast path <100ms"). Assertions that aren't measured drift. This doc catalogs every performance assertion, says how to benchmark it, sets the SLO floor, and defines regression-catching.

## Assertion catalog

Every performance target currently in the kit, with source and SLO floor:

| Assertion | Where it lives | SLO floor (p95) | SLO floor (p99) | Hard cap |
|---|---|---|---|---|
| `digest-rebuild` full rebuild | `skills/council-post/plan.md` | 500 ms | 1 s | 3 s |
| `digest-rebuild` incremental | `skills/council-post/plan.md` | 100 ms | 250 ms | 1 s |
| `/council-check` fast path (no unreads) | `skills/council-check/SKILL.md` | 50 ms | 100 ms | 500 ms |
| `/council-check` with ≤10 unreads | `skills/council-check/plan.md` | 400 ms | 800 ms | 2 s |
| `/council-check` with 50+ unreads | `skills/council-check/plan.md` | 2 s | 4 s | 10 s |
| `/council-post` end-to-end (body < 1KB, no mentions) | `skills/council-post/plan.md` | 200 ms | 500 ms | 2 s |
| `/council-post` with body at 32KB cap | `skills/council-post/plan.md` | 400 ms | 1 s | 3 s |
| `/council-open` cold start (new channel) | `skills/council-open/plan.md` | 800 ms | 1.5 s | 5 s |
| `/council-join` cold start (new member) | `skills/council-join/plan.md` | 500 ms | 1 s | 3 s |
| `/council-list` rendering 20 channels | `skills/council-list/tests.md` T5-03 | 1 s | 2 s | 3 s |
| `/council-review` `propose` mode (3 roles) | `skills/council-review/plan.md` | 3 min | 4 min | 5 min (Claude Code stream-abort) |
| `/council-review` `auto` mode (6 calls + fuser) | `skills/council-review/plan.md` | 4 min | 4.5 min | 5 min |
| `/council-leave` Completion Report generation | `skills/council-leave/plan.md` | 1 s | 2 s | 5 s |
| `/council-retro` 7-prompt flow (excluding user think time) | `skills/council-retro/plan.md` | 500 ms | 1 s | 2 s |
| `seq-increment.ps1` uncontended | `scripts/seq-increment.ps1` | 5 ms | 20 ms | 100 ms |
| `seq-increment.ps1` 10-agent concurrent | `scripts/seq-increment.ps1` | 50 ms | 200 ms | 1 s |
| `atomic-write.ps1` typical JSON (~5KB) | `scripts/atomic-write.ps1` | 5 ms | 30 ms | 200 ms |
| `literal-phrase-scan.ps1` on 32KB body | `scripts/literal-phrase-scan.ps1` | 10 ms | 40 ms | 200 ms |

**p95/p99** = 95th / 99th percentile across 100+ samples. **Hard cap** = if this is exceeded, fail the benchmark outright and fire alert.

## Benchmark harness

`evals/perf/` is a dedicated sub-folder (not a new Layer — benchmarks are measurements, not pass/fail-at-the-functional-layer). Structure:

```
MAD/evals/perf/
  README.md
  run-benchmarks.ps1                      ← top-level runner
  digest-rebuild.bench.ps1
  council-check-fast-path.bench.ps1
  council-post-small-body.bench.ps1
  council-post-cap-body.bench.ps1
  council-list-20-channels.bench.ps1
  council-review-propose.bench.ps1         ← uses mock models; real-model bench is separate
  council-review-propose-real.bench.ps1    ← optional, requires credentials
  seq-increment-concurrent.bench.ps1
  atomic-write.bench.ps1
  literal-phrase-scan.bench.ps1
  fixtures/
    large-channel-150-messages/
    10-agent-concurrent/
    32kb-body/
  results/                                 ← machine-readable output
    2026-04-17-1430.json
    …
```

## Benchmark format

Every `.bench.ps1` emits a single JSON record:

```json
{
  "assertion": "digest-rebuild-full",
  "samples": 100,
  "unit": "ms",
  "p50": 210,
  "p95": 430,
  "p99": 820,
  "max": 1150,
  "slo_p95": 500,
  "slo_p99": 1000,
  "hard_cap": 3000,
  "status": "passed",
  "env": {
    "os": "Windows 11",
    "ps_version": "7.4.3",
    "cpu": "AMD Ryzen 9 5900X",
    "disk_kind": "NVMe SSD",
    "free_ram_gb": 42.1
  },
  "git_commit": "24460e4",
  "timestamp_utc": "2026-04-17T14:30:00Z"
}
```

Machine-readable output feeds the trend dashboard (Phase-5 deliverable) — for now it's a file in `evals/perf/results/` kept across runs.

## Methodology

For each assertion:

1. **Warm up** with 5 iterations — discarded.
2. **Measure** 100 iterations unless stated otherwise.
3. **Use realistic fixtures** (not synthetic empty ones). Example: `digest-rebuild` uses `fixtures/large-channel-150-messages/`.
4. **Between samples**, tear down any cache (file page cache) where OS permits. On Windows: no reliable sync-drop-caches; document this limitation and take medians of many runs rather than relying on cold-cache precision.
5. **Report p50, p95, p99, max.** Never report just "mean" — tail latency is what matters.
6. **Fail the bench** if any of: p95 > SLO floor, p99 > SLO floor, max > hard cap. Print the failing samples (top 5 slowest) for debugging.

## Catching regressions

**In CI (Layer 5):** a subset of fast benchmarks (`seq-increment`, `atomic-write`, `literal-phrase-scan`, `digest-rebuild` small channel, `council-check` fast path) run on every PR. Compares current p95/p99 against the `results/baseline.json` committed to the repo. A **20% regression on p95** or **any SLO floor breach** fails the check.

**Nightly:** the full benchmark suite (including `council-review-propose.bench.ps1` with mocked models) runs on a dedicated bench machine. Publishes results to the trend dashboard.

**Per-release:** a release candidate must pass:
1. Full suite on reference hardware (spec'd in `evals/perf/README.md`).
2. Comparison against the previous release: no SLO-floor regression; aggregate p95 across all benches ≤ previous release + 10%.

## Environment reproducibility

Performance is environment-dependent. To make benchmarks comparable:

- Every result records the environment block above.
- The repo contains a "reference environment" spec in `evals/perf/reference-env.md` — the reviewer can say "benchmarks on machine X must match reference to within 2× on p95."
- Divergence from reference is permitted; the benchmark report must include an environment-delta section.
- CI runners are the *one* environment where "we care about absolute numbers" — baseline is set on the CI runner, not on developer laptops.

## Benchmarks that don't exist yet

Flag: Phase 1 delivery must produce real numbers for every assertion above. Until then, every SLO floor is **aspirational** — the assertion says what we want, not what we've measured.

- Priority for the first pass: `digest-rebuild` full, `council-check` fast path, `seq-increment` concurrent, `atomic-write`, `literal-phrase-scan`. These are Phase-1 critical-path.
- Deferred to Phase 2: `council-review` modes (requires real model credentials or faithful mocks).
- Deferred to Phase 3: MAD-artifact benchmarks (spec-file scan, tasks.md update).

## Non-goals

- **Do not benchmark user think time.** `/council-retro` SLO excludes the user's reading/typing on the 7 prompts — we measure only the skill's overhead around the prompts.
- **Do not benchmark on production fixtures.** Use representative synthetic fixtures; production data may contain PII that must not go through benchmarks.
- **Do not infer SLOs from benchmarks alone.** SLOs also depend on user perception, contracted availability, etc. Benchmarks verify the floor we promised; they don't set the floor.

## Related

- `rules/concurrency-safety.md` — every concurrency benchmark here validates that rule under load.
- `evals/layer-0-data-sources.md` — fixture prerequisites for these benchmarks.
- `metrics/technical-metrics.md` — runtime latency histograms that correspond to these SLOs.
- `operations/rate-limits.md` — rate-limit events invalidate council-review benchmarks; record separately.
- `plans/phase-1-mvp.md §M3 Evals production` — where the initial benchmark numbers get produced.
