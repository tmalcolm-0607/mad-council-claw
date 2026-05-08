# Expected output shape — copilot-canary-tiny

## Cross-model agreement table

| Finding ID | Opus | GPT | Decision |
|---|---|---|---|
| F1 (CRITICAL: stale FIX verdict — claimed fix not present in cited branch) | flagged | flagged | HARD BLOCK |

## Required structural elements

- Body contains `## Cross-model agreement table` heading
- F1 row exists with `flagged` in both Opus and GPT columns
- Decision column for F1 reads `HARD BLOCK` (or equivalent literal "hard block")
- Mode field of dispatcher result is `CopilotCLI` (real run) OR `TaskFallback` (CLI absent)
- TaskFallback path: produces a Context Gap line per `degradation-fallback-policy.md` Rule 3
- F1 cites message 4 (`verdict-claim`) and the absence of matching commits on
  `users/synth/payment-retry-fix`
- Verdict computation rejects the FIX claim — final verdict is `INVESTIGATE` or `FIX`
  (never `ACCEPT` while F1 is unmitigated)
- Per Step 8 rubric: ≥1 CRITICAL forces verdict away from ACCEPT

## Skill features exercised

- `--copilot` mode dispatches via `Invoke-CopilotMultiModel.ps1` (or fallback) ✓
- Both-flag-CRITICAL hard-block rule applied ✓
- Synthesis lens (binding-verdict cross-check) honored ✓
- Anti-hallucination: F1 cites the literal verdict-claim message and absence of
  supporting commits, not paraphrase ✓
- Mechanical ESCALATE triggers honored: cross-model agreement on CRITICAL forces
  verdict away from ACCEPT regardless of role-confidence ✓
