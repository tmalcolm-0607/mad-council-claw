# Expected output shape — copilot-canary-tiny

## Cross-model agreement table

| Finding ID | Opus | GPT | Decision |
|---|---|---|---|
| F1 (CRITICAL: hardcoded API credential committed in source) | flagged | flagged | HARD BLOCK |

## Required structural elements

- Body contains `## Cross-model agreement table` heading
- F1 row exists with `flagged` in both Opus and GPT columns
- Decision column for F1 reads `HARD BLOCK` (or equivalent literal "hard block")
- Mode field of dispatcher result is `CopilotCLI` (real run) OR `TaskFallback` (CLI absent)
- TaskFallback path: produces a Context Gap line per `degradation-fallback-policy.md` Rule 3
- Verdict is `wait-for-author` or `reject` (never `approve` while F1 is unmitigated)
- Citation includes file:line reference to `src/clients/weather-client.js` line that introduces `WEATHER_API_KEY`

## Skill features exercised

- `--copilot` mode dispatches via `Invoke-CopilotMultiModel.ps1` (or fallback) ✓
- Both-flag-CRITICAL hard-block rule applied ✓
- Synthesis lens (security + correctness cross-check) honored ✓
- Anti-hallucination: F1 cites the literal credential string, not paraphrase ✓
