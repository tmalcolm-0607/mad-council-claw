---
description: 'Task list template for feature implementation'
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: The examples below include test tasks. Tests are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description with Enhanced Context`

### Task Structure Requirements

Every task MUST include:

1. **Checkbox and ID**: `- [ ] T001`
2. **Markers**: `[P]` for parallel, `[USX]` for user story
3. **File path**: Exact filename in description
4. **Context fields** (below the main line, indented with `-`):
   - **Functionality**: What this task does (1 sentence)
   - **Purpose**: Why this task is needed (1 sentence)
   - **Trigger**: What causes this to execute (for UI) or what calls it (for API)
   - **Progression**: Step-by-step flow (brief bullet points or arrow flow)
   - **Success criteria**: How to verify it works (deterministic gate)
   - **Intake**: What inputs/state/preconditions are required to start (NEW - REQUIRED)
   - **Failure handling**: How each failure mode is handled (NEW - REQUIRED for interactive tasks)
   - **Connects to**: What tasks/workflows this enables or depends on (NEW - REQUIRED)

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
  steps: ["action → output → next"]
  final_state: "What changes when complete"
  emits: "Events broadcast to other systems"

failure_paths:
  - validation: "Invalid input → show error, preserve data"
  - not_found: "Resource missing → toast, offer alternatives"
  - system_error: "Exception/crash → log, offer retry"
  - timeout: "Too slow → cancel, offer retry"

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

### Example Task Format (Updated with Intake/Failure/Connections)

```markdown
#### UI Tasks

- [ ] **T051** [US1]: Join session via invite code in frontend/src/components/views/JoinSession.tsx
  - **Functionality**: Form to submit invite code, validates, calls API, navigates on success
  - **Purpose**: Allow players to join existing sessions
  - **Trigger**: User navigates to /sessions/join
  - **Progression**: Render form → validate code → POST /api/sessions/join → navigate to lobby
  - **Success criteria**: User added to session, sees lobby, WebSocket connected
  - **Intake**: Authenticated user (JWT in localStorage), no active session conflict
  - **Failure handling**:
    - Invalid format → inline error "Code must be 6 characters", focus input
    - 404 → toast "Session not found", clear input
    - 409 (full) → toast "Session full (max 6 players)"
    - 409 (conflict) → modal "Leave current session first?"
    - 5xx → toast "Server error", show retry button
    - Network → toast "Connection failed", show retry button
  - **Connects to**: Receives from authentication, emits to world_voting/character_creation

#### API Tasks

- [ ] **T052** [US1]: Create POST /api/sessions/join endpoint in backend/src/routes/sessions.ts
  - **Functionality**: Validates invite code, creates participant record, returns session data
  - **Purpose**: Backend handler for session join requests
  - **Trigger**: POST request from JoinSession form
  - **Progression**: Validate JWT → lookup session by code → check capacity → create participant → return session
  - **Success criteria**: Returns 201 with session data, participant created in DB
  - **Intake**: Valid JWT in Authorization header, invite_code in request body
  - **Failure handling**:
    - Missing/invalid JWT → 401 "Authentication required"
    - Invalid code format → 400 "Invalid invite code format"
    - Session not found → 404 "Session not found"
    - Session full → 409 "Session is full"
    - User already in session → 409 "Already in another session"
    - DB error → 500 with logged error, generic message to client
  - **Connects to**: Receives from auth middleware, emits participant.joined event to WebSocket
```

### Old Example Format (DEPRECATED - do not use)

```markdown
#### UI Tasks

- [ ] T051 Install React Router v6 and configure browser router in src/main.tsx
- **Functionality**: Client-side routing for single-page navigation
- **Purpose**: Enable view transitions without full page reloads
- **Trigger**: Application initialization
- **Progression**: Install dependency → Configure BrowserRouter → Wrap App → Define routes
- **Success criteria**: Navigation between views works, URLs update, back button functional

#### API Tasks

- [ ] T051b Create GET /api/sessions endpoint handler in src/server/routes/sessions.ts
- **Functionality**: Query database for user's sessions and return JSON array
- **Purpose**: Provide session data to frontend hook
- **Trigger**: HTTP GET request from useSessions hook
- **Progression**: Authenticate request → Query sessions table → Filter by user_id → Apply .limit(50) → Return JSON
- **Success criteria**: Returns 200 with Session[], enforces auth, respects RLS, handles errors with 4xx/5xx
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

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

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

**⚠️ MANDATORY: Complete ALL gates before proceeding. Paste actual command output as proof.**

Run gates from project CLAUDE.md "Commands" section. See `mad-implement/gate-definitions.md` for detailed gate definitions.

- [ ] **GATE-2.1**: Build — [BUILD_COMMAND] → Proof: [PASTE OUTPUT]
- [ ] **GATE-2.2**: Tests — [TEST_COMMAND] → Proof: [PASTE OUTPUT]
- [ ] **GATE-2.3**: Deploy (if applicable) — [HEALTH_CHECK] → Proof: [PASTE OUTPUT]
- [ ] **GATE-2.4**: Commit with gate results

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1 (OPTIONAL - only if tests requested) ⚠️

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

**⚠️ MANDATORY: Complete ALL gates before proceeding to next user story.**

Run gates from project CLAUDE.md. See `mad-implement/gate-definitions.md` for details.

- [ ] **GATE-US1.1**: Build — [BUILD_COMMAND] → Proof: [PASTE OUTPUT]
- [ ] **GATE-US1.2**: Tests — [TEST_COMMAND] → Proof: [PASTE OUTPUT]
- [ ] **GATE-US1.3**: Coverage (if configured) — [COVERAGE_COMMAND] → Proof: [PASTE OUTPUT]
- [ ] **GATE-US1.4**: E2E (for UI stories) — [E2E_COMMAND] → Proof: [PASTE OUTPUT]
- [ ] **GATE-US1.5**: Commit with gate results

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2 (OPTIONAL - only if tests requested) ⚠️

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

### Tests for User Story 3 (OPTIONAL - only if tests requested) ⚠️

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
  - Or sequentially in priority order (P1 → P2 → P3)
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

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
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
