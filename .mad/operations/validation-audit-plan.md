# Validation Audit Plan

**Purpose:** systematically prove (or disprove) every claim the MAD kit makes. This is not "will it work in production" — that's `validation-strategy.md`. This is "is what we wrote internally consistent, grounded, and executable?"

**Method:** 10 phases × ~33 checks. Each check is a mechanical verification (grep, read, count) with a pass/fail/gap outcome. Items that fail become new CHK entries; items that pass close existing ambiguity.

**Stop condition:** 2 consecutive iterations produce **zero new HIGH** items.

## Phases

### A — Spec & schemas
- [A1] Every field in `mad.council.a2a.md §7` schema prose has a matching field in `schemas/*.schema.json`.
- [A2] Every `required` field in a schema is populated in the corresponding dry-run example.
- [A3] `additionalProperties: false` does not reject any field mentioned elsewhere.
- [A4] `$id` URLs in schemas are consistent.

### B — Rules
- [B1] Every `rules/*.md` is cited by ≥1 skill SKILL.md.
- [B2] Every `rules/*.md` is cited by ≥1 wiki pattern or reciprocal rule.
- [B3] No rule contradicts another rule (conflict detection via keyword pairs).
- [B4] Every numerical claim in a rule (e.g. "60s timeout", "32KB cap", "3 retries") has a source or derivation.

### C — Wiki
- [C1] Every `wiki/patterns/*.md` has a "Common implementations" or canonical-source section.
- [C2] Every forward reference in wiki resolves to an existing file.
- [C3] Every arxiv citation in wiki files is listed in `wiki/references.md`.
- [C4] Every URL in wiki/references.md is syntactically valid.

### D — Skills
- [D1] Every `skills/*/SKILL.md` cites ≥1 rule + ≥1 wiki pattern + ≥1 script.
- [D2] Every SKILL.md's return codes map to the ones enumerated in spec §11.
- [D3] Every SKILL.md's Output Format corresponds to a schema file.
- [D4] Every skill's `tests.md` has a test per return code.
- [D5] Every skill's `plan.md` milestones sum to the effort estimate at the top.
- [D6] Every skill's `allowed-tools` frontmatter is explicit (no wildcards).

### E — Scripts
- [E1] Every `scripts/*.ps1` stub has a `throw "NOT YET IMPLEMENTED"` so calling it fails loudly.
- [E2] Every script's contract header (SYNOPSIS/DESCRIPTION/PARAMETER) is complete.
- [E3] Every `scripts/*.ps1` referenced in a SKILL.md or plan.md actually exists.
- [E4] Every script has a Layer-1 test listed in `evals/layer-1-unit.md`.

### F — Agents
- [F1] Every `agents/*/agent.md` role name matches `skills/council-review/` role list.
- [F2] Every agent's output schema fields appear in `verdict.schema.json`.
- [F3] Every agent's policy inheritance references `rules/prompt-injection-policy.md`.
- [F4] Every agent's timeout value is consistent (4 min per CHK-043).
- [F5] Every agent has both `agent.md` and `plan.md`.

### G — Evals
- [G1] Every skill's `tests.md` test ID (e.g., T1-01) maps to a Layer in `evals/layer-*.md`.
- [G2] Every `evals/layer-4-adversarial.md` test is marked as locked.
- [G3] Every referenced fixture path in `evals/` follows convention.
- [G4] Every perf assertion in `operations/performance-benchmarks.md` has an evals/perf/ slot.

### H — Metrics
- [H1] Every metric in `metrics/*.md` follows `<component>.<signal>_<unit>` naming.
- [H2] Every alert threshold has a runbook pointer.
- [H3] Every skill emits an `invoke_skill <name>` span (per OTel GenAI).
- [H4] Every `*_total` counter has labels documented.

### I — Operations
- [I1] Every `operations/*.md` has a "Verification" or "Related" section.
- [I2] Every operations claim has a validation-strategy layer assigned.
- [I3] Every phase plan (`plans/phase-*.md`) cross-references relevant operations docs.

### J — Cross-cutting
- [J1] Every CHK item in `_review-checklist.md` has status (open/closed/deferred).
- [J2] `_loop-state.md` inventory count matches actual file count.
- [J3] Every internal `file:line` style reference resolves.
- [J4] Every "Related" section lists only existing files.

## Execution order

- **Iter 29**: Phase A + B (spec/schemas, rules)
- **Iter 30**: Phase C + D (wiki, skills)
- **Iter 31**: Phase E + F (scripts, agents)
- **Iter 32**: Phase G + H (evals, metrics)
- **Iter 33**: Phase I + J (operations, cross-cutting)
- **Iter 34+**: remediate HIGH findings; continue until 2 consecutive zero-HIGH

## Reporting format

Each iter produces a findings block in `_review-checklist.md`:

```
### Iter N audit findings — Phase X.Y

- [VERIFIED] A1 — N schemas checked, 0 divergences
- [VERIFIED] A2 — …
- [HIGH] Axx — <description>; fix tracked as CHK-NNN
- [MEDIUM] Axx — <description>; fix tracked as CHK-NNN
```

Severity rubric matches `_review-checklist.md §Severity rubric`:
- **CRITICAL** — blocks scaffold coherence (e.g., schema rejects its own dry-run example)
- **HIGH** — misleads implementer (e.g., skill cites a script that doesn't exist)
- **MEDIUM** — quality/consistency (e.g., inconsistent citation format)
- **LOW** — cosmetic (e.g., broken link that is clearly a typo)

## Related

- `operations/validation-strategy.md` — per-deployment validation (this audit plan is internal-consistency validation).
- `_review-checklist.md` — where findings land.
- `_loop-state.md` — iter log.
