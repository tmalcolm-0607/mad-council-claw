# Template — learning proposal

Canonical shape for individual proposals emitted by `/apply-learnings --knowledge`. Each pending knowledge candidate gets one proposal.

> **EXAMPLE — replace this when authoring**

```markdown
# Proposal — <topic-slug>

**Source**: <session/PR id> | **Duration/Scope**: <N min, M files>
**Type**: skill | rule | doc-update
**Confidence**: 0-100

## What was observed

<2-3 sentences on the pattern or knowledge captured.>

## Reusability check

- [ ] Would this help a future task? (specific scenarios)
- [ ] Is the pattern non-obvious from current codebase?
- [ ] Has it appeared ≥3× in distinct contexts? (or once in a high-stakes context)

## Proposed artifact

```yaml
target_path: <e.g. .claude/skills/<slug>/SKILL.md or rules/<slug>.md>
status: preview
since: <ISO date>
```

### Body draft

<full body content, ready to write>

## Decision

- [ ] APPROVE — write artifact + mark candidate `applied`
- [ ] REJECT — mark candidate `rejected` with reason
- [ ] SKIP — re-surface next run
```

## Anti-hallucination

The reusability check is non-negotiable. A candidate with no answer to "what future scenario uses this?" is REJECT.
