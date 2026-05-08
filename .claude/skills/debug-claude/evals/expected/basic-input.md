# Expected output: basic input for /debug-claude

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (.claude/ + .mad/ exist) passes |
| Step 1 | parse user report → categorize symptom (hooks / MCP / skills / context) |
| Step 2 | gather signals: settings.json, hook scripts, MCP health, frontmatter |
| Step 3 | run diagnostic probes (parse YAML frontmatter, dry-run hook, check JSON) |
| Step 4 | propose root cause + fix per symptom |
| Step 5 | write diagnostic report to `.mad/reports/debug-claude-<ts>.md` |

## Output Contract

- Each finding cites: file:line where issue lives + evidence
- Severity: BLOCKING (session broken) / MUST-FIX (silent fail) / SHOULD-FIX / CONSIDER
- Confidence floor enforced
- FETCH BEFORE CITE: every claim about hook/skill behavior is read first
- Empty categories stated explicitly

## Verdict

ACCEPT — diagnostic complete; user reviews proposed fixes before applying.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE, ACTUAL BEFORE PRESENT)
- Standards inheritance ✓
- Anti-hallucination check ✓
