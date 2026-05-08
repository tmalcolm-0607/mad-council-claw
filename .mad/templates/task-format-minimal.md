---
description: 'Minimal task format for simple infrastructure tasks (60% token reduction)'
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md

**Organization**: Tasks grouped by phase or category for clear execution order.

## Format: `[ID] Description with File Path`

### Minimal Task Structure

Every task MUST include:

1. **Checkbox and ID**: `- [ ] T001`
2. **Description**: Brief description with exact file path
3. **Success criteria**: How to verify completion

Example:

```markdown
- [ ] T001 Create health endpoint in src/api/health.ts
  - **Success criteria**: Returns 200 with status "healthy"
```

---

## Phase 1: Setup (Infrastructure Foundation)

**Purpose**: Project initialization and configuration

### Project Structure

- [ ] T001 Create project directory structure per implementation plan
  - **Success criteria**: Directories exist, match plan.md specification

- [ ] T002 Initialize [language] project with [framework] and dependencies
  - **Success criteria**: Build succeeds, all dependencies installed

- [ ] T003 [P] Configure development tools (linters, formatters, etc.)
  - **Success criteria**: Tools run successfully, configuration files present

### Configuration Files

- [ ] T004 Create configuration files (.env.example, config.yaml, etc.)
  - **Success criteria**: Configuration files present, documented

- [ ] T005 [P] Setup version control (.gitignore, .gitattributes)
  - **Success criteria**: Repository initialized, ignore rules applied

### Documentation

- [ ] T006 Create initial README.md with setup instructions
  - **Success criteria**: README exists, setup steps documented

- [ ] T007 [P] Create CHANGELOG.md for tracking changes
  - **Success criteria**: CHANGELOG exists, follows Keep a Changelog format

---

## Phase 2: Core Implementation

**Purpose**: Primary feature implementation

### Data Layer

- [ ] T010 Create database schema/migrations in db/migrations/
  - **Success criteria**: Schema created, migrations run successfully

- [ ] T011 [P] Create data models in src/models/
  - **Success criteria**: Models defined, validation rules implemented

### Business Logic

- [ ] T012 Implement core service in src/services/[service].ts
  - **Success criteria**: Service methods complete, error handling present

- [ ] T013 [P] Implement helper utilities in src/utils/
  - **Success criteria**: Utilities tested, reusable across codebase

### API/Interface Layer

- [ ] T014 Create API endpoints in src/api/routes/
  - **Success criteria**: Endpoints respond correctly, validation works

- [ ] T015 [P] Create UI components in src/components/ (if applicable)
  - **Success criteria**: Components render, handle user input

### Integration

- [ ] T016 Wire dependencies via dependency injection/service locator
  - **Success criteria**: Services resolve correctly, no circular dependencies

- [ ] T017 Add error handling and logging
  - **Success criteria**: Errors caught, logs structured and informative

---

## Phase 3: Testing & Verification

**Purpose**: Validate implementation quality

### Build Verification

- [ ] T020 Run build command and verify exit code 0
  - **Success criteria**: Build completes, no compilation errors

- [ ] T021 Run linter and verify no errors
  - **Success criteria**: Linter passes, code style consistent

### Test Execution

- [ ] T022 Run unit tests and verify all pass
  - **Success criteria**: Tests execute, 0 failures

- [ ] T023 [P] Run integration tests and verify all pass
  - **Success criteria**: Integration tests pass, external dependencies mocked or available

### Coverage & Quality

- [ ] T024 Check code coverage meets threshold (typically 80%+)
  - **Success criteria**: Coverage report generated, meets threshold

- [ ] T025 [P] Run security scanner (if configured)
  - **Success criteria**: No high/critical vulnerabilities found

### Manual Verification

- [ ] T026 Execute quickstart commands from quickstart.md
  - **Success criteria**: All commands succeed, expected output observed

- [ ] T027 Verify feature works end-to-end manually
  - **Success criteria**: Feature meets acceptance criteria from spec

---

## Phase 4: Documentation & Polish

**Purpose**: Finalize documentation and prepare for delivery

### Documentation Updates

- [ ] T030 Update README.md with usage examples
  - **Success criteria**: Usage documented, examples accurate

- [ ] T031 [P] Update API documentation (OpenAPI, JSDoc, etc.)
  - **Success criteria**: API docs reflect implementation, examples valid

### Code Cleanup

- [ ] T032 Remove debug code, console.log statements
  - **Success criteria**: No debug artifacts in production code

- [ ] T033 [P] Refactor duplicated code
  - **Success criteria**: DRY principles applied, shared logic extracted

### Deployment Preparation

- [ ] T034 Create deployment configuration (Dockerfile, docker-compose.yml, etc.)
  - **Success criteria**: Deployment config present, tested locally

- [ ] T035 [P] Update CI/CD pipeline configuration
  - **Success criteria**: Pipeline runs successfully, gates pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Implementation (Phase 2)**: Depends on Setup completion
- **Testing (Phase 3)**: Depends on Implementation completion
- **Documentation (Phase 4)**: Depends on Testing completion

### Parallel Opportunities

Tasks marked `[P]` can run in parallel within their phase:
- Phase 1: T003, T005, T007 (different files, no conflicts)
- Phase 2: T011, T013, T015 (independent modules)
- Phase 3: T023, T025 (different test suites)
- Phase 4: T031, T033, T035 (different concerns)

---

## Implementation Strategy

### Sequential Execution

1. Complete Phase 1 (Setup) → verify directory structure and build
2. Complete Phase 2 (Implementation) → verify feature works locally
3. Complete Phase 3 (Testing) → verify all quality gates pass
4. Complete Phase 4 (Documentation) → verify ready for deployment

### Checkpoints

- **After Phase 1**: Project builds successfully
- **After Phase 2**: Feature demonstrates core functionality
- **After Phase 3**: All tests pass, coverage meets threshold
- **After Phase 4**: Documentation complete, ready for deployment

---

## Notes

### When to Use MINIMAL Format

- Simple infrastructure tasks (Docker setup, CI/CD configuration)
- Configuration changes (environment variables, feature flags)
- Small bug fixes (1-2 files changed)
- Refactoring without behavior changes

### When to Use Other Formats

- **STANDARD**: Most feature development (user stories, API endpoints)
- **FULL**: Complex interactive features (workflows with multiple failure paths)

### Format Comparison

| Format | Fields | Line Count | Best For |
|--------|--------|------------|----------|
| MINIMAL | 3 (checkbox, description, success) | ~200 | Infrastructure, config |
| STANDARD | 5 (+ functionality, purpose, progression) | ~300 | Standard features |
| FULL | 8 (+ trigger, intake, failure handling, connections) | ~460 | Complex workflows |

---

## Commit Guidelines

- Commit after each phase completion
- Use conventional commit format: `type(scope): description`
- Reference tasks in commit messages: `feat(api): implement health endpoint (T014)`
- Ensure all quality gates pass before committing

---

## Self-Review Checklist

Before marking tasks.md complete, verify:

- [ ] All tasks have checkbox format `- [ ] T###`
- [ ] All tasks have success criteria
- [ ] File paths are specific and accurate
- [ ] Dependencies are documented
- [ ] Parallel opportunities identified
- [ ] Implementation strategy is clear
