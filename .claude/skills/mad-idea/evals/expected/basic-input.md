# Expected output: basic input for /mad-idea

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (specs/ideas/ writable; slug derivable) passes |
| Step 1 | derive slug from input phrase |
| Step 2 | expand into idea.md sections |
| Step 3 | flag every assumption as `[NEEDS CLARIFICATION]` |
| Step 4 | write to `specs/ideas/<slug>.md` |

## Output Contract

- idea.md template fully populated (no skipped sections)
- Vision-flag set (path under `specs/ideas/`); not a contract
- Anti-hallucination: assumptions explicit via `[NEEDS CLARIFICATION]` markers
- Empty sections stated explicitly ("No non-functional considerations identified yet.")

## Verdict

ACCEPT_WITH_CAVEATS — vision authored; user must promote to contract via /mad-spec to advance.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Templates applied (idea.md) ✓
