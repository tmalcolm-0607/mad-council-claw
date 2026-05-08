---
globs: "**/*.cs,**/*.tsx,**/*.ts,**/*.bicep,**/*.csproj,**/Directory.Packages.props"
---

# Code Review Conventions

When reviewing code changes in LENS repositories, always check against the project's `CLAUDE.md` and `.claude/rules/` conventions. Carve-outs are listed inline so reviewers (model and human) don't need to chase back to CLAUDE.md to disambiguate — if a rule says "no carve-outs," treat it as absolute.

Key org-wide rules that apply to ALL LENS repos:

- **No `var` keyword** — use explicit type declarations. *Carve-out:* `var` is acceptable in LINQ query continuations where the element type is unambiguous from the query expression.
- **ParameterContracts** (from `Microsoft.LENS.Common.Core`) — use `ParameterContracts.CheckIsNotNull()` for parameter validation, not `?? throw` or `ThrowIfNull`. *Carve-out:* required only on public / internal entry points; private methods are exempt.
- **One class per file** — every public type gets its own `.cs` file. *No carve-outs.*
- **No nested IFs** — use guard clauses and early returns. *No carve-outs.*
- **Sealed classes** — use `sealed` for implementations not designed for inheritance. *Carve-out:* skip if the class has subclasses elsewhere in the codebase.
- **No `_` prefix** — use `this.` for instance members. *No carve-outs.*
- **Layered architecture** — API → BusinessLogic → DataAccess → Common (no skip/reverse). *No carve-outs.* Detailed standards forthcoming in Jamie Cote's layered-architecture document; the link will be folded in once published.

Run `/lens-multi-model-review:multi-model-review` for a full multi-model review with LENS context injection.

## Output contract

When emitting findings on a diff, every finding must follow the shape below. Without a shared shape, cross-model dedup collapses and "no `var`" lands at the same weight as "fail-open authorization" — the user gets a flat wall of findings instead of a ship / no-ship signal.

```
[<severity>] <file>:<line> — <one-line title>

Evidence:
  <offending snippet, ≤6 lines>

Rule:
  <citation: CLAUDE.md path:line, .claude/rules/<file>.md, or S# from the security checklist>

Suggested fix:
  <one-line description, or a code snippet ≤6 lines>
```

Severities:

- **[BLOCKING]** — security CRITICAL, broken build, data corruption, regulatory violation. Cannot ship.
- **[MUST-FIX]** — convention violation where no carve-out applies, or a clear bug. Fix in this PR.
- **[SHOULD-FIX]** — likely bug, weak test coverage, missing XML docs on public API.
- **[CONSIDER]** — style nit, refactor suggestion, optional improvement.
- **[PRAISE]** — explicitly call out things done well; balances the signal so the user gets a ship / no-ship verdict rather than a wall of negatives.

A finding without a cited rule is not actionable — drop it rather than emit it.
