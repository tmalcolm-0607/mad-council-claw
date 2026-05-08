# Expected output: basic input for /code-reviewer

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (target file exists; language detected) passes |
| Step 1 | security pass (S1-S15) |
| Step 2 | correctness pass (recurring-issue checks) |
| Step 3 | style pass (matches existing project conventions) |
| Step 4 | emit findings using template `code-reviewer/templates/code-review.md` |

## Output Contract

Per finding:
- `[severity] file:line — title`
- Evidence (≤6 lines)
- Rule (citation)
- Confidence (0-100)
- Suggested fix

Severities: BLOCKING / MUST-FIX / SHOULD-FIX / CONSIDER / PRAISE
Confidence floors: 80 / 70 / 60 / 50 / 70

## Expected findings on this fixture

- MUST-FIX: `IsValid` only checks JWT shape (3 parts), not signature. Real validation missing.
- SHOULD-FIX: `null` check before split — could use `string.IsNullOrWhiteSpace`.
- CONSIDER: unused `logger` parameter — wire log on validation failure or remove dependency.
- Anti-hallucination: every cited line read; categories with no findings stated explicitly.

## Verdict

ACCEPT_WITH_CAVEATS — MUST-FIX security gap; user needs to wire actual JWT validation.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE, security-first)
- Standards inheritance ✓
- Template applied ✓
