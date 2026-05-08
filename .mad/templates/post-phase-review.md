# Post-Phase Review Checklist

**Purpose**: Systematic review after completing any development phase to ensure implementation matches documentation and maintains project standards.

**When to Run**: After completing any phase and before moving to the next phase.

**Time Estimate**: 15-30 minutes per phase

---

## 1. Implementation Review

### Code Quality
- [ ] Project builds with zero errors: `[BUILD_COMMAND from CLAUDE.md]`
- [ ] Linting passes: `[LINT_COMMAND from CLAUDE.md]`
- [ ] Code formatting is consistent: `[FORMAT_COMMAND from CLAUDE.md]`
- [ ] Functions follow project size limits (see CLAUDE.md/AGENTS.md)
- [ ] Database queries use limits/pagination
- [ ] Errors are explicitly handled (no silent failures)

### Testing
- [ ] All tests pass: `[TEST_COMMAND from CLAUDE.md]`
- [ ] Test coverage meets threshold (if configured)
- [ ] No skipped tests without TODO comments
- [ ] New features have corresponding tests

### Schema Consistency
- [ ] Shared types/contracts match database schema
- [ ] API route schemas match data model
- [ ] Frontend/client models use correct field names
- [ ] Validation rules match database constraints

---

## 2. Documentation Review

### Project Docs
- [ ] README.md reflects current structure
- [ ] All commands in docs work as documented
- [ ] New features are mentioned in appropriate sections
- [ ] Architecture diagram is current (if applicable)

### Agent Configuration
- [ ] CLAUDE.md / AGENTS.md / copilot-instructions.md reflects current patterns
- [ ] New conventions are documented
- [ ] File naming conventions match actual files

### API Documentation
- [ ] All endpoints are documented
- [ ] Request/response schemas match implementations
- [ ] Error codes match actual error handling
- [ ] Implementation status is current

### Feature Records
- [ ] Completed tasks marked `[x]` in tasks.md
- [ ] Task descriptions match what was implemented
- [ ] Dependencies are accurate

---

## 3. Consistency Checks

### Data Flow: Database → Types → Routes → Docs

For each entity:
- [ ] Database migration/schema defines all columns
- [ ] Shared types include all fields
- [ ] Backend routes use correct column names
- [ ] API docs show correct request/response schema
- [ ] Frontend/client uses correct field names

### Boundary Rules
- [ ] Backend never imports from frontend
- [ ] Frontend never imports from backend
- [ ] Only shared types cross boundaries
- [ ] No server-only modules in client code
- [ ] No client-only APIs in server code

---

## 4. Deployment Verification (if applicable)

### Build and Start
- [ ] All services build successfully
- [ ] All services start and become healthy
- [ ] Health endpoints respond correctly
- [ ] No error logs on startup

### Data
- [ ] Migrations apply cleanly
- [ ] Seed data loads (if applicable)
- [ ] No orphaned tables or columns

---

## 5. Git Housekeeping

- [ ] All changes committed with conventional commit messages
- [ ] No uncommitted changes: `git status`
- [ ] No merge conflicts
- [ ] Branch is up to date with main
- [ ] tasks.md updated and committed

---

## 6. Output: Consistency Report

Create a phase review document:

```markdown
# Phase [N] Review - [Date]

## Summary
- Phase: [Phase Name]
- Tasks Completed: [T001-T010]
- Status: ✅ Ready for Next Phase / ⚠️ Issues Found / ❌ Blocked

## Gate Results
- Build: [✓ Pass / ✗ Fail]
- Tests: [X passing, Y failing]
- Coverage: [X% / N/A]
- Deployment: [✓ All healthy / ✗ Issues / N/A]

## Documentation Updates
- [List docs updated or "No changes needed"]

## Schema Consistency
- Database ↔ Types: [✓ Match / ⚠️ N issues]
- Types ↔ Routes: [✓ Match / ⚠️ N issues]
- Routes ↔ Docs: [✓ Match / ⚠️ N issues]

## Issues Found
1. [Issue description and resolution]

## New Patterns Documented
- [Pattern name]: [Where documented]
```

---

**Next Phase**: [Link to next phase in tasks.md]
