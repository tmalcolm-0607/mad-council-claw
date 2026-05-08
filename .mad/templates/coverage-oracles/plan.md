# Coverage Oracle — plan.md

What a *complete* `specs/<N>-<feature>/plan.md` must cover. Loaded when content-type is `plan-change`.

## Required sections

| # | Section | What it covers |
|---|---------|----------------|
| 1 | **Overview** | 2-3 sentences on implementation approach |
| 2 | **Architectural decisions** | Cited ADRs / rationale for highest-impact choices |
| 3 | **Verification Spec** | All 5 sub-sections: Feature Intent, Change Type, Expected Impact, Structural Signals, Not a Failure (mandatory per Phase 0.5) |
| 4 | **Phases** | Numbered phases with: goal, inputs, outputs, gate, atomic tasks |
| 5 | **Quality gates** | Build, test, coverage, lint, bicep — what runs at each phase boundary |
| 6 | **Open questions** | Phase-bound `[NEEDS CLARIFICATION]` markers |
| 7 | **Rollback plan** | How to revert if a phase ships and breaks prod; cite specific commits / migrations / feature flags |

## Severity per missing section (when content-type is `plan-change`)

| Section | Missing severity |
|---------|------------------|
| 1 Overview | MUST-FIX |
| 2 Architectural decisions | MUST-FIX (or "none — straightforward implementation" stated) |
| 3 **Verification Spec (all 5 sub-sections)** | **BLOCKING** (matches plan-gate hook) |
| 4 Phases | **BLOCKING** |
| 5 Quality gates | **BLOCKING** |
| 6 Open questions | SHOULD-FIX (or "none" stated) |
| 7 Rollback plan | **BLOCKING** for prod-touching phases; SHOULD-FIX for purely-internal |

## Verification Spec sub-section check

For each sub-section: missing = BLOCKING.

| Sub-section | Required content |
|-------------|------------------|
| Feature Intent | 1-2 sentences on user-visible outcome |
| Change Type | one of: new-capability, bug-fix, refactor, perf, security, infra |
| Expected Impact | concrete metric/observable that should move |
| Structural Signals | per-FR verification table |
| Not a Failure | outcomes that look like failures but are intentional |

## Phase-boundary check

Each phase row in the Phases section must specify:
- Goal (single sentence)
- Inputs (files/data read)
- Outputs (files/data written)
- Gate (what test/probe must pass before next phase)

## Anti-hallucination

- Verification Spec missing → cite hook output verbatim ("Plan gate warnings for plan.md: [verification-spec-completeness]: …")
- Phase-without-gate → cite the offending phase number

## Cross-references

- `mad-plan/templates/plan.md` — canonical shape
- `.claude/hooks/plan-gate-validate.js` (or equivalent) — runtime hook
