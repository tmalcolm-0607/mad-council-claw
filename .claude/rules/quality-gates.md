# Quality Gates

After EACH user story or phase, execute gates with ACTUAL OUTPUT as proof.

## Gates

| Gate | Purpose | Success Criteria |
|------|---------|------------------|
| Build | Compile/transpile code | Exit 0, no errors |
| Test | Run unit/integration tests | All pass, 0 failed |
| Coverage | Measure code coverage | 100% diff coverage |
| Lint/Format | Check code style | Exit 0, no errors |
| Security | Check for vulnerabilities | No high/critical issues |
| Pre-flight | Mechanical grep-based checks | `.claude/scripts/Check-Preflight.ps1` |

Run all: `powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1`
E2E: `powershell.exe -NoProfile -File .claude/scripts/Test-E2E-ACI.ps1 -Environment tonym`

## 5-Tier Progressive Validation

| Tier | Scope | Expected Time | Use Case |
|------|-------|---------------|----------|
| **0** | Single test (`--filter`) | <1s | TDD red-green cycle |
| **1** | Domain + Application | 1s | Development (rapid feedback) |
| **2** | + Infrastructure | 81s | Pre-commit (infra layer changed) |
| **3** | + Integration | 1m 30s | Phase gate (baseline) |
| **4** | Full suite + E2E | 7m 40s | PR gate, nightly only |

Use `test-selector` agent to auto-select minimum tier based on `git diff`.

## Risk-Tiered Verification

| Tier | Additional Gates |
|------|------------------|
| `SECURITY-CRITICAL` | Security audit + manual approval |
| `STANDARD` / absent | Standard gates only |

Assign `SECURITY-CRITICAL` for: auth, crypto, secrets, PII, payments, input sanitization, infra security.

### SECURITY-CRITICAL Routing

When a task is `SECURITY-CRITICAL`:
1. **Pre-implementation**: `domain-reviewer` agent (domain=security) produces a threat assessment before code is written
2. **Post-implementation**: `domain-reviewer` agent (domain=security) performs a code review after implementation
3. **Manual approval**: Pause for explicit user sign-off before marking the task complete

## Enforcement

1. **NO SKIPPING** - every gate must run
2. **PROOF REQUIRED** - paste actual output
3. **BUILD FIRST** - then other gates (parallel OK)
4. **FIX BEFORE PROCEED** - targeted `--filter` first, then re-run all
5. **COMMIT AFTER GATES** - only commit passing code
6. **ZERO TOLERANCE** - all failures are your responsibility (fix, track via `/mad-spec`, or add skip logic)

### Windows Stdout Note
On Windows, shell script stdout may not be captured by Bash tool. If a quality gate silently returns empty output:
```bash
# Redirect to file and read back
powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1 > .mad/scratch/gates-output.txt 2>&1
cat .mad/scratch/gates-output.txt
```
