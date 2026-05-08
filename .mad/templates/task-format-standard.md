---
description: 'Standard task format balancing token efficiency with context richness'
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (recommended), data-model.md, contracts/

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description with File Path`

### Standard Task Structure

Every task MUST include:

1. **Checkbox and ID**: `- [ ] T001`
2. **Markers**: `[P]` for parallel, `[USX]` for user story
3. **File path**: Exact filename in description
4. **Context fields** (indented with `-`):
   - **Functionality**: What this task does (1 sentence)
   - **Purpose**: Why this task is needed (1 sentence)
   - **Progression**: Step-by-step flow (brief bullet points or arrow flow)
   - **Success criteria**: How to verify it works (deterministic gate)

### Example Task Format

```markdown
#### API Tasks

- [ ] T052 [US1] Create POST /api/sessions/join endpoint in backend/src/routes/sessions.ts
  - **Functionality**: Validates invite code, creates participant record, returns session data
  - **Purpose**: Backend handler for session join requests
  - **Progression**: Validate JWT → lookup session by code → check capacity → create participant → return session
  - **Success criteria**: Returns 201 with session data, participant created in DB
```

### Section Headers

Tasks MUST be organized under these section headers where applicable:

- **UI Tasks**: Frontend/client work
- **API Tasks**: Backend/server endpoints
- **Infrastructure Tasks**: Servers, middleware, orchestration
- **Shared Tasks**: Code used by multiple layers
- **Database Tasks**: Schema, migrations
- **Test Tasks**: Testing

---

## Phase 1: Setup

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project structure per implementation plan
  - **Functionality**: Initialize directory structure and configuration files
  - **Purpose**: Establish foundation for all subsequent work
  - **Progression**: Create directories → copy templates → initialize git
  - **Success criteria**: Directory structure matches plan.md, git initialized

- [ ] T002 Initialize [language] project with [framework] dependencies
  - **Functionality**: Install runtime, framework, and core dependencies
  - **Purpose**: Enable development environment setup
  - **Progression**: Install runtime → create package manifest → install dependencies
  - **Success criteria**: Dependencies installed, build succeeds

---

## Phase 2: Foundational

**Purpose**: Core infrastructure that MUST be complete before user stories

- [ ] T004 Setup database schema and migrations framework
  - **Functionality**: Create migration system and initial schema
  - **Purpose**: Enable data persistence for all features
  - **Progression**: Install migration tool → create initial migration → apply migration
  - **Success criteria**: Database exists, schema applied, migrations run

- [ ] T005 [P] Implement authentication/authorization framework
  - **Functionality**: Create auth middleware and token validation
  - **Purpose**: Secure API endpoints
  - **Progression**: Create middleware → integrate JWT library → add to routes
  - **Success criteria**: Protected endpoints require valid token

- [ ] T006 [P] Setup API routing and middleware structure
  - **Functionality**: Configure HTTP server with routing and middleware chain
  - **Purpose**: Handle incoming requests with logging, auth, error handling
  - **Progression**: Create server → add middleware stack → configure routes
  - **Success criteria**: Server starts, health endpoint returns 200

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - [Title] (Priority: P1)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create [Entity1] model in src/models/[entity1].ts
  - **Functionality**: Define data structure and validation rules
  - **Purpose**: Represent [entity] in application
  - **Progression**: Define interface → add validation → export type
  - **Success criteria**: Type compiles, validation enforces constraints

- [ ] T013 [P] [US1] Create [Entity2] model in src/models/[entity2].ts
  - **Functionality**: Define data structure and relationships
  - **Purpose**: Represent [entity] in application
  - **Progression**: Define interface → add relationships → export type
  - **Success criteria**: Type compiles, relationships defined

- [ ] T014 [US1] Implement [Service] in src/services/[service].ts
  - **Functionality**: Business logic for [feature]
  - **Purpose**: Handle [operation] requests
  - **Progression**: Create class → implement methods → add error handling
  - **Success criteria**: Service methods complete, errors handled

- [ ] T015 [US1] Implement [endpoint/feature] in src/[location]/[file].ts
  - **Functionality**: Expose [operation] via API/UI
  - **Purpose**: Enable users to [action]
  - **Progression**: Create handler → integrate service → add validation
  - **Success criteria**: Endpoint/feature works end-to-end

**Checkpoint**: User Story 1 fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Implementation for User Story 2

- [ ] T020 [P] [US2] Create [Entity] model in src/models/[entity].ts
  - **Functionality**: Define data structure
  - **Purpose**: Represent [entity] in application
  - **Progression**: Define interface → add validation → export type
  - **Success criteria**: Type compiles, validation works

- [ ] T021 [US2] Implement [Service] in src/services/[service].ts
  - **Functionality**: Business logic for [feature]
  - **Purpose**: Handle [operation] requests
  - **Progression**: Create class → implement methods → add error handling
  - **Success criteria**: Service methods complete

- [ ] T022 [US2] Implement [endpoint/feature] in src/[location]/[file].ts
  - **Functionality**: Expose [operation] via API/UI
  - **Purpose**: Enable users to [action]
  - **Progression**: Create handler → integrate service → add validation
  - **Success criteria**: Endpoint/feature works

**Checkpoint**: User Stories 1 AND 2 both work independently

---

[Add more user story phases as needed]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements affecting multiple user stories

- [ ] T030 [P] Documentation updates in docs/
  - **Functionality**: Update user documentation and API docs
  - **Purpose**: Ensure documentation reflects implementation
  - **Progression**: Review features → update docs → validate examples
  - **Success criteria**: Documentation accurate and complete

- [ ] T031 Run quickstart.md validation
  - **Functionality**: Execute verification commands from quickstart
  - **Purpose**: Validate all acceptance criteria met
  - **Progression**: Run each command → verify output → document results
  - **Success criteria**: All quickstart commands pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Final Phase)**: Depends on all user stories being complete

### User Story Dependencies

- User Story 1: Can start after Foundational - no dependencies on other stories
- User Story 2: Can start after Foundational - may integrate with US1 but independently testable
- User Story 3: Can start after Foundational - may integrate with US1/US2 but independently testable

### Parallel Opportunities

- All Setup tasks marked `[P]` can run in parallel
- All Foundational tasks marked `[P]` can run in parallel
- Once Foundational complete, all user stories can start in parallel (if team capacity allows)
- Models within a story marked `[P]` can run in parallel

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. STOP and VALIDATE: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Each story adds value without breaking previous stories

---

## Quality Gates (Per User Story)

After implementing each user story, run these gates before proceeding:

### Build Gate

- [ ] Run build command from project CLAUDE.md
  - **Success criteria**: Exit code 0, no compilation errors

### Test Gate

- [ ] Run test command from project CLAUDE.md
  - **Success criteria**: All tests pass, 0 failures

### Coverage Gate (if configured)

- [ ] Run coverage command from project CLAUDE.md
  - **Success criteria**: Coverage >= threshold (typically 80%+)

### Lint/Format Gate

- [ ] Run lint command from project CLAUDE.md
  - **Success criteria**: Exit code 0, no errors (warnings OK)

**Commit after all gates pass**

---

## Markers Explained

- **[P]**: Can run in parallel (different files, no dependencies)
- **[USX]**: User story identifier (US1, US2, US3, etc.)
- File paths must be exact and absolute where possible

---

## Common Task Patterns

### Data Layer Pattern

```markdown
- [ ] TXXX [P] [USX] Create [Entity] model in src/models/[entity].ts
  - **Functionality**: Define data structure with validation
  - **Purpose**: Represent [domain concept] in application
  - **Progression**: Define interface → add validation → add relationships
  - **Success criteria**: Type compiles, validation rules enforce constraints
```

### Service Layer Pattern

```markdown
- [ ] TXXX [USX] Implement [Feature]Service in src/services/[feature].service.ts
  - **Functionality**: Business logic for [feature operations]
  - **Purpose**: Coordinate data access and business rules
  - **Progression**: Create class → implement CRUD methods → add error handling
  - **Success criteria**: Service methods complete, errors propagated correctly
```

### API Endpoint Pattern

```markdown
- [ ] TXXX [USX] Create POST /api/[resource] endpoint in src/routes/[resource].ts
  - **Functionality**: Handle [resource] creation requests
  - **Purpose**: Expose [operation] to clients
  - **Progression**: Add route → validate input → call service → return response
  - **Success criteria**: Returns 201 on success, 400/500 on errors
```

### UI Component Pattern

```markdown
- [ ] TXXX [P] [USX] Create [Component] in src/components/[feature]/[Component].tsx
  - **Functionality**: Display [UI element] with user interactions
  - **Purpose**: Enable users to [action]
  - **Progression**: Create component → add state management → handle events → style
  - **Success criteria**: Component renders, handles user input, updates state
```

---

## Template Selection Guide

### Use MINIMAL format when:

- Simple infrastructure tasks (Docker, CI/CD, config files)
- Small bug fixes affecting 1-2 files
- Configuration changes without behavior impact
- Documentation updates

### Use STANDARD format when:

- Feature development with clear user stories
- API endpoint implementation
- Database schema changes
- Most application development tasks

### Use FULL format when:

- Complex interactive workflows with multiple failure paths
- Features requiring detailed intake/output documentation
- Multi-system integration tasks
- Critical user-facing features with extensive error handling

---

## Notes

- `[P]` tasks = different files, no dependencies
- `[Story]` label maps task to user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Run quality gates after each user story phase
- File paths should be specific (not vague like "update files")
- Success criteria must be deterministic (observable, testable)
