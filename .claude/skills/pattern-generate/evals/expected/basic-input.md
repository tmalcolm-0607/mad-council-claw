# Expected output: basic input for /pattern-generate

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (candidate exists; rules/patterns dir writable) passes |
| Step 1 | scaffold pattern file: name, applies-to, rule, do/don't, examples, anti-patterns |
| Step 2 | populate examples from cited candidate sources |
| Step 3 | populate anti-patterns from divergent files |
| Step 4 | write `rules/patterns/<lang>/<pattern>.md` |

## Output Contract

- Pattern file fully populated (no skipped sections)
- Each example cites: actual file:line excerpt
- Status frontmatter set to `preview` (per `_status-convention.md`)
- Anti-hallucination: don't fabricate examples not in source

## Verdict

ACCEPT — pattern file generated as `preview`; user promotes to `stable` after one rollout cycle.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Templates applied ✓
