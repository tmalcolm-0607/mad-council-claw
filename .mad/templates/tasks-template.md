---
description: 'Task list template for feature implementation'
deprecated: true
replacement: 'Use task-format-minimal.md, task-format-standard.md, and task-format-full.md for tiered task formats'
---

# Tasks: [FEATURE NAME]

**DEPRECATION NOTICE**: This template is deprecated in favor of the tiered task format system. See `.mad/templates/task-format-minimal.md`, `.mad/templates/task-format-standard.md`, and `.mad/templates/task-format-full.md` for the current format definitions.

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: The examples below include test tasks. Tests are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description with Enhanced Context`

### Task Structure Requirements

Every task MUST include:

1. **Checkbox and ID**: `- [ ] T001`
2. **Markers**: `[P]` for parallel, `[USX]` for user story
3. **Subject**: An **outcome** the user can observe, NOT a code change. "Team page displays real members" not "Wire Team.tsx to teamApi"
4. **Context fields** (below the main line, indented with `-`):
   - **Functionality**: What this task does (1 sentence)
   - **Verify**: A concrete command the orchestrator runs after implementation to prove the outcome works. This is the most important field - if you can't write a verify command, the task is too vague.
   - **Success criteria**: User-observable outcome that proves the task is done
   - **Intake**: What inputs/state/preconditions are required to start
   - **Failure handling**: How each failure mode is handled (REQUIRED for interactive tasks)
   - **Connects to**: What tasks/workflows this enables or depends on
   - **Risk Tier**: `SECURITY-CRITICAL` or `STANDARD` (optional -- see [risk-tiered verification guide](../../.claude/docs/risk-tiered-verification-guide.md))

**CRITICAL - Task Subjects Must Be Outcomes**:

| BAD (code-centric) | GOOD (outcome-centric) |
|---------------------|----------------------|
| Wire Team.tsx to real teamApi | Team page displays real team members |
| Replace mock imports with real API calls | Case list loads data from backend on page refresh |
| Add error boundary component | App shows friendly error page when component crashes |
| Install Tailwind CSS | All pages render with correct styling |
| Create Redux slice for users | User profile displays current user's name and email |

### Intake/Success/Failure Requirements (MANDATORY)

**CRITICAL**: Every task that involves user interaction, API calls, CLI commands, game actions, or state changes MUST define:

#### Intake (Prerequisites)
- What data/state must exist before this task can execute
- What triggers this task to start
- What validation happens on inputs

#### Success Path
- What state changes when task succeeds
- What events are emitted
- What user feedback is shown (UI, CLI output, game state)

#### Failure Handling (REQUIRED for all interactive tasks)

**Universal failure categories** (apply to ALL application types):

| Category | Web App | CLI App | Game | Library |
|----------|---------|---------|------|--------|
| **Input validation** | Form errors | Invalid args | Bad input | Invalid parameters |
| **Resource/state error** | 404/409 | File missing | Illegal state | Key not found |
| **System failure** | 500/exception | Exit code != 0 | Crash | Throws exception |
| **External dependency** | Network/timeout | Service down | Disconnect | Dependency failure |

At minimum, document handling for 3 categories:
- **Validation failure**: Invalid input, missing required fields, bad arguments
- **Resource/state errors**: Not found, conflict, illegal state, constraint violation
- **System/external failures**: Exceptions, timeouts, network errors, dependencies

For each failure, specify:
- User-visible message
- Recovery action (retry, redirect, fallback)
- State cleanup (if any)

#### Connections
- **Receives from**: What must complete before this starts
- **Emits to**: What can start after this completes
- **Parallel with**: What runs concurrently

### Complete Workflow Definition (Inline)

Every interactive task MUST define its complete workflow INLINE (no external references):

```yaml
# Inline in task under "Failure handling" and "Connects to" fields
intake:
  trigger: "Event/action that starts this"
  preconditions: ["State that MUST be true"]
  inputs: [{name, type, validation}]

success_path:
  steps: ["action -> output -> next"]
  final_state: "What changes when complete"
  emits: "Events broadcast to other systems"

failure_paths:
  - validation: "Invalid input -> show error, preserve data"
  - not_found: "Resource missing -> toast, offer alternatives"
  - system_error: "Exception/crash -> log, offer retry"
  - timeout: "Too slow -> cancel, offer retry"

connections:
  receives_from: "Previous task/workflow"
  emits_to: "Next task/workflow"
```

**Workflow Validation Checklist** (verify before task is complete):
- [ ] Intake defined: trigger, preconditions, inputs
- [ ] All inputs validated with rules
- [ ] Success path: steps, final state, events
- [ ] 3+ failure categories covered with recovery
- [ ] User feedback for each failure
- [ ] Connections: receives_from and emits_to defined
- [ ] Timeouts specified for blocking operations

### Section Headers

Tasks MUST be organized under these section headers where applicable:

#### **UI Tasks** (for frontend/client work)

Tasks that run in the browser or mobile app

#### **API Tasks** (for backend/server work)

Tasks for REST endpoints, GraphQL resolvers, gRPC services

#### **Infrastructure Tasks** (for servers/orchestration)

Tasks for servers, middleware, queues, orchestration layers

#### **Shared Tasks** (for code used by both UI and API)

Tasks for utilities, types, schemas used across layers

#### **Database Tasks** (for schema/migrations)

Tasks for database schemas, migrations, seed data

#### **Test Tasks** (for testing)

Tasks for unit tests, integration tests, E2E tests

### Example Task Format (Outcome-Based with Verify)

```markdown
#### UI Tasks

- [ ] **T051** [US1]: Player can join a session via invite code
  - **Functionality**: Join session form at /sessions/join - validates code, calls API, navigates to lobby
  - **Verify**: `curl -s -X POST localhost:3001/api/sessions/join -H "Authorization: Bearer $TOKEN" -d '{"invite_code":"ABC123"}' | jq '.id'` returns a session ID
  - **Success criteria**: Player sees lobby with session details; page reload preserves session membership
  - **Intake**: Authenticated user, valid invite code from another player
  - **Failure handling**:
    - Invalid format - inline error "Code must be 6 characters"
    - 404 - toast "Session not found"
    - 409 (full) - toast "Session full (max 6 players)"
    - 5xx - toast "Server error", retry button
  - **Connects to**: Receives from authentication, emits to lobby/character_creation

#### API Tasks

- [ ] **T052** [US1]: Session join endpoint returns 201 with session data
  - **Functionality**: POST /api/sessions/join - validates invite code, creates participant, returns session
  - **Verify**: `curl -s -o /dev/null -w "%{http_code}" -X POST localhost:3001/api/sessions/join -H "Authorization: Bearer $TOKEN" -d '{"invite_code":"ABC123"}'` returns 201
  - **Success criteria**: Participant record exists in DB after join; GET /api/sessions returns the joined session
  - **Intake**: Valid JWT, invite_code in request body
  - **Failure handling**:
    - Missing JWT - 401
    - Invalid code format - 400
    - Session not found - 404
    - Session full - 409
  - **Connects to**: Receives from auth middleware, emits participant.joined event
  - **Risk Tier**: SECURITY-CRITICAL

#### Risk Tier Example

- [ ] **T053** [US1]: Auth token validation middleware rejects expired tokens
  - **Functionality**: JWT validation middleware checks expiry, signature, and issuer claims
  - **Verify**: `curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer EXPIRED_TOKEN" localhost:3001/api/sessions` returns 401
  - **Success criteria**: Expired/invalid tokens return 401; valid tokens pass through to handler
  - **Risk Tier**: SECURITY-CRITICAL

- [ ] **T054** [US1]: Session list page renders sessions in a table
  - **Functionality**: React component fetches and displays user's sessions
  - **Verify**: `curl -s localhost:3000 | grep 'session-list'` returns matching HTML
  - **Success criteria**: Page renders session names, dates, and player counts
  - **Risk Tier**: STANDARD
```

### Old Example Format (DEPRECATED - do not use)

```markdown
# BAD: Code-centric subject, no Verify command
- [ ] T051 Install React Router v6 and configure browser router in src/main.tsx
- **Functionality**: Client-side routing for single-page navigation
- **Success criteria**: Navigation between views works

# BAD: Code-centric subject "Wire X to Y"
- [ ] T052 Wire Team.tsx to real teamApi
- **Functionality**: Replace mock imports with real API calls
- **Success criteria**: Build passes, no type errors
```

### Markers Explained

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /mad-tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize [language] project with [framework] dependencies
- [ ] T003 [P] Configure linting and formatting tools

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks (adjust based on your project):

- [ ] T004 Setup database schema and migrations framework
- [ ] T005 [P] Implement authentication/authorization framework
- [ ] T006 [P] Setup API routing and middleware structure
- [ ] T007 Create base models/entities that all stories depend on
- [ ] T008 Configure error handling and logging infrastructure
- [ ] T009 Setup environment configuration management
- [ ] T010 Configure ESLint with quality rules in eslint.config.js
- [ ] T011 Add pre-commit hooks for automated quality checks

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

### Phase 2 Quality Gates (BLOCKING)

**MANDATORY: Complete ALL gates before proceeding. Paste actual command output as proof.**

- [ ] **GATE-2.1**: Build Verification
  - Command: `npm run build`
  - Required: Exit code 0, no errors
  - Proof: [PASTE BUILD OUTPUT]

- [ ] **GATE-2.2**: Test Execution
  - Command: `npm test`
  - Required: All tests pass (X passed, 0 failed)
  - Proof: [PASTE TEST OUTPUT]

- [ ] **GATE-2.3**: Docker Deployment (if applicable)
  - Command: `docker compose up -d && curl localhost:3001/api/v1/health`
  - Required: Health check returns {"status":"healthy"}
  - Proof: [PASTE HEALTH CHECK OUTPUT]

- [ ] **GATE-2.4**: Commit Phase 2
  - Command: `git commit -m "feat: complete Phase 2 - [description]

    Gate Results:
    - Build: PASS
    - Tests: X passed, 0 failed
    - Docker: healthy"`
  - Required: Commit includes gate results

---

## Phase 3: User Story 1 - [Title] (Priority: P1) MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1 (OPTIONAL - only if tests requested)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Contract test for [endpoint] in tests/contract/test\_[name].py
- [ ] T011 [P] [US1] Integration test for [user journey] in tests/integration/test\_[name].py

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create [Entity1] model in src/models/[entity1].py
- [ ] T013 [P] [US1] Create [Entity2] model in src/models/[entity2].py
- [ ] T014 [US1] Implement [Service] in src/services/[service].py (depends on T012, T013)
- [ ] T015 [US1] Implement [endpoint/feature] in src/[location]/[file].py
- [ ] T016 [US1] Add validation and error handling
- [ ] T017 [US1] Add logging for user story 1 operations

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

### User Story 1 Quality Gates (BLOCKING)

**MANDATORY: Complete ALL gates before proceeding to next user story.**

- [ ] **GATE-US1.1**: Build Verification
  - Command: `npm run build`
  - Required: Exit code 0, no errors
  - Proof: [PASTE BUILD OUTPUT]

- [ ] **GATE-US1.2**: Test Execution
  - Command: `npm test`
  - Required: All tests pass (X passed, 0 failed)
  - Proof: [PASTE TEST OUTPUT]

- [ ] **GATE-US1.3**: Coverage Check (if configured)
  - Command: `npm run test:coverage`
  - Required: Coverage >= 80%
  - Proof: [PASTE COVERAGE SUMMARY]

- [ ] **GATE-US1.4**: E2E Tests (for UI stories)
  - Command: `npm run test:e2e`
  - Required: All scenarios pass
  - Proof: [PASTE E2E OUTPUT]

- [ ] **GATE-US1.5**: Commit User Story 1
  - Command: Include gate results in commit message
  - Required: `git commit -m "feat(US1): [description]

    Gate Results:
    - Build: PASS
    - Tests: X passed, 0 failed
    - Coverage: X%"`

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2 (OPTIONAL - only if tests requested)

- [ ] T018 [P] [US2] Contract test for [endpoint] in tests/contract/test\_[name].py
- [ ] T019 [P] [US2] Integration test for [user journey] in tests/integration/test\_[name].py

### Implementation for User Story 2

- [ ] T020 [P] [US2] Create [Entity] model in src/models/[entity].py
- [ ] T021 [US2] Implement [Service] in src/services/[service].py
- [ ] T022 [US2] Implement [endpoint/feature] in src/[location]/[file].py
- [ ] T023 [US2] Integrate with User Story 1 components (if needed)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 3 (OPTIONAL - only if tests requested)

- [ ] T024 [P] [US3] Contract test for [endpoint] in tests/contract/test\_[name].py
- [ ] T025 [P] [US3] Integration test for [user journey] in tests/integration/test\_[name].py

### Implementation for User Story 3

- [ ] T026 [P] [US3] Create [Entity] model in src/models/[entity].py
- [ ] T027 [US3] Implement [Service] in src/services/[service].py
- [ ] T028 [US3] Implement [endpoint/feature] in src/[location]/[file].py

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Documentation updates in docs/
- [ ] TXXX Code cleanup and refactoring
- [ ] TXXX Performance optimization across all stories
- [ ] TXXX [P] Additional unit tests (if requested) in tests/unit/
- [ ] TXXX Security hardening
- [ ] TXXX Run quickstart.md validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 -> P2 -> P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (if tests requested):
Task: "Contract test for [endpoint] in tests/contract/test_[name].py"
Task: "Integration test for [user journey] in tests/integration/test_[name].py"

# Launch all models for User Story 1 together:
Task: "Create [Entity1] model in src/models/[entity1].py"
Task: "Create [Entity2] model in src/models/[entity2].py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Test independently -> Deploy/Demo (MVP!)
3. Add User Story 2 -> Test independently -> Deploy/Demo
4. Add User Story 3 -> Test independently -> Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
