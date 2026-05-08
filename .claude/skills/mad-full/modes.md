# mad-full: Modes Reference

This file documents two aspects of mad-full behavior:
1. **Complexity-Based Workflow Depth** (Phase 0): Adaptive pipeline based on feature complexity
2. **Execution Modes**: Interactive, Autonomous, Headless

---

## Part 1: Complexity-Based Workflow Depth

### Overview

Phase 0 of mad-full performs complexity triage to determine the appropriate workflow depth:
- **TRIVIAL**: Skip spec+plan → go straight to tasks+implement (saves ~15 minutes, no research)
- **STANDARD**: Full pipeline with research (spec with `--deep-research` → plan → tasks → implement)
- **COMPLEX**: Full pipeline with deep research (`--deep-research` flag passed to mad-spec and mad-plan)

### Complexity → Phase Mapping

| Complexity | Phases Executed | Skip | Rationale |
|------------|-----------------|------|-----------|
| **TRIVIAL** | 0.5 (worktree) → 3 (tasks) → 4 (implement) → 5 (validate) → 6 (PR) | spec, plan | Simple changes don't need architecture docs |
| **STANDARD** | 0.5 → 1 (spec with `--deep-research`) → 2 (plan) → 3 (tasks) → 4 (implement) → 5 (validate) → 6 (PR) | none | Full pipeline with research for features |
| **COMPLEX** | 0.5 → 1 (spec with `--deep-research`) → 2 (plan with `--deep-research`) → 3 → 4 → 5 → 6 | none | Add research depth for architectural decisions |

### Complexity Detection

**TRIVIAL** indicators:
- Keywords: fix, typo, update, config, tweak, small, minor, bump, patch
- Scope: 1-2 files, configuration only, documentation only
- Examples: "Fix typo in README", "Update version in package.json"

**STANDARD** indicators:
- Keywords: feature, add, implement, create, build, develop
- Scope: New functionality, API endpoints, UI components
- Examples: "Add user authentication with OAuth2", "Implement user profile page"

**COMPLEX** indicators:
- Keywords: architecture, redesign, integration, multi-system, migration, refactor, overhaul, restructure
- Scope: 3+ systems, architectural changes, cross-team impact
- Examples: "Redesign multi-tenant architecture with event sourcing", "Migrate from monolith to microservices"

### User Override Flags

**`--complexity <trivial|standard|complex>`**: Explicitly set complexity level (bypasses automatic detection).

```bash
/mad-full "Add caching" --complexity trivial    # Force skip spec+plan
/mad-full "Fix bug" --complexity standard       # Force full pipeline
/mad-full "New feature" --complexity complex    # Force deep research
```

**`--force-full`**: Always use full pipeline (STANDARD complexity), regardless of detection. Equivalent to `--complexity standard`.

```bash
/mad-full "Fix typo in README" --force-full
```

---

## Part 2: Execution Modes

## Interactive Mode (Default)

```bash
/mad-full "Add user authentication"
```

- Pauses at each phase completion for review
- Shows artifacts created, asks "Proceed to next phase?"
- Shows gate results with actual output
- **When to use**: Normal development, learning the system

## Autonomous Mode

```bash
/mad-full "Add user authentication" --autonomous --max-iterations 30
```

- Runs without user interaction
- Automatically retries on gate failures
- Stops when: all gates pass → PR | max iterations → report | unrecoverable error → save progress
- **When to use**: Overnight runs, well-defined features

## Headless Mode

```bash
/mad-full "Add user authentication" --headless
```

- No interactive prompts, outputs structured JSON
- Designed for CI/CD integration
- **When to use**: GitHub Actions, scheduled jobs

**Output format**:
```json
{
  "success": true,
  "feature": "user-authentication",
  "branch": "2-user-authentication",
  "pr_url": "https://github.com/org/repo/pull/123",
  "duration": "4h 23m",
  "phases": [
    { "name": "specify", "status": "pass", "artifact": "spec.md" },
    { "name": "plan", "status": "pass", "artifact": "plan.md" },
    { "name": "tasks", "status": "pass", "artifact": "tasks.md" },
    { "name": "implement", "status": "pass", "iterations": 8 },
    { "name": "automation", "status": "pass" },
    { "name": "pr", "status": "pass", "url": "..." }
  ],
  "gates": {
    "build": "pass",
    "tests": { "passed": 2502, "failed": 0 },
    "coverage": "85%"
  }
}
```

## Example Session

```
> /mad-full "Add session management with join codes"

Starting MAD Full Pipeline...

Phase 1/6: Specification
──────────────────────────
Invoking /mad-spec...
✓ Created specs/3-session-management/spec.md
✓ Gate: Spec lint passed (0 errors, 2 warnings)

[Checkpoint] Proceed to planning? [Y/n] Y

Phase 2/6: Planning
───────────────────
Invoking /mad-plan...
✓ Created plan.md, contracts/sessions.md, data-model.md
✓ Gate: Constitution check passed

[Checkpoint] Proceed to tasks? [Y/n] Y

Phase 3/6: Task Generation
──────────────────────────
Invoking /mad-tasks...
✓ Created tasks.md (47 tasks across 6 phases)
✓ Gate: All 5 user stories have tasks

[Checkpoint] Proceed to implementation? [Y/n] Y

Phase 4/6: Implementation
─────────────────────────
  Phase 1: Setup ✓ (attempt 1)
  Phase 2: Foundation ✓ (attempt 1)
  Phase 3: US1 ✓ (attempt 2)
  Phase 4: US2 ✓ (attempt 1)
  Phase 5: US3 ✓ (attempt 3)
  Phase 6: Polish ✓ (attempt 1)
Gate: Build ✓ | Tests: 2547 passed, 0 failed | Coverage: 83%

Phase 5/6: Validation → All checks passed
Phase 6/6: Commit & PR → PR #47 created

Pipeline Complete! Total time: 2h 14m
```

## Files Created

- `.mad-progress.json` — Checkpoint file for resume
- `specs/[feature]/` — All artifacts (spec.md, plan.md, tasks.md, etc.)
- Feature implementation files as defined in plan.md

## Cleanup

After PR merge:
```bash
rm .mad-progress.json
git worktree remove "$WORKTREE_PATH"
git branch -d "feature/${FEATURE_NAME}"
```
