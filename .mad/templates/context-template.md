# Context: [FEATURE_NAME]

**Branch**: `[BRANCH]` | **Updated**: [TIMESTAMP] | **Status**: [IN_PROGRESS|BLOCKED|READY]

---

## Workflow State

| Skill | Status | Date | Notes |
|-------|--------|------|-------|
| specify | PENDING | - | - |
| plan | PENDING | - | - |
| tasks | PENDING | - | - |
| implement | PENDING | - | - |
| automation | PENDING | - | - |

---

## Progress

**Phase**: [N] [Name] | **Task**: [TXXX] | **Completed**: [X/Y] ([Z]%)

| Phase | Range | Done | Status |
|-------|-------|------|--------|
| 1 Setup | T001-007 | 0/7 | - |
| 2 Foundation | T008-020 | 0/13 | - |

### Current Task
- **ID**: [TXXX]
- **Status**: [PENDING|STARTED|BLOCKED]
- **Description**: [Brief]

---

## Decisions (Summary)

*Keep ≤10 active decisions. Archive older ones to context-archive.md*

| Date | Decision | Rationale | Source |
|------|----------|-----------|--------|
| [DATE] | [What was decided] | [Why] | [Skill] |

---

## Clarifications (Last 5)

| Date | Question | Answer | Affects |
|------|----------|--------|---------|
| [DATE] | [Q] | [A] | [File] |

*Older clarifications: context-archive.md*

---

## Blockers

### Active
| ID | Sev | Description | Blocking | Resolution |
|----|-----|-------------|----------|------------|
| - | - | None | - | - |

### Recently Resolved (Last 3)
- *None yet*

---

## Failure Log (Last 10)

*Track failures for pattern analysis and skill improvement*

| ID | Date | Category | Task | Error Summary | Root Cause | Fix Applied |
|----|------|----------|------|---------------|------------|-------------|
| F001 | [DATE] | [CAT] | [TXXX] | [Brief error] | [Why it happened] | [How fixed] |

**Categories**: BUILD, TEST, GATE, TYPE, LINT, DOCKER, E2E, API, DB, CONFIG, LOGIC, OTHER

### Failure Patterns Detected

*Repeated failures suggest skill/CLAUDE.md improvements needed*

| Pattern | Count | Suggested Improvement |
|---------|-------|----------------------|
| [Pattern name] | [N] | [What to add to CLAUDE.md or skill] |

### Lessons Learned (Exportable)

*Copy to CLAUDE.md "Anti-Patterns" section when pattern count >= 3*

```markdown
<!-- LESSON: [ID] - [Category] -->
| [Anti-Pattern] | [Problem] | [Correct Approach] |
```

---

## Gate Results

**Last Run**: [TIMESTAMP] | **Attempt**: [N] | **Overall**: [PASS|FAIL]

| Gate | Result | Notes |
|------|--------|-------|
| Build | - | - |
| Tests | - | - |
| Coverage | - | - |
| Docker | - | - |
| E2E | - | - |

### Previous Failure (if any)
- *None*

---

## Artifact Integrity

| Artifact | Hash | Status |
|----------|------|--------|
| spec.md | - | - |
| plan.md | - | - |
| tasks.md | - | - |

---

## Phase Commits

| Phase | Commit | Date |
|-------|--------|------|
| - | - | - |

---

## Handoff

**For**: [Next skill or action]

### Completed
- [What was done]

### Ready
- [Artifacts ready to use]

### Needs Attention
- [Issues requiring decision]

### Next Action
```bash
[Command to run]
```

---

## Session Log (Last 20)

| Time | Skill | Event | Details |
|------|-------|-------|---------|
| [TS] | [SKILL] | [EVENT] | [Brief] |

*Events: STARTED, COMPLETED, BLOCKED, DECISION, GATE_PASS, GATE_FAIL, ERROR*
*Full log: context-archive.md (when >20 entries)*

---

## Size Check

**Lines**: ~150 | **Target**: <500 | **Status**: OK

*Auto-archive triggers at 450 lines*
