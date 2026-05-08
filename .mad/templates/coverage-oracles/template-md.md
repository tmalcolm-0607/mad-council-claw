# Coverage Oracle — template-md

What a *complete* `templates/*.md` (under `.claude/skills/<name>/templates/` or `.mad/templates/`) must cover. Loaded for `template-change`.

## Required sections

| # | Section | What it covers |
|---|---------|----------------|
| 1 | **Title + 1-line purpose** | What artifact this template shapes |
| 2 | **Canonical example** | A complete, fillable example with placeholders that show shape, not specific content |
| 3 | **Required vs optional fields** | Frontmatter or section enumeration with `required \| recommended \| optional` |
| 4 | **Field/section semantics** | Each field cites: what populates it, accepted values, validation rule |
| 5 | **Anti-hallucination requirement** | What must be cited from real sources (no fabrication) |
| 6 | **Cross-references** | Related templates, the rule the template implements, the consuming skill |

## Severity per missing section (when content-type is `template-change`)

| Section | Missing severity |
|---------|------------------|
| 1 Title + purpose | BLOCKING |
| 2 Canonical example | **BLOCKING** (template without an example is unusable) |
| 3 Required vs optional fields | MUST-FIX |
| 4 Field semantics | MUST-FIX |
| 5 Anti-hallucination requirement | SHOULD-FIX |
| 6 Cross-references | SHOULD-FIX |

## Cross-template consistency (when ≥2 templates in PR)

- Examples consistency: if both shape the same artifact class, examples follow the same field ordering
- Required field overlap: if template A says "frontmatter `status` required", template B (same class) says the same
- Reference back-links: each template links back to its consuming skill and rule

## Anti-hallucination

- Example must be illustrative (placeholder values clearly marked) OR runnable; can't claim "use this template" if the example is broken
- Required-field claims must match what the consuming skill actually checks
