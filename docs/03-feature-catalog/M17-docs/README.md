---
artifact-class: milestone-overview
generated-by: hand-authored (wave-007 / lane-a)
status: red
milestone: M17
short-slug: docs
features: F-114..F-118
authored: 2026-05-06
---

# M17 — Docs

The engineering-documentation plane. Five docs deliverables that together get a new engineer from "downloaded the installer" to "understanding the engine well enough to author a skill, add an MCP server, or wire an automation". Mirrors clawpilot's `docs/` shape where applicable; deviates where the engine's council-centric model differs. Every claim cites the corresponding kit rule or F-NNN ledger per `rules/verification-protocol.md` (FETCH BEFORE CITE) — no orphan claims.

This milestone is the load-bearing surface for "engineers can extend the engine without reading the source first" — the inverse of the unmaintained-OSS default. It consumes M0..M16 (docs describe what those milestones built) and produces the contributor-onboarding plane.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-114 | readme-quickstart | Top-level `README.md`: install + first-launch + 5-minute quickstart; <10-min wall-clock to first council-review |
| F-115 | architecture-docs | `docs/architecture/` mirroring clawpilot's shape; 8 topics + Mermaid diagrams + ledger cross-links |
| F-116 | skill-authoring-guide | `docs/skill-authoring-guide.md`: SKILL.md template + 6-dimension compliance + canonical-skill-only contract |
| F-117 | mcp-server-adding-guide | `docs/mcp-server-adding-guide.md`: tier model + consent gates + prompt-injection threat framing |
| F-118 | automation-cookbook | `docs/automation-cookbook.md`: 6+ end-to-end recipes (cron / CLI / MCP / autonomous-loop / multi-skill / a2a) |

## Dependency DAG

```
M0..M16 (every prior milestone)  ──→ docs describe their contracts

F-114 README              ──→ entry point; cross-links to F-115/F-116/F-117/F-118
F-115 architecture-docs   ──→ F-116 (skill authoring cross-links architecture)
                          ├──→ F-117 (MCP guide cross-links MCP boundary)
                          └──→ F-118 (cookbook cross-links component boundaries)

F-104 electron-builder    ──→ F-114 (install section links to release artifacts)
F-109 cli-binary          ──→ F-114 (quickstart references npm install path)
F-076 MSAL                ──→ F-114 (first-launch auth)
F-113 telemetry-opt-in    ──→ F-114 (first-launch telemetry default)
F-040 skills runtime      ──→ F-116 (skill authoring describes runtime contract)
F-029 MCP runtime         ──→ F-117 (MCP guide describes runtime contract)
F-023 cron + F-024 CLI    ──→ F-118 (recipes 1, 2, 4)
```

## Milestone exit criteria

- All 5 ledgers GREEN
- README walks a fresh GitHub visitor to first `/council-review` against a newly-created channel in <10 minutes wall-clock (verified by usability harness)
- `docs/architecture/` has 8 topic files (process model, IPC contract, lifecycle, identity, storage, governance, telemetry, MCP+skills) — each with a Mermaid diagram and ledger cross-links
- Skill-authoring-guide enables a first-time author to produce a Tier-A or higher skill on first attempt (verified via `/skill-audit`)
- MCP-server-adding guide walks an engineer from "I want to add msft-learn" to "first tool call returns successfully" in <5 minutes wall-clock
- Automation cookbook has 6 recipes minimum, each with prerequisites + step-by-step + expected wall-clock + expected outputs + pitfalls
- CI link-check + Mermaid-parse + recipe-syntax-check passes on every PR touching `docs/`
- Every architecture / skill / MCP / cookbook claim cites the corresponding kit rule or F-NNN ledger (FETCH BEFORE CITE per `rules/verification-protocol.md`)
- Loop-related recipes use "iter N checkpoint" framing per `rules/loop-stop-language-discipline.md`; never "loop complete" mid-run

## Out of scope (tracked elsewhere)

- Marketing / landing-page README — F-114 is engineering-focused install + smoke-test
- Multi-language READMEs (i18n) — v1.5
- Animated GIFs / video walkthroughs in any doc — v1 = text + screenshots only
- Per-feature design docs (one per F-NNN) — handled by per-feature ledgers under `docs/03-feature-catalog/`
- Decision-log archaeology (ADRs for past decisions) — v1 covers current state only
- Performance tuning + scaling guides — v1.5
- Internal Microsoft-only architecture (Geneva / WorkIQ inner workings) — public-architecture only
- Sandbox skill testing harness — v1.5; v1 = describe contract, users validate against own engine
- Marketplace / skill-publishing pipeline — M11+ scope
- Skill-versioning semver enforcement — v1 = docs convention only
- Auto-generated SKILL.md scaffolding tool — v1.5
- Building / publishing your own MCP server (server-side authoring) — v1 = adding existing servers only
- MCP-server marketplace UX — M11+ scope
- Auto-discovery of locally-installed MCP servers — v1.5
- OAuth-based MCP server auth setup — v1.5
- Visual workflow builder UI for automation — v1 = text recipes only
- Marketplace of community recipes — M11+ scope
- Per-recipe scheduling beyond cron expressions — v1.5
- Automation analytics / "which recipes ran this week" dashboard — v1.5
- Recipe versioning + import/export between users — v1.5

## Provenance

`cp:README.md` (clawpilot README structure), `cp:docs/architecture/`, `cp:docs/architecture/electron-process-model.md`, `cp:docs/architecture/ipc-contract.md`, `cp:docs/skills`, `cp:docs/mcp`, `cp:docs/automation`, `cp:docs/quickstart`, `kit:rules/verification-protocol.md` (FETCH BEFORE CITE applied across every doc), `kit:rules/skill-standards.md` (F-116 centerpiece), `kit:rules/canonical-skill-only.md` + `kit:rules/canonical-artifact-frontmatter.md` (F-116 contract docs), `kit:rules/mcp-tiering.md` (F-117 tier model), `kit:rules/dangerous-operations-policy.md` (F-117 + F-118 consent gates), `kit:rules/prompt-injection-policy.md` (F-117 threat framing), `kit:rules/loop-cadence-discipline.md` + `kit:rules/autonomous-loop-discipline.md` + `kit:rules/loop-stop-language-discipline.md` (F-118 loop recipes), `kit:rules/no-silent-deferrals.md` (every doc names absences explicitly), `foundational-plan.md` M17 docs section (5-deliverable scope). Per-ledger `provenance.surfaces`.
