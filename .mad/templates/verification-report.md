# Verification Report Template

Use this template for feature-verifier agent output.

```markdown
# Feature Verification Report

**Feature**: [Name/description]
**Verified**: [YYYY-MM-DD HH:MM]

---

## Feature Intent

**What was implemented**: [Brief description]
**Change type**: [Filter | Gate | Threshold | New logic | Refactor | New feature]
**Expected impact**: [What the feature should do]

---

## Baseline vs Modified Comparison

| Metric | Baseline | Modified | Delta | Assessment |
|--------|----------|----------|-------|------------|
| Tests Passing | X | Y | +/-Z | [OK/CONCERN/FAILURE] |
| Coverage | X% | Y% | +/-Z% | [OK/CONCERN/FAILURE] |
| Feature Activity | X | Y | +/-Z% | [OK/CONCERN/FAILURE] |
| Errors | X | Y | +/-Z | [OK/FAILURE] |

---

## Structural Assessment

- **Feature triggers as expected**: [Yes/No/Unclear]
- **Error handling**: [Proper/Missing/Broken]
- **Expected outputs produced**: [Yes/No/Partial]
- **Integration points working**: [Yes/No/Untested]

**Structural verdict**: [PASS / FAIL / INVESTIGATE]

---

## Mechanical Assessment

- **Build**: [Success / Failure]
- **Tests**: [All passing / Some failing]
- **Lint/Types**: [Clean / Errors]
- **Runtime errors**: [None / List]

**Mechanical verdict**: [PASS / FAIL]

---

## Performance Assessment (Informational)

| Metric | Baseline | Modified | Delta |
|--------|----------|----------|-------|
| Response Time | Xms | Yms | +/-Zms |
| Memory Usage | X | Y | +/-Z |

**Note**: Performance changes do not affect verification outcome.

---

## VERIFICATION OUTCOME

### [VERIFIED | VERIFIED_WITH_NOTE | NEEDS_INVESTIGATION | STRUCTURAL_FAILURE | MECHANICAL_FAILURE]

**Rationale**: [2-3 sentences explaining outcome]

---

## Recommended Action

[One of:]
- **No action needed** - Proceed to commit/PR
- **Create optimization work item** - Works but could improve
- **Create investigation work item** - Need to understand [specific question]
- **Create repair work item** - Needs fixes for [specific issues]
- **Fix errors** - Mechanical errors must be resolved
```

---

## Outcome Definitions

| Outcome | Meaning | Action |
|---------|---------|--------|
| VERIFIED | Structurally sound | Proceed |
| VERIFIED_WITH_NOTE | Sound but notable change | Proceed with docs |
| NEEDS_INVESTIGATION | Unclear if structural | Investigate first |
| STRUCTURAL_FAILURE | Broke intended behavior | Fix or revert |
| MECHANICAL_FAILURE | Runtime/build errors | Fix errors |

## Decision Matrix

```
                    |  <15%  |  15-40% |  40-70% |  >70%  |
--------------------|--------|---------|---------|--------|
No errors           |VERIFIED|VERIFIED |NEEDS_INV|STRUCT  |
                    |        |(note)   |         |FAIL    |
--------------------|--------|---------|---------|--------|
Errors in output    |MECH_   |MECH_    |MECH_    |MECH_   |
                    |FAILURE |FAILURE  |FAILURE  |FAILURE |
```
