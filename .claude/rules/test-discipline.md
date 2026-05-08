# Test Discipline

## TDD Workflow

Follow Red-Green-Refactor: write/update test first (Red), modify source to pass (Green), refactor.

The TDD advisory hook reminds you when modifying `.cs`/`.ts` source files without recent test changes. It is non-blocking. Disable: `TDD_ADVISORY_ENABLED=false` in `settings.local.json`.

**Excluded from TDD advisory**: `*.md`, `*.json`, `*.yaml`, `*.yml`, `*.tsx` files (explicit exclusion list). All other non-`.cs`/`.ts` extensions (`.xml`, `.csproj`, `.props`, `.sln`, `.css`, etc.) also do not trigger because only `.cs` and `.ts` are in the advisory source-file allowlist. Cooldown: 5 minutes after last advisory (won't repeat for same file within window).

## Test Failure Protocol

**All failures discovered during your work are your responsibility.**

### On Failure

1. **Categorize**: Run tests on main to distinguish regressions vs pre-existing
2. **Regressions**: Fix immediately, verify with `--filter`, re-run full suite
3. **Pre-existing** - choose one:
   - **Fix now** if trivial (<30 min)
   - **Track** via `/mad-spec` bug template
   - **Skip** with `[SkippableFact(Skip = "reason")]`
4. **Report**: State count, categories, actions taken

**FORBIDDEN**: Dismissing failures as "pre-existing/unrelated" without action.

### Infrastructure-Dependent Tests

Use `Skip.If(true, "PostgreSQL/Docker not available")` or `[SkippableFact(Skip = "...")]`. Never let infra tests fail hard.
