# Expected output: basic input for /council-verdict

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (thread + findings present; issuer authorized) passes |
| Step 1 | apply severity-to-verdict rubric:
   - 0 CRITICAL, <3 HIGH, 0 MEDIUM, all roles ≥0.85 → ACCEPT
   - 0 CRITICAL, <3 HIGH, ≥1 MEDIUM, some roles 0.5-0.85 → ACCEPT_WITH_CAVEATS
   - ≥1 CRITICAL or ≥3 HIGH → FIX
   - any role <0.5 → eligible for ESCALATE
   - any role evidence_incomplete → INVESTIGATE |
| Step 2 | check mechanical ESCALATE triggers (3-role disagreement, all roles <0.5, timeout) |
| Step 3 | emit verdict.json with rubric reasoning |
| Step 4 | atomic write to `<thread>/verdict.json` (via `.tmp` + rename) |

## Output Contract

- verdict.json conforms to `council-review/templates/verdict.md` shape
- verdict_reasoning cites which rubric branch fired
- verdict_confidence in [0,1]
- For OWNERSHIP_TRANSFER: issuer must be current owner (per rules/single-owner-accountability)

## Expected verdict on this fixture

ACCEPT — 0 CRITICAL/HIGH/MEDIUM and all role_confidence ≥0.82 (just below the 0.85 strict ACCEPT threshold) → ACCEPT_WITH_CAVEATS.

## Skill features exercised

- Smart-default flow ✓
- Severity-to-verdict rubric ✓
- Mechanical ESCALATE triggers ✓
- Atomic write ✓
- Standards inheritance ✓
