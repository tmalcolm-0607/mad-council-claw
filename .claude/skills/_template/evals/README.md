# Template-skill evals

Synthetic fixtures + expected outputs for structural verification.

## What this checks

- Output Contract format on every finding (severity + file:line + evidence + rule + fix)
- Confidence-gate behavior (sub-floor findings demoted to mention)
- Anti-hallucination compliance (empty categories stated explicitly)
- Mode dispatch (--quick / --council / --deep / --copilot)

## Fixtures

| Fixture | Tests |
|---------|-------|
| `clean-input.md` | smart default produces no findings; PRAISE-only output |
| `dirty-input.md` | smart default surfaces ≥1 BLOCKING and ≥2 MUST-FIX |
| `migration-input.md` | FETCH-BEFORE-CITE caps validator-shape claims at conf ≤50 |
| `multi-pass-input.md` | --council promotes correctly when risk score ≥6 |

## Run

```
pwsh test.ps1
```

Expected: all fixtures match expected outputs structurally (same severity counts, same rule citations, same confidence ordering). Body text may differ on synonyms; assertions check structure not prose.
