# Eval: cross-repo-consistency

## Scenario: Pattern-Consensus-Gauge

### Overview

Zero-LLM-cost eval that fingerprints 8 architectural concern dimensions across
12 the ecosystem reference repos at `references/`, computes weighted majority voting
consensus using maturity-tiered weights, and validates that the ecosystem has
measurable consensus patterns.

This is a meta-eval -- it validates the consensus infrastructure itself rather
than testing agent output. No Claude CLI invocation required.

### Setup

Fingerprint all the ecosystem reference repos and compute consensus:

1. Scan each repo for pattern presence/absence across 8 dimensions
2. Classify raw pattern matches into canonical variant names
3. Apply maturity-tier weights (Tier 1: 3x, Tier 2: 2x, Tier 3: 1x, Tier 4: 0.5x)
4. Compute weighted majority vote per dimension
5. Write consensus baseline to workspace

### Maturity Tiers

| Tier | Weight | Repos |
|------|--------|-------|
| 1 (Reference) | 3x | a shared service, a gateway API service |
| 2 (Established) | 2x | a portal service, another consumer service, a data-collection service |
| 3 (Developing) | 1x | a frontend project, a delivery service |
| 4 (Legacy) | 0.5x | another ecosystem service, a publish service, MDEP |

### 8 Concern Dimensions

| # | Dimension | Key Patterns |
|---|-----------|-------------|
| 1 | DI Registration | AddSingleton, AddScoped, AddTransient, ServiceCollectionExtensions |
| 2 | Error Handling | SanitizedException, dual middleware, ProblemDetails, Result<T> |
| 3 | Configuration | IConfigOptions, Options pattern, dual config (appsettings + runtimesettings) |
| 4 | Logging | LoggerMessage source generators, structured logging, correlation IDs |
| 5 | Testing | xUnit, NSubstitute, FluentAssertions, integration testing |
| 6 | Security | Managed Identity, JWT Bearer, policy-based authorization |
| 7 | Resilience | Polly v8, classic Polly, resilience pipelines |
| 8 | Cosmos | SDK v3, queries, advanced features (batching, change feed, HPK) |

### Task Prompt

```
This is a static analysis eval. No agent invocation required.
Run Setup-CrossRepo to fingerprint repos and compute consensus.
Run Invoke-CrossRepoAssertions to validate the consensus baseline.
```

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| Baseline exists | consensus-baseline.json written | Required |
| Sufficient repos | >= 6 .NET repos fingerprinted | Required |
| All dimensions | 8 dimensions computed | Required |
| Majority consensus | >= 4 dimensions with strong consensus | Required |
| No empty dimensions | Every dimension has >= 1 repo with data | Required |
| Agreement variance | Ratios are not all identical | Required |
| Tier 1 presence | a shared service and a gateway API service both contribute | Required |
| Security exclusions | No anomalous match counts from .git scanning | Required |
| Composite score | Invoke-MultiDimensionalScore returns >= 0 | Required |

### Assertions (machine-checkable)

```powershell
# 1. Baseline file exists
Test-Path consensus-baseline.json

# 2. Sufficient .NET repos
$b = Get-Content consensus-baseline.json | ConvertFrom-Json
$b.net_repo_count -ge 6

# 3. All 8 dimensions
$b.consensus.PSObject.Properties.Count -ge 8

# 4. Consensus on majority
($b.consensus.PSObject.Properties | Where-Object { $_.Value.status -eq 'consensus' }).Count -ge 4

# 5. Tier 1 repos present
($b.fingerprints | Where-Object { $_.repo -in @('a shared service','a gateway API service') -and $_.status -ne 'not_applicable' }).Count -ge 2

# 6. Composite score computed
$score = Invoke-MultiDimensionalScore -Dimensions $dims
$score.composite -ge 0
```

---

## Security Considerations

- `.git/` directories excluded from scanning (PII in commit messages)
- `**/secrets/`, `.env*`, `**/test-data/` excluded
- Pattern detection is match/no-match only -- no content captured

## Metrics to Collect

| Metric | How to Measure |
|--------|---------------|
| Repos scanned | Count of fingerprinted repos |
| .NET repos | Count excluding not_applicable |
| Consensus dimensions | Count with status='consensus' |
| Weak consensus | Count with status='weak_consensus' |
| Composite score | Invoke-MultiDimensionalScore output |
| Scan duration | Wall-clock time for Setup-CrossRepo |
| Cache hit rate | Count of from_cache=true fingerprints |
