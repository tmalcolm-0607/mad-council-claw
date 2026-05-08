# Expected output: basic input for /research-swarm

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (topics enumerable; web access available) passes |
| Step 1 | spawn N parallel-researcher agents (1 per topic) |
| Step 2 | each runs scout → curator → reviewer pipeline internally |
| Step 3 | aggregate validated findings per topic |
| Step 4 | synthesize cross-topic insights |
| Step 5 | write report to `.mad/reports/research-swarm-<ts>.md` |

## Output Contract

- Each finding cites: source URL + confidence (high/medium/low)
- Cross-topic synthesis flags overlaps + contradictions
- Anti-hallucination: every claim has a source citation
- Empty topics stated explicitly

## Verdict

ACCEPT — N topics researched in parallel; synthesis returned.

## Skill features exercised

- Smart-default flow ✓
- Parallel orchestration ✓
- Standards inheritance ✓
- Multi-pass: scout → curator → reviewer per topic ✓
