# Spec Quality Checklist: [FEATURE NAME]

**Date**: [DATE]
**Spec**: [SPEC_PATH]

## Implementability Gates (BLOCKING)

- [ ] **VISION/CONTRACT**: This spec describes what will EXIST (contract), not what COULD exist (vision). Vision docs belong in `specs/ideas/`. Contracts move to `specs/<N>-<feature>/`.
  - Contract = every FR has a Logical Proof pointing to a specific file, endpoint, or command output
  - Vision = FRs describe desired behaviors without specifying observable artifacts
  - **If Vision**: STOP. Move to `specs/ideas/` and write a Contract spec from scratch.

- [ ] **NEWSPAPER TEST**: For each FR, the question "What file or output would I look at to confirm this works?" has a concrete answer (not "it depends on how we build it").

- [ ] **3 NOUNS TEST**: Each user story names >= 3 concrete artifacts (endpoint path, database table, file name, UI element, CLI command, log entry). Stories with only abstract nouns ("the system", "the agent", "the factory") are vision statements.

- [ ] **IMPLEMENTATION SQUEEZE**: For each FR, an agent with only Read/Write/Bash/Grep tools can determine the first command to verify it passes. If not, the FR needs a Logical Proof.

- [ ] **TEST PLAN DERIVABLE**: `/testplan --source spec` can generate a test plan from this spec without errors. Failure to generate = spec is still a vision document.

## Standard Quality Checks

- [ ] All mandatory sections filled (User Scenarios, Requirements, Success Criteria)
- [ ] Each user story has Priority, Independent Test, Access, Data, Integration, Presentation fields
- [ ] Each user story has >= 2 acceptance scenarios in Given/When/Then format
- [ ] <= 3 [NEEDS CLARIFICATION] markers (max)
- [ ] Each FR has BOTH Semantic (what success means) AND Logical Proof (how to prove it)
- [ ] Success criteria are measurable and technology-agnostic
- [ ] Edge cases section addresses boundary conditions
- [ ] Key entities defined with relationships (if data involved)
- [ ] Deployment & Integration section covers operational needs
- [ ] Assumptions documented
- [ ] E2E test coverage matrix present (if UI feature)
- [ ] Applicable patterns section populated (or noted as N/A)
- [ ] **CROSS-MILESTONE COORDINATION**: If this spec creates or alters database tables, migration numbers are assigned from the milestone's dedicated range (see `.claude/rules/cross-milestone-coordination.md`). Schema ownership is documented. No NNN placeholders remain.

## Constitution Compliance

- [ ] **OBSERVABILITY FROM DAY 1** (Principle II): If this feature adds new endpoints, services, or data flows, it includes observability primitives — at minimum: structured logging with correlation IDs, health check coverage, and base metrics. Observability should not be deferred to a later milestone.

## Concept Density Check

- [ ] Spec introduces <= 5 new coined terms (compound concepts not in standard technical vocabulary)
- [ ] Each new coined term is defined in terms of existing system primitives (files, APIs, tables, commands)
- [ ] No section relies on more than 2 undefined/deferred concepts to be implementable

## Notes

_Fill during validation. Document specific issues found._
