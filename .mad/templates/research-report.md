# Research Report Templates

Templates for research-curator and research-reviewer agents.

---

## Curator Report Template

```markdown
# Research Curator Report: [Topic]

**Date**: [YYYY-MM-DD HH:MM]
**Scout Report**: [path]
**Claims Evaluated**: [N] | **Retained**: [N] | **Dropped**: [N]

---

## Curation Summary

| Confidence | Count |
|------------|-------|
| HIGH | X |
| MEDIUM | Y |
| DROPPED | Z |

---

## Curated Findings

### Finding F01: [Topic]

**Confidence**: HIGH
**Based on Claims**: C01, C03

**Summary**: [2-3 sentences]

**Evidence**:
| Claim | Source | Type | Validation |
|-------|--------|------|------------|
| "[claim]" | [source] | PRIMARY | [check] |

**Rationale**: [Why this confidence level]

---

## Dropped Claims

| Claim | Source | Reason |
|-------|--------|--------|
| C08 | Vendor | No evidence |

---

## Conflicts

### Resolved: [Topic]
**Resolution**: [Explanation]

### Unresolved: [Topic]
**For Reviewer**: [What to investigate]

---

## For Reviewer

- Findings: [N] (High: X, Medium: Y)
- Areas to challenge: [list]
- Key assumptions: [list]
```

---

## Reviewer Report Template

```markdown
# Research Review Report: [Topic]

**Date**: [YYYY-MM-DD HH:MM]
**Curator Report**: [path]
**Findings Reviewed**: [N]
**Challenges Raised**: [N]
**Safeguards Proposed**: [N]

---

## Executive Summary

[2-3 paragraphs: challenges, risks, recommendation]

---

## Finding Reviews

### Finding F01: [Topic]

**Curator Confidence**: HIGH
**Reviewer Assessment**: [VALIDATED | CHALLENGED | CONDITIONAL]

#### Challenges

1. **Challenge**: [Statement]
   - **Basis**: [Why]
   - **Impact if wrong**: [What breaks]
   - **Verdict**: [Resolved | Concern]

#### Hidden Assumptions

| Assumption | Risk if Wrong | Likelihood | Mitigation |
|------------|---------------|------------|------------|
| [Assumption] | [Impact] | H/M/L | [Action] |

#### Stress-Test Results

**Scenario**: [What if X?]
- Impact: [Description]
- Verdict: [Acceptable | Need safeguard]

#### Safeguards Required

1. **[Name]**: [Type] - [Implementation]

#### Final Assessment

- **Recommendation**: [PROCEED | CAUTION | RECONSIDER | REJECT]
- **Conditions**: [Requirements]

---

## Safeguard Summary

| # | Safeguard | Protects Against | Priority |
|---|-----------|------------------|----------|
| S01 | [Name] | [Risk] | HIGH |

---

## Final Recommendations

### Proceed With
| Finding | Confidence | Conditions |
|---------|------------|------------|
| F01 | HIGH | None |

### Proceed With Caution
| Finding | Concerns | Required Safeguards |
|---------|----------|---------------------|
| F03 | [Concern] | S02 |

### Reconsider/Reject
| Finding | Reason | Alternative |
|---------|--------|-------------|
| F04 | [Why] | [What instead] |

---

## Key Takeaways

1. [Most important]
2. [Second]
3. [Third]

## Required Actions Before Proceeding

- [ ] [Action 1]
- [ ] [Action 2]
```
