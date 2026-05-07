# 05 — Design reviews

Adversarial reviews of features, architecture choices, and methodology. Three sub-channels:

- `council-reviews/` — multi-role (Advocate / Skeptic / Architect) reviews per `/council-review` skill, one file per F-NNN reaching review gate.
- `copilot-cli-design-reviews/` — Copilot CLI multi-model dispatch outputs (Claude Opus + GPT-5+ in parallel via `Invoke-CopilotMultiModel.ps1`). At least one per N=5 waves per quality gate QG7.
- `retros/` — `/council-retro` outputs per wave or per milestone (per Standing Milestone L4: quarterly retros every ~13 waves).

## Verdict envelope (every review MUST end with)

```
Verdict consensus: APPROVE | APPROVE-WITH-SUGGESTIONS | WAIT-FOR-AUTHOR | REJECT
Median confidence: N (0-100)
Reviewer summary: <table of role + verdict + confidence>
Cross-model agreement: <only for copilot-cli reviews — table of finding × Opus × GPT × decision>
```

Per kit's `council-verdict-artifact.md` rule (status: preview): the artifact IS the verdict. No file → no verdict.
