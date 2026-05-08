# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: User description: "$ARGUMENTS"

## User Scenarios & Testing _(mandatory)_

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently

  REQUIRED CONSIDERATIONS for each user story (answer "None" or "N/A" if not applicable):
  - Access: Who can perform this action? (If restricted, generates auth/permission requirements)
  - Data: What persists after this action? (If data persists, generates data model requirements)
  - Integration: What external dependencies does this trigger? (If external, generates integration requirements & error handling)
  - Presentation: What interface surfaces this? (If user-facing, generates UI/API requirements)

  These fields ensure architectural concerns are consciously addressed and flow into functional requirements when applicable.
  DO NOT skip these fields - explicitly state "None", "N/A", or "Not applicable" if the concern doesn't apply.
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Access**: [Who can perform this action? e.g., "All authenticated users" / "DM only" / "Public" / "Admin role required" / "None - no restrictions"]

**Data**: [What persists after this action? e.g., "User preferences saved to profile" / "Session state updated" / "Append-only event log" / "None - read-only operation"]

**Integration**: [What external dependencies does this trigger? e.g., "Calls Ollama API" / "Requires ComfyUI service" / "Postgres + pgvector" / "None - fully local"]

**Presentation**: [What interface surfaces this? e.g., "React component in SessionView" / "CLI command" / "API endpoint" / "None - background job"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Access**: [Who can perform this action?]

**Data**: [What persists after this action?]

**Integration**: [What external dependencies does this trigger?]

**Presentation**: [What interface surfaces this?]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Access**: [Who can perform this action?]

**Data**: [What persists after this action?]

**Integration**: [What external dependencies does this trigger?]

**Presentation**: [What interface surfaces this?]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Applicable Patterns _(auto-populated)_

<!--
  This section is populated by /mad-spec based on technology detection from the feature description.
  During planning, patterns are validated and compliance is tracked.

  Pattern files are located in .claude/rules/patterns/ and provide:
  - Correct code examples to use as templates
  - Anti-patterns to avoid
  - Enforcement rules (REJECT/WARN)
-->

| Pattern File | Applies To | Key Constraints |
|--------------|------------|-----------------|
| [TO BE POPULATED BY /mad-spec step 2.5] | [TO BE POPULATED] | [See .claude/rules/patterns/] |

<!--
  Technology Detection Keywords:
  - C#/.NET/ASP.NET → dotnet-*.md patterns
  - Marten/Event Sourcing → dotnet-marten-patterns.md
  - API/REST/endpoints → dotnet-architecture.md, dotnet-error-handling.md
  - Authentication/auth/JWT → dotnet-security.md
  - SignalR/WebSocket → signalr-client-patterns.md
  - React/TypeScript/Frontend → react-patterns.md, typescript-patterns.md
  - Playwright/E2E → playwright-e2e-patterns.md
-->

## Requirements _(mandatory)_

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

<!--
  Each FR MUST have two sub-bullets (required by /mad-spec step 4.5 and the Implementability Gate in step 7.1):
  - **Semantic**: what success means in domain terms
  - **Logical Proof**: the concrete command, file, artifact, or observable that demonstrates the FR is satisfied

  Use domain-prefixed IDs when helpful (e.g. FR-AUTH-001, FR-DATA-001). IDs must be unique within the spec.
-->

**FR-001**: [Short imperative title, e.g. "Allow user account creation"]
- **Semantic**: System MUST [specific capability, e.g. "allow users to create accounts with email + password"]
- **Logical Proof**: [e.g. "`POST /users` with valid payload returns 201 and persists row in `users` table"]

**FR-002**: [Short imperative title, e.g. "Validate email address format"]
- **Semantic**: System MUST [specific capability]
- **Logical Proof**: [e.g. "Unit test `EmailValidator.RejectsMalformed` passes; integration test confirms 400 response on `user@`"]

**FR-003**: [Short imperative title]
- **Semantic**: Users MUST be able to [key interaction]
- **Logical Proof**: [the observable / command / artifact]

_Example of marking unclear requirements:_

**FR-004**: [Short title]
- **Semantic**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **Logical Proof**: [TBD once method decided]

**FR-005**: [Short title]
- **Semantic**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]
- **Logical Proof**: [TBD]

### Key Entities _(include if feature involves data)_

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria _(mandatory)_

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]

## E2E Test Coverage _(mandatory for UI features)_

<!--
  For features with UI components (Presentation field != "None"), define critical user journeys that will be validated with E2E tests.

  Journey Priority Levels:
  - P0 (Smoke): Critical paths that MUST work for production (auth, core workflows)
  - P1 (Critical Path): Important workflows validated pre-merge
  - P2 (Regression): Secondary features validated nightly
  - P3 (Optional): Nice-to-have features validated manually

  Each journey maps to ONE Playwright test file. Focus on complete user flows, not individual components.
  Target: 50-200 well-designed journeys covering critical paths (NOT exhaustive coverage).
-->

### Critical User Journeys

| Journey ID | User Story | Journey Description | Priority | E2E Test File | Status |
|------------|------------|---------------------|----------|---------------|--------|
| J-001 | US-001 | [Complete user flow, e.g., "Login → Dashboard → Create Campaign → Verify"] | P0 (Smoke) | `e2e/campaigns/create-campaign.spec.ts` | To Implement |
| J-002 | US-002 | [Another complete flow] | P1 (Critical) | `e2e/[category]/[journey].spec.ts` | To Implement |

**Smoke Test Criteria** (P0 journeys):
- Run on every deployment
- Must achieve 100% pass rate (blocking)
- Cover authentication and core navigation
- Execution time: < 1 minute

**Critical Path Criteria** (P1 journeys):
- Run pre-merge (PR gate)
- Must achieve ≥95% pass rate
- Cover "money paths" (primary value delivery)
- Execution time: 2-5 minutes

### Component Audit

<!--
  For UI features, list new components and their testing coverage.
  Ensures Page Object Model coverage and accessibility compliance.
-->

| Component | Page Object Method | Accessibility (WCAG 2.1) | E2E Coverage | Notes |
|-----------|-------------------|--------------------------|--------------|-------|
| `[ComponentName]` | `[PageClass].[method]()` | [ ] AA Compliant | [ ] Covered | [Any specific considerations] |

**Example**:
| Component | Page Object Method | Accessibility (WCAG 2.1) | E2E Coverage | Notes |
|-----------|-------------------|--------------------------|--------------|-------|
| `CampaignForm` | `CampaignPage.createCampaign()` | [x] AA Compliant | [x] Covered | Keyboard navigation, screen reader labels |
| `PlayerInviteModal` | `InviteModal.sendInvite()` | [x] AA Compliant | [x] Covered | Focus trap, ESC to close |

## Assumptions _(mandatory)_

<!--
  ACTION REQUIRED: List every assumption the spec relies on that is NOT a stated user requirement.
  Each assumption should be falsifiable — if proven wrong, the spec changes.
  Examples: "Target NuGet feed is reachable from dev boxes", "Existing auth middleware is not being migrated in this work",
  "Downstream consumers tolerate additive enum values".
-->

- [Assumption 1 — falsifiable statement]
- [Assumption 2]

## Deployment & Integration Considerations _(mandatory)_

<!--
  ACTION REQUIRED (required by /mad-spec step 4.6). Cover:
  - Infra changes (Azure deployment pipeline, bicep, new Azure resources) — or explicit "None"
  - Feature flags / ring rollout
  - External service dependencies (3rd-party APIs, internal services, feeds)
  - Hand-off points to downstream teams
  - Rollback plan if deploy fails
-->

- **Infra changes**: [Describe, or "None"]
- **Feature flags / rings**: [Describe, or "None"]
- **External dependencies**: [List services/feeds, or "None"]
- **Downstream hand-offs**: [Describe, or "None"]
- **Rollback plan**: [Describe]

## Out of Scope _(mandatory)_

<!--
  ACTION REQUIRED: State what this spec explicitly does NOT cover so reviewers and implementers know where to draw the line.
  Each item should be a concrete exclusion, not a vague "future work" handwave.
-->

- [Out-of-scope item 1 — e.g. "a shared library source changes; consumed as-is from the feed"]
- [Out-of-scope item 2]

## Source Document Coverage _(mandatory when spec references external specs, CHANGELOGs, ADRs)_

<!--
  Required by /mad-spec step 6 (references/source-coverage.md). Prove every source-document claim is mapped to an FR, Assumption, or Out-of-Scope item.
  BLOCKING gate: do not proceed if any source-doc bullet is not mapped.
-->

| Source doc (path / URL) | Claim / bullet | Mapped to | Status |
|---|---|---|---|
| [CHANGELOG.md v1.X entry] | [the specific breaking change or feature] | [FR-XXX / Assumption-N / OoS-M] | Covered / Deferred / Rejected |

## Self-Review _(mandatory — appended by agent after spec is written)_

<!--
  Required by /mad-spec "Output Requirements". Every spec concludes with this block, written by the agent in first-person-as-agent voice.
  Keep honest — document what the agent didn't verify or couldn't confirm.
-->

- **What I am confident about**: [list]
- **What I am uncertain about**: [list; includes [NEEDS CLARIFICATION] markers by reference]
- **What I did not verify**: [skipped checks, missing tooling, un-read files]
- **Ambiguity / risk flags for reviewer attention**: [list]
- **Fallback mode used** (if any): [e.g. "Task dispatch unavailable — reviews performed inline as self-review questions per mad-spec SKILL.md step 7.5 headless fallback"]
