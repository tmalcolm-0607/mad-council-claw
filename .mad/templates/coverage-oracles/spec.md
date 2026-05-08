# Coverage Oracle — spec.md

What a *complete* `specs/<N>-<feature>/spec.md` must cover. Loaded when content-type is `spec-change`. Extends the 6 implementability gates from mad-spec.

## Required sections

| # | Section | What it covers |
|---|---------|----------------|
| 1 | **Problem statement** | The user-visible problem (not the solution) |
| 2 | **Audience / actors** | Who interacts with this feature (roles, agents, services) |
| 3 | **User stories** | ≥3 stories, each naming ≥3 concrete artifacts (3 Nouns Test) |
| 4 | **Functional Requirements** | Numbered FR-1, FR-2, … each with: description + Logical Proof (concrete file/endpoint/command/test that confirms it) |
| 5 | **Non-functional requirements** | Latency, throughput, availability, security; with measurable targets |
| 6 | **Out-of-scope** | Things explicitly NOT being built; prevents scope creep |
| 7 | **Open questions** | `[NEEDS CLARIFICATION]` markers explicitly enumerated |
| 8 | **Implementability gates** | All 6 gates listed with status (✓ / ✗ / non-blocking) — Vision/Contract flag, Newspaper Test, 3 Nouns Test, Implementation Squeeze, Concept Density, Test Plan Generation |

## Severity per missing section (when content-type is `spec-change`)

| Section | Missing severity |
|---------|------------------|
| 1 Problem statement | BLOCKING |
| 2 Audience / actors | MUST-FIX |
| 3 User stories (≥3) | **BLOCKING** |
| 4 Functional Requirements (with Logical Proof) | **BLOCKING** |
| 5 Non-functional requirements | MUST-FIX (or "none" stated explicitly) |
| 6 Out-of-scope | SHOULD-FIX |
| 7 Open questions | MUST-FIX (silent gaps inflate scope later) |
| 8 Implementability gates | **BLOCKING** (per mad-spec) |

## Special checks

- **FR Logical Proof presence**: every FR must have a Logical Proof; missing Logical Proof on any FR = BLOCKING
- **Vision-vs-Contract**: if the spec lives under `specs/ideas/`, the implementability gates are non-blocking but still emitted; if under `specs/<N>-feature/`, they are blocking
- **Concept density**: warn if >5 new coined terms not defined via primitives

## Anti-hallucination

- Each missing finding cites: oracle section number + spec path + line where it should appear
- For "FR-3 missing Logical Proof": quote the FR-3 line and show what's absent
- Implementability gate failures cite the gate number from mad-spec, not just the gate name

## Cross-references

- `mad-spec/SKILL.md` § implementability gates
- `mad-spec/templates/spec.md` — canonical shape
- `rules/prescriptive-content-review.md` § Gap 3
