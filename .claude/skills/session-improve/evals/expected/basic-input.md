# Expected output: basic input for /session-improve

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (logs/metrics readable) passes |
| Step 1 | enumerate recent friction signals |
| Step 2 | classify: rule needed / hook needed / skill needed / threshold tweak |
| Step 3 | propose patches with severity + rationale |
| Step 4 | user-confirm before apply |
| Step 5 | apply approved patches |

## Output Contract

- Each proposed patch cites: signal source + count + proposed remediation
- Severity: BLOCKING / MUST-FIX / SHOULD-FIX
- Anti-hallucination: cite raw signal evidence (log line, anomaly ID)
- Empty signal list stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS — patches proposed; user approves before apply.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
