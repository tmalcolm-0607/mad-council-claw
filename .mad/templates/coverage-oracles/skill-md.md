# Coverage Oracle — SKILL.md

What a *complete* `.claude/skills/<name>/SKILL.md` must cover, per `rules/skill-standards.md`. Loaded when input classifies as `skill-md-change`.

## Required frontmatter fields

| Field | Required | Example |
|-------|----------|---------|
| `name` | yes | `name: pr-review` |
| `description` | yes | one sentence |
| `allowed-tools` | yes (or `*` only with explicit auditable exception) | `Read, Bash, Grep` |
| `inherits-rules` | when skill consumes prescriptive content | list of rule paths |
| `tier-exempt` | when skill is pure-utility | list of dimensions: `[evals, templates, multi-pass, best-practices, standards]` |

Forbidden patterns:
- `allowed-tools: *` without an `auditable-exception:` field stating who approved + when (per `rules/dangerous-operations-policy.md` Least-privilege)
- `disable-model-invocation` placed inside `allowed-tools:` list (must be top-level)

## Required body sections

For each: skill emits `present | missing | partial`.

### 1. Title + 1-2-line summary

The `# /<skill-name>` header followed by what the skill does.

### 2. Usage examples

≥1 invocation with arguments and expected behavior.

### 3. Workflow

Numbered steps. If skill inherits `prescriptive-content-review.md`, the standard ordering is:
- Step 0 preflight
- Step 0.5 content-type detection
- Step 1 traditional first lens
- Step 1.5 production grounding
- Step 1.6 risk score (with blast_radius)
- Step 1.7 reference-repo cross-check
- Step 1.8 cross-file consistency
- Step 1.9 completeness oracle
- Step 2+ skill-specific

### 4. Best Practices

Cites `rules/verification-protocol.md` (FETCH BEFORE CITE etc.), confidence floors per severity, anti-hallucination invariants. Or `tier-exempt: [best-practices]` declared.

### 5. Standards

Inherits load-bearing rules; declares naming conventions. Or `tier-exempt: [standards]` declared.

### 6. `--copilot` mode (if multi-pass)

Wired to multi-model dispatch: either inherits `rules/lens-multi-model-review-pattern.md` via `inherits-rules` frontmatter (with body `See \`rules/lens-multi-model-review-pattern.md\` § Mechanism + Inheritance contract.` + non-empty synthesis lens), OR direct `Invoke-CopilotMultiModel.ps1` invocation, OR declared `tier-exempt: [multi-pass]`.

### 7. Templates dir or `tier-exempt: [templates]`

`.claude/skills/<name>/templates/*.md` exists with at least one canonical output shape.

### 8. Evals dir or `tier-exempt: [evals]`

`.claude/skills/<name>/evals/{fixtures,expected}/basic-input.md` exists OR bespoke evals layout under `evals/`.

## Severity per missing section (when content-type is `skill-md-change`)

| Section / field | Missing severity |
|-----------------|------------------|
| Frontmatter `name` | BLOCKING |
| Frontmatter `description` | BLOCKING |
| Frontmatter `allowed-tools` | BLOCKING |
| `allowed-tools: *` without auditable exception | BLOCKING |
| `disable-model-invocation` in wrong place | BLOCKING |
| Title + summary | MUST-FIX |
| Usage examples | MUST-FIX |
| Workflow | MUST-FIX |
| Best Practices section | MUST-FIX (or skip if tier-exempt) |
| Standards section | MUST-FIX (or skip if tier-exempt) |
| `--copilot` wired | SHOULD-FIX (or skip if tier-exempt) |
| Templates dir non-empty | SHOULD-FIX (or skip if tier-exempt) |
| Evals dir with fixture pair | SHOULD-FIX (or skip if tier-exempt) |

## Cross-file consistency (when ≥2 SKILL.md in input)

Compare each pair on:
1. Frontmatter shape — both have same set of required fields populated
2. Tool overlap — if both touch the same external system (e.g., Bash + ADO scripts), consistent allowed-tools wording
3. Step numbering — consistent ordering when both inherit the same rule
4. Inherits-rules — both inherit `prescriptive-content-review.md` if both consume prescriptive content
5. tier-exempt declarations — flag if one declares an exemption the other does not for the same dimension class

## Anti-hallucination

- Frontmatter parsed by reading the YAML block, not regex'd loosely
- "Missing section" cites this oracle's section number verbatim
- Cross-file consistency findings quote both files' relevant lines

## Cross-references

- `rules/skill-standards.md` — the 6 dimensions + tier scoring
- `rules/prescriptive-content-review.md` — the cross-cutting rule this oracle implements for Gap 3
