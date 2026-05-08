# Quality Gates

After EACH user story or phase, execute gates with ACTUAL OUTPUT as proof.

> **Note on coverage:** the "100% diff coverage" target below is a **kit-internal policy**, not a canonical LENS pipeline gate. Canonical LENS pipelines (per `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/rules/pipeline-standards-catalog.md`) gate ring promotion on **Managed SDP bake times + `ManualValidation@0` + 5-stage region progression**, NOT on coverage thresholds. Adopt or override the kit's diff-coverage stance per consumer project.

## Gates

| Gate | Purpose | Success Criteria |
|------|---------|------------------|
| Build | Compile/transpile code | Exit 0, no errors |
| Test | Run unit/integration tests | All pass, 0 failed |
| Coverage | Measure code coverage | 100% diff coverage |
| Lint/Format | Check code style | Exit 0, no errors |
| Security | Check for vulnerabilities | No high/critical issues |
| Pre-flight | Mechanical grep-based checks | `.claude/scripts/Check-Preflight.ps1` |
| WAF Audit | Semantic WAF rule check (when Front Door Bicep changes) | CRITICAL/HIGH findings block merge; manual fix PR required |
| Docs Accuracy | Source-vs-doc validation (when API surface changes) | docs-review findings block merge until docs are accurate |

Run all: `powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1`
E2E: `powershell.exe -NoProfile -File .claude/scripts/Test-E2E-ACI.ps1 -Environment tonym`

### Local Diff Coverage

Use `Measure-DiffCoverage.ps1` for local diff-coverage checks against the kit's 100% diff target:

```powershell
powershell.exe -NoProfile -File .claude/scripts/Measure-DiffCoverage.ps1
```

> **ADO is the source of truth.** Local diff coverage is systematically lower than ADO's because ADO counts ALL changed executable lines (including files not present in any coverage XML), while the local script only counts files actually present in the coverage XMLs. Always check the ADO PR's "Update N" coverage tab before claiming the kit's 100% diff target is met. Zero-covered files appear in ADO but are invisible to the local measure.

## 5-Tier Progressive Validation

| Tier | Scope | Expected Time | Use Case |
|------|-------|---------------|----------|
| **0** | Single test (`--filter`) | <1s | TDD red-green cycle |
| **1** | Domain + Application | 1s | Development (rapid feedback) |
| **2** | + Infrastructure + API-surface docs-review + WAF audit (when WAF Bicep changes) | ~81s + ~2-5 min on API-surface PRs / WAF Bicep changes | Pre-commit (infra layer changed) |
| **3** | + Integration | 1m 30s | Phase gate (baseline) |
| **4** | Full suite + E2E | 7m 40s | PR gate, nightly only |

Use `test-selector` agent to auto-select minimum tier based on `git diff`.

## Skills Triggered Per Path

| File-change pattern | Skill triggered | Mode |
|---|---|---|
| `**/Controllers/**/*.cs`, `**/*Dto.cs`, `**/Enums/**/*.cs`, `**/Models/**/*.cs`, `**/Repositories/**Repository.cs` | `/lens-docs:docs-review {service}` | read-only; auto-trigger at Tier 2 |
| `**/*{frontdoor,waf,FrontDoor,Waf,WAF}*.bicep` + any `.bicep`/`.json` containing `FrontDoorWebApplicationFirewallPolicies` | `/lens-waf-audit:waf-audit --path <scan-root>` | read-only; auto-trigger at Tier 2; CRITICAL/HIGH findings block merge; **NEVER auto-apply fix snippets** |
| Source-vs-doc accuracy gap surfaced by `docs-review` | `/lens-docs:lens-docs sync {service}` | mutating; **manual-only** — operator invokes explicitly |

### Operator policy

- `lens-docs:lens-docs` (mutating actions: `create`/`update`/`sync`): invoked manually only. Never auto-triggered. Commits to LENS-Docs repo go through normal PR review.
- `lens-waf-audit:waf-audit --fix`: display-only output. Operator manually creates a separate WAF-fix PR. Never auto-applied.
- Disable per skill via env flag in `.claude/settings.local.json`: `AUTO_DOCS_REVIEW_ENABLED=false` or `AUTO_WAF_AUDIT_ENABLED=false`.

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
