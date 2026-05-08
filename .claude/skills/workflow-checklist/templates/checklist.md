# Workflow Checklist Template

Copy and fill in this checklist for each work session.

---

## Session Info

- **Date**: YYYY-MM-DD
- **Work Item**: WI-YYYYMMDD-HHMM-slug
- **Branch**: feature/name

---

## Phase 1: PRE-WORK

- [ ] Work item active (check `.claude/work-items/sessions/${CLAUDE_SESSION_ID:-default}`)
- [ ] On feature branch (not main/master)
- [ ] Spec/plan exists
- [ ] Checked CHANGELOG for duplicate work
- [ ] Read existing plan.md if resuming

---

## Phase 2: DURING-WORK

### Agent Delegation
- [ ] Code reading → code-investigator
- [ ] Code writing → code-implementer
- [ ] Code review → code-reviewer
- [ ] Research → research pipeline

### Real-Time Updates
- [ ] Updated checkbox after each task
- [ ] Filled Results with file:line refs
- [ ] Marked blockers with [!]

### Verification
- [ ] Ran build myself after agent claimed success
- [ ] Ran tests myself after agent claimed success
- [ ] Documented verification results

---

## Phase 3: POST-WORK

### Gates
- [ ] `npm run build` - Exit 0
- [ ] `npm test` - X passed, 0 failed
- [ ] `npm run check` - No lint errors
- [ ] Coverage >= threshold (if applicable)

### Completion
- [ ] All plan.md checkboxes marked
- [ ] Results sections filled with specifics
- [ ] CHANGELOG.md entry added
- [ ] manifest.json status updated
- [ ] ACTIVE file cleared

---

## Phase 4: SESSION HEALTH

- **Context usage**: ~Xk tokens
- **MCP count**: X enabled
- **Status**: Good / Marginal / Clear needed

### Recommendation
- [ ] Continue current work
- [ ] Clear context, then continue
- [ ] Start new work item
- [ ] Close session

---

## Notes

[Any session-specific notes, blockers, or follow-ups]
