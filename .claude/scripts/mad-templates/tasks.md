# Tasks: <channel-purpose>

<!--
MAD tasks template per mad.council.a2a.md §4.4 and plugins/dotnet-dev-kit/skills/mad-tasks/SKILL.md.

Tier auto-selected by /council-post when MAD-enabled channel first receives
type:task posts:

  MINIMAL  — ≤3 stories, no escalation keywords       → flat list below
  STANDARD — 4-10 stories, moderate complexity        → grouped by phase with deps
  FULL     — >10 stories OR high-complexity keywords  → full format + parallel annotations + per-phase verification

Task format (strict):
  - [ ] [T001] [US-001] Do the thing
  - [ ] [T002] [US-001] Do the related thing (depends on T001)
  - [ ] [T003] [US-002] Do the other thing (parallel with T001)

Checkboxes are auto-updated by `/council-resolve` when the resolve summary or
thread messages contain the matching [T###] patterns.
-->

<!-- TEMPLATE AUTO-SELECTS ONE OF THESE FORMATS AT FIRST TASK POST -->

<!-- ================================================================== -->
<!-- MINIMAL — ≤3 stories, no escalation                                 -->
<!-- ================================================================== -->

## Tasks

- [ ] [T001] [US-001] ...
- [ ] [T002] [US-001] ...

<!-- ================================================================== -->
<!-- STANDARD — 4-10 stories, moderate complexity                        -->
<!-- ================================================================== -->

<!--
## Phase 1: <name>

- [ ] [T001] [US-001] Do first thing
- [ ] [T002] [US-001] Do second (depends on T001)
- [ ] [T003] [US-002] Parallel with T001

## Phase 1 Verification
- [ ] Build passes
- [ ] Tests pass
- [ ] Coverage ≥ threshold

## Phase 2: <name>
...
-->

<!-- ================================================================== -->
<!-- FULL — >10 stories or high-complexity                                -->
<!-- ================================================================== -->

<!--
## Phase 1: <name>

### Parallel execution example
| Group | Tasks | Rationale |
|---|---|---|
| A | T001, T003, T005 | Different files, no deps |
| B | T002 → T004 | Serial: T004 depends on T002 |

### Tasks

- [ ] [T001] [US-001] ...
- [ ] [T002] [US-001] ...
...

## Phase 1 Verification
- [ ] ...
-->

---

**Tasks metadata**:
- Created: <!-- ISO-8601 -->
- Tier: `<MINIMAL | STANDARD | FULL>` <!-- auto-selected -->
- Total tasks: <!-- count -->
- Completed: <!-- count -->
- Gate status: `open` (passes when all tasks completed + all phase checklists green)
