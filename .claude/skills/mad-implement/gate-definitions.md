# Quality Gate Definitions

Detailed gate definitions for mad-implement Step 10. All gate commands come from the project's CLAUDE.md "Commands" or "Quality Gates" section.

## Gate 1: Build Verification (BLOCKING)

Run the project's build command. Paste FULL output as proof.

```
[PASTE ACTUAL BUILD OUTPUT HERE]
```

**Required**: Output must show successful compilation.
**If FAIL**: Fix errors and re-run. Do NOT proceed.

## Gate 2: Test Execution (BLOCKING)

Run the project's FULL test command at phase gates. Paste output as proof.

```
[PASTE ACTUAL TEST OUTPUT HERE - must show "X passed, 0 failed"]
```

**Required**: ALL tests must pass with visible count.

**If FAIL — Graduated Recovery (MANDATORY)**:
1. Parse the failing test name(s) from output
2. Re-run ONLY failing test(s): `dotnet test tests/<Project>.Tests --filter "FullyQualifiedName~<FailingTest>"`
3. Fix and re-run targeted test until GREEN
4. Run affected test project: `dotnet test tests/<Project>.Tests`
5. Then re-run full suite ONCE to confirm no regressions

**DO NOT**: Re-run the full test suite repeatedly while debugging a single failure.

## Gate 3: Coverage Check (BLOCKING if configured)

Run the project's coverage command (if available).

```
[PASTE COVERAGE SUMMARY - must show >= 80%]
```

**Required**: Coverage >= 80% on all metrics.
**If FAIL**: Add tests. Do NOT proceed.

## Gate 4: Deployment Health (BLOCKING if docker/deployment exists)

Run deployment + health check commands.

```
[PASTE HEALTH CHECK RESPONSE - must show "healthy"]
[PASTE LOG TAIL - must show no errors]
```

**If FAIL**: Debug and fix. Do NOT proceed.

## Gate 5: E2E/Integration Tests (BLOCKING for UI phases)

Run E2E test command.

```
[PASTE E2E TEST OUTPUT - must show all scenarios passed]
```

**If FAIL**: Fix scenarios. Do NOT proceed.

## Gate 6: Code Quality Checks

Run linting and static analysis commands.

```
[PASTE LINT/STATIC ANALYSIS OUTPUT]
```

## Gate 7: API URL Consistency (frontend/backend projects)

Verify all frontend API calls use consistent URL prefixes matching backend mount point. REJECT if mixed prefixes found.

```
[PASTE API URL CHECK OUTPUT - must show consistent prefixes]
```

## Gate 8: Environment/CORS Configuration (if deployment config exists)

Verify environment variables and CORS origins. REJECT if required env vars missing.

```
[PASTE ENVIRONMENT CONFIG CHECK OUTPUT]
```

## Gate 9: Test Plan Verification (if verify script exists)

Check whether the feature's verification script passes. Conditional blocking based on implementation phase.

**Slug Derivation**:
1. Read `.claude/work-items/ACTIVE` to get work item ID
2. Read `.claude/work-items/{WI-ID}/manifest.json` → `spec_directory` field
3. Take the last path segment as the slug (e.g., `specs/002-unified-testplan` → `unified-testplan`)

**If no script at `.mad/scratch/verify-{slug}.sh`**: WARN and skip (non-blocking).

**Phase 1** (first implementation phase):
```
bash .mad/scratch/verify-{slug}.sh
```
FAIL result = NON-BLOCKING — document failure count as expected baseline (tests are supposed to fail before implementation).

**Phase 2+**:
```
bash .mad/scratch/verify-{slug}.sh
```
Any FAIL = BLOCKING. Report count and halt phase. Fix required before proceeding.

```
[PASTE VERIFY SCRIPT OUTPUT]
Results: N passed, M failed
```

## Gate Summary Template

Complete after running all gates:

```markdown
## Phase [N] Gate Results

| Gate | Command | Result | Proof |
|------|---------|--------|-------|
| Build | [build command] | ✅/❌ | [output] |
| Tests | [test command] | ✅/❌ | [X passed, 0 failed] |
| Coverage | [coverage command] | ✅/❌/N/A | [X%] |
| Deploy | [health check] | ✅/❌/N/A | [healthy] |
| E2E | [e2e command] | ✅/❌/N/A | [X passed] |
| Lint | [lint command] | ✅/❌ | [no errors] |
| API URLs | consistency check | ✅/❌ | [consistent] |
| Environment | config check | ✅/❌/N/A | [vars set] |

**Overall: [PASS/FAIL]**
```

**If test gate ❌**: STOP. Fix using Graduated Recovery (see Gate 2). Then re-run ALL gates once.
**If other gate ❌**: STOP. Fix. Re-run ALL gates.
**If ALL gates ✅**: Proceed to commit.

## Trust-But-Verify Protocol (MANDATORY after gates)

Agent claims are INPUT, not PROOF. After gates report success, independently verify:

1. **Build**: Verify output contains no "error" strings (not just exit code)
2. **Tests**: Verify actual test count is reasonable (not 0)
3. **Coverage**: Verify report file was updated recently
4. If any verification fails → Return to fix phase, do NOT proceed

See `.claude/rules/trust-but-verify.md` for full protocol.

## Atomic Commit (after ALL gates + verification pass)

```bash
git add .
git commit -m "feat: complete phase N - [description]

Gate Results:
- Build: ✅ (verified: 0 errors in output)
- Tests: X passed, 0 failed (verified: X tests ran)
- Coverage: X% (verified: report updated)
- Docker: healthy
- E2E: X passed"
```
