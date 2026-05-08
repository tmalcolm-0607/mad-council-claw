# mad-implement Risk Routing

How `mad-implement` detects and routes tasks based on their Risk Tier classification.

> **Status**: Schema and documentation complete. Actual routing implementation in `mad-implement` is FUTURE work. This document defines the target behavior.

## Overview

During task execution, `mad-implement` reads each task's `Risk Tier` field and dispatches to different agent pipelines based on the classification:

```
tasks.md task
     |
     v
Parse Risk Tier field
     |
     +--- SECURITY-CRITICAL ---> security review pipeline
     |
     +--- STANDARD (or absent) ---> normal implementation pipeline
```

## Detection Logic

When `mad-implement` processes a task, it scans the task's context fields for the Risk Tier marker:

```
Pattern: /^\s*-\s+\*\*Risk Tier\*\*:\s*(SECURITY-CRITICAL|STANDARD)/m
```

**Matching rules**:
- `SECURITY-CRITICAL` (case-sensitive): Routes to security review pipeline
- `STANDARD` (case-sensitive): Routes to normal pipeline
- Field absent: Routes to normal pipeline (backward compatible)
- Unknown value: Warns and routes to normal pipeline

## Dispatch Pipelines

### Normal Pipeline (STANDARD / absent)

No change from current behavior:

```
1. code-investigator  -> investigate patterns and dependencies
2. code-implementer   -> TDD implementation
3. quality gates      -> build, test, lint
4. task complete
```

### Security Review Pipeline (SECURITY-CRITICAL)

Adds security audit before and after implementation:

```
1. code-investigator  -> investigate patterns and dependencies
2. security-auditor   -> pre-implementation threat assessment
3. code-implementer   -> TDD implementation
4. security-auditor   -> post-implementation code review
5. quality gates      -> build, test, lint
6. MANUAL APPROVAL    -> orchestrator pauses for user sign-off
7. task complete
```

### Pre-Implementation Threat Assessment

Before implementation begins, the security auditor:
- Reviews the task requirements for security implications
- Identifies attack vectors relevant to the task
- Recommends security controls the implementation must include
- Outputs a threat model to `.claude/work-items/{WI-ID}/artifacts/security/threat-{TASK-ID}.md`

The code-implementer receives the threat model as additional context.

### Post-Implementation Code Review

After implementation and quality gates pass, the security auditor:
- Performs character-level review of all changed files
- Validates that recommended security controls were implemented
- Checks for common vulnerability patterns (OWASP Top 10)
- Outputs findings to `.claude/work-items/{WI-ID}/artifacts/security/review-{TASK-ID}.md`

### Manual Approval Gate

The orchestrator presents the security auditor's findings to the user:

```
[SECURITY REVIEW] Task T020: Auth middleware validates JWT signatures

Security auditor findings:
- [PASS] Token signature validation uses jose library
- [PASS] Expiry checked server-side
- [WARN] No rate limiting on token validation endpoint
- [PASS] No secrets in source code

Approve implementation? (y/n)
```

The task is only marked complete after explicit user approval.

## Artifact Output Structure

```
.claude/work-items/{WI-ID}/artifacts/security/
  threat-T020.md          # Pre-implementation threat model
  review-T020.md          # Post-implementation security review
  threat-T035.md          # Another task's threat model
  review-T035.md          # Another task's security review
```

## Integration with Quality Gates

Risk-tiered verification does NOT replace quality gates. It adds an additional layer:

| Gate | STANDARD | SECURITY-CRITICAL |
|------|----------|-------------------|
| Build | Required | Required |
| Test | Required | Required |
| Lint | Required | Required |
| Coverage | Required | Required |
| Security audit | -- | **Required (added)** |
| Manual approval | -- | **Required (added)** |

See `.claude/rules/quality-gates.md` "Risk-Tiered Verification" section for the gate definition.

## Future Implementation Notes

When implementing the routing logic in `mad-implement`:

1. **Parse step**: Add Risk Tier field parsing alongside existing task field parsing
2. **Agent selection**: Add conditional dispatch based on parsed tier value
3. **Artifact paths**: Create security artifact directory under work item
4. **Approval UX**: Use existing orchestrator pause mechanism (same as plan approval)
5. **Fallback**: If security-auditor agent is not available, warn and proceed with normal pipeline (do not block)

## References

| Resource | Description |
|----------|-------------|
| `.claude/docs/risk-tiered-verification-guide.md` | Full guide on when and how to use risk tiers |
| `.claude/rules/quality-gates.md` | Quality gates with risk-tier section |
| `.mad/templates/tasks-template.md` | Task template with Risk Tier field |
