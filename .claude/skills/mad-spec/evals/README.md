# Evals — mad-spec

Synthetic fixtures + expected outputs for structural verification.

## What this checks

- Output Contract format on every finding
- Confidence-gate behavior (sub-floor demoted to mention)
- Anti-hallucination compliance
- Mode dispatch where applicable

## Fixtures

Place synthetic inputs under `fixtures/` and expected outputs under `expected/` (matching filenames). The `test.ps1` runner asserts each fixture has a corresponding expected output and that the actual output matches structurally.

## Run

```pwsh
pwsh test.ps1
```
