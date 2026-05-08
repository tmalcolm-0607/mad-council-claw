# Implementation Report Template

Use this template for code-implementer agent output.

```markdown
# Implementation Report: [Feature/Fix]

**Date**: [YYYY-MM-DD HH:MM]
**Based On**: [Investigation report path]
**Plan**: [Plan file path]

---

## Summary

[2-3 sentence summary of what was implemented]

---

## Changes Made

### File: `src/path/file.ext`

**Action**: [Created | Modified | Deleted]
**Changes**:
- Lines X-Y: [Description]

**Code**:
```
// src/path/file.ext:X-Y
[snippet]
```

---

## Tests Added

### Test File: `tests/path/file.test.ext`

| Test Name | Purpose | Status |
|-----------|---------|--------|
| `test_name` | [Purpose] | Pass |

---

## TDD Evidence

### Feature: [Name]

1. **Test Written First**: `tests/path:line`
2. **Test Failed Initially**: Confirmed
3. **Implementation**: `src/path:line`
4. **Test Passed**: Confirmed

---

## Quality Gates

### After Each Change

| Change | Build | Test | Lint |
|--------|-------|------|------|
| [Change] | Pass | Pass | Pass |

### Final Gate Check

```
Build: [command]
Output: [result]

Test: [command]
Output: X passed, 0 failed

Lint: [command]
Output: No errors
```

---

## Files Modified Summary

| File | Action | Lines Changed |
|------|--------|---------------|
| `path` | Modified | +X, -Y |

---

## Plan Updates

- [x] Task 1
- [x] Task 2

---

## Issues Encountered

### Issue: [Description]

**Problem**: [What]
**Solution**: [How]

---

## Verification Checklist

- [x] Tests written before implementation (TDD)
- [x] All tests passing
- [x] Build succeeds
- [x] Lint clean
- [x] Plan file updated
```
