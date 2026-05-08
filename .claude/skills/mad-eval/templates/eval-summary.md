# Template — mad-eval summary

Canonical shape for `/mad-eval <target>` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Eval Summary — <target>

**Target**: <skill | workflow>
**Mode**: structural | --llm | --copilot
**Date**: <ISO date>

## Fixtures

| Fixture | Status | Reason if failing |
|---------|--------|-------------------|
| basic-input.md | PASS | — |
| edge-case-foo.md | FAIL | expected output mismatch on line 14 |

## Aggregate

- Pass: N / Total
- Time: <seconds>
- Mode artifacts: <paths to LLM responses or Copilot dispatcher output>

## Anti-hallucination

- Each PASS row cites: matching expected file present + structural shape verified
- FAIL rows quote the diff, never paraphrase
- Empty fixtures dir stated explicitly

## Verdict

ACCEPT (all PASS) | ACCEPT_WITH_CAVEATS (≥1 FAIL but expected during preview) | REJECT (production fixtures failing)
```

## Reference

- Per-skill `evals/test.ps1` runner is the pass/fail source-of-truth
