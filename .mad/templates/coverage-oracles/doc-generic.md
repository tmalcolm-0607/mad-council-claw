# Coverage Oracle — generic documentation

What a *complete* doc-change must cover when the topic doesn't have a dedicated oracle (cosmos-doc, etc.). Skills load this oracle for `doc-change` content-type when no topic-specific oracle matches.

## Required sections

| # | Section | What it covers |
|---|---------|----------------|
| 1 | **Audience + scope** | Who reads this and what problem it solves; bounds what is and isn't in scope |
| 2 | **Mental model / context** | Enough background that a new engineer can navigate; cite ADRs, related rules, related code |
| 3 | **Concrete examples** | ≥1 worked example. Code blocks must be runnable or annotated as illustrative |
| 4 | **Anti-patterns** | What NOT to do, with a concrete bad example for the most common mistake |
| 5 | **Cross-references** | Pointers to: related rules, source code, ADRs, schemas, dashboards |
| 6 | **Status / lifecycle** | `preview \| stable \| deprecated`; last-reviewed date; promote/retire path |
| 7 | **How to verify** | The reader can confirm they applied this correctly — concrete check (test, lint, grep, behavioral probe) |

## Severity per missing section (when content-type is `doc-change`)

| Section | Missing severity |
|---------|------------------|
| 1 Audience + scope | BLOCKING (without it the doc has no purpose) |
| 2 Mental model / context | MUST-FIX |
| 3 Concrete examples | **BLOCKING** (a teaching doc with no examples is unverifiable) |
| 4 Anti-patterns | MUST-FIX |
| 5 Cross-references | SHOULD-FIX |
| 6 Status / lifecycle | MUST-FIX (per `rules/_status-convention.md`) |
| 7 How to verify | **BLOCKING** (without it the prescription is untestable) |

## Anti-hallucination

- Section presence cited verbatim from oracle
- Don't claim "section is partial" without quoting what's there
- Don't claim a doc is teaching-grade if it has no audience declaration
