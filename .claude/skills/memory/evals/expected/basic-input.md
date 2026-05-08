# Expected output: basic input for /memory

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (memory dir exists or createable) passes |
| Step 1 | classify type: user / feedback / project / reference |
| Step 2 | check MEMORY.md for existing entry on the topic; update if duplicate |
| Step 3 | write the memory file with frontmatter (`name`, `description`, `type`) |
| Step 4 | append index line to MEMORY.md |

## Output Contract

- Memory file shows: name + description + type + body
- For feedback/project: includes **Why:** + **How to apply:** lines
- Index entry under ~150 chars
- Anti-hallucination: don't store ephemeral or trivially-derivable info

Expected classification on this fixture: project (operational fact about pipelines).

## Verdict

ACCEPT — memory written; index updated.

## Skill features exercised

- Smart-default flow ✓
- Auto-memory protocol applied ✓
- Standards inheritance ✓
