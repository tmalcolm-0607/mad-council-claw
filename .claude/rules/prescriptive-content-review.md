---
title: Prescriptive content review
status: preview
since: 2026-05-01
last_reviewed: 2026-05-01
---

# Prescriptive content review

**Applies to:** every skill that reviews, audits, or produces *prescriptive* artifacts — material that other engineers will read and apply (docs, SKILL.md bodies, `rules/*.md`, templates, design docs, config-as-code, ADRs). Specifically: pr-review, code-reviewer, design-review, mad-spec, mad-plan, code-audit, refresh-best-practices, refresh-references, claude-md-refresh, council-review, validate-features, validate-dashboard, pattern-generate.

**Source:** post-mortem of PRs #5157555 + #5157551 (May 2026). Six structural misses identified in pr-review surface as cross-cutting gaps in the skill kit. This rule formalizes the patterns each affected skill must inherit.

## The eight gap categories (to be closed at every inheriting skill)

Originally six (May 2026 post-mortem). Two added (Gaps 7 and 8) from the May 2026 LENS-CMS PR-batch calibration run after the council-mode false-positive on PR #5152767 and the telemetry contract drift finding on PR #5155393.

### Gap 1 — Production grounding triggered too narrowly

**Symptom:** Skills pull external context (WorkIQ, ADO history, lessons-learned) only on narrow signal patterns (work-item ID, branch name, feature area). Topics described in prose without IDs never trigger the lookup.

**Rule:** Production-grounding fires on any of:
- Explicit work-item / PR / incident ID anywhere in input
- Topic keywords matching `.mad/learning/topic-grounding-keywords.json` (e.g., "cosmos repository", "etag propagation", "validator wiring")
- Reference-repo path mentions in input

**Implementation:** every inheriting skill calls `pwsh -NoProfile -File .claude/scripts/Pull-ProductionGrounding.ps1 -Input <input-file>` in Step 1.5 (or equivalent). The script returns matched lessons-learned + recent incidents + author voice signals.

### Gap 2 — Reference-repo cross-check gated on consumer code, not prescriptive content

**Symptom:** When input *prescribes* a pattern (a doc says "ETag propagation works like X"), nothing verifies X actually exists in reference repos. Cross-repo trigger only fires when consumer-side code uses LENS-Common.

**Rule:** Any skill consuming prescriptive content calls reference-repo verification when:
- Input contains code blocks claiming a pattern (≥3 lines)
- Input contains "should" / "must" / "always" / "never" prescriptions
- Input is a doc/skill/rule/template prescribing how to build something

**Implementation:** Step 1.7 in inheriting skills MUST invoke the reference-repo cross-check on prescriptive content, decoupled from any consumer-code-uses-LENS-Common gate.

### Gap 3 — No completeness oracle (absence is invisible)

**Symptom:** Skills check what is present in input but have no baseline of what *should* be present for the input's content-type. Missing sections look like "no findings".

**Rule:** Every skill consuming a content-type-classified input loads a coverage oracle from `.mad/templates/coverage-oracles/<content-type>.md` and emits a per-oracle-section "present | missing | partial" pass.

**Implementation:** new directory `.mad/templates/coverage-oracles/` holds one file per content-type. Skills resolve content-type via the dispatcher in Gap 6, then load the matching oracle.

**Content-type → oracle mapping** (matches `Detect-ContentType.ps1` `oracleMap`):

| Content-type | Oracle file |
|--------------|-------------|
| `code-change` | `.mad/templates/coverage-oracles/handler-tests.md` |
| `doc-change` | `.mad/templates/coverage-oracles/doc-generic.md` |
| `skill-md-change` | `.mad/templates/coverage-oracles/skill-md.md` |
| `rule-md-change` | `.mad/templates/coverage-oracles/rule-md.md` |
| `template-change` | `.mad/templates/coverage-oracles/template-md.md` |
| `spec-change` | `.mad/templates/coverage-oracles/spec.md` |
| `plan-change` | `.mad/templates/coverage-oracles/plan.md` |
| `tasks-change` | `.mad/templates/coverage-oracles/tasks.md` |
| `infra-change` | `.mad/templates/coverage-oracles/bicep.md` |
| `config-change` | `.mad/templates/coverage-oracles/config.md` |
| `ev2-config-change` | `.mad/templates/coverage-oracles/ev2-config.md` (added 2026-05; covers Ev2 ScopeBindings/ServiceSpec/RolloutSpec/StageMap/env-config/parameter files) |

### Gap 4 — No same-type cross-file consistency pass

**Symptom:** When ≥2 files of the same type appear together (2 SKILL.md, 2 rule files, 2 config files, 2 specs), skills review each in isolation; never diff them against each other for inconsistent claims.

**Rule:** When input includes ≥2 files matching the same content-type, run a consistency-diff pass:
- Frontmatter consistency (status, applies-to scope, version)
- Cross-file claim consistency (file A says "X is forbidden", file B uses X)
- Cross-file naming consistency (singular/plural; field name conventions)

**Implementation:** Step 1.8 in inheriting skills.

### Gap 5 — Risk-score blind to blast radius (audience size)

**Symptom:** A teaching-skill PR that shapes how every future engineer onboards scored 0 in the risk table because it has no test failures, no migrations, no infra. Stayed in standard two-pass; never escalated to council where Architect would catch scoping issues.

**Rule:** Risk score adds a `blast_radius` axis (0-10):
- 0: change affects only its own callers (typical code change)
- 3: change affects one team's repos (private library version bump)
- 5: change affects org-internal docs/config (one-team SKILL.md)
- 7: change affects cross-team prescriptive material (kit rules, kit templates, doc patterns)
- 10: change is onboarding-grade material (new-engineer-facing skill, public templates, top-level CLAUDE.md)

Final risk score = max(traditional risk axes, blast_radius). When blast_radius ≥ 7, skill auto-escalates to `--council` mode regardless of other axes.

**Implementation:** every inheriting skill that has a risk table adds a row with `blast_radius` and applies the auto-escalate gate.

### Gap 6 — Content-type detection is missing or per-skill ad-hoc

**Symptom:** Skills assume "code change" by default. Doc PRs, skill-body PRs, config-only PRs, design-doc PRs all get reviewed with the same lenses. The right first finding for a teaching doc (e.g., "PATCH section missing") never surfaces because nothing classifies the input as a teaching doc.

**Rule:** A shared content-type dispatcher classifies input before any rules-pass. Output is one of:
- `code-change` (source files in src/, language-typed)
- `doc-change` (Markdown under docs/, design docs, READMEs)
- `skill-md-change` (`.claude/skills/*/SKILL.md`)
- `rule-md-change` (`rules/*.md`, `.claude/rules/*.md`)
- `template-change` (`templates/*.md`, `.mad/templates/*`)
- `config-change` (settings.json, mcp.json, .yml, .yaml)
- `spec-change` (`specs/<N>-*/spec.md` or under `specs/ideas/`)
- `plan-change` (`specs/<N>-*/plan.md`)
- `tasks-change` (`specs/<N>-*/tasks.md`)
- `infra-change` (`*.bicep`, `*.bicepparam`, ARM templates, Helm charts)
- `mixed` (any combination)

**Implementation:** `.claude/scripts/Detect-ContentType.ps1`. Inheriting skills call it as Step 0.5 (right after preflight, before any other lens). Result drives:
- Which oracle to load (Gap 3)
- Whether reference-repo cross-check fires (Gap 2)
- Severity calibration (different content-types weight findings differently — see below)

### Gap 7 — Scope-vs-claim drift (PR title overstates / understates the diff)

**Symptom (May 2026 calibration)**: a Council Architect on PR #5152767 declared "PR title oversells scope — lifecycle methods aren't in the diff" — a finding that turned out to be a false positive caused by reading the wrong source. But the inverse failure mode is real: a PR title that promises one thing while the diff delivers another (or vice versa) is genuinely confusing for reviewers and load-bearing for archaeology.

**Rule:** when the dispatcher classifies a PR, also extract the title's load-bearing nouns/verbs and check that they appear somewhere in the changed-file paths or diff content. Three states:
- **PASS**: title nouns appear in diff (e.g., title "feat(dft-agency-lookup)" + paths under `/dft/` ✓)
- **WARN**: title nouns are general; diff is consistent but title is non-specific
- **FLAG**: title nouns absent from diff entirely → SHOULD-FIX scope-vs-claim drift finding

**Implementation:** new step in dispatcher (or follow-on script `Detect-ScopeClaimDrift.ps1`) that returns a structured drift report. Avoid the "title oversells" false positive seen pre-G/E by always verifying against PR-branch source, not working tree.

### Gap 8 — PR-description contract drift (numeric promises in description not kept by code)

**Symptom (May 2026 calibration)**: PR #5155393 description promised `cms.lookup.write_failures` counter with 4 specific tags `(operation, lookup_type, failure_class, cosmos_status_code)`. Actual code emits a 3-tag success/failure counter. Geneva alerts in deferred work (T081-T084) would have matched zero series. Caught only because Architect read TelemetryConstants vs PR description carefully.

**Rule:** for every numeric / contract claim in PR description (counter names, tag names, EventIds, partition keys, throughput targets, RU costs, latency targets), greppable against source. If description says "we add counter X with tags Y" or "EventId N", the source MUST contain those exact strings. Mismatch → MUST-FIX.

**Implementation:** new script `Detect-ContractDrift.ps1` (next iter G14) — extracts numeric/contract claims from PR description (regex: `cms\.[a-z_]+`, `EventId(?:s)?\s*\.\s*[A-Za-z]+`, `partition[\s-]?key\s*[:=]\s*[/A-Za-z]+`, `\b\d{4}\b` near EventId context, etc.) and greps for each in the PR-branch source. Findings have severity per `rules/prescriptive-content-review.md` § Severity calibration. This is the Step 1.7 enhancement called out in the May 2026 calibration log.

**LENS telemetry contract regexes (CC-12):** the canonical regex set above is extended for LENS services with the following patterns, derived from `lens-telemetry` SKILL.md v1.3.0 Standards 5, 7, 8, 10, 14:

| Regex | Detects | Source MUST contain |
|-------|---------|--------------------|
| `\[Counter\(` | `[Counter(...)]` partial-method declarations promised in PR description | A matching `static partial class { [Counter(...)] public static partial ... }` declaration in the PR-branch source — verifies the source-generator instrument exists with promised dimensions |
| `\[Histogram\(` | `[Histogram(...)]` partial-method declarations | Same as `[Counter(`; additionally check that an `ExplicitBucketHistogramConfiguration` view is registered via `configureViews:` on `AddLensTelemetry` per Standard 13 (rule #68 in implementation-checklist.md) |
| `\[StructuredEvent\(` | `[StructuredEvent("TableName")]` event class declarations | A `[StructuredEvent("...")] sealed partial class : IStructuredLogEvent` in the PR-branch source AND a corresponding `<Source>` entry in the Geneva monitoring agent XML (rule #44c) |
| `RequestContextItems\.[A-Z]\w+` | References to canonical accessors (`ErrorCode`, `ReliabilityScenario`, `IsSynthetic`, `ExceptionType`) | The accessor exists on `Microsoft.LENS.Common.Core.RequestContextItems`; PR description claims about new accessors must add them in `Core/Context/RequestContextItems.cs` |
| `MiseAuthContextBuilder` | PR description promising MISE V2 wiring | `services.AddMiseAuthContextBuilder()` call in `Program.cs` / DI extensions per Standard 14 (rule #70) |

These regexes drive the `Detect-ContractDrift.ps1` LENS-extension lens — every claim that names one of these constructs in PR description prose must have a greppable presence in the PR-branch source. Mismatches escalate per Severity calibration (`code-change` → MUST-FIX; `skill-md-change` / `rule-md-change` → BLOCKING).

## Severity calibration by content-type

Per-content-type severity weighting (overrides default `pr-review/templates/review-findings.md` confidence floors):

| Content-type | Structural absence | Stylistic precision | Cross-file inconsistency |
|--------------|--------------------|--------------------|--------------------------|
| `code-change` | MUST-FIX | SHOULD-FIX | MUST-FIX |
| `doc-change` | **BLOCKING** | CONSIDER | MUST-FIX |
| `skill-md-change` | **BLOCKING** | SHOULD-FIX | **BLOCKING** |
| `rule-md-change` | **BLOCKING** | SHOULD-FIX | **BLOCKING** |
| `template-change` | **BLOCKING** | SHOULD-FIX | MUST-FIX |
| `config-change` | MUST-FIX | CONSIDER | **BLOCKING** |
| `spec-change` | **BLOCKING** | SHOULD-FIX | MUST-FIX |
| `infra-change` | **BLOCKING** | CONSIDER | **BLOCKING** |

The "right first finding" for a teaching doc is "PATCH section missing" (structural absence in `doc-change`), not "field rename incomplete in line 219" (stylistic precision).

## Inheritance

Inheriting skills add to their frontmatter:

```yaml
inherits-rules:
  - rules/prescriptive-content-review.md
```

And in the skill body, the standard workflow becomes:

```
Step 0     preflight
Step 0.5   content-type detection (Detect-ContentType.ps1)
Step 1     traditional Step 1
Step 1.5   production grounding (Pull-ProductionGrounding.ps1) — fires on ID OR topic keyword OR reference-repo mention
Step 1.6   risk score (with blast_radius axis; auto-escalate to --council if ≥7)
Step 1.7   reference-repo cross-check on prescriptive content (decoupled from any consumer-code gate)
Step 1.8   same-type cross-file consistency (when ≥2 files of same content-type in input)
Step 1.9   completeness oracle pass (load coverage-oracles/<content-type>.md and check each section)
Step 2+    skill-specific lenses
```

## STRIDE Delta

| Category | Expand attack surface? | Mitigation |
|----------|------------------------|------------|
| Spoofing | No | — |
| Tampering | No | — |
| Repudiation | No | — |
| Info Disclosure | No | — |
| DoS | No (oracles are static; reference-repo reads are bounded) | — |
| Elevation | No | — |

## Anti-hallucination

- Coverage-oracle "missing" findings cite the oracle file path + section name verbatim
- Reference-repo cross-check findings cite reference-repo file:line where the pattern actually lives (or "not found in any reference repo")
- Production-grounding signals cite source URL / message ID / incident ID
- Blast-radius axis value cites which trigger fired (path pattern, keyword match, frontmatter scope)

## References

- Post-mortem: PR #5157555 + #5157551 review (May 2026)
- `rules/skill-standards.md` § Dimension 2 — confidence floors (this rule overrides for content-type)
- `pr-review/templates/review-findings.md` — finding shape (severity tags inherit)
- `mad-analyze/SKILL.md` — example of cross-artifact consistency at the spec/plan/tasks level (Gap 4 generalizes)
