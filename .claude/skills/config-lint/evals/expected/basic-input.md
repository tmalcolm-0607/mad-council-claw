# Expected output: basic input for /config-lint

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (config files parse as JSON) passes |
| Step 1 | enumerate config files in `.claude/` |
| Step 2 | match against deprecated-field rules + known-bad patterns |
| Step 3 | propose fixes per finding |
| Step 4 | write report to `.mad/reports/config-lint-<ts>.md` |

## Output Contract

- Each finding cites: file:line + the matched pattern + replacement
- Severity: BLOCKING (auth break, secret leak) / MUST-FIX (deprecated field) / SHOULD-FIX (drift) / CONSIDER
- Confidence floor enforced
- Empty categories stated explicitly

Expected findings on this fixture:
- BLOCKING: `ANTHROPIC_API_KEY` in env block (Max auth override)
- MUST-FIX: deprecated `decision`/`reason` → use `hookSpecificOutput.permissionDecision`

## Verdict

REJECT — BLOCKING finding present; must remediate before session use.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
