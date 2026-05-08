# Risk-Tiered Verification Guide

Task-level security classification that routes high-risk work through additional review gates.

## What Is Risk-Tiered Verification?

Risk-tiered verification is an optional field on tasks in `tasks.md` that classifies each task by its security impact. Tasks marked `SECURITY-CRITICAL` are routed through a security-auditor agent and require manual approval before the implementation proceeds. Tasks marked `STANDARD` (or with no Risk Tier field) follow the normal quality gate flow.

The field is added to the task context block:

```markdown
- [ ] **T020** [US1]: Auth middleware validates JWT signatures
  - **Functionality**: Validates token signature, expiry, and issuer
  - **Success criteria**: Invalid tokens rejected with 401
  - **Risk Tier**: SECURITY-CRITICAL
```

## When to Use SECURITY-CRITICAL

Assign `SECURITY-CRITICAL` to any task that modifies, creates, or touches:

| Domain | Examples |
|--------|----------|
| **Authentication** | Login, logout, token generation, token validation, session management |
| **Authorization** | Role checks, permission guards, access control lists, policy enforcement |
| **Cryptography** | Encryption, decryption, hashing, key management, certificate handling |
| **Secrets management** | API keys, connection strings, environment variables, vault access |
| **Payment processing** | Charge creation, refund handling, payment method storage, PCI-scoped code |
| **PII handling** | User data storage, data export, GDPR endpoints, anonymization |
| **Input sanitization** | SQL query construction, HTML rendering, command execution, file path handling |
| **Infrastructure security** | CORS configuration, CSP headers, TLS settings, firewall rules |

**Rule of thumb**: If a bug in this task could lead to unauthorized access, data breach, or financial loss, it is `SECURITY-CRITICAL`.

## When to Use STANDARD

Assign `STANDARD` (or omit the field entirely) for:

| Domain | Examples |
|--------|----------|
| **UI components** | Layout, styling, animations, non-auth forms |
| **Business logic** | Calculations, state machines, game rules, workflow orchestration |
| **Utilities** | Date formatting, string helpers, logging utilities |
| **Tests** | Test files, test fixtures, test utilities |
| **Documentation** | README updates, API docs, architecture diagrams |
| **Configuration** | Non-security config (feature flags, UI settings, theme config) |

## What SECURITY-CRITICAL Triggers

When `mad-implement` encounters a task with `Risk Tier: SECURITY-CRITICAL`:

1. **Security-auditor agent dispatch**: The task is routed to the `security-auditor` agent instead of (or in addition to) the standard `code-implementer`.
2. **Character-level code review**: The security auditor performs line-by-line analysis, not just pattern matching. It examines:
   - Input validation completeness
   - Authentication/authorization correctness
   - Cryptographic implementation safety
   - Secret exposure risks
   - Injection vulnerability surface
3. **Manual approval gate**: The orchestrator pauses and requests explicit user approval before marking the task complete. The approval prompt includes the security auditor's findings.
4. **Audit trail**: Security review findings are persisted to `.claude/work-items/{WI-ID}/artifacts/security/` for traceability.

## Classification Examples

| Task | Risk Tier | Rationale |
|------|-----------|-----------|
| Implement JWT token refresh endpoint | SECURITY-CRITICAL | Token generation = authentication |
| Add role-based route guard middleware | SECURITY-CRITICAL | Authorization enforcement |
| Create password reset flow | SECURITY-CRITICAL | Authentication + secret (reset token) |
| Encrypt PII fields at rest | SECURITY-CRITICAL | Cryptography + PII handling |
| Store Stripe payment method | SECURITY-CRITICAL | Payment + PCI scope |
| Add CORS allowed origins config | SECURITY-CRITICAL | Infrastructure security |
| Parse user input for SQL query | SECURITY-CRITICAL | Input sanitization (SQL injection risk) |
| Build character sheet UI component | STANDARD | UI rendering, no auth/security impact |
| Calculate damage based on dice roll | STANDARD | Game logic, no security surface |
| Add pagination to session list API | STANDARD | Business logic, read-only list endpoint |
| Format date strings for display | STANDARD | Utility function, no security surface |
| Write unit tests for game engine | STANDARD | Test code, not production security path |

## Security Auditor Review Checklist

When the security-auditor agent reviews a `SECURITY-CRITICAL` task, it checks:

### Authentication
- [ ] Tokens validated on every request (not just at login)
- [ ] Token expiry enforced server-side
- [ ] Refresh tokens stored securely (httpOnly, secure, sameSite)
- [ ] Password hashing uses bcrypt/argon2 with sufficient rounds

### Authorization
- [ ] Every endpoint checks permissions (no "open by default")
- [ ] Role escalation prevented (users cannot grant themselves higher roles)
- [ ] Resource ownership verified (user can only access own resources)
- [ ] Admin endpoints restricted to admin role

### Input Validation
- [ ] All user input validated and sanitized before use
- [ ] SQL queries use parameterized statements
- [ ] HTML output encoded to prevent XSS
- [ ] File paths validated to prevent traversal
- [ ] Request size limits enforced

### Cryptography
- [ ] No custom crypto implementations (use established libraries)
- [ ] Keys not hardcoded in source
- [ ] Secure random generation used (not Math.random)
- [ ] TLS enforced for all external communication

### Secrets
- [ ] No secrets in source code or logs
- [ ] Environment variables or vault used for all secrets
- [ ] Secrets rotatable without code changes
- [ ] Audit logging for secret access

### Data Protection
- [ ] PII encrypted at rest
- [ ] PII not logged in plaintext
- [ ] Data retention policies enforced
- [ ] User data deletable (right to be forgotten)

## Integration Points

| Resource | Description |
|----------|-------------|
| `.mad/templates/tasks-template.md` | Task template with Risk Tier field |
| `.claude/rules/quality-gates.md` | Quality gates with risk-tier routing section |
| `.claude/docs/mad-implement-risk-routing.md` | Dispatch logic documentation |
| `.claude/agents/security-auditor.md` | Security auditor agent definition (if exists) |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Marking everything SECURITY-CRITICAL | Slows all work, dilutes security focus | Only tasks touching auth/crypto/secrets/PII |
| Omitting Risk Tier on auth tasks | Security-sensitive code skips review | Always classify auth/payment/permission tasks |
| Treating STANDARD as "no review" | All code still goes through quality gates | STANDARD = normal gates; SECURITY-CRITICAL = gates + security audit |
| Skipping manual approval | Defeats purpose of security gate | Always require user sign-off for SECURITY-CRITICAL |
