# Expected output: basic input for /project-init

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (target writable; no existing `.claude/` to overwrite — or user-confirmed merge) passes |
| Step 1 | copy `.claude/` → target (skipping LOCAL settings) |
| Step 2 | copy `.mad/` → target (excluding scratch + work-items) |
| Step 3 | scaffold project-specific CLAUDE.md skeleton |
| Step 4 | emit getting-started note |

## Output Contract

- Each copied area cites: source path → target path
- Dangerous-operations consent gate before overwriting any pre-existing files
- Anti-hallucination: don't claim init succeeded without verifying file presence post-copy

## Verdict

ACCEPT — kit installed; user customizes CLAUDE.md.

## Skill features exercised

- Smart-default flow ✓
- Dangerous-operations consent gate ✓
- Standards inheritance ✓
