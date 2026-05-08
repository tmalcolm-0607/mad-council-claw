# Work Item Plan Template

Copy this template when creating new work item plans.

---

```markdown
# Plan: [Work Item Name]

**Type**: [Refactor | Investigation | Maintenance | Research | Bug Fix]
**Created**: [YYYY-MM-DD]
**Status**: Not Started
**Work Item**: WI-[YYYYMMDD]-[HHMM]-[slug]

---

## Prerequisites (Before Starting)

- [ ] **Check current branch**: `git branch --show-current`
- [ ] **Create branch if needed**: `git checkout -b [type]/[plan-name]`
- [ ] **Branch name**: `_____________`

---

## Work Description

[Clear description of what needs to be done and why]

## Rationale

[Why this work is needed - business value, technical necessity, etc.]

## Success Criteria

- [ ] [Specific, measurable criterion 1]
- [ ] [Specific, measurable criterion 2]
- [ ] [Specific, measurable criterion 3]

---

## Verification Spec

**REQUIRED.** This tells `feature-verifier` how to interpret results.

### Work Intent
[1-2 sentences: What does this work accomplish?]

### Change Type
[ ] filter | [ ] gate | [ ] threshold | [ ] logic | [ ] refactor | [ ] new_feature

### Expected Behavior Impact
- **Expected change**: [ ] none | [ ] decrease_minor | [ ] decrease_moderate | [ ] increase
- **Rationale**: [Why is this impact expected?]

### Structural Signals
| Signal | Pass Condition | Fail Condition |
|--------|----------------|----------------|
| [What to check #1] | [Success indicator] | [Failure indicator] |
| [What to check #2] | [Success indicator] | [Failure indicator] |

### Not a Failure
These outcomes may look concerning but are NOT structural failures:
- [Acceptable outcome #1]
- [Acceptable outcome #2]

---

## Workflow Phases

### Phase 1: [Baseline/Setup]
**Status**: [ ] Not Started
**Assigned Agent**: [agent-name]

**Tasks**:
- [ ] [Task 1]
- [ ] [Task 2]

**Success Gate**: [How to know this phase is complete]

**Results**:
<!-- Fill in when phase completes -->

---

### Phase 2: [Investigate/Research]
**Status**: [ ] Not Started
**Assigned Agent**: [agent-name]

**Tasks**:
- [ ] [Task 1]
- [ ] [Task 2]

**Success Gate**: [How to know this phase is complete]

**If Fails**: [What to do]

**Results**:
<!-- Fill in when phase completes -->

---

### Phase 3: [Implement/Execute]
**Status**: [ ] Not Started
**Assigned Agent**: [agent-name]

**Tasks**:
- [ ] [Task 1]
- [ ] [Task 2]

**Success Gate**: [Build passes, tests pass, etc.]

**If Fails**: [Return to Phase 2 / escalate / etc.]

**Results**:
<!-- Fill in when phase completes -->

---

### Phase 4: [Verify]
**Status**: [ ] Not Started
**Assigned Agent**: feature-verifier

**Tasks**:
- [ ] Spawn feature-verifier with verification spec
- [ ] Review verification outcome
- [ ] Address any issues found

**Success Gate**: VERIFIED or VERIFIED_WITH_NOTE outcome

**If Fails**: [Return to Phase 3 / investigate / etc.]

**Results**:
<!-- Fill in when phase completes -->

---

### Phase 5: [Complete]
**Status**: [ ] Not Started
**Assigned Agent**: orchestrator

**Tasks**:
- [ ] Commit all changes
- [ ] Update CHANGELOG.md
- [ ] Clear ACTIVE pointer
- [ ] Close work item

**Results**:
<!-- Fill in when phase completes -->

---

## Completion

When work is done, add this entry to `.claude/work-items/CHANGELOG.md`:

```
### [YYYY-MM-DD]

### WI-[YYYYMMDD]-[HHMM]-[slug]
- **Type**: [type]
- **Status**: Completed
- **Summary**: [1-2 sentence summary of what was accomplished]
```
```

---

## Phase Templates by Work Type

### Refactoring Phases

1. **Baseline** - Record current test results, build status
2. **Investigate** - Identify refactoring targets, dependencies
3. **Implement** - Apply refactoring, update tests if needed
4. **Verify** - Confirm no behavioral change
5. **Complete** - Commit, changelog

### Investigation Phases

1. **Define Scope** - Clarify questions, success criteria
2. **Gather Evidence** - Collect data, logs, samples
3. **Analyze** - Root cause analysis, impact assessment
4. **Report** - Document findings, recommendations
5. **Complete** - Create follow-up work items, changelog

### Bug Fix Phases

1. **Reproduce** - Confirm bug, document steps
2. **Investigate** - Root cause analysis
3. **Implement Fix** - Apply fix, add regression test
4. **Verify** - Confirm fix, no regression
5. **Complete** - Commit with bug reference, changelog

### Maintenance Phases

1. **Assess** - Current state, what needs updating
2. **Plan** - Identify changes, dependencies
3. **Execute** - Apply updates, fixes
4. **Verify** - Confirm system still works
5. **Complete** - Document changes, changelog
