# Expected output: basic input for /council-retro

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (channel status = resolved or closed; facilitator authorized) passes |
| Step 1 | gather signals: thread outcomes, verdict types, role-confidence histogram, body-size distribution, prompt-injection flag count |
| Step 2 | synthesize: what worked, what was hard, what we'd do differently |
| Step 3 | compute calibration: estimate-vs-actual hours, role-confidence vs final correctness |
| Step 4 | emit retro.json + readable summary |
| Step 5 | atomic write to `<channel>/retros/<ts>-retro.json` |

## Output Contract

- Each finding cites: thread / verdict / metric source
- Confidence score per claim (0-100)
- Anti-hallucination: claims about engineering outcomes ("EventBridge p95 met") flagged unverified unless evidence cited
- Signed off by `facilitator_alias` (immutable)

## Verdict

ACCEPT — retro emitted; calibration data feeds learning-signals pipeline.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Concurrency-safety (atomic write) ✓
- Multi-pass: gather → synthesize → calibrate ✓
