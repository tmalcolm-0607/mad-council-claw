# Expected output shape — copilot-canary-tiny

## Cross-model agreement table

| Finding ID | Opus | GPT | Decision |
|---|---|---|---|
| F1 (CRITICAL: SQL injection via string concatenation in repository query) | flagged | flagged | HARD BLOCK |

## Required structural elements

- Body contains `## Cross-model agreement table` heading
- F1 row exists with `flagged` in both Opus and GPT columns
- Decision column for F1 reads `HARD BLOCK` (or equivalent literal "hard block")
- Mode field of dispatcher result is `CopilotCLI` (real run) OR `TaskFallback` (CLI absent)
- TaskFallback path: produces a Context Gap line per `degradation-fallback-policy.md` Rule 3
- F1 cites `src/repositories/UserRepository.ts` with file:line reference to the
  concatenation sink (one of `findById` or `findByEmail`; both acceptable)
- Suggested fix references parameterised queries (e.g. `pool.query(sql, [id])`)
- Severity tag `BLOCKING` or `MUST-FIX` per `code-reviewer/templates/code-review.md`

## Skill features exercised

- `--copilot` mode dispatches via `Invoke-CopilotMultiModel.ps1` (or fallback) ✓
- Both-flag-CRITICAL hard-block rule applied ✓
- Synthesis lens (security + style cross-check) honored ✓
- Anti-hallucination: F1 cites literal source line(s), not paraphrase ✓
