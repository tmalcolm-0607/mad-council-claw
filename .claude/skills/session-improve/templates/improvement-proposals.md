# Template — session improvement proposals

Canonical shape for `/session-improve apply` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Session Improvement Proposals — <ISO date>

**Window**: last <N> sessions / <since>
**Signal sources**: anomaly log, friction log, gates log, consent log

## Per-friction-class

### FC-1: Hook fail-open events (3 instances)

**Evidence**:
- session 2026-04-30T18:14Z: pre-bash-validate.js exit-50 swallowed
- session 2026-04-30T18:42Z: same hook, same swallow
- session 2026-05-01T09:11Z: same

**Diagnosis**: hook lacks fail-closed branch on internal exception
**Proposed patch**: edit `.claude/hooks/pre-bash-validate.js` to log + propagate
**Confidence**: 0.84

### FC-2: PR-review false convergence claims (2 instances)

(same shape)

## Apply queue (user reviews)

| ID | Type | Severity | Apply? |
|----|------|----------|--------|
| FC-1 | hook fix | MUST-FIX | [ ] |
| FC-2 | rule tighten | SHOULD-FIX | [ ] |

## Anti-hallucination

- Each finding cites raw signal: log line, anomaly ID, gate output
- Empty signal classes stated explicitly
- Never propose a fix without a reproducible signal

## Verdict

ACCEPT_WITH_CAVEATS — N proposals queued; user approves before apply.
```
