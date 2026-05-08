# Test Specification

Test cases for validating the skill functionality.

## Test Cases

### TC-001: Basic Invocation

**Description**: Verify the skill responds to basic invocation.

**Steps**:
1. Invoke `/template-skill`
2. Observe output

**Expected Result**: Skill produces expected output format.

---

### TC-002: With Arguments

**Description**: Verify the skill handles arguments correctly.

**Steps**:
1. Invoke `/template-skill arg1`
2. Observe output includes arg1

**Expected Result**: Arguments are processed and reflected in output.

---

### TC-003: Error Handling

**Description**: Verify the skill handles errors gracefully.

**Steps**:
1. Invoke `/template-skill --invalid-option`
2. Observe error message

**Expected Result**: Clear error message is displayed.

---

## Validation Checklist

- [ ] Skill responds to invocation
- [ ] Arguments are processed correctly
- [ ] Errors are handled gracefully
- [ ] Output format matches specification
- [ ] No hardcoded paths or project-specific content
