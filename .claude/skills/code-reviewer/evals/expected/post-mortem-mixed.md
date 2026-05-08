# Expected output: post-mortem mixed PR (code + doc)

## Smart-default flow

| Step | Result |
|------|--------|
| 0 preflight | passes |
| 1.4 content-type | mixed (`code-change` + `doc-change`); blast_radius=5; oracles: `handler-tests.md` + `doc-generic.md` |
| 1.5 grounding | fires (keyword: validator wiring, auth) |
| 1.6 risk score | code at auth path (+3) + doc-change blast (+5) → ≥7 → auto-promote `--council` |
| 1.7 ref-repo cross-check | fires on doc; cross-checks JWT validation pattern against `references/` |
| 1.8 cross-file consistency | empty (mixed types, no group of ≥2 same type) |
| 1.9 oracle | handler-tests.md + doc-generic.md loaded |

## Findings (in posting order)

### First — doc structural absence (BLOCKING per content-type calibration)

```
[BLOCKING] docs/auth/session-validation-pattern.md — PATCH-style update flow section missing

Evidence:
  Doc covers when-to-use, API shape, error handling, but no section
  addresses the PATCH-style update flow that the prescription claims
  is part of "the pattern".

Rule:
  rules/prescriptive-content-review.md § Gap 3
  + .mad/templates/coverage-oracles/doc-generic.md § 3 (Concrete examples)
  + § 7 (How to verify)

Confidence: 90
```

### Second — code structural absence (MUST-FIX per code-change calibration)

```
[MUST-FIX] src/services/auth/SessionValidator.cs:8 — JWT signature not verified

Evidence:
  return parts.Length == 3;

Only checks JWT shape (3 parts), not signature against IssuerSigningKey.

Rule:
  rules/patterns/_dotnet/dotnet-auth.md § JWT validation
  + .mad/templates/coverage-oracles/handler-tests.md § scenario #3 (auth)

Confidence: 88
Suggested fix:
  Use JwtSecurityTokenHandler.ValidateToken with the IssuerSigningKey from MISE config.
```

### Third — handler-tests oracle, missing scenarios (SHOULD-FIX)

- Missing #6 conflict / ETag scenario test for SessionValidator
- Missing #11 telemetry scenario (no ActivitySource span)

### Fourth — doc, missing test guidance for concurrency (SHOULD-FIX)

```
[SHOULD-FIX] docs/auth/session-validation-pattern.md — concurrency / ETag test scenario absent

Evidence:
  Doc's "Test guidance" section covers happy-path + invalid-token but
  doesn't address concurrent-validation or stale-ETag scenarios.

Rule:
  .mad/templates/coverage-oracles/handler-tests.md § scenario #6 (conflict)
  + doc-generic.md § 7 (How to verify)
```

## NOT first

`[CONSIDER]` unused `logger` parameter — emitted AFTER all BLOCKING / MUST-FIX findings.

## Verdict

REJECT — BLOCKING + MUST-FIX both present; auto-promoted to `--council` for Architect to confirm scoping.

## Anti-hallucination

- Each oracle section number cited by reading the oracle, not paraphrased
- Code excerpt quoted from actual file
- Severity table cited from `rules/prescriptive-content-review.md` for the content-type-aware calibration

## Skill features exercised

- Content-type detection on mixed PR ✓
- blast_radius cross-axis combination (code +3 + doc +5) ✓
- Per-content-type oracle pass ✓
- Per-content-type severity calibration ✓
- First-finding-by-severity ordering ✓
