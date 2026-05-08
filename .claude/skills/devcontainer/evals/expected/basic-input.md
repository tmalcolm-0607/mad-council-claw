# Expected output: basic input for /devcontainer

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (existing devcontainer.json parses or scaffold target accessible) passes |
| Step 1 | infer required runtime + tools from project state |
| Step 2 | diff vs existing devcontainer.json |
| Step 3 | propose patches: feature additions, version bumps, mounts, ports |
| Step 4 | write proposed devcontainer.json to `.mad/scratch/devcontainer-proposed.json` |

## Output Contract

- Each proposed patch cites: rationale + source-of-truth (.csproj, requirements.txt, infra spec)
- Severity: BLOCKING (build won't run) / MUST-FIX (test infra missing) / SHOULD-FIX (DX) / CONSIDER
- Confidence floor enforced
- Empty categories stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS — proposed devcontainer; user reviews + applies.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
