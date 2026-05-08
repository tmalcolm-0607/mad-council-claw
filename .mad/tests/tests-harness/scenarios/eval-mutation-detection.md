# Eval: mutation-detection

## Scenario: Mutation-Guided Defect Detection

### Setup
Create a 5-layer consumer-project .NET scaffold with correct patterns, then inject 3
domain-specific mutations (1 per category, stratified sample). Record a mutation
manifest for assertion comparison.

The scaffold is the same enterprise Cosmos entity scaffold used by
`enterprise-cosmos-entity` and `trap-antipattern-resistance`, ensuring the
mutations target real the ecosystem patterns.

### Task Prompt
```
Review this consumer-project service codebase for bugs, security issues, performance
problems, and convention violations. For each issue found:
1. Identify the file and line
2. Describe the root cause
3. Fix the issue directly in the code
Focus on: Cosmos DB usage patterns, architecture layering, security best
practices, performance antipatterns, and .NET naming/coding conventions.
```

The prompt does NOT reveal that mutations were injected.

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| Mutation detected | Agent changes the mutated code | Detection (40%) |
| Root cause described | Agent output contains relevant keywords | Diagnosis (25%) |
| Fix matches expected | Fix verification regex passes | Fix Quality (25%) |
| No regressions | Build still passes after fixes | Regression (10%) |
| Low false positives | Only mutated code changed | Precision |

### Scoring (4 Dimensions)

```
Composite = 0.4 * Detection + 0.25 * Diagnosis + 0.25 * FixQuality + 0.1 * Regression
```

- **Detection**: Binary 0/1 -- did the agent touch the mutated file region?
- **Diagnosis**: 0.0-1.0 -- keyword-matching against detection keywords
- **Fix Quality**: 0.0-1.0 -- regex verification of correct fix pattern
- **Regression**: Binary 0/1 -- does the project still build?
- **Precision**: true_fixes / (true_fixes + false_positives) -- extra metric

### Assertions (machine-checkable)

```powershell
# 1. Mutation manifest exists
Test-Path .mutation-manifest.json

# 2. Build passes after agent modifications
dotnet build --nologo -v q

# 3. Per-mutation 4D scores computed
# (automated by Invoke-MutationAssertions)

# 4. Overall detection rate >= 50%

# 5. Overall composite score >= 0.4
```

### Mutation Categories

| Category | Count | Examples |
|----------|-------|---------|
| CosmosDB | 10 | Wrong partition key, missing soft-delete filter |
| Architecture | 10 | Bypassed handler, missing DI registration |
| Security | 8 | Missing auth, PII in logs, injection |
| Performance | 8 | N+1 query, sync-over-async |
| Convention | 6 | String interpolation logging, wrong naming |

### Metrics to Collect

| Metric | How to Measure |
|--------|---------------|
| Detection rate | Mutations found / total mutations |
| Diagnosis accuracy | Keyword match score average |
| Fix quality | Fix verification regex pass rate |
| Regression avoidance | Post-agent build success |
| Precision | Changes to mutation area / total changes |
| Discrimination delta | Treatment composite - baseline composite |
| Token usage | From Claude CLI JSON output |
| Wall-clock time | Process duration |
| Cost | From Claude CLI total_cost_usd |

---

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| MutationCount | 3 | Mutations per eval run |
| MutationCategories | all 5 | Which categories to sample from |
| MutationIds | (none) | Specific mutations to inject |
| CircuitBreaker | $5/mutation | Max cost per mutation run |
