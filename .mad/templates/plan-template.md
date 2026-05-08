# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/mad-plan` command. See `.mad/templates/commands/plan.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]  
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]  
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]  
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]  
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [single/web/mobile - determines source structure]  
**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]  
**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]  
**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

[Gates determined based on constitution file]

## Pattern Compliance

<!--
  This section is populated by /mad-plan based on patterns from spec.md.
  Each applicable pattern is validated against the plan.

  Status values:
  - ✓ PASS: Plan complies with pattern requirements
  - ⚠ WARN: Verify compliance during implementation
  - ✗ REJECT: Plan violates pattern - must be fixed before proceeding
-->

### Validated Patterns

| Pattern | Check | Status |
|---------|-------|--------|
| _Load from spec's Applicable Patterns section_ | _Pattern-specific validation_ | _✓/⚠/✗_ |

### Pattern-Specific Requirements

<!--
  Extract key requirements from each applicable pattern file.
  Reference pattern file and line numbers for enforcement.
-->

- **[Pattern Name]**: [Key constraint from pattern file]
- **[Pattern Name]**: [Key constraint from pattern file]

_If no patterns applicable: "No technology-specific patterns detected for this feature."_

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/mad-plan command output)
├── research.md          # Phase 0 output (/mad-plan command)
├── data-model.md        # Phase 1 output (/mad-plan command)
├── quickstart.md        # Phase 1 output (/mad-plan command)
├── contracts/           # Phase 1 output (/mad-plan command)
└── tasks.md             # Phase 2 output (/mad-tasks command - NOT created by /mad-plan)
```

### Source Code (repository root)

<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Infrastructure & Integration Points

<!--
  CRITICAL: If spec mentions APIs, data storage, authentication, or multi-user features,
  this section MUST explicitly list the infrastructure components needed.
-->

### Required Infrastructure

**Presentation Layer** (if feature has user interface):

- [ ] UI framework/toolkit (web, mobile, desktop, CLI framework)
- [ ] Component/module structure and shared elements
- [ ] Navigation/routing (if applicable)
- [ ] Input handling and validation
- [ ] State management (local and global)
- [ ] Error handling and user feedback

**Service Layer** (if feature has endpoints/services):

- [ ] Server/listener setup with routing
- [ ] Request/response handling (REST, gRPC, GraphQL, message queue, etc.)
- [ ] API documentation/contracts

**Data Layer** (if feature persists data):

- [ ] Storage client/connection (database, file system, cache, etc.)
- [ ] Schema management (migrations, versioning)
- [ ] Data lifecycle strategy (if required by compliance/business needs)

**Authentication** (if feature has access control):

- [ ] Auth middleware/guards
- [ ] Credential/session management
- [ ] Permission/authorization checks

**Configuration** (always required):

- [ ] Configuration management (env vars, config files, registries)
- [ ] Feature toggles (if incremental rollout needed)
- [ ] External service configuration (if integrations exist)

**Observability** (always required):

- [ ] Logging infrastructure
- [ ] Error tracking/reporting
- [ ] Health/status monitoring

### Integration Flows

**Module Entry Points**: [How other modules will invoke this feature]
**External Dependencies**: [APIs, services, or data sources this depends on]
**State Management**: [How data flows between components]

**Critical**: Tasks.md Phase 2 MUST include implementation tasks for all checked items above.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
