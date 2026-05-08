# Expected output: basic input for /context-sync

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (ACTIVE pointer present; plan.md + tasks.md parseable) passes |
| Step 1 | read persisted state |
| Step 2 | reconcile: plan checkboxes, blockers, recent commits |
| Step 3 | report drift: where in-session belief diverges from disk |
| Step 4 | propose alignment actions |

## Output Contract

- Each drift cites: in-session belief vs disk state
- Severity: BLOCKING (incoherent) / MUST-FIX (missed blocker) / SHOULD-FIX
- Anti-hallucination: never claim alignment without re-reading source
- Empty drift stated explicitly

## Verdict

ACCEPT — drift surfaced; user reconciles in-session belief with disk truth.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
