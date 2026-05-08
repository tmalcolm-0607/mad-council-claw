# Troubleshooting Knowledge Base

Structured troubleshooting documentation shared across multiple skills.

## Purpose

Individual skills scope their reference docs internally, but some troubleshooting
knowledge applies across skill boundaries (deployment errors, infrastructure
failures, authentication issues). This directory holds that cross-cutting content
so any skill can search and reference it without duplicating material.

## Organization

| File Pattern | Content |
|--------------|---------|
| `<domain>-errors.md` | Error code registries with category grouping |
| `<domain>-diagnostics.md` | Diagnostic commands, log paths, query patterns |
| `<domain>-solutions.md` | Symptom-Cause-Solution entries |

## Conventions

- Each file covers one domain (e.g., `ev2-errors.md`, `cosmos-diagnostics.md`)
- Use the Symptom-Cause-Solution template from pattern discovery S1/K1
- Keep files under 200 lines; split by sub-domain if larger
- Skills reference these docs via `Read` tool, not by inlining content

## See Also

- `.claude/skills/` -- Individual skill definitions
- `.claude/rules/patterns/` -- Technology-specific coding patterns
- `.mad/docs/patterns-index.md` -- Full pattern inventory
