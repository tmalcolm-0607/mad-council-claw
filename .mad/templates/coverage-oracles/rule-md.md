# Coverage Oracle — rule-md.md

What a *complete* `rules/*.md` or `.claude/rules/*.md` must cover. Loaded when content-type is `rule-md-change`.

## Required frontmatter

| Field | Required | Example |
|-------|----------|---------|
| `title` | yes | `title: Triage gate` |
| `status` | yes | one of: `preview \| stable \| deprecated` |
| `since` | yes | ISO-8601 date |
| `last_reviewed` | yes | ISO-8601 date (updated on each QSR) |
| `supersedes` | optional | filename of replaced rule |
| `superseded_by` | optional | filename that replaced this one |

## Required body sections

| # | Section | What it covers |
|---|---------|----------------|
| 1 | **Title + 1-line summary** | What the rule says in one sentence |
| 2 | **Applies to** | Which artifacts/skills/operations are subject to the rule |
| 3 | **Rationale (Why)** | The failure mode this prevents OR the consistency it enforces; cite incident or pattern |
| 4 | **The rule(s)** | Imperative statements; each rule is a single check |
| 5 | **Examples** | ≥1 do, ≥1 don't, drawn from real artifacts |
| 6 | **Anti-patterns** | Common drifts, with explicit "rejected at review" verdict |
| 7 | **Enforcement** | Hook, lint, agent, or human review; cite the actual check |
| 8 | **Cross-references** | Related rules + load-bearing dependencies |
| 9 | **STRIDE Delta** (when changing security-relevant rules) | 6-row Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/Elevation table |

## Severity per missing element

| Element | Missing severity |
|---------|------------------|
| Frontmatter `title` | BLOCKING |
| Frontmatter `status` | **BLOCKING** (per `rules/_status-convention.md`) |
| Frontmatter `since` / `last_reviewed` | MUST-FIX |
| 1 Title + summary | BLOCKING |
| 2 Applies to | **BLOCKING** (rule with no scope is unenforceable) |
| 3 Rationale | MUST-FIX |
| 4 The rule(s) | **BLOCKING** |
| 5 Examples | MUST-FIX |
| 6 Anti-patterns | SHOULD-FIX |
| 7 Enforcement | **BLOCKING** (rule with no enforcement path is theater) |
| 8 Cross-references | SHOULD-FIX |
| 9 STRIDE Delta (when applicable) | MUST-FIX |

## Cross-file consistency (when ≥2 rule-md in PR)

- Status field consistency: if both rules share `status: preview`, both should list a `promote_by` date
- Rationale consistency: rule A says "X is forbidden", rule B says "X is required" → BLOCKING contradiction
- Inheritance graph: if rule A inherits rule B, rule A's status ≤ rule B's status (a stable rule cannot inherit a preview rule without explicit acknowledgment)

## Anti-hallucination

- Status field parsed from frontmatter, not inferred from filename
- "Rationale missing" cites the section header line (or its absence)
- Cross-rule contradictions quote both rules' relevant lines
