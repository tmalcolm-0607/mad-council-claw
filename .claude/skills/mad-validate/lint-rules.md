# mad-validate: Lint Rules Reference

## Rule 1: Required Sections

Check spec.md contains all required sections:
- Goals
- Non-Goals
- User Scenarios OR User Stories
- Requirements (Functional and/or Non-Functional)
- Acceptance Scenarios OR Acceptance Criteria
- Scope

**Report format**: `[required-sections] spec.md - Missing section: <section-name>`

## Rule 2: User Story Format

Validate user stories have proper structure:
- P1/P2/P3 priority labels
- "As a [role], I want [feature], so that [benefit]" format
- Acceptance criteria (list of testable conditions)
- Data requirements
- Integration points
- Error handling

**Report format**: `[user-story-format] spec.md:45 - US1 missing acceptance criteria`

## Rule 3: Vague Language Detection

Flag imprecise language that lacks quantification:

| Vague Term | Replace With |
|------------|-------------|
| "fast", "quick", "rapid" | Quantify with milliseconds (e.g., "< 200ms p95") |
| "easy", "simple", "intuitive" | Define specific UX criteria |
| "scalable", "performant" | Specify load/throughput numbers |
| "secure", "safe" | Reference specific security controls |
| "flexible", "extensible" | Describe actual extension points |

**Report format**: `[vague-language] spec.md:45 - "fast response time" - quantify with metrics`

## Rule 4: Task Format

Validate tasks have all 8 required fields per `tasks-template.md`:

| Field | Description |
|-------|-------------|
| Functionality | What this task does (1 sentence) |
| Purpose | Why this task is needed (1 sentence) |
| Trigger | What causes this to execute or what calls it |
| Progression | Step-by-step flow |
| Success criteria | How to verify it works (deterministic gate) |
| Intake | What inputs/state/preconditions are required |
| Failure handling | How each failure mode is handled (required for interactive tasks) |
| Connects to | What tasks/workflows this enables or depends on |

**Report format**: `[task-format] tasks.md:34 - T003 missing "Success criteria" field`

## Rule 5: Implementation Leak Detection

Flag technology-specific terms in spec.md (specs should be tech-agnostic):
- Framework names: React, Vue, Angular, Express, FastAPI
- Database names: PostgreSQL, MongoDB, Redis
- Infrastructure: Docker, Kubernetes, AWS, Azure
- Libraries: Zod, Prisma, Axios, lodash

**Report format**: `[implementation-leak] spec.md:120 - Found "PostgreSQL" - specs should be technology-agnostic`

## Fix Strategies

| Issue Type | Fix |
|-----------|-----|
| Missing sections | Add section with appropriate content |
| Vague language | Replace with quantified requirements |
| User story format | Add missing fields |
| Task format | Add required fields per tasks-template.md |
| Implementation leaks | Move technology details to plan.md |
